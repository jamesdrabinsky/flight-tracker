require 'date'

require "sinatra"
# require "sinatra/content_for"
# require "tilt/erubis"
require 'bcrypt'
require "pg"

require "pry"

# require_relative "database_persistence"

configure do
  enable :sessions
  set :session_secret, "de802eb57d356b52574ab84bb23ee5b64c404440c2a3f85da18483765cdab230"
  set :erb, escape_html: true
end

configure(:development) do 
  require "sinatra/reloader"
  # also_reload "database_persistence.rb"
end

helpers do 
  def flash_formatting
    erb :flash_error_message
  end

  def airport_options
    connection = PG.connect(dbname: "flights")
    sql = <<~SQL
      SELECT country_city_airport 
      FROM airports
      WHERE name is NOT NULL 
      ORDER BY country, city, name;
    SQL
    connection.exec(sql)
  end

  def flight_dates
    [Date.today, Date.today + 1].map { |d| d.strftime('%Y-%m-%d') }
  end
end

def require_signed_in_user
  unless session[:username]
    session[:error] = "You must be signed in to do that."
    redirect "/"
  end
end

def hash_passwords
  connection = PG.connect(dbname: "flights")
  passwords = connection.exec("SELECT password FROM users;").map { |tuple| tuple["password"] }
  hashed_passwords = passwords.map { |pass| BCrypt::Password.create(pass) }
  connection.exec("UPDATE users SET password = '#{hashed_passwords[0]} WHERE id = 1;")
  connection.exec("UPDATE users SET password = '#{hashed_passwords[1]}' WHERE id = 2;")
end

def load_user_credentials(username)
  connection = PG.connect(dbname: "flights")
  result = connection.exec_params("SELECT * FROM users WHERE username = $1", [username])
  tuple = result.first || {}
  
  { user_id: tuple.fetch("id", nil),
    first_name: tuple.fetch("first_name", nil), 
    last_name: tuple.fetch("last_name", nil), 
    username: tuple.fetch("username", nil), 
    password: tuple.fetch("password", BCrypt::Password.create(nil)) }
end

def valid_credentials?(username, password)
  credentials = load_user_credentials(username)
  BCrypt::Password.new(credentials[:password]) == password
end

def validate_registration(params)
  first_name, last_name, username, password = params.values.map(&:strip)
  session[:error] = []

  session[:error] << "First names can only contain alpha characters" if !(first_name =~ /^[a-z]+$/i)
  session[:error] << "Last names must contain alpha characters and an optional '-' or space" if !(last_name =~ /^[a-z]+( |-)?[a-z]*$/i)
  session[:error] << "Username can only contain alpha and numeric characters" if !(username =~ /^[a-z0-9]+$/i)
  session[:error] << "Password can only contain alpha and numeric characters and must be at least 6 characters" if !(password =~ /^[a-z0-9]{6,}$/i)

  session.delete(:error) if session[:error].empty?
end

def create_new_user(first_name, last_name, username, password)
  hashed_password = BCrypt::Password.create(password)

  connection = PG.connect(dbname: "flights")
  sql = "INSERT INTO users (first_name, last_name, username, password) VALUES ($1, $2, $3, $4)"
  connection.exec_params(sql, [first_name, last_name, username, hashed_password])
end

def validate_flight(params)
  origin, destination, departure_string, return_string = params.values
  departure_date, return_date = [departure_string, return_string].map { |d| Date.strptime(d, "%Y-%m-%d") }
  session[:error] = []

  session[:error] << "Origin or destination cannot be empty" if origin.empty? || destination.empty?
  session[:error] << "Origin and destination values cannot be the same" if origin == destination
  if !departure_string =~ /\d{4}\/\d{2}\/\d{2}/ || !return_string =~ /\d{4}\/\d{2}\/\d{2}/
    session[:error] << "Departure and return dates can only contain numeric characters (mm/dd/yyyy)"
  end
  session[:error] << "Return date must be on the same day or after the departure date" if return_date < departure_date

  session.delete(:error) if session[:error].empty?
end

def create_new_flight(origin, destination, departure_date, return_date, user_id)
  sql = <<~SQL
    INSERT INTO flights (origin, destination, departure_date, return_date, user_id) 
    VALUES ($1, $2, $3, $4, $5)
  SQL
  connection = PG.connect(dbname: "flights")
  p connection.exec_params(sql, [origin, destination, departure_date, return_date, user_id])
end

def all_flights
  connection = PG.connect(dbname: "flights")
  connection.exec_params("SELECT * FROM flights WHERE user_id = $1", [session[:user_id]])
end

get "/" do 
  erb :index, layout: :layout
end

# Login form
get "/users/signin" do
  erb :signin, layout: :layout
end

# User signin validation
post "/users/signin" do
  username, password = params.values

  if valid_credentials?(username, password)
    session.merge!(load_user_credentials(username))
    session[:success] = "You are signed in"
    redirect "/"
  else
    session[:error] = "Invalid credentials"
    status 422
    erb :signin, layout: :layout
  end
end

# User signout
post "/users/signout" do
  session.clear
  session[:success] = "You have been signed out."
  redirect "/"
end

get "/register" do
  erb :register, layout: :layout
end

post "/register" do 
  validate_registration(params)

  if session[:error]
    status 422
    erb :register, layout: :layout
  else
    create_new_user(*params.values)
    session[:success] = "You are registered"
    redirect "/users/signin"
  end
end

get "/flight/new" do 
  erb :new_flight, layout: :layout
end

post "/flight/new" do 
  validate_flight(params)

  if session[:error]
    status 422
    erb :new_flight, layout: :layout
  else
    create_new_flight(*params.values, session[:user_id])
    session[:success] = "The list has been created."
    redirect "/"
  end
end
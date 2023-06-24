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

  def all_airports
    sql = <<~SQL
      SELECT 
        id, 
        city_country_airport, 
        name_iata_code
      FROM airports
      WHERE name is NOT NULL 
      AND iata_code IS NOT NULL
      ORDER BY city, country, name;
    SQL

    result = query(sql)

    result.map do |tuple|
      { id: tuple["id"],
        city_country_airport: tuple["city_country_airport"],
        name_iata_code: tuple["name_iata_code"] }
    end
  end

  def full_airport_name(abbreviated_name)
    sql = <<~SQL
      SELECT city_country_airport
      FROM airports 
      WHERE name_iata_code = $1;
    SQL

    result = query(sql, abbreviated_name)
    result.first["city_country_airport"] if result.ntuples > 0
  end
end

def database_connection
  PG.connect(dbname: "flights")
end

def query(statement, *params)
  db = database_connection
  db.exec_params(statement, params)
end

def require_signed_in_user
  unless session[:username]
    session[:error] = "You must be signed in to do that."
    redirect "/"
  end
end

# def hash_passwords
#   passwords = query("SELECT password FROM users;").map { |tuple| tuple["password"] }
#   hashed_passwords = passwords.map { |pass| BCrypt::Password.create(pass) }
#   connection.exec("UPDATE users SET password = '#{hashed_passwords[0]} WHERE id = 1;")
#   connection.exec("UPDATE users SET password = '#{hashed_passwords[1]}' WHERE id = 2;")
# end

def load_user_credentials(username)
  result = query("SELECT * FROM users WHERE username = $1", username)
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

  if !(first_name =~ /^[a-z]+$/i)
    session[:error] = "First names can only contain alpha characters"
  elsif !(last_name =~ /^[a-z]+( |-)?[a-z]*$/i)
    session[:error] = "Last names must contain alpha characters and an optional '-' or space"
  elsif !(username =~ /^[a-z0-9]+$/i)
    session[:error] = "Username can only contain alpha and numeric characters"
  elsif !(password =~ /^[a-z0-9]{6,}$/i)
    session[:error] = "Password can only contain alpha and numeric characters and must be at least 6 characters"
  end
end

def create_new_user(first_name, last_name, username, password)
  hashed_password = BCrypt::Password.create(password)

  sql = "INSERT INTO users (first_name, last_name, username, password) VALUES ($1, $2, $3, $4)"
  query(sql, first_name, last_name, username, hashed_password)
end

def validate_flight(params)
  origin, destination, date_string = params.values
  date = Date.strptime(date_string, "%Y-%m-%d") 

  if origin == 'Select an origin' || destination == 'Select a destination'
    session[:error] = "Select values for the origin and destination"
  elsif origin == destination
    session[:error] = "Origin and destination cannot be the same"
  elsif !(date_string =~ /\d{4}-\d{2}-\d{2}/)
    session[:error] = "Date can only contain numeric characters (mm/dd/yyyy)"
  elsif !flight_unique?(params, session[:user_id])
    session[:error] = "Flight origin, destination and date must be unique"
  end
end

def flight_unique?(params, user_id)
  all_flights(user_id).none? do |flight|
    flight.values_at(:origin, :destination, :date) == params.values
  end
end

def create_new_flight(origin, destination, date, user_id)
  sql = <<~SQL
    INSERT INTO flights (origin, destination, date, user_id) 
    VALUES ($1, $2, $3, $4)
  SQL

  query(sql, origin, destination, date, user_id)
end

def all_flights(user_id)
  sql = <<~SQL
    SELECT 
      id,
      origin,
      destination,
      date
    FROM flights 
    WHERE user_id = $1;
  SQL

  result = query(sql, user_id)

  result.map do |tuple|
    { id: tuple["id"],
      origin: tuple["origin"],
      destination: tuple["destination"],
      date: tuple["date"] }
  end
end

def load_flight(flight_id)
  sql = "SELECT * FROM flights WHERE id = $1"
  result = query(sql, flight_id)
  result.first.transform_keys(&:to_sym)
end

def update_flight(origin, destination, date, flight_id)
  sql = <<~SQL
    UPDATE flights
    SET origin = $1,
        destination = $2,
        date = $3
    WHERE id = $4
  SQL

  query(sql, origin, destination, date, flight_id)
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

get "/" do
  redirect "/flights"
end

# View all flights
get "/flights" do 
  @airports = all_airports
  @today = Date.today.strftime('%Y-%m-%d')
  @flights = all_flights(session[:user_id])
  erb :index, layout: :layout
end

post "/flights" do 
  validate_flight(params)

  @airports = all_airports
  @today = Date.today.strftime('%Y-%m-%d')
  @flights = all_flights(session[:user_id])

  if session[:error]
    status 422
    erb :index, layout: :layout
  else
    create_new_flight(*params.values, session[:user_id])
    session[:success] = "A new flight has been created"
    redirect "/"
  end
end

# Edit an existing flight
get "/flights/:id/edit" do
  @airports = all_airports
  @today = Date.today.strftime('%Y-%m-%d')
  id = params[:id].to_i
  @flight = load_flight(id)

  erb :flight, layout: :layout
end

# Update an existing flight
post "/flights/:id" do
  validate_flight(params)

  @airports = all_airports
  @today = Date.today.strftime('%Y-%m-%d')
  id = params[:id].to_i
  @flight = load_flight(id)

  if session[:error]
    status 422
    erb :flight, layout: :layout
  else
    update_flight(*params.values_at(:origin, :destination, :date), id)
    session[:success] = "The flight has been updated"
    redirect "/flights/#{id}/edit"
  end
end
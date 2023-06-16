require "sinatra"
# require "sinatra/content_for"
# require "tilt/erubis"
require 'bcrypt'
require "pg"

# require "pry"

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
  def flash_error_formatting(session_errors)
    if session_errors.is_a?(Array)
      "<br>" + session_errors.join("<br>")
    else
      session_errors
    end
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
  tuple = result.first
  
  { first_name: tuple["first_name"], 
    last_name: tuple["last_name"], 
    username: tuple["username"], 
    password: tuple["password"] }
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
    session[:username] = username
    session[:success] = "You are signed in"
    redirect "/"
  else
    session[:error] = "Invalid credentials"
    status 422
    erb :signin, layout: layout
  end
end

get "/register" do
  erb :register, layout: :layout
end

post "/register" do 
  validate_registration(params)

  # binding.pry

  if session[:error]
    status 422
    erb :register, layout: :layout
    pry
  else
    session[:success] = "You are registered"
    redirect "/users/signin"
  end
end

# # Render the new flight form
# get "/flight/new" do
#   erb :new_list, layout: :layout
# end
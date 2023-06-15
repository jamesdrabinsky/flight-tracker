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
  # require "sinatra/reloader"
  # also_reload "database_persistence.rb"
end

def require_signed_in_user
  unless session[:username]
    session[:error] = "You must be signed in to do that."
    redirect "/"
  end
end

def load_user_credentials
  connection = PG.connect(dbname: "flights")
  result = connection.exec("SELECT * FROM users;")
  
  result.map do |tuple|
    { first_name: tuple["first_name"], 
      last_name: tuple["last_name"], 
      username: tuple["username"], 
      password: tuple["password"] }
  end  
end

def valid_credentials?(username, password)
  credentials = load_user_credentials
  BCrypt::Password.new(credentials[username]) == password
end

get "/" do 
  erb :index, layout: :layout
end

# Login form
get "/users/signin" do
  erb :signin, layout: :layout
end

# Render the new flight form
get "/flight/new" do
  erb :new_list, layout: :layout
end

# User signin validation
post "/users/signin" do
  username, password = params.values_at(:username, :password)

  if valid_credentials?(username, password)
    session[:username] = username
    session[:success] = "Welcome!"
    redirect "/"
  else
    session[:error] = "Invalid credentials"
    status 422
    erb :signin
  end
end
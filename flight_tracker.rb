require "sinatra"
require "sinatra/content_for"
require "tilt/erubis"

# require "pry"

# require_relative "database_persistence"

configure do
  enable :sessions
  set :session_secret, "secret"
  set :erb, escape_html: true
end

configure(:development) do 
  require "sinatra/reloader"
  also_reload "database_persistence.rb"
end

get "/" do 
  erb :index
end

get "/users/signin" do
  erb :signin
end
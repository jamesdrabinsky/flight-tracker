require 'date'

require 'dotenv'
require "sinatra"
# require "sinatra/content_for"
require "tilt/erubis"
require 'bcrypt'
require "pg"

require "pry"

require_relative "database_persistence"

Dotenv.load('./.env')

configure do
  enable :sessions
  set :session_secret, ENV["SECRET"]
  set :erb, escape_html: true
end

configure(:development) do 
  require "sinatra/reloader"
  also_reload "database_persistence.rb"
end

before do
  @storage = DatabasePersistence.new(logger)
end

helpers do 
#   def flash_formatting
#     erb :flash_error_message
#   end

  def full_airport_name(abbreviated_name)
    result = @storage.city_country_airport(abbreviated_name)
    result.first["city_country_airport"] if result.ntuples > 0
  end

  def page_count
    result = @storage.page_count(session[:user_id])
    result.zero? ? 1 : result
  end

  def flight_count
    @storage.all_flights(session[:user_id]).size
  end

  def ticket_count(flight_id)
    @storage.ticket_count(flight_id)
  end

  def pagination_range(page_number)
    ranges = (1..flight_count).step(5).zip((5..flight_count).step(5))
    
    ranges[-1][1] = flight_count

    ranges.each.with_index(1).with_object([]) do |((first, last), idx), arr|
      arr << first << last if idx == page_number
    end
  end

  def signin_link(string, text)
    string.sub(text, %(<u><strong><a href="/users/signin">#{text}</a></strong></u>)) 
  end
end

def database_connection
  # PG.connect(dbname: "flights")
  PG.connect(dbname: "flight_tracker")
end

def query(statement, *params)
  db = database_connection
  db.exec_params(statement, params)
end

def require_signed_in_user
  unless session[:username]
    if request.get?
      session[:error] = "Must be signed in to access this page"
    else
      session[:error] = "Must be signed in to perform this action"
    end
    redirect "/"
  end
end

def valid_credentials?(username, password)
  credentials = @storage.load_user_credentials(username)
  BCrypt::Password.new(credentials[:password]) == password unless credentials.nil?
end

def validate_registration(params)
  first_name, last_name, username, password = params.values.map(&:strip)
  session[:error] = []

  if !(first_name =~ /^[a-z]+$/i)
    session[:error] << "First names can only contain alpha characters (no spaces)"
  end
  if !(last_name =~ /^[a-z]+( |-)?[a-z]*$/i)
    session[:error] << "Last names can only contain alpha characters and an optional '-' or space"
  end
  if !(username =~ /^[a-z0-9]+$/i)
    session[:error] << "Username can only contain alpha and numeric characters (no spaces)"
  end
  if !(password =~ /^[a-z0-9]{6,}$/i)
    session[:error] << "Password can only contain alpha and numeric characters and must be at least 6 characters (no spaces)"
  end
  if !username_unique?(username)
    session[:error] << "The username entered is already in use"
  end

  session.delete(:error) if session[:error].empty?
end

def username_unique?(username)
  @storage.find_user(username).ntuples == 0
end

def validate_flight(params)
  origin, destination, date_string = params.values
  date = Date.strptime(date_string, "%Y-%m-%d") 
  session[:error] = []

  if origin == 'Select an origin' || destination == 'Select a destination'
    session[:error] << "Select values for the origin and destination"
  end
  if origin == destination
    session[:error] << "Origin and destination cannot be the same"
  end
  if !(date_string =~ /\d{4}-\d{2}-\d{2}/)
    session[:error] << "Date must be entered in the following format (mm/dd/yyyy)"
  end
  if !flight_unique?(params, session[:user_id])
    session[:error] << "Flight origin, destination and date must be unique"
  end

  session.delete(:error) if session[:error].empty?
end

def flight_unique?(params, user_id)
  @storage.matching_flights(params, user_id).ntuples == 0
end

def validate_ticket(ticket_class, seat, traveler, bags, flight_id)
  session[:error] = []

  if ticket_class == 'Select a class' || seat == 'Select a seat'\
    || traveler == 'Select a traveler' || bags == 'Select number of bags'
    session[:error] << "Select values for class, seat, traveler and bags"
  end
  if @storage.ticket_count(flight_id) == 4
    session[:error] << "You have reached the limit of four tickets for this flight"
  end

  session.delete(:error) if session[:error].empty?
end

def page_exist?(page_number)
  (1..page_count).cover? page_number
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
    return_path = session.delete(:last_request) || "/"
    redirect return_path
  else
    session[:error] = "Invalid credentials"
    status 422
    erb :signin, layout: :layout
  end
end

# User signout
post "/users/signout" do
  session.clear
  session[:success] = "You have been signed out"
  redirect "/"
end

# Sign up form
get "/register" do
  erb :register, layout: :layout
end

# Sign up validation
post "/register" do 
  validate_registration(params)

  if session[:error]
    status 422
    erb :register, layout: :layout
  else
    select_params = params.values_at(:first_name, :last_name, :username, :password)
    @storage.create_new_user(*select_params)
    session[:success] = "You are registered"
    redirect "/users/signin"
  end
end

get "/" do
  redirect "/flights"
end

# View all flights
get "/flights" do
  @page_number = params[:page] ? params[:page].to_i : 1

  # session[:last_request] = request.fullpath
  session[:page] = @page_number

  @airports = @storage.all_airports
  @today = Date.today.strftime('%Y-%m-%d')
  @flights = @storage.load_current_page_flights(@page_number, session[:user_id])

  if page_exist?(@page_number)
    erb :index, layout: :layout
  else
    session[:error] = "That page does not exist"
    redirect "/"
  end
end

# Create a new flight
post "/flights" do   
  require_signed_in_user

  validate_flight(params)

  @page_number = session[:page]
  @airports = @storage.all_airports
  @today = Date.today.strftime('%Y-%m-%d')
  @flights = @storage.load_current_page_flights(@page_number, session[:user_id])

  if session[:error]
    status 422
    erb :index, layout: :layout
  else
    select_params = params.values_at(:origin, :destination, :date)
    @storage.create_new_flight(*select_params, session[:user_id])
    session[:success] = "A new flight has been created"    
    redirect "/flights?page=#{session[:page]}" # Do you want to redirect to first page or to current page?
  end
end

# View a single flight and its tickets
get "/flights/:id/edit" do
  session[:last_request] = request.fullpath
  
  require_signed_in_user
  
  id = params[:id].to_i
  @flight = @storage.load_flight(id)

  if @flight
    @airports = @storage.all_airports
    @today = Date.today.strftime('%Y-%m-%d')
    @flight_id = params[:id].to_i
    @tickets = @storage.find_tickets_for_flight(id)

    erb :flight, layout: :layout
  else
    session[:error] = "That page does not exist"
    redirect "/"
  end
end

get "/flights/:id" do
  redirect "/flights/#{params[:id]}/edit"
end

# Update an existing flight
post "/flights/:id" do
  validate_flight(params)

  @airports = @storage.all_airports
  @today = Date.today.strftime('%Y-%m-%d')
  id = params[:id].to_i
  @flight = @storage.load_flight(id)
  @tickets = @storage.find_tickets_for_flight(id)

  if session[:error]
    status 422
    erb :flight, layout: :layout
  else
    origin, destination, date = params.values_at(:origin, :destination, :date)
    # update_flight(*params.values_at(:origin, :destination, :date), id)
    @storage.update_flight(origin, destination, date, id)
    session[:success] = "The flight has been updated"
    redirect "/flights/#{id}/edit"
  end
end

# Delete a flight
post "/flights/:id/destroy" do
  id = params[:id].to_i
  @storage.delete_flight(id)
  session[:success] = "The flight has been deleted."
  redirect "/"
end

# Remove all flights
post "/flights_remove_all" do  
  @storage.remove_all_flights(session[:user_id])
  session[:success] = "All flights were deleted"
  redirect "/"
end

# Add a new ticket to a flight
post "/flights/:id/tickets" do
  select_params = params.values_at(:class, :seat, :traveler, :bags, :id)

  validate_ticket(*select_params)
  
  @airports = @storage.all_airports
  @flight_id = params[:id].to_i
  @flight = @storage.load_flight(@flight_id)
  @tickets = @storage.find_tickets_for_flight(@flight_id)

  if session[:error]
    status 422
    erb :flight, layout: :layout
  else
    @storage.create_new_ticket(*select_params)
    session[:success] = "A new ticket has been created"
    redirect "/flights/#{@flight_id}/edit"
  end
end

# Edit an existing ticket
get "/flights/:flight_id/tickets/:id/edit" do 
  session[:last_request] = request.fullpath
  require_signed_in_user
  @id = params[:id].to_i
  @flight_id = params[:flight_id].to_i
  @ticket = @storage.load_ticket(@flight_id, @id)

  if @ticket
    @flight = @storage.load_flight(@flight_id)
    erb :ticket, layout: :layout
  else
    session[:error] = "That page does not exist"
    redirect "/"
  end
end

get "/flights/:flight_id/tickets/:id" do 
  redirect "/flights/#{params[:flight_id]}/tickets/#{params[:id]}/edit"
end

# Update an existing ticket
post "/flights/:flight_id/tickets/:id" do
  @flight_id = params[:flight_id].to_i
  id = params[:id].to_i
  @ticket = @storage.load_ticket(@flight_id, id)

  @storage.update_ticket(*params.values_at(:class, :seat, :traveler, :bags), id)
  session[:success] = "The ticket has been updated"
  redirect "/flights/#{@flight_id}/tickets/#{id}/edit"
end

# Delete a ticket
post "/flights/:flight_id/tickets/:id/destroy" do
  @flight_id = params[:flight_id].to_i
  id = params[:id].to_i
  @storage.delete_ticket(id)

  session[:success] = "The ticket has been deleted."
  redirect "/flights/#{@flight_id}/edit"
end

# Delete all tickets for a flight
post "/flights/:id/tickets/remove_all" do
  @flight_id = params[:id].to_i
  @storage.remove_all_tickets(@flight_id)
  session[:success] = "All tickets were deleted"
  redirect "/flights/#{@flight_id}/edit"
end
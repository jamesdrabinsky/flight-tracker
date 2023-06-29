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

  def page_count
    sql = <<~SQL
      SELECT CEIL(COUNT(id)::numeric / 5) page_count 
      FROM flights 
      WHERE user_id = $1;
    SQL

    query(sql, session[:user_id]).first["page_count"].to_i
  end

  def flight_count
    all_flights(session[:user_id]).size
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
  PG.connect(dbname: "flights")
end

def query(statement, *params)
  db = database_connection
  db.exec_params(statement, params)
end

def require_signed_in_user
  unless session[:username]
    session[:error] = "Must be signed in to perform this action"
    redirect "/"
  end
end

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
  session[:error] = []

  if !(first_name =~ /^[a-z]+$/i)
    session[:error] << "First names can only contain alpha characters"
  end
  if !(last_name =~ /^[a-z]+( |-)?[a-z]*$/i)
    session[:error] << "Last names must contain alpha characters and an optional '-' or space"
  end
  if !(username =~ /^[a-z0-9]+$/i)
    session[:error] << "Username can only contain alpha and numeric characters"
  end
  if !(password =~ /^[a-z0-9]{6,}$/i)
    session[:error] << "Password can only contain alpha and numeric characters and must be at least 6 characters"
  end
  if !username_unique?(username)
    session[:error] << "The username entered is already in use"
  end

  session.delete(:error) if session[:error].empty?
end

def username_unique?(username)
  sql = "SELECT username FROM users;"
  usernames = query(sql).field_values("username")

  usernames.none? do |name|
    name == username
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
  session[:error] = []

  if origin == 'Select an origin' || destination == 'Select a destination'
    session[:error] << "Select values for the origin and destination"
  end
  if origin == destination
    session[:error] << "Origin and destination cannot be the same"
  end
  if !(date_string =~ /\d{4}-\d{2}-\d{2}/)
    session[:error] << "Date can only contain numeric characters (mm/dd/yyyy)"
  end
  if !flight_unique?(params, session[:user_id])
    session[:error] << "Flight origin, destination and date must be unique"
  end

  session.delete(:error) if session[:error].empty?
end

def flight_unique?(params, user_id)
  all_flights(user_id).none? do |flight|
    flight_values = flight.values_at(:origin, :destination, :date)
    param_values = params.values_at(:origin, :destination, :date)
    flight_values == param_values && flight[:id] != params[:id]
  end
end

def create_new_flight(origin, destination, date, user_id)
  sql = <<~SQL
    INSERT INTO flights (origin, destination, date, code, user_id) 
    VALUES ($1, $2, $3, flight_code($1, $2, $3), $4)
  SQL

  query(sql, origin, destination, date, user_id)
end

def all_flights(user_id)
  sql = <<~SQL
    SELECT *
    FROM flights 
    WHERE user_id = $1
    ORDER BY date , origin, destination;
  SQL

  result = query(sql, user_id)

  result.map do |tuple|
    { id: tuple["id"],
      origin: tuple["origin"],
      destination: tuple["destination"],
      date: tuple["date"],
      code: tuple["code"] }
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
        date = $3,
        code = flight_code($1, $2, $3)
    WHERE id = $4
  SQL

  query(sql, origin, destination, date, flight_id)
end

def delete_flight(flight_id)
  sql = "DELETE FROM flights WHERE id = $1;"
  query(sql, flight_id)
end

def create_new_ticket(ticket_class, seat, traveler, bags, flight_id)
  sql = <<~SQL
    INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
    VALUES ($1, $2, $3, $4, ticket_code($5), $5);
  SQL
  query(sql, ticket_class, seat, traveler, bags, flight_id)
end

def validate_ticket(ticket_class, seat, traveler, bags, flight_id)
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

def ticket_limit?(flight_id)
  sql = "SELECT COUNT(id) FROM tickets WHERE flight_id = $1"
  result = query(sql, flight_id)
  result.first["count"] == 4
end

def find_tickets_for_flight(flight_id)
  sql = "SELECT * FROM tickets WHERE flight_id = $1"
  result = query(sql, flight_id)
  
  result.map do |tuple|
    { id: tuple["id"].to_i,
      class: tuple["class"],
      seat: tuple["seat"],
      traveler: tuple["traveler"],
      bags: tuple["bags"].to_i,
      code: tuple["code"] }
    
  end
end

def load_ticket(ticket_id)
  sql = "SELECT * FROM tickets WHERE id = $1"
  result = query(sql, ticket_id)
  result.first.transform_keys(&:to_sym)
end

def update_ticket(ticket_class, seat, traveler, bags, ticket_id)
  sql = <<~SQL
    UPDATE tickets
    SET class = $1,
        seat = $2,
        traveler = $3,
        bags = $4
    WHERE id = $5
  SQL

  query(sql, ticket_class, seat, traveler, bags, ticket_id)
end

def delete_ticket(ticket_id)
  sql = "DELETE FROM tickets WHERE id = $1;"
  query(sql, ticket_id)
end

def load_current_page_flights(page_number)
  sql = <<~SQL 
    SELECT * 
    FROM flights 
    WHERE user_id = $1 
    LIMIT 5 OFFSET $2
  SQL

  result = query(sql, session[:user_id], (page_number - 1) * 5)
  
  result.map do |tuple|
    { id: tuple["id"],
      origin: tuple["origin"],
      destination: tuple["destination"],
      date: tuple["date"],
      code: tuple["code"] }
  end
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
  params[:page] ||= 1

  @airports = all_airports
  @today = Date.today.strftime('%Y-%m-%d')
  @page_number = params[:page].to_i
  @flights = load_current_page_flights(@page_number)

  erb :index, layout: :layout
end

# Create a new flight
post "/flights" do   
  require_signed_in_user

  validate_flight(params)

  @airports = all_airports
  @today = Date.today.strftime('%Y-%m-%d')
  @page_number = 1
  @flights = load_current_page_flights(@page_number)

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
  require_signed_in_user

  @airports = all_airports
  @today = Date.today.strftime('%Y-%m-%d')
  id = params[:id].to_i
  @flight = load_flight(id)
  @tickets = find_tickets_for_flight(id)

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

# Delete a flight
post "/flights/:id/destroy" do
  id = params[:id].to_i
  delete_flight(id)

  session[:success] = "The flight has been deleted."
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/"
  else
    redirect "/"
  end
end

# Add a new ticket to a flight
post "/flights/:id/tickets" do

  # validate_ticket()
  @flight_id = params[:id].to_i
  @flight = load_flight(@flight_id)

  select_params = params.values_at(:class, :seat, :traveler, :bags, :id)

  if session[:error]
    status 422
    erb :flight, layout: :layout
  else
    create_new_ticket(*select_params)
    session[:success] = "A new ticket has been created"
    redirect "/flights/#{@flight_id}/edit"
  end
end

# Edit an existing ticket
get "/flights/:flight_id/tickets/:id/edit" do 
  @flight_id = params[:flight_id].to_i
  @id = params[:id].to_i
  @ticket = load_ticket(@id)

  erb :ticket, layout: :layout
end

# Update an existing ticket
post "/flights/:flight_id/tickets/:id" do
  @flight_id = params[:flight_id].to_i
  id = params[:id].to_i
  @ticket = load_ticket(id)

  update_ticket(*params.values_at(:class, :seat, :traveler, :bags), id)
  session[:success] = "The ticket has been updated"
  redirect "/flights/#{@flight_id}/tickets/#{id}/edit"
end

# Delete a ticket
post "/flights/:flight_id/tickets/:id/destroy" do
  @flight_id = params[:flight_id].to_i
  id = params[:id].to_i
  delete_ticket(id)

  session[:success] = "The ticket has been deleted."
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/flights/#{@flight_id}/edit"
  else
    redirect "/flights/#{@flight_id}/edit"
  end
end
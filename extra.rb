# Pagination implementation in Ruby

# flights_groups = all_flights(session[:user_id]).each_slice(5)
# flights_groups.each.with_index(1).with_object([]) do |(sub_arr, idx), arr|
#   sub_arr.each do |flight|
#     arr << flight if idx == page_number
#   end
# end  

# Original error flash message

# <% if session[:error] %>
#     <div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded relative" role="alert">
#         <strong class="font-bold">Error!</strong>
#         <span class="block sm:inline"> <%= session.delete(:error) %> </span>
#         <span class="absolute top-0 bottom-0 right-0 px-4 py-3"></span>
#     </div>
# <% end %>

# Hashing passwords

# def hash_passwords
#   passwords = query("SELECT password FROM users;").map { |tuple| tuple["password"] }
#   hashed_passwords = passwords.map { |pass| BCrypt::Password.create(pass) }
#   connection.exec("UPDATE users SET password = '#{hashed_passwords[0]} WHERE id = 1;")
#   connection.exec("UPDATE users SET password = '#{hashed_passwords[1]}' WHERE id = 2;")
# end

# Original logic for loading credentials

# tuple = result.first || {}

# { user_id: tuple.fetch("id", nil),
#   first_name: tuple.fetch("first_name", nil), 
#   last_name: tuple.fetch("last_name", nil), 
#   username: tuple.fetch("username", nil), 
#   password: tuple.fetch("password", BCrypt::Password.create(nil)) }

# Original logic for validating credentials

# if credentials.nil? 
#   false
# else
#   BCrypt::Password.new(credentials[:password]) == password
# end

# Original logic for deciding whether a username is unique

# usernames = @storage.all_usernames
# usernames.none? do { |name| name == username }

# Original logic for deciding whether a flight is unique

# @storage.all_flights(user_id).none? do |flight|
#   flight_values = flight.values_at(:origin, :destination, :date)
#   param_values = params.values_at(:origin, :destination, :date)
#   flight_values == param_values && flight[:id] != params[:id]
# end

# SELECT SUM(
# CASE 
#     WHEN (origin, destination, date) = ($1, $2, $3) AND flight_id != $4
#     THEN 1
# END) 'count'

# Original logic for updating a flight

# def update_flight(origin, destination, date, flight_id)
#   flight_sql = <<~SQL
#     UPDATE flights
#     SET origin = $1,
#         destination = $2,
#         date = $3,
#         code = flight_code($1, $2, $3)
#     WHERE id = $4
#   SQL

#   query(flight_sql, origin, destination, date, flight_id)

#   ticket_sql = <<~SQL
#     UPDATE tickets
#     SET code = (SELECT code FROM flights WHERE id = $1) || SUBSTRING(code, '-[a-z0-9]+$')
#     WHERE flight_id = $1;
#   SQL

#   # -- (SELECT code FROM flights WHERE id = $1)
#   # -- SUBSTRING(code, '-[a-z\d]+$')
#   # CONCAT(SELECT code FROM flights WHERE id = $1), SUBSTRING(code, '-[a-z0-9]+$'))

#   query(sql_2, ticket_sql)
# end

# Extra methods

# def ticket_limit?(flight_id)
#     sql = "SELECT COUNT(id) FROM tickets WHERE flight_id = $1"
#     result = query(sql, flight_id)
#     result.first["count"] == 4
#   end

# def flight_exist?(flight_id)
#   sql = "SELECT * FROM flights WHERE id = $1"
#   result = query(sql, flight_id)
#   result.ntuples > 0
# end

# def ticket_exist?(flight_id, ticket_id)
#   sql = "SELECT * FROM tickets WHERE id = $1 AND flight_id = $2"
#   result = query(sql, ticket_id, flight_id)
#   result.ntuples > 0
# end
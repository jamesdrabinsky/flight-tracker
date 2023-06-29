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
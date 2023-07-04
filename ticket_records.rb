# (1..20).each do |flight_id|
#   rand(0..4).times do 
#       ticket_class = ['1. Economy', '2. Premium Economy', '3. Business Class', '4. First Class'].sample
#       seat = ['Window', 'Middle', 'Aisle'].sample
#       traveler = ['Adult', 'Child', 'Infant'].sample
#       bags = rand(0..2)

#       puts <<~SQL
#       INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
#         VALUES ('#{ticket_class}', '#{seat}', '#{traveler}', '#{bags}', ticket_code(#{flight_id}), #{flight_id});
#       SQL
#   end
# end 

require 'dotenv'
Dotenv.load('./.env')


p ENV['SECRET']
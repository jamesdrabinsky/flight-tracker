-- psql -d postgres < sql_file.sql

CREATE DATABASE flight_tracker;

\c flight_tracker

-----------------------------------------

CREATE TABLE users (
    id serial PRIMARY KEY,
    first_name text NOT NULL CHECK(first_name ~* '^[a-z]+$'),
    last_name text NOT NULL CHECK(last_name ~* '^[a-z]+( |-)?[a-z]*$'),
    username text NOT NULL UNIQUE CHECK(username ~* '^[a-z0-9]+$'),
    password text NOT NULL
);

-----------------------------------------

\i data/gadb_postgresql_create_airports_table.sql

UPDATE airports 
SET name = INITCAP(name),
city = INITCAP(city),
country = INITCAP(country);

UPDATE airports
SET country = CASE WHEN country IN ('Usa', 'Uk') THEN UPPER(country) ELSE country END;

UPDATE airports 
SET name = NULL 
WHERE name = 'N/A';

UPDATE airports 
SET iata_code = NULL 
WHERE iata_code = 'N/A';

ALTER TABLE airports 
ADD COLUMN city_country_airport text;

UPDATE airports
SET city_country_airport = CONCAT(city, ', ', country, ' ', '(', name, ' - ', iata_code, ')');

ALTER TABLE airports
ALTER COLUMN city_country_airport 
SET NOT NULL;

ALTER TABLE airports
ADD COLUMN name_iata_code text;

UPDATE airports
SET name_iata_code = CONCAT(name, ' - ', iata_code);

ALTER TABLE airports
ALTER COLUMN name_iata_code 
SET NOT NULL;

-----------------------------------------

CREATE TABLE flights (
    id serial PRIMARY KEY,
    origin text NOT NULL CHECK(origin != destination),
    destination text NOT NULL CHECK(destination != origin),
    date date NOT NULL CHECK(date::text ~ '\d{4}-\d{2}-\d{2}'),
    created_on timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    code text NOT NULL,
    user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(origin, destination, date)
);

-----------------------------------------

CREATE TYPE ticket_class_enum AS ENUM ('1. Economy', '2. Premium Economy', '3. Business Class', '4. First Class');
CREATE TYPE ticket_seat_enum AS ENUM ('Window', 'Middle', 'Aisle');
CREATE TYPE ticket_traveler_enum AS ENUM ('Adult', 'Child', 'Infant');

CREATE TABLE tickets (
  id serial PRIMARY KEY,
  class ticket_class_enum NOT NULL,
  seat ticket_seat_enum NOT NULL,
  traveler ticket_traveler_enum NOT NULL,
  bags integer NOT NULL,
  code text NOT NULL,
  flight_id integer REFERENCES flights(id) ON DELETE CASCADE
);

-----------------------------------------

CREATE FUNCTION flight_code (origin text, destination text, date date) RETURNS text
  AS $$ 
    SELECT SPLIT_PART($1, ' - ', 2) || '-' || SPLIT_PART($2, ' - ', 2) || '-' || REGEXP_REPLACE($3::text, '[-]', '', 'g'); 
    $$
  LANGUAGE SQL;

CREATE FUNCTION ticket_code (flight_id integer) RETURNS text
  AS $$
    SELECT code || '-' || SUBSTR(md5(RANDOM()::text), 0, 10)
    FROM flights
    WHERE id = $1

    -- WITH flight_info AS (SELECT code FROM flights WHERE flight_id = $1)
    -- SELECT (SELECT code FROM flights WHERE flight_id = $1) || '-' || SUBSTR(md5(RANDOM()::text), 0, 10)
    -- FROM flight_info
  $$
  LANGUAGE SQL;

-----------------------------------------

-- sql = <<~SQL
--     INSERT INTO users (first_name, last_name, username, password) 
--       VALUES ('launch', 'school', 'lsuser1', '#{BCrypt::Password.create('lsuser1password')}');
-- SQL

INSERT INTO users (first_name, last_name, username, password)
  VALUES ('launch', 'school', 'lsuser1', '$2a$12$lQJS8NGvqID8ZxVZ2Kl1XuEIlrSY4JgP1wUWG4J0Ve9Mecx3yKdTi');

-----------------------------------------

-- 20.times.map do 

--     origin, destination, date = 2.times.map { all_airports.sample[:name_iata_code] }
--     date = rand(Date.new(2023,7,5)..Date.new(2024,7,5)).strftime('%Y-%m-%d')

--     puts <<~SQL
--         INSERT INTO flights (origin, destination, date, code, user_id)
--           VALUES ('#{origin}', '#{destination}', '#{date}', flight_code('#{origin}', '#{destination}', '#{date}'), 1);
--     SQL

-- end

INSERT INTO flights (origin, destination, date, code, user_id)
  VALUES ('Cork - ORK', 'Richards Bay - RCB', '2023-09-18', flight_code('Cork - ORK', 'Richards Bay - RCB', '2023-09-18'), 1);
INSERT INTO flights (origin, destination, date, code, user_id)
  VALUES ('Brussels Natl - BRU', 'Tamanrasset - TMR', '2023-12-30', flight_code('Brussels Natl - BRU', 'Tamanrasset - TMR', '2023-12-30'), 1);
INSERT INTO flights (origin, destination, date, code, user_id)
  VALUES ('Monclova International - LOV', 'Lambarene - LBQ', '2023-10-09', flight_code('Monclova International - LOV', 'Lambarene - LBQ', '2023-10-09'), 1);
INSERT INTO flights (origin, destination, date, code, user_id)
  VALUES ('Kos - KGS', 'Tafaraoui - TAF', '2023-09-30', flight_code('Kos - KGS', 'Tafaraoui - TAF', '2023-09-30'), 1);
INSERT INTO flights (origin, destination, date, code, user_id)
  VALUES ('Decimomannu - DCI', 'Davis Monthan Afb - DMA', '2024-06-07', flight_code('Decimomannu - DCI', 'Davis Monthan Afb - DMA', '2024-06-07'), 1);
INSERT INTO flights (origin, destination, date, code, user_id)
  VALUES ('Jasionka - RZE', 'Wanganui - WAG', '2024-06-03', flight_code('Jasionka - RZE', 'Wanganui - WAG', '2024-06-03'), 1);
INSERT INTO flights (origin, destination, date, code, user_id)
  VALUES ('Syamsudin Noor - BDJ', 'Douala - DLA', '2023-08-30', flight_code('Syamsudin Noor - BDJ', 'Douala - DLA', '2023-08-30'), 1);
INSERT INTO flights (origin, destination, date, code, user_id)
  VALUES ('Kiruna - KRN', 'Mahshahr - MRX', '2024-01-12', flight_code('Kiruna - KRN', 'Mahshahr - MRX', '2024-01-12'), 1);
INSERT INTO flights (origin, destination, date, code, user_id)
  VALUES ('Dusseldorf - DUS', 'Nizhnevartovsk - NJC', '2024-01-30', flight_code('Dusseldorf - DUS', 'Nizhnevartovsk - NJC', '2024-01-30'), 1);
INSERT INTO flights (origin, destination, date, code, user_id)
  VALUES ('Long Beach - LGB', 'Boone Co - HRO', '2024-03-11', flight_code('Long Beach - LGB', 'Boone Co - HRO', '2024-03-11'), 1);
INSERT INTO flights (origin, destination, date, code, user_id)
  VALUES ('Van - VAN', 'Mitzic - MZC', '2023-10-15', flight_code('Van - VAN', 'Mitzic - MZC', '2023-10-15'), 1);
INSERT INTO flights (origin, destination, date, code, user_id)
  VALUES ('Treasure Cay - TCB', 'Kochi - KCZ', '2023-12-27', flight_code('Treasure Cay - TCB', 'Kochi - KCZ', '2023-12-27'), 1);
INSERT INTO flights (origin, destination, date, code, user_id)
  VALUES ('Alicante - ALC', 'Bron - LYN', '2023-12-13', flight_code('Alicante - ALC', 'Bron - LYN', '2023-12-13'), 1);
INSERT INTO flights (origin, destination, date, code, user_id)
  VALUES ('Tacuarembo - TAW', 'Maio - MMO', '2024-06-11', flight_code('Tacuarembo - TAW', 'Maio - MMO', '2024-06-11'), 1);
INSERT INTO flights (origin, destination, date, code, user_id)
  VALUES ('Jasionka - RZE', 'Barajas - MAD', '2024-01-05', flight_code('Jasionka - RZE', 'Barajas - MAD', '2024-01-05'), 1);
INSERT INTO flights (origin, destination, date, code, user_id)
  VALUES ('Salt Lake City International - SLC', 'El Jaguel International - PDP', '2023-12-27', flight_code('Salt Lake City International - SLC', 'El Jaguel International - PDP', '2023-12-27'), 1);
INSERT INTO flights (origin, destination, date, code, user_id)
  VALUES ('Fort Chipewyan - YPY', 'Lampedusa - LMP', '2023-08-28', flight_code('Fort Chipewyan - YPY', 'Lampedusa - LMP', '2023-08-28'), 1);
INSERT INTO flights (origin, destination, date, code, user_id)
  VALUES ('Mazar I Sharif - MZR', 'Moffett Federal Afld - NUQ', '2023-10-08', flight_code('Mazar I Sharif - MZR', 'Moffett Federal Afld - NUQ', '2023-10-08'), 1);
INSERT INTO flights (origin, destination, date, code, user_id)
  VALUES ('Santa Maria - STM', 'Mc Minnville Muni - MMV', '2024-01-09', flight_code('Santa Maria - STM', 'Mc Minnville Muni - MMV', '2024-01-09'), 1);
INSERT INTO flights (origin, destination, date, code, user_id)
  VALUES ('Chatham Islands - CHT', 'Cranbrook - YXC', '2023-07-14', flight_code('Chatham Islands - CHT', 'Cranbrook - YXC', '2023-07-14'), 1);

-----------------------------------------

-- (1..20).each do |flight_id|
--   rand(0..4).times do 
--       ticket_class = ['1. Economy', '2. Premium Economy', '3. Business Class', '4. First Class'].sample
--       seat = ['Window', 'Middle', 'Aisle'].sample
--       traveler = ['Adult', 'Child', 'Infant'].sample
--       bags = rand(0..2)

--       puts <<~SQL
--       INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
--         VALUES ('#{ticket_class}', '#{seat}', '#{traveler}', '#{bags}', ticket_code(#{flight_id}), #{flight_id});
--       SQL
--   end
-- end 

INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
  VALUES ('2. Premium Economy', 'Window', 'Child', '0', ticket_code(1), 1);
INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
  VALUES ('1. Economy', 'Aisle', 'Child', '1', ticket_code(2), 2);
INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
  VALUES ('3. Business Class', 'Window', 'Child', '0', ticket_code(2), 2);
INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
  VALUES ('1. Economy', 'Window', 'Infant', '0', ticket_code(2), 2);
INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
  VALUES ('2. Premium Economy', 'Window', 'Child', '2', ticket_code(2), 2);
INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
  VALUES ('3. Business Class', 'Middle', 'Infant', '2', ticket_code(3), 3);
INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
  VALUES ('3. Business Class', 'Aisle', 'Child', '0', ticket_code(3), 3);
INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
  VALUES ('4. First Class', 'Middle', 'Adult', '0', ticket_code(6), 6);
INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
  VALUES ('2. Premium Economy', 'Middle', 'Infant', '0', ticket_code(7), 7);
INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
  VALUES ('2. Premium Economy', 'Middle', 'Infant', '1', ticket_code(8), 8);
INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
  VALUES ('2. Premium Economy', 'Window', 'Adult', '2', ticket_code(8), 8);
INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
  VALUES ('1. Economy', 'Aisle', 'Adult', '1', ticket_code(9), 9);
INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
  VALUES ('4. First Class', 'Window', 'Adult', '2', ticket_code(9), 9);
INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
  VALUES ('1. Economy', 'Aisle', 'Child', '2', ticket_code(12), 12);
INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
  VALUES ('1. Economy', 'Window', 'Infant', '0', ticket_code(13), 13);
INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
  VALUES ('1. Economy', 'Window', 'Infant', '1', ticket_code(14), 14);
INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
  VALUES ('3. Business Class', 'Window', 'Adult', '2', ticket_code(14), 14);
INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
  VALUES ('1. Economy', 'Aisle', 'Child', '0', ticket_code(14), 14);
INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
  VALUES ('4. First Class', 'Middle', 'Infant', '2', ticket_code(14), 14);
INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
  VALUES ('3. Business Class', 'Middle', 'Adult', '1', ticket_code(15), 15);
INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
  VALUES ('3. Business Class', 'Middle', 'Child', '0', ticket_code(15), 15);
INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
  VALUES ('1. Economy', 'Aisle', 'Adult', '1', ticket_code(18), 18);
INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
  VALUES ('3. Business Class', 'Window', 'Child', '1', ticket_code(18), 18);
INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
  VALUES ('1. Economy', 'Aisle', 'Adult', '2', ticket_code(19), 19);
INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
  VALUES ('4. First Class', 'Window', 'Child', '2', ticket_code(19), 19);
INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
  VALUES ('4. First Class', 'Aisle', 'Infant', '0', ticket_code(19), 19);
INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
  VALUES ('3. Business Class', 'Window', 'Adult', '0', ticket_code(19), 19);
INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
  VALUES ('4. First Class', 'Window', 'Child', '2', ticket_code(20), 20);
INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
  VALUES ('3. Business Class', 'Window', 'Child', '2', ticket_code(20), 20);
INSERT INTO tickets (class, seat, traveler, bags, code, flight_id) 
  VALUES ('4. First Class', 'Aisle', 'Adult', '2', ticket_code(20), 20);
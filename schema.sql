-- -- createdb flights

-- CREATE TABLE airports (
--     id serial,
--     name text,
--     latitude_deg numeric,
--     longitude_deg numeric,
--     iso_country varchar(3),
--     municipality text
-- );

-- CREATE TABLE countries (
--     id serial,
--     code varchar(3),
--     name text,
--     continent varchar(3)
-- );

-- \copy airports(name, latitude_deg, longitude_deg, iso_country, municipality) FROM 'data/airports.csv' WITH HEADER CSV;
-- \copy countries(code, name, continent) FROM 'data/countries.csv' WITH HEADER CSV;

CREATE TABLE users (
    id serial PRIMARY KEY,
    first_name text NOT NULL,
    last_name text NOT NULL,
    username text NOT NULL,
    password text NOT NULL
);

-- INSERT INTO users (first_name, last_name, username, password) VALUES ('James', 'Drabinsky', 'jamesdrabinsky', 'Scottiebarnes4!');
-- INSERT INTO users (first_name, last_name, username, password) VALUES ('Cayle', 'Drabinsky', 'cayledrabinsky', 'ChrisBosh4!');
-- INSERT INTO users (first_name, last_name, username, password) VALUES ('Allie', 'Drabinsky', 'alliedrabinsky', 'Ballerina23');
-- INSERT INTO users (first_name, last_name, username, password) VALUES ('Daryl', 'Drabinsky', 'daryldrabinsky', 'socialmedia11');

ALTER TABLE airports 
ADD COLUMN city_country_airport text;

UPDATE airports
SET city_country_airport = CONCAT(city, ', ', country, ' ', '(', name, ' - ', iata_code, ')');

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

------------------------------------------------

SELECT 
  CASE WHEN f.origin_id = a.id THEN a.iata_code END origin,
  CASE WHEN f.destination_id = a.id THEN a.iata_code END destination,
  f.departure_date,
  f.return_date
FROM flights f 
INNER JOIN airports a ON a.id = f.origin_id OR a.id = f.destination_id;

SELECT 
  (SELECT a.iata_code FROM airports a WHERE a.id = f.origin_id),
  (SELECT a.iata_code FROM airports a WHERE a.id = f.destination_id),
  f.departure_date,
  f.return_date
FROM flights f;

WITH flight_info AS (
  SELECT 
    array_agg(a.iata_code) arr,
    f.departure_date, 
    f.return_date
  FROM flights f
  INNER JOIN airports a ON a.id IN (f.origin_id, f.destination_id) 
  GROUP BY f.id
)

SELECT
  arr[1] origin,
  arr[2] destination,
  departure_date,
  return_date
FROM flight_info;

------------------------------------------------

CREATE TABLE flights (
    id serial PRIMARY KEY,
    origin_id integer NOT NULL,
    destination_id integer NOT NULL,
    departure_date date NOT NULL,
    return_date date NOT NULL,
    created_on timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE tickets (
  id serial PRIMARY KEY,
  class text NOT NULL,
  traveler text NOT NULL,
  bags integer NOT NULL,
  flight_id integer REFERENCES flights(id) ON DELETE CASCADE
)

------------------------------------------------


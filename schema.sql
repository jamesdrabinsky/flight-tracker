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
ADD COLUMN country_city_airport text;

UPDATE airports
SET country_city_airport = CONCAT(country, ' - ', city, ' - ', name);

UPDATE airports 
SET name = NULL 
WHERE name = 'N/A';

------------------------------------------------

CREATE TABLE flights (
    id serial PRIMARY KEY,
    origin text NOT NULL,
    destination text NOT NULL,
    departure_date date NOT NULL,
    return_date date NOT NULL,
    created_on timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE
);




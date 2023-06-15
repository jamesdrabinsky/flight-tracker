-- createdb flights

CREATE TABLE airports (
    id serial,
    name text,
    latitude_deg numeric,
    longitude_deg numeric,
    iso_country varchar(3),
    municipality text
);

CREATE TABLE countries (
    id serial,
    code varchar(3),
    name text,
    continent varchar(3)
);

\copy airports(name, latitude_deg, longitude_deg, iso_country, municipality) FROM 'data/airports.csv' WITH HEADER CSV;
\copy countries(code, name, continent) FROM 'data/countries.csv' WITH HEADER CSV;

CREATE TABLE users (
    id serial PRIMARY KEY,
    first_name text NOT NULL,
    last_name text NOT NULL,
    username text NOT NULL,
    password text NOT NULL
);

INSERT INTO users (first_name, last_name, username, password) VALUES ('James', 'Drabinsky', 'jamesdrabinsky', 'Scottiebarnes4!');
INSERT INTO users (first_name, last_name, username, password) VALUES ('Cayle', 'Drabinsky', 'cayledrabinsky', 'ChrisBosh4!');
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

-- \copy airports(name, latitude_deg, longitude_deg, iso_country, municipality) FROM 'data/airports.csv' WITH HEADER CSV;
-- \copy countries(code, name, continent) FROM 'data/countries.csv' WITH HEADER CSV;
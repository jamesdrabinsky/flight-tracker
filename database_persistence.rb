require "pg"

class DatabasePersistence
  def initialize(logger)
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: "flight_tracker")
          end
    @logger = logger
  end

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def find_user(username)
    sql = "SELECT * FROM users WHERE username = $1"
    query(sql, username)
  end

  def all_airports
    sql = <<~SQL
      SELECT id, city_country_airport, name_iata_code
      FROM airports
      WHERE name is NOT NULL
      AND iata_code IS NOT NULL
      ORDER BY city, country, name;
    SQL

    result = query(sql)

    result.map do |tuple|
      { id: tuple["id"].to_i,
        city_country_airport: tuple["city_country_airport"],
        name_iata_code: tuple["name_iata_code"] }
    end
  end

  def city_country_airport(abbreviated_name)
    sql = <<~SQL
      SELECT city_country_airport
      FROM airports
      WHERE name_iata_code = $1;
    SQL

    query(sql, abbreviated_name)
  end

  def page_count(user_id)
    sql = <<~SQL
      SELECT CEIL(COUNT(id)::numeric / 5) page_count
      FROM flights
      WHERE user_id = $1;
    SQL

    query(sql, user_id).first["page_count"].to_i
  end

  def ticket_count(flight_id)
    sql = <<~SQL
      SELECT COUNT(*) ticket_count
      FROM tickets
      WHERE  flight_id = $1
    SQL

    query(sql, flight_id).first["ticket_count"].to_i
  end

  def load_user_credentials(username)
    sql = "SELECT * FROM users WHERE username = $1"
    result = query(sql, username)

    return unless result.ntuples > 0
    tuple = result.first

    { user_id: tuple["id"],
      first_name: tuple["first_name"],
      last_name: tuple["last_name"],
      username: tuple["username"],
      password: tuple["password"] }
  end

  def create_new_flight(origin, destination, date, user_id)
    sql = <<~SQL
      INSERT INTO flights (origin, destination, date, code, user_id)
      VALUES ($1, $2, $3, flight_code($1, $2, $3), $4)
    SQL
    query(sql, origin, destination, date, user_id)
  end

  def create_new_user(first_name, last_name, username, password)
    hashed_password = BCrypt::Password.create(password)
    sql = <<~SQL
      INSERT INTO users (first_name, last_name, username, password)
      VALUES ($1, $2, $3, $4)
    SQL
    query(sql, first_name, last_name, username, hashed_password)
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
      { id: tuple["id"].to_i,
        origin: tuple["origin"],
        destination: tuple["destination"],
        date: tuple["date"],
        code: tuple["code"] }
    end
  end

  def matching_flights(origin, destination, date, flight_id, user_id)
    sql = <<~SQL
        SELECT *
        FROM flights
        WHERE (origin, destination, date) = ($1, $2, $3)
        AND id != COALESCE($4, 0)
        AND user_id = $5;
    SQL

    query(sql, origin, destination, date, flight_id, user_id)
  end

  def load_flight(flight_id, user_id)
    sql = "SELECT * FROM flights WHERE id = $1 AND user_id = $2"
    result = query(sql, flight_id, user_id)

    return unless result.ntuples > 0
    tuple = result.first

    { id: tuple["id"].to_i,
      origin: tuple["origin"],
      destination: tuple["destination"],
      date: tuple["date"],
      code: tuple["code"] }
  end

  def update_flight(origin, destination, date, flight_id)
    flight_sql = <<~SQL
      UPDATE flights
      SET origin = $1,
          destination = $2,
          date = $3,
          code = flight_code($1, $2, $3)
      WHERE id = $4
    SQL
    query(flight_sql, origin, destination, date, flight_id)
  
    ticket_sql = <<~SQL
      UPDATE tickets
      SET code = (SELECT code FROM flights WHERE id = $1) || SUBSTRING(code, '-[a-z0-9]+$')
      WHERE flight_id = $1;
    SQL
    query(ticket_sql, flight_id)
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

  def find_tickets_for_flight(flight_id)
    sql = <<~SQL
      SELECT *
      FROM tickets
      WHERE flight_id = $1
      ORDER BY SUBSTRING(class::text, '^[0-9]{1}')::int DESC, bags DESC;
    SQL
  
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

  def load_ticket(flight_id, ticket_id, user_id)
    sql = <<~SQL
      SELECT t.*
      FROM tickets t
      INNER JOIN flights f ON f.id = t.flight_id
      WHERE t.flight_id = $1
      AND t.id = $2
      AND f.user_id = $3;
    SQL

    result = query(sql, flight_id, ticket_id, user_id)

    return unless result.ntuples > 0
    tuple = result.first

    { id: tuple["id"].to_i,
      class: tuple["class"],
      seat: tuple["seat"],
      traveler: tuple["traveler"],
      bags: tuple["bags"].to_i,
      code: tuple["code"] }
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

  def load_current_page_flights(page_number, user_id)
    sql = <<~SQL
      SELECT
        f.id, f.origin, f.destination, f.date, f.code,
        COUNT(t.id) ticket_count
      FROM flights f
      LEFT JOIN tickets t ON t.flight_id = f.id
      WHERE f.user_id = $1
      GROUP BY 1,2,3,4,5
      ORDER BY f.date , f.origin, f.destination
      LIMIT 5 OFFSET $2
    SQL
  
    result = query(sql, user_id, (page_number - 1) * 5)
    
    result.map do |tuple|
      { id: tuple["id"],
        origin: tuple["origin"],
        destination: tuple["destination"],
        date: tuple["date"],
        code: tuple["code"],
        ticket_count: tuple["ticket_count"] }
    end
  end

  def remove_all_flights(user_id)
    sql = "DELETE FROM flights WHERE user_id = $1"
    query(sql, user_id)
  end

  def remove_all_tickets(flight_id)
    sql = "DELETE FROM tickets WHERE flight_id = $1"
    query(sql, flight_id)
  end
end

require 'rubygems'
require 'pg'

conn = PG.connect(
  host: ENV['POSTGRES_PORT_5432_TCP_ADDR'],
  port: ENV['POSTGRES_PORT_5432_TCP_PORT'],
  user: 'postgres',
  password: ENV['POSTGRES_ENV_POSTGRES_PASSWORD'],
  dbname: 'postgres',
)

conn.exec "CREATE TABLE hello ( hello TEXT );"
conn.exec "INSERT INTO hello VALUES ('world');"
conn.exec "SELECT * FROM hello" do |result|
  result.each do |row|
    puts row
  end
end

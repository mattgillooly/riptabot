require 'pry'

require 'protobuf'
require 'google/transit/gtfs-realtime.pb'
require 'net/http'
require 'uri'
require 'influxdb'

DATABASE = 'ripta_vehicles'

influxdb = InfluxDB::Client.new
# influxdb.delete_database(DATABASE)
influxdb.create_database(DATABASE)

influxdb = InfluxDB::Client.new(DATABASE, async: true)

# URLs for real-time data (vehicle positions, alerts, etc)
TRIP_UPDATES_URL = 'http://realtime.ripta.com:81/api/tripupdates?format=gtfs.proto'

def trip_updates
  data = Net::HTTP.get(URI.parse(TRIP_UPDATES_URL))
  Transit_realtime::FeedMessage.decode(data)
end

loop do
  matches = trip_updates.entity.select{|e| e.trip_update.trip.route_id == '11'}

  influx_data = matches.flat_map do |e|
    tu = e.trip_update
    ts = tu.timestamp
    route_key = "ripta.routes.#{tu.trip.route_id}"

    tu.stop_time_update.map do |stop_time_update|
      stop_key = "#{route_key}.stop.#{stop_time_update.stop_id}"

      v = stop_time_update.arrival ? stop_time_update.arrival.delay.to_f : 0.0

      { series: "#{stop_key}.arrival.delay", values: { value: v }, timestamp: ts }
    end
  end

  influxdb.write_points(influx_data, 's')

  puts '.'

  sleep 10
end

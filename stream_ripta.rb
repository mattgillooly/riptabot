require 'pry'

require 'google_static_maps_helper'
require 'gtfs'
require 'protobuf'
require 'google/transit/gtfs-realtime.pb'
require 'net/http'
require 'uri'

# URLs for real-time data (vehicle positions, alerts, etc)
VEHICLE_POSITIONS_URL = 'http://realtime.ripta.com:81/api/vehiclepositions?format=gtfs.proto'
TRIP_UPDATES_URL = 'http://realtime.ripta.com:81/api/tripupdates?format=gtfs.proto'

# URL for static data (routes, stops, etc.)
STATIC_DATA_URL = 'http://www.ripta.com/googledata/current/google_transit.zip'

source = GTFS::Source.build(STATIC_DATA_URL)
ROUTES_BY_ID = source.routes.group_by{|r| r.id.strip.to_i}
STOPS_BY_ID = source.stops.group_by{|s| s.id.strip.to_i}

def route(id)
  ROUTES_BY_ID[id.strip.to_i].first
end

def stop(id)
  STOPS_BY_ID[id.strip.to_i].first
end

def vehicle_positions
  data = Net::HTTP.get(URI.parse(VEHICLE_POSITIONS_URL))
  Transit_realtime::FeedMessage.decode(data)
end

loop do
  matches = vehicle_positions.entity.select{|e| e.vehicle.trip.route_id == '11'}

  # Build a map with locations of all vehicles on the route
  map = GoogleStaticMapsHelper::Map.new(size: '640x480', sensor: false)

  matches.each do |e|
    v = e.vehicle
    p = v.position
    t = v.trip

    map << GoogleStaticMapsHelper::Marker.new(lng: p.longitude, lat: p.latitude)

    puts [
      route(t.route_id).short_name,
      route(t.route_id).long_name,
      e.id,
      'V:' + v.vehicle.id,
      'T:' + t.trip_id,
      t.start_date + 'T'  + t.start_time,
      p.latitude,
      p.longitude,
      Time.at(v.timestamp),
      stop(v.stop_id).name,
      e.alert
      # t.direction_id,
      # v.current_status,
      # v.occupancy_status,
      # v.congestion_level,
    ].join("\t")
  end

  puts map.url
  puts '---'

  sleep 10
end

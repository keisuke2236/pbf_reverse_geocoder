# frozen_string_literal: true

require_relative 'pbf_reverse_geocoder/version'
require_relative 'pbf_reverse_geocoder/simple_pbf_parser'
require_relative 'pbf_reverse_geocoder/geometry_decoder'
require_relative 'pbf_reverse_geocoder/point_in_polygon'
require_relative 'pbf_reverse_geocoder/tile_calculator'
require_relative 'pbf_reverse_geocoder/pbf_tile_reader'

# PBF-based reverse geocoding for Japanese administrative areas
module PbfReverseGeocoder

  class Error < StandardError; end

  # Main entry point for reverse geocoding
  #
  # @param lng [Float] Longitude
  # @param lat [Float] Latitude
  # @param tiles_dir [String, Pathname] Path to the tiles directory
  # @return [Hash, nil] Administrative area information or nil if not found
  #   { prefecture: '東京都', city: '千代田区', code: '13101' }
  #
  # @example
  #   result = PbfReverseGeocoder.reverse_geocode(139.7671, 35.6812, '/path/to/tiles')
  #   #=> { 'prefecture' => '東京都', 'city' => '千代田区', 'code' => '13101' }
  def self.reverse_geocode(lng, lat, tiles_dir)
    # Calculate tile coordinates
    tile_x, tile_y, zoom = TileCalculator.lng_lat_to_tile(lng, lat)
    tile_path = TileCalculator.tile_path(tile_x, tile_y, zoom, tiles_dir)

    # Read and parse the PBF tile
    features = PbfTileReader.read_tile(tile_path, tile_x, tile_y, zoom)

    # Find the polygon that contains the point
    point = [lng, lat]
    features.each do |feature|
      if PointInPolygon.contains?(point, feature[:geometry])
        return feature[:properties]
      end
    end

    nil
  end

end

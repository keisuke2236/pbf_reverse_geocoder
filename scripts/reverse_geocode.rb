# frozen_string_literal: true

require 'optparse'
require 'json'
require_relative '../lib/pbf_reverse_geocoder'

options = {
  tiles_dir: './tiles',
  lng: 139.7671,
  lat: 35.6812
}

OptionParser.new do |opts|
  opts.banner = 'Usage: ruby scripts/reverse_geocode.rb --tiles-dir ./tiles --lng 139.7671 --lat 35.6812'

  opts.on('--tiles-dir PATH', 'Directory where PBF tiles are stored') do |v|
    options[:tiles_dir] = v
  end

  opts.on('--lng FLOAT', Float, 'Longitude') do |v|
    options[:lng] = v
  end

  opts.on('--lat FLOAT', Float, 'Latitude') do |v|
    options[:lat] = v
  end
end.parse!

result = PbfReverseGeocoder.reverse_geocode(options[:lng], options[:lat], options[:tiles_dir])

if result
  puts JSON.pretty_generate(result)
else
  warn 'No administrative area found for the given coordinate.'
end

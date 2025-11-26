# frozen_string_literal: true

# Build vector tiles from the raw N03 dataset without altering attributes.
# Usage:
#   ruby scripts/build_tiles.rb --source N03-20250101_GML --tiles-dir ./tiles
#
# Requirements:
#   - tippecanoe
#   - (optional) ogr2ogr when GeoJSON is not present in the source directory

require 'optparse'
require 'pathname'
require 'fileutils'

options = {
  source: 'N03-20250101_GML',
  tiles_dir: 'tiles',
  zoom: 10,
  layer: 'N03'
}

OptionParser.new do |opts|
  opts.banner = 'Usage: ruby scripts/build_tiles.rb [options]'

  opts.on('--source PATH', 'Path to the extracted N03 dataset directory') do |v|
    options[:source] = v
  end

  opts.on('--geojson PATH', 'Use a specific GeoJSON file (skip conversion)') do |v|
    options[:geojson] = v
  end

  opts.on('--tiles-dir PATH', 'Output directory for the generated tiles') do |v|
    options[:tiles_dir] = v
  end

  opts.on('--zoom LEVEL', Integer, 'Zoom level (default: 10)') do |v|
    options[:zoom] = v
  end

  opts.on('--layer NAME', 'Layer name to embed in tiles (default: N03)') do |v|
    options[:layer] = v
  end
end.parse!

def command_available?(cmd)
  system("command -v #{cmd} >/dev/null 2>&1")
end

def find_first(pattern)
  Dir.glob(pattern).first
end

def ensure_geojson(source_dir, geojson_override)
  return Pathname.new(geojson_override).expand_path if geojson_override

  geojson = find_first(source_dir.join('*.geojson').to_s)
  return Pathname.new(geojson) if geojson

  shp = find_first(source_dir.join('*.shp').to_s)
  return nil unless shp

  unless command_available?('ogr2ogr')
    abort 'GeoJSON not found. Install GDAL (ogr2ogr) or provide --geojson to continue.'
  end

  geojson_path = Pathname.new(shp.sub(/\.shp\z/, '.geojson'))
  puts "Converting Shapefile to GeoJSON with ogr2ogr -> #{geojson_path}"
  system('ogr2ogr', '-f', 'GeoJSON', geojson_path.to_s, shp) || abort('ogr2ogr failed')

  geojson_path
end

def build_tiles(geojson_path, tiles_dir, zoom, layer)
  abort 'tippecanoe is required to build tiles' unless command_available?('tippecanoe')

  FileUtils.rm_rf(tiles_dir)
  FileUtils.mkdir_p(tiles_dir)

  cmd = [
    'tippecanoe',
    '--output-to-directory', tiles_dir.to_s,
    '--force',
    '--layer', layer,
    '-Z', zoom.to_s,
    '-z', zoom.to_s,
    '--no-feature-limit',
    '--no-tile-size-limit',
    geojson_path.to_s
  ]

  puts "Building tiles with tippecanoe (zoom=#{zoom}, layer=#{layer})"
  system(*cmd) || abort('tippecanoe failed')

  puts "Tiles created in #{tiles_dir}"
end

source_dir = Pathname.new(options[:source]).expand_path
abort "Source directory not found: #{source_dir}" unless source_dir.directory?

geojson_path = ensure_geojson(source_dir, options[:geojson])
abort 'GeoJSON source could not be prepared.' unless geojson_path && geojson_path.file?

build_tiles(geojson_path, Pathname.new(options[:tiles_dir]).expand_path,
            options[:zoom], options[:layer])

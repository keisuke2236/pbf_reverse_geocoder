# frozen_string_literal: true

require_relative 'lib/pbf_reverse_geocoder'

# 使用例
tiles_dir = '/path/to/tiles'

# 東京駅の座標
result = PbfReverseGeocoder.reverse_geocode(139.7671, 35.6812, tiles_dir)

if result
  puts "都道府県: #{result['prefecture']}"
  puts "市区町村: #{result['city']}"
  puts "地方公共団体コード: #{result['code']}"
else
  puts '該当する行政区域が見つかりませんでした'
end

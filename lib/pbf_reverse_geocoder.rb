# frozen_string_literal: true

require_relative 'pbf_reverse_geocoder/version'
require_relative 'pbf_reverse_geocoder/simple_pbf_parser'
require_relative 'pbf_reverse_geocoder/geometry_decoder'
require_relative 'pbf_reverse_geocoder/point_in_polygon'
require_relative 'pbf_reverse_geocoder/tile_calculator'
require_relative 'pbf_reverse_geocoder/pbf_tile_reader'

# 日本の行政区域のためのPBFベースのリバースジオコーディング
module PbfReverseGeocoder

  class Error < StandardError; end

  # リバースジオコーディングのメインエントリーポイント
  #
  # @param lng [Float] 経度
  # @param lat [Float] 緯度
  # @param tiles_dir [String, Pathname] タイルディレクトリへのパス
  # @return [Hash, nil] 行政区域情報、見つからない場合はnil
  #   { prefecture: '東京都', city: '千代田区', code: '13101' }
  #
  # @example
  #   result = PbfReverseGeocoder.reverse_geocode(139.7671, 35.6812, '/path/to/tiles')
  #   #=> { 'prefecture' => '東京都', 'city' => '千代田区', 'code' => '13101' }
  def self.reverse_geocode(lng, lat, tiles_dir)
    # タイル座標を計算
    tile_x, tile_y, zoom = TileCalculator.lng_lat_to_tile(lng, lat)
    tile_path = TileCalculator.tile_path(tile_x, tile_y, zoom, tiles_dir)

    # PBFタイルを読み込んでパース
    features = PbfTileReader.read_tile(tile_path, tile_x, tile_y, zoom)

    # 点を含むポリゴンを検索
    point = [lng, lat]
    features.each do |feature|
      if PointInPolygon.contains?(point, feature[:geometry])
        return feature[:properties]
      end
    end

    nil
  end

end

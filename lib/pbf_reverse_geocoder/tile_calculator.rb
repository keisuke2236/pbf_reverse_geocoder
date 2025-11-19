# frozen_string_literal: true

# 緯度経度からタイル座標を計算するモジュール
# @geolonia/open-reverse-geocoder の lngLatToGoogle ロジックを実装
module PbfReverseGeocoder
  class TileCalculator
    # ズームレベル10固定(@geoloniaと同じ、約30km四方)
    ZOOM = 10

    # Google XYZ タイル座標を計算
    # Web Mercator投影を使用
    #
    # @param lng [Float] 経度 (-180 ~ 180)
    # @param lat [Float] 緯度 (-90 ~ 90)
    # @return [Array<Integer>] [x, y, zoom]
    #
    # @example
    #   TileCalculator.lng_lat_to_tile(139.7671, 35.6812)
    #   #=> [904, 403, 10]
    # rubocop:disable Metrics/AbcSize
    def self.lng_lat_to_tile(lng, lat)
      # global-mercator の pointToTileFraction ロジック
      n = 2.0**ZOOM
      lat_rad = lat * Math::PI / 180.0
      sin_lat = Math.sin(lat_rad)

      # X座標(経度ベース)
      x = ((lng + 180.0) / 360.0 * n).floor

      # Y座標(緯度ベース、メルカトル投影)
      y = ((0.5 - (0.25 * Math.log((1 + sin_lat) / (1 - sin_lat)) / Math::PI)) * n).floor

      [x, y, ZOOM]
    end

    # タイルのファイルパスを生成
    #
    # @param x [Integer] タイルX座標
    # @param y [Integer] タイルY座標
    # @param zoom [Integer] ズームレベル
    # @param tiles_dir [String, Pathname] タイルディレクトリのベースパス
    # @return [Pathname] PBFファイルのパス
    #
    # @example
    #   TileCalculator.tile_path(904, 403, 10, '/app/public/tiles')
    #   #=> #<Pathname:/app/public/tiles/10/904/403.pbf>
    def self.tile_path(x, y, zoom, tiles_dir)
      require 'pathname'
      Pathname.new(tiles_dir).join(zoom.to_s, x.to_s, "#{y}.pbf")
    end
    # rubocop:enable Metrics/AbcSize
  end
end

# frozen_string_literal: true

# Mapbox Vector Tile (MVT) のジオメトリをデコードするモジュール
# Command integers と ZigZag encoding, Delta encoding を処理
module PbfReverseGeocoder

  class GeometryDecoder

    # MVT標準のタイル解像度
    EXTENT = 4096

    # MVTジオメトリをデコードして緯度経度ポリゴンに変換
    #
    # @param geometry [Array<Integer>] MVTエンコードされたジオメトリ
    # @param tile_x [Integer] タイルX座標
    # @param tile_y [Integer] タイルY座標
    # @param zoom [Integer] ズームレベル
    # @return [Array<Array<Float>>] [[lng, lat], ...] 緯度経度座標の配列
    #
    # @example
    #   GeometryDecoder.decode([9, 50, 34, ...], 904, 403, 10)
    #   #=> [[139.7671, 35.6812], ...]
    def self.decode(geometry, tile_x, tile_y, zoom)
      return [] if geometry.nil? || geometry.empty?

      coordinates = decode_commands(geometry)
      tile_coords_to_lng_lat(coordinates, tile_x, tile_y, zoom)
    end

    # Command integersをデコードしてタイル内座標に変換
    #
    # @param geometry [Array<Integer>] MVTエンコードされたジオメトリ
    # @return [Array<Array<Integer>>] [[x, y], ...] タイル内座標の配列
    #
    # @private
    def self.decode_commands(geometry)
      coords = []
      x = 0
      y = 0
      i = 0

      while i < geometry.length
        command_int = geometry[i]
        command = command_int & 0x7  # 下位3ビット:コマンド種別
        count = command_int >> 3     # 上位ビット:繰り返し回数

        case command
        when 1  # MoveTo:新しいパスを開始
          count.times do
            i += 1
            dx = decode_zigzag(geometry[i])
            i += 1
            dy = decode_zigzag(geometry[i])

            x += dx
            y += dy
            coords << [x, y]
          end
        when 2  # LineTo:現在位置から線を引く
          count.times do
            i += 1
            dx = decode_zigzag(geometry[i])
            i += 1
            dy = decode_zigzag(geometry[i])

            x += dx
            y += dy
            coords << [x, y]
          end
        when 7  # ClosePath:ポリゴンを閉じる
          # 座標追加は不要(最初の点に戻る)
        else
          # 不明なコマンド:スキップ
          warn "Unknown MVT command: #{command}" if $DEBUG
        end

        i += 1
      end

      coords
    end

    # ZigZag デコーディング
    # 負数をサポートするための変換を戻す
    #
    # @param n [Integer] エンコードされた値
    # @return [Integer] デコードされた値
    #
    # @private
    def self.decode_zigzag(n)
      (n >> 1) ^ -(n & 1)
    end

    # タイル内座標を緯度経度に変換
    #
    # @param coords [Array<Array<Integer>>] [[x, y], ...] タイル内座標
    # @param tile_x [Integer] タイルX座標
    # @param tile_y [Integer] タイルY座標
    # @param zoom [Integer] ズームレベル
    # @return [Array<Array<Float>>] [[lng, lat], ...] 緯度経度座標
    #
    # @private
    def self.tile_coords_to_lng_lat(coords, tile_x, tile_y, zoom)
      n = 2**zoom

      coords.map do |x, y|
        # タイル内相対座標 (0-4096) → 絶対座標 (0-1)
        rel_x = x.to_f / EXTENT
        rel_y = y.to_f / EXTENT

        # Google XYZ → 緯度経度(Web Mercator逆投影)
        pixel_x = (tile_x + rel_x) / n
        pixel_y = (tile_y + rel_y) / n

        lng = (pixel_x * 360.0) - 180.0

        lat_rad = Math.atan(Math.sinh(Math::PI * (1 - (2 * pixel_y))))
        lat = lat_rad * 180.0 / Math::PI

        [lng, lat]
      end
    end

    private_class_method :decode_commands, :decode_zigzag, :tile_coords_to_lng_lat

  end

end

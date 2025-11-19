# frozen_string_literal: true

require_relative 'simple_pbf_parser'
require_relative 'geometry_decoder'

# PBFタイルを読み込んでフィーチャー一覧を返すモジュール
module PbfReverseGeocoder

  class PbfTileReader

    # @geoloniaと同じレイヤー名
    LAYER_NAME = 'japanese-admins'

    # PBFタイルを読み込んでフィーチャー一覧を返す
    #
    # @param tile_path [String, Pathname] PBFファイルパス
    # @param tile_x [Integer] タイルX座標
    # @param tile_y [Integer] タイルY座標
    # @param zoom [Integer] ズームレベル
    # @return [Array<Hash>] フィーチャー配列
    #
    # @example
    #   features = PbfTileReader.read_tile('/app/public/tiles/10/904/403.pbf', 904, 403, 10)
    def self.read_tile(tile_path, tile_x, tile_y, zoom)
      return [] unless File.exist?(tile_path)

      # バイナリ読み込み
      pbf_data = File.binread(tile_path)

      # SimplePbfParserでパース
      tile = SimplePbfParser.parse(pbf_data)

      # japanese-admins レイヤーを抽出
      layer = tile[:layers].find { |l| l[:name] == LAYER_NAME }
      return [] unless layer

      # フィーチャーをGeoJSON形式に変換
      layer[:features].map do |feature|
        geometry = GeometryDecoder.decode(feature[:geometry], tile_x, tile_y, zoom)
        properties = decode_properties(feature, layer)

        {
          geometry: geometry,
          properties: properties
        }
      end
    rescue StandardError => e
      warn "Failed to read PBF tile: #{tile_path}, error: #{e.message}"
      warn e.backtrace.join("\n") if $DEBUG
      []
    end

    # フィーチャーのプロパティをデコード
    # tagsは [key_index, value_index, key_index, value_index, ...] の形式
    #
    # @param feature [Hash] フィーチャーデータ
    # @param layer [Hash] レイヤーデータ
    # @return [Hash] プロパティハッシュ
    #
    # @private
    def self.decode_properties(feature, layer)
      props = {}

      # IDがある場合はcodeとして扱う
      if feature[:id]
        code = feature[:id].to_s
        # 4桁の場合は先頭にゼロを追加（例: 1101 → 01101）
        code = code.rjust(5, '0') if code.length == 4
        props['code'] = code
      end

      # tagsをデコード（2要素ずつペアになっている）
      feature[:tags].each_slice(2) do |key_idx, val_idx|
        key = layer[:keys][key_idx]
        value_obj = layer[:values][val_idx]

        # 値を文字列として取得
        value = value_obj&.dig(:string_value) || ''

        props[key] = value
      end

      props
    end

    private_class_method :decode_properties

  end

end

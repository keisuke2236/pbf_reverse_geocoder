# frozen_string_literal: true

require_relative 'simple_pbf_parser'
require_relative 'geometry_decoder'
require 'zlib'
require 'stringio'

# PBFタイルを読み込んでフィーチャー一覧を返すモジュール
module PbfReverseGeocoder

  class PbfTileReader

    # サポートするレイヤー名
    # - 最新のN03タイルをそのまま使う場合: N03
    # - 互換用: @geolonia/open-reverse-geocoder の japanese-admins
    LAYER_NAMES = ['N03', 'N03-2025', 'japanese-admins'].freeze

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

      # バイナリ読み込み（gzipなら展開）
      pbf_data = File.binread(tile_path)
      if gzip?(pbf_data)
        begin
          pbf_data = Zlib::GzipReader.new(StringIO.new(pbf_data)).read
        rescue Zlib::GzipFile::Error
          warn "Failed to gunzip tile: #{tile_path}"
          return []
        end
      end

      # SimplePbfParserでパース
      tile = SimplePbfParser.parse(pbf_data)

      # japanese-admins レイヤーを抽出
      layer = find_layer(tile)
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

        value = extract_value(value_obj)
        props[key] = value unless key.nil?
      end

      normalize_properties(props)
    end

    # 値オブジェクトからRuby値を抽出
    #
    # @param value_obj [Hash, nil]
    # @return [Object, nil]
    def self.extract_value(value_obj)
      return '' unless value_obj

      value_obj[:string_value] ||
        value_obj[:float_value] ||
        value_obj[:double_value] ||
        value_obj[:int_value] ||
        value_obj[:uint_value] ||
        value_obj[:sint_value] ||
        value_obj[:bool_value] ||
        ''
    end

    # N03形式のプロパティを標準化
    #
    # - N03_* を pref/municipality/ward などに正規化
    # - city は municipality と ward を連結した互換フィールド
    #
    # @param props [Hash]
    # @return [Hash]
    def self.normalize_properties(props)
      normalized = props.dup

      prefecture = props['prefecture'] || props['N03_001']
      sub_prefecture = props['sub_prefecture'] || props['N03_002']
      county = props['county'] || props['N03_003']
      municipality = props['municipality'] || props['city'] || props['N03_004']
      ward = props['ward'] || props['N03_005']

      code = props['code'] || props['N03_007'] || props['id']
      code = code.to_i.to_s if code.is_a?(Integer)
      code = code.to_s.rjust(5, '0') if code

      if ward.to_s.empty? && municipality == props['city']
        # 分離されていない市+区の文字列を分割（例: 大阪市中央区）
        if municipality && (m = municipality.match(/\A(.+市)(.+区)\z/))
          municipality = m[1]
          ward = m[2]
        end
      end

      city = props['city'] || [municipality, ward].compact.join

      normalized['prefecture'] ||= prefecture if prefecture
      normalized['sub_prefecture'] ||= sub_prefecture if sub_prefecture
      normalized['county'] ||= county if county
      normalized['municipality'] ||= municipality if municipality
      normalized['ward'] ||= ward if ward
      normalized['city'] ||= city unless city.nil? || city.empty?
      normalized['code'] ||= code if code

      normalized
    end

    def self.find_layer(tile)
      tile[:layers].find { |l| LAYER_NAMES.include?(l[:name]) } ||
        tile[:layers].first
    end

    def self.gzip?(data)
      data.bytes[0, 2] == [0x1f, 0x8b]
    end

    private_class_method :decode_properties, :extract_value, :find_layer, :gzip?

  end

end

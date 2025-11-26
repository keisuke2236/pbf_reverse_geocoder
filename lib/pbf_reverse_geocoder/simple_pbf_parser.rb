# frozen_string_literal: true

# Mapbox Vector Tile (MVT) に特化した簡易PBFパーサー
# Protocol Buffersの基本的なワイヤフォーマットをパース
module PbfReverseGeocoder

  class SimplePbfParser

    # Protocol Buffersのワイヤタイプ
    WIRE_TYPE_VARINT = 0
    WIRE_TYPE_64BIT = 1
    WIRE_TYPE_LENGTH_DELIMITED = 2
    WIRE_TYPE_32BIT = 5

    # PBFバイナリをパースしてMVTタイルデータを返す
    #
    # @param data [String] バイナリデータ
    # @return [Hash] パースされたタイルデータ
    def self.parse(data)
      buffer = data.bytes
      pos = 0
      tile = { layers: [] }

      while pos < buffer.length
        field_key, pos = read_varint(buffer, pos)
        field_number = field_key >> 3
        wire_type = field_key & 0x7

        case wire_type
        when WIRE_TYPE_LENGTH_DELIMITED
          length, pos = read_varint(buffer, pos)
          value_bytes = buffer[pos, length]
          pos += length

          # Field 3: layers
          if field_number == 3
            layer = parse_layer(value_bytes)
            tile[:layers] << layer if layer
          end
        else
          # その他のフィールドはスキップ
          pos = skip_field(buffer, pos, wire_type)
        end
      end

      tile
    end

    # レイヤーをパース
    #
    # @param data [Array<Integer>] バイナリデータ
    # @return [Hash] パースされたレイヤーデータ
    # @private
    def self.parse_layer(data)
      pos = 0
      layer = { name: '', features: [], keys: [], values: [] }

      while pos < data.length
        field_key, pos = read_varint(data, pos)
        field_number = field_key >> 3
        wire_type = field_key & 0x7

        case wire_type
        when WIRE_TYPE_LENGTH_DELIMITED
          length, pos = read_varint(data, pos)
          value_bytes = data[pos, length]
          pos += length

          case field_number
          when 1  # name
            layer[:name] = value_bytes.pack('C*').force_encoding('UTF-8')
          when 2  # features
            feature = parse_feature(value_bytes)
            layer[:features] << feature if feature
          when 3  # keys
            layer[:keys] << value_bytes.pack('C*').force_encoding('UTF-8')
          when 4  # values
            value = parse_value(value_bytes)
            layer[:values] << value if value
          end
        else
          pos = skip_field(data, pos, wire_type)
        end
      end

      layer
    end

    # フィーチャーをパース
    #
    # @param data [Array<Integer>] バイナリデータ
    # @return [Hash] パースされたフィーチャーデータ
    # @private
    def self.parse_feature(data)
      pos = 0
      feature = { id: nil, tags: [], type: 0, geometry: [] }

      while pos < data.length
        field_key, pos = read_varint(data, pos)
        field_number = field_key >> 3
        wire_type = field_key & 0x7

        case wire_type
        when WIRE_TYPE_VARINT
          value, pos = read_varint(data, pos)
          case field_number
          when 1  # id
            feature[:id] = value
          when 3  # type
            feature[:type] = value
          end
        when WIRE_TYPE_LENGTH_DELIMITED
          length, pos = read_varint(data, pos)
          value_bytes = data[pos, length]
          pos += length

          case field_number
          when 2  # tags (packed)
            feature[:tags] = unpack_packed_varint(value_bytes)
          when 4  # geometry (packed)
            feature[:geometry] = unpack_packed_varint(value_bytes)
          end
        else
          pos = skip_field(data, pos, wire_type)
        end
      end

      feature
    end

    # 値をパース
    #
    # @param data [Array<Integer>] バイナリデータ
    # @return [Hash] パースされた値
    # @private
    def self.parse_value(data)
      pos = 0
      value = {}

      while pos < data.length
        field_key, pos = read_varint(data, pos)
        field_number = field_key >> 3
        wire_type = field_key & 0x7

        case wire_type
        when WIRE_TYPE_VARINT
          number, pos = read_varint(data, pos)
          case field_number
          when 4
            value[:int_value] = number
          when 5
            value[:uint_value] = number
          when 6
            value[:sint_value] = zigzag_decode(number)
          when 7
            value[:bool_value] = number != 0
          end
        when WIRE_TYPE_32BIT
          # float_value
          if field_number == 2
            bytes = data[pos, 4]
            pos += 4
            value[:float_value] = bytes.pack('C*').unpack1('e')
          end
        when WIRE_TYPE_64BIT
          # double_value
          if field_number == 3
            bytes = data[pos, 8]
            pos += 8
            value[:double_value] = bytes.pack('C*').unpack1('E')
          end
        when WIRE_TYPE_LENGTH_DELIMITED
          length, pos = read_varint(data, pos)
          value_bytes = data[pos, length]
          pos += length

          value[:string_value] = value_bytes.pack('C*').force_encoding('UTF-8') if field_number == 1 # string_value
        else
          pos = skip_field(data, pos, wire_type)
        end
      end

      value
    end

    # Varint (可変長整数) を読み取る
    #
    # @param buffer [Array<Integer>] バイトバッファ
    # @param pos [Integer] 現在位置
    # @return [Array<Integer, Integer>] [値, 新しい位置]
    # @private
    def self.read_varint(buffer, pos)
      value = 0
      shift = 0

      loop do
        byte = buffer[pos]
        pos += 1

        value |= (byte & 0x7F) << shift
        shift += 7

        break unless byte.anybits?(0x80)
      end

      [value, pos]
    end

    # Packed varint配列を展開
    #
    # @param data [Array<Integer>] バイトデータ
    # @return [Array<Integer>] 展開された整数配列
    # @private
    def self.unpack_packed_varint(data)
      pos = 0
      result = []

      while pos < data.length
        value, pos = read_varint(data, pos)
        result << value
      end

      result
    end

    # フィールドをスキップ
    #
    # @param buffer [Array<Integer>] バイトバッファ
    # @param pos [Integer] 現在位置
    # @param wire_type [Integer] ワイヤタイプ
    # @return [Integer] 新しい位置
    # @private
    def self.skip_field(buffer, pos, wire_type)
      case wire_type
      when WIRE_TYPE_VARINT
        _value, pos = read_varint(buffer, pos)
      when WIRE_TYPE_64BIT
        pos += 8
      when WIRE_TYPE_LENGTH_DELIMITED
        length, pos = read_varint(buffer, pos)
        pos += length
      when WIRE_TYPE_32BIT
        pos += 4
      end

      pos
    end

    def self.zigzag_decode(value)
      (value >> 1) ^ -(value & 1)
    end

    private_class_method :parse_layer, :parse_feature, :parse_value,
                         :read_varint, :unpack_packed_varint, :skip_field,
                         :zigzag_decode

  end

end

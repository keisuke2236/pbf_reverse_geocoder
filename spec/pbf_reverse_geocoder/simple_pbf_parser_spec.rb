# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PbfReverseGeocoder::SimplePbfParser do
  describe '.read_varint' do
    it '1バイトのvarint（127以下）を読み取ること' do
      buffer = [0x05]  # 5
      value, pos = described_class.send(:read_varint, buffer, 0)

      expect(value).to eq(5)
      expect(pos).to eq(1)
    end

    it '2バイトのvarint（128以上）を読み取ること' do
      # 150 = 0x96 = 0b10010110
      # varint: [0x96, 0x01] = [0b10010110, 0b00000001]
      buffer = [0x96, 0x01]
      value, pos = described_class.send(:read_varint, buffer, 0)

      expect(value).to eq(150)
      expect(pos).to eq(2)
    end

    it '3バイトのvarint を読み取ること' do
      # 16384 = 0x4000
      # varint: [0x80, 0x80, 0x01]
      buffer = [0x80, 0x80, 0x01]
      value, pos = described_class.send(:read_varint, buffer, 0)

      expect(value).to eq(16_384)
      expect(pos).to eq(3)
    end

    it 'オフセット位置から読み取ること' do
      buffer = [0xFF, 0xFF, 0x05, 0x10]  # 前2バイトはダミー
      value, pos = described_class.send(:read_varint, buffer, 2)

      expect(value).to eq(5)
      expect(pos).to eq(3)
    end
  end

  describe '.unpack_packed_varint' do
    it '単一のvarintを展開すること' do
      data = [0x05]
      result = described_class.send(:unpack_packed_varint, data)

      expect(result).to eq([5])
    end

    it '複数のvarintを展開すること' do
      # [5, 150, 10]
      data = [0x05, 0x96, 0x01, 0x0A]
      result = described_class.send(:unpack_packed_varint, data)

      expect(result).to eq([5, 150, 10])
    end

    it '空の配列で空配列を返すこと' do
      result = described_class.send(:unpack_packed_varint, [])

      expect(result).to eq([])
    end
  end

  describe '.skip_field' do
    it 'VARINT フィールドをスキップすること' do
      buffer = [0x96, 0x01, 0xFF]  # 150(varint), 0xFF(次のデータ)
      pos = described_class.send(:skip_field, buffer, 0, described_class::WIRE_TYPE_VARINT)

      expect(pos).to eq(2)  # 2バイトスキップ
    end

    it '64BIT フィールドをスキップすること' do
      buffer = [0x00] * 10
      pos = described_class.send(:skip_field, buffer, 0, described_class::WIRE_TYPE_64BIT)

      expect(pos).to eq(8)  # 8バイトスキップ
    end

    it '32BIT フィールドをスキップすること' do
      buffer = [0x00] * 10
      pos = described_class.send(:skip_field, buffer, 0, described_class::WIRE_TYPE_32BIT)

      expect(pos).to eq(4)  # 4バイトスキップ
    end

    it 'LENGTH_DELIMITED フィールドをスキップすること' do
      # length=5, data=5バイト
      buffer = [0x05, 0x01, 0x02, 0x03, 0x04, 0x05, 0xFF]
      pos = described_class.send(:skip_field, buffer, 0, described_class::WIRE_TYPE_LENGTH_DELIMITED)

      expect(pos).to eq(6)  # 1(length) + 5(data) = 6バイトスキップ
    end
  end

  describe '.parse_value' do
    it '文字列値をパースすること' do
      # Field 1 (string_value): wire_type=2, value="test"
      # field_key = (1 << 3) | 2 = 10
      data = [
        10,                           # field_key
        4,                            # length
        0x74, 0x65, 0x73, 0x74       # "test"
      ]

      result = described_class.send(:parse_value, data)

      expect(result).to eq({ string_value: 'test' })
    end

    it '空の文字列値をパースすること' do
      data = [10, 0]  # field_key=10, length=0

      result = described_class.send(:parse_value, data)

      expect(result).to eq({ string_value: '' })
    end

    it '不明なフィールドをスキップして空ハッシュを返すこと' do
      # Field 5 (unknown): wire_type=2
      data = [42, 2, 0x01, 0x02]  # field_key=(5<<3)|2=42

      result = described_class.send(:parse_value, data)

      expect(result).to eq({})
    end
  end

  describe '.parse_feature' do
    it 'フィーチャーのid, type, tags, geometryをパースすること' do
      # Feature with:
      # - id = 13101 (field 1, varint)
      # - type = 3 (Polygon) (field 3, varint)
      # - tags = [0, 0, 1, 1] (field 2, packed)
      # - geometry = [9, 100, 68] (field 4, packed)

      # Simplified mock data
      data = [
        0x08, 0xCD, 0xE6, 0x03,      # field 1: id=13101 (varint)
        0x18, 0x03,                   # field 3: type=3 (varint)
        0x12, 0x04, 0x00, 0x00, 0x01, 0x01,  # field 2: tags=[0,0,1,1]
        0x22, 0x03, 0x09, 0x64, 0x44  # field 4: geometry=[9,100,68]
      ]

      result = described_class.send(:parse_feature, data)

      expect(result[:id]).to eq(13_101)
      expect(result[:type]).to eq(3)
      expect(result[:tags]).to eq([0, 0, 1, 1])
      expect(result[:geometry]).to eq([9, 100, 68])
    end

    it '最小限のフィーチャー（id/typeなし）をパースすること' do
      data = []  # 空のフィーチャー

      result = described_class.send(:parse_feature, data)

      expect(result[:id]).to be_nil
      expect(result[:type]).to eq(0)
      expect(result[:tags]).to eq([])
      expect(result[:geometry]).to eq([])
    end
  end

  describe 'integration: parse full tile' do
    # 完全な統合テストは実際のPBFバイナリが必要なため、
    # ここでは構造のバリデーションのみ行う

    it 'parse メソッドが存在すること' do
      expect(described_class).to respond_to(:parse)
    end

    it '空のバイナリで空のタイルを返すこと' do
      result = described_class.parse('')

      expect(result).to have_key(:layers)
      expect(result[:layers]).to be_an(Array)
      expect(result[:layers]).to be_empty
    end
  end
end

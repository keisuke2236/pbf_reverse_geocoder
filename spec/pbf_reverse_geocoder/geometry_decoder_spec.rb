# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PbfReverseGeocoder::GeometryDecoder do
  describe '.decode_zigzag' do
    it '0 を正しくデコードすること' do
      expect(described_class.send(:decode_zigzag, 0)).to eq(0)
    end

    it '正の数（1 → 1）を正しくデコードすること' do
      expect(described_class.send(:decode_zigzag, 1)).to eq(-1)
    end

    it '正の数（2 → 1）を正しくデコードすること' do
      expect(described_class.send(:decode_zigzag, 2)).to eq(1)
    end

    it '負の数をデコードすること' do
      expect(described_class.send(:decode_zigzag, 3)).to eq(-2)
      expect(described_class.send(:decode_zigzag, 5)).to eq(-3)
    end

    it '大きな正の数を正しくデコードすること' do
      expect(described_class.send(:decode_zigzag, 200)).to eq(100)
    end

    it '大きな負の数を正しくデコードすること' do
      expect(described_class.send(:decode_zigzag, 201)).to eq(-101)
    end
  end

  describe '.decode_commands' do
    context 'MoveTo コマンド（command=1）の場合' do
      it '1点の MoveTo を正しくデコードすること' do
        geometry = [9, 100, 68]
        coords = described_class.send(:decode_commands, geometry)

        expect(coords).to eq([[50, 34]])
      end

      it '複数点の MoveTo を正しくデコードすること' do
        geometry = [17, 20, 40, 10, 10]
        coords = described_class.send(:decode_commands, geometry)

        expect(coords).to eq([[10, 20], [15, 25]])
      end
    end

    context 'LineTo コマンド（command=2）の場合' do
      it 'MoveTo + LineTo の組み合わせを正しくデコードすること' do
        geometry = [9, 20, 40, 18, 10, 10, 10, 10]
        coords = described_class.send(:decode_commands, geometry)

        expect(coords).to eq([[10, 20], [15, 25], [20, 30]])
      end
    end

    context 'ClosePath コマンド（command=7）の場合' do
      it 'ClosePath を処理すること（座標追加なし）' do
        geometry = [9, 20, 40, 18, 10, 10, 10, 10, 15]
        coords = described_class.send(:decode_commands, geometry)

        expect(coords).to eq([[10, 20], [15, 25], [20, 30]])
      end
    end

    context 'エッジケース' do
      it '空の geometry 配列で空配列を返すこと' do
        coords = described_class.send(:decode_commands, [])

        expect(coords).to eq([])
      end

      it '不明なコマンドをスキップすること' do
        geometry = [13, 9, 20, 40]
        coords = described_class.send(:decode_commands, geometry)

        expect(coords).to eq([[10, 20]])
      end
    end
  end

  describe '.tile_coords_to_lng_lat' do
    it 'タイル内座標を緯度経度に変換すること' do
      coords = [[2048, 2048]]
      result = described_class.send(:tile_coords_to_lng_lat, coords, 904, 403, 10)

      lng, lat = result.first
      expect(lng).to be_within(0.5).of(138.0)
      expect(lat).to be_within(0.5).of(35.7)
    end

    it 'タイル左上隅（0, 0）を正しく変換すること' do
      coords = [[0, 0]]
      result = described_class.send(:tile_coords_to_lng_lat, coords, 904, 403, 10)

      lng, lat = result.first
      expect(lng).to be_a(Float)
      expect(lat).to be_a(Float)
    end

    it 'タイル右下隅（4096, 4096）を正しく変換すること' do
      coords = [[4096, 4096]]
      result = described_class.send(:tile_coords_to_lng_lat, coords, 904, 403, 10)

      lng, lat = result.first
      expect(lng).to be_a(Float)
      expect(lat).to be_a(Float)
    end

    it '複数の座標を一括変換すること' do
      coords = [[0, 0], [2048, 2048], [4096, 4096]]
      result = described_class.send(:tile_coords_to_lng_lat, coords, 904, 403, 10)

      expect(result.length).to eq(3)
      result.each do |lng, lat|
        expect(lng).to be_a(Float)
        expect(lat).to be_a(Float)
      end
    end

    it '空の座標配列で空配列を返すこと' do
      result = described_class.send(:tile_coords_to_lng_lat, [], 904, 403, 10)

      expect(result).to eq([])
    end
  end

  describe '.decode' do
    it 'MVTジオメトリを緯度経度ポリゴンに変換すること' do
      geometry = [9, 100, 68, 26, 20, 0, 0, 40, 40, 0, 15]

      result = described_class.decode(geometry, 904, 403, 10)

      expect(result).to be_an(Array)
      expect(result.length).to eq(4)
      result.each do |lng, lat|
        expect(lng).to be_a(Float)
        expect(lat).to be_a(Float)
      end
    end

    it 'nil のジオメトリで空配列を返すこと' do
      result = described_class.decode(nil, 904, 403, 10)

      expect(result).to eq([])
    end

    it '空のジオメトリで空配列を返すこと' do
      result = described_class.decode([], 904, 403, 10)

      expect(result).to eq([])
    end
  end
end

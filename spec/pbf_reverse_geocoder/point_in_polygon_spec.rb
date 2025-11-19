# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PbfReverseGeocoder::PointInPolygon do
  describe '.contains?' do
    # 簡単な四角形ポリゴン (0,0), (10,0), (10,10), (0,10)
    let(:square_polygon) do
      [
        [0.0, 0.0],
        [10.0, 0.0],
        [10.0, 10.0],
        [0.0, 10.0]
      ]
    end

    let(:l_shaped_polygon) do
      [
        [0.0, 0.0],
        [10.0, 0.0],
        [10.0, 5.0],
        [5.0, 5.0],
        [5.0, 10.0],
        [0.0, 10.0]
      ]
    end

    context 'ポリゴン内の点を渡した場合' do
      it '四角形の中心点で true を返すこと' do
        result = described_class.contains?([5.0, 5.0], square_polygon)

        expect(result).to be true
      end

      it '四角形の左上隅付近で true を返すこと' do
        result = described_class.contains?([1.0, 9.0], square_polygon)

        expect(result).to be true
      end

      it 'L字型ポリゴンの左下部分で true を返すこと' do
        result = described_class.contains?([2.0, 2.0], l_shaped_polygon)

        expect(result).to be true
      end

      it 'L字型ポリゴンの左上部分で true を返すこと' do
        result = described_class.contains?([2.0, 7.0], l_shaped_polygon)

        expect(result).to be true
      end
    end

    context 'ポリゴン外の点を渡した場合' do
      it '四角形の外側（右上）で false を返すこと' do
        result = described_class.contains?([15.0, 15.0], square_polygon)

        expect(result).to be false
      end

      it '四角形の外側（左下）で false を返すこと' do
        result = described_class.contains?([-5.0, -5.0], square_polygon)

        expect(result).to be false
      end

      it 'L字型ポリゴンの切り欠き部分で false を返すこと' do
        result = described_class.contains?([7.0, 7.0], l_shaped_polygon)

        expect(result).to be false
      end
    end

    context '境界線上の点を渡した場合' do
      it '四角形の辺上で結果を返すこと' do
        result = described_class.contains?([5.0, 0.0], square_polygon)

        expect([true, false]).to include(result)
      end

      it '四角形の頂点で結果を返すこと' do
        result = described_class.contains?([0.0, 0.0], square_polygon)

        expect([true, false]).to include(result)
      end
    end

    context 'エッジケース' do
      it '空のポリゴンで false を返すこと' do
        result = described_class.contains?([5.0, 5.0], [])

        expect(result).to be false
      end

      it 'nil のポリゴンで false を返すこと' do
        result = described_class.contains?([5.0, 5.0], nil)

        expect(result).to be false
      end

      it '1点のみのポリゴンで false を返すこと' do
        result = described_class.contains?([5.0, 5.0], [[0.0, 0.0]])

        expect(result).to be false
      end

      it '2点のみのポリゴン（線分）で false を返すこと' do
        result = described_class.contains?([5.0, 5.0], [[0.0, 0.0], [10.0, 10.0]])

        expect(result).to be false
      end
    end

    context '実際の日本の座標に近い値' do
      let(:tokyo_polygon) do
        [
          [139.5, 35.5],
          [139.9, 35.5],
          [139.9, 35.8],
          [139.5, 35.8]
        ]
      end

      it '東京駅の座標で true を返すこと' do
        result = described_class.contains?([139.7671, 35.6812], tokyo_polygon)

        expect(result).to be true
      end

      it '横浜の座標で false を返すこと' do
        result = described_class.contains?([139.6380, 35.4437], tokyo_polygon)

        expect(result).to be false
      end
    end
  end
end

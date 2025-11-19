# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PbfReverseGeocoder::TileCalculator do
  describe '.lng_lat_to_tile' do
    context '東京駅の座標を渡した場合' do
      it '正しいタイル座標を返すこと' do
        x, y, zoom = described_class.lng_lat_to_tile(139.7671, 35.6812)

        expect(zoom).to eq(10)
        expect(x).to eq(904)
        expect(y).to eq(403)
      end
    end

    context '大阪城の座標を渡した場合' do
      it '正しいタイル座標を返すこと' do
        x, y, zoom = described_class.lng_lat_to_tile(135.5258, 34.6873)

        expect(zoom).to eq(10)
        expect(x).to eq(899)
        expect(y).to eq(406)
      end
    end

    context '札幌駅の座標を渡した場合' do
      it '正しいタイル座標を返すこと' do
        x, y, zoom = described_class.lng_lat_to_tile(141.3506, 43.0686)

        expect(zoom).to eq(10)
        expect(x).to eq(907)
        expect(y).to eq(390)
      end
    end

    context '境界値の座標を渡した場合' do
      it '西端（経度-180）で正しい座標を返すこと' do
        x, y, zoom = described_class.lng_lat_to_tile(-180.0, 0.0)

        expect(zoom).to eq(10)
        expect(x).to eq(0)
        expect(y).to eq(512)
      end

      it '東端（経度180）で正しい座標を返すこと' do
        x, y, zoom = described_class.lng_lat_to_tile(180.0, 0.0)

        expect(zoom).to eq(10)
        expect(x).to eq(1024)
        expect(y).to eq(512)
      end

      it '北端付近（緯度85）で正しい座標を返すこと' do
        x, y, zoom = described_class.lng_lat_to_tile(0.0, 85.0)

        expect(zoom).to eq(10)
        expect(y).to be < 10  # 北端に近い座標
      end

      it '南端付近（緯度-85）で正しい座標を返すこと' do
        x, y, zoom = described_class.lng_lat_to_tile(0.0, -85.0)

        expect(zoom).to eq(10)
        expect(y).to be > 1014  # 南端に近い座標
      end
    end
  end

  describe '.tile_path' do
    it '正しいファイルパスを生成すること' do
      path = described_class.tile_path(904, 403, 10, '/app/tiles')

      expect(path.to_s).to eq('/app/tiles/10/904/403.pbf')
    end

    it 'Pathnameオブジェクトを返すこと' do
      path = described_class.tile_path(904, 403, 10, '/app/tiles')

      expect(path).to be_a(Pathname)
    end

    it 'tiles_dirがPathnameの場合も正しく動作すること' do
      require 'pathname'
      tiles_dir = Pathname.new('/app/tiles')
      path = described_class.tile_path(904, 403, 10, tiles_dir)

      expect(path.to_s).to eq('/app/tiles/10/904/403.pbf')
    end
  end
end

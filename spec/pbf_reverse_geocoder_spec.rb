# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe PbfReverseGeocoder do
  it 'バージョン番号が定義されていること' do
    expect(PbfReverseGeocoder::VERSION).not_to be_nil
  end

  describe '.reverse_geocode' do
    let(:temp_dir) { Dir.mktmpdir }
    let(:tiles_dir) { File.join(temp_dir, 'tiles') }

    after do
      FileUtils.rm_rf(temp_dir)
    end

    context 'タイルファイルが存在しない場合' do
      it 'nil を返すこと' do
        result = described_class.reverse_geocode(139.7671, 35.6812, tiles_dir)

        expect(result).to be_nil
      end
    end

    context 'タイルファイルは存在するが該当する地域がない場合' do
      it 'nil を返すこと' do
        # モックで空のフィーチャーリストを返す
        allow(PbfReverseGeocoder::PbfTileReader).to receive(:read_tile)
          .and_return([])

        result = described_class.reverse_geocode(139.7671, 35.6812, tiles_dir)

        expect(result).to be_nil
      end
    end

    context '該当する地域が見つかった場合' do
      it '行政区域情報を返すこと' do
        mock_features = [
          {
            geometry: [[139.7, 35.6], [139.8, 35.6], [139.8, 35.7], [139.7, 35.7]],
            properties: {
              'prefecture' => '東京都',
              'city' => '千代田区',
              'code' => '13101'
            }
          }
        ]

        allow(PbfReverseGeocoder::PbfTileReader).to receive(:read_tile)
          .and_return(mock_features)
        allow(PbfReverseGeocoder::PointInPolygon).to receive(:contains?)
          .and_return(true)

        result = described_class.reverse_geocode(139.7671, 35.6812, tiles_dir)

        expect(result).to include(
          'prefecture' => '東京都',
          'city' => '千代田区',
          'municipality' => '千代田区',
          'code' => '13101'
        )
      end
    end

    context '複数のポリゴンがあるが最初のものだけがマッチする場合' do
      it '最初にマッチしたポリゴンの情報を返すこと' do
        mock_features = [
          {
            geometry: [[139.7, 35.6], [139.8, 35.6], [139.8, 35.7], [139.7, 35.7]],
            properties: {
              'prefecture' => '東京都',
              'city' => '千代田区',
              'code' => '13101'
            }
          },
          {
            geometry: [[140.0, 36.0], [140.1, 36.0], [140.1, 36.1], [140.0, 36.1]],
            properties: {
              'prefecture' => '茨城県',
              'city' => 'つくば市',
              'code' => '08220'
            }
          }
        ]

        allow(PbfReverseGeocoder::PbfTileReader).to receive(:read_tile)
          .and_return(mock_features)

        # 最初のポリゴンのみマッチ
        call_count = 0
        allow(PbfReverseGeocoder::PointInPolygon).to receive(:contains?) do
          call_count += 1
          call_count == 1  # 最初の呼び出しのみ true
        end

        result = described_class.reverse_geocode(139.7671, 35.6812, tiles_dir)

        expect(result['city']).to eq('千代田区')
        expect(result['municipality']).to eq('千代田区')
      end
    end

    context 'タイル座標計算が正しく行われること' do
      it 'TileCalculator を使用してタイル座標を計算すること' do
        allow(PbfReverseGeocoder::TileCalculator).to receive(:lng_lat_to_tile)
          .and_return([904, 403, 10])
        allow(PbfReverseGeocoder::TileCalculator).to receive(:tile_path)
          .and_return(Pathname.new("#{tiles_dir}/10/904/403.pbf"))
        allow(PbfReverseGeocoder::PbfTileReader).to receive(:read_tile)
          .and_return([])

        described_class.reverse_geocode(139.7671, 35.6812, tiles_dir)

        expect(PbfReverseGeocoder::TileCalculator).to have_received(:lng_lat_to_tile)
          .with(139.7671, 35.6812)
        expect(PbfReverseGeocoder::TileCalculator).to have_received(:tile_path)
          .with(904, 403, 10, tiles_dir)
      end
    end

    context '実際の地点での動作確認（モック使用）' do
      before do
        # 全体をモック化
        allow(PbfReverseGeocoder::TileCalculator).to receive(:lng_lat_to_tile)
          .and_return([904, 403, 10])
        allow(PbfReverseGeocoder::TileCalculator).to receive(:tile_path)
          .and_return(Pathname.new("#{tiles_dir}/10/904/403.pbf"))
        allow(PbfReverseGeocoder::PbfTileReader).to receive(:read_tile)
          .and_return(mock_features)
        allow(PbfReverseGeocoder::PointInPolygon).to receive(:contains?)
          .and_return(should_match)
      end

      let(:mock_features) do
        [
          {
            geometry: [[139.7, 35.6], [139.8, 35.6], [139.8, 35.7], [139.7, 35.7]],
            properties: properties
          }
        ]
      end

      context '東京駅の座標' do
        let(:properties) do
          {
            'prefecture' => '東京都',
            'city' => '千代田区',
            'code' => '13101'
          }
        end
        let(:should_match) { true }

        it '東京都千代田区を返すこと' do
          result = described_class.reverse_geocode(139.7671, 35.6812, tiles_dir)

          expect(result['prefecture']).to eq('東京都')
          expect(result['city']).to eq('千代田区')
          expect(result['municipality']).to eq('千代田区')
          expect(result['code']).to eq('13101')
        end
      end

      context '大阪城の座標' do
        let(:properties) do
          {
            'prefecture' => '大阪府',
            'city' => '大阪市中央区',
            'code' => '27128'
          }
        end
        let(:should_match) { true }

        it '大阪府大阪市中央区を返すこと' do
          allow(PbfReverseGeocoder::TileCalculator).to receive(:lng_lat_to_tile)
            .and_return([899, 406, 10])

          result = described_class.reverse_geocode(135.5258, 34.6873, tiles_dir)

          expect(result['prefecture']).to eq('大阪府')
          expect(result['city']).to eq('大阪市中央区')
          expect(result['municipality']).to eq('大阪市')
          expect(result['ward']).to eq('中央区')
        end
      end

      context '海上など該当地域がない座標' do
        let(:properties) { {} }
        let(:should_match) { false }

        it 'nil を返すこと' do
          result = described_class.reverse_geocode(140.0, 30.0, tiles_dir)

          expect(result).to be_nil
        end
      end
    end

    context 'N03生データのフィールド構成' do
      it 'N03_* の値をprefecture/municipality/ward/codeにマッピングすること' do
        raw_features = [
          {
            geometry: [[139.7, 35.6], [139.8, 35.6], [139.8, 35.7], [139.7, 35.7]],
            properties: {
              'N03_001' => '北海道',
              'N03_002' => '石狩振興局',
              'N03_003' => nil,
              'N03_004' => '札幌市',
              'N03_005' => '中央区',
              'N03_007' => '01101'
            }
          }
        ]

        allow(PbfReverseGeocoder::PbfTileReader).to receive(:read_tile)
          .and_return(raw_features)
        allow(PbfReverseGeocoder::PointInPolygon).to receive(:contains?)
          .and_return(true)

        result = described_class.reverse_geocode(139.7671, 35.6812, tiles_dir)

        expect(result).to include(
          'prefecture' => '北海道',
          'sub_prefecture' => '石狩振興局',
          'city' => '札幌市中央区',
          'municipality' => '札幌市',
          'ward' => '中央区',
          'code' => '01101'
        )
      end
    end
  end
end

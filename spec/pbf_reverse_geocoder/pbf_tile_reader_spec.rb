# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe PbfReverseGeocoder::PbfTileReader do
  describe '.decode_properties' do
    let(:layer) do
      {
        keys: %w[prefecture city],
        values: [
          { string_value: '東京都' },
          { string_value: '千代田区' }
        ]
      }
    end

    context 'タグと ID が両方ある場合' do
      it 'プロパティとコードを正しくデコードすること' do
        feature = {
          id: 13_101,
          tags: [0, 0, 1, 1]  # prefecture=0, city=1
        }

        result = described_class.send(:decode_properties, feature, layer)

        expect(result).to eq({
                               'code' => '13101',
                               'prefecture' => '東京都',
                               'city' => '千代田区'
                             })
      end
    end

    context 'ID が4桁の場合' do
      it '先頭に0を追加して5桁にすること' do
        feature = {
          id: 1101,  # 4桁
          tags: []
        }

        result = described_class.send(:decode_properties, feature, layer)

        expect(result['code']).to eq('01101')
      end
    end

    context 'ID が5桁の場合' do
      it 'そのまま使用すること' do
        feature = {
          id: 13_101,  # 5桁
          tags: []
        }

        result = described_class.send(:decode_properties, feature, layer)

        expect(result['code']).to eq('13101')
      end
    end

    context 'ID がない場合' do
      it 'code キーを含まないこと' do
        feature = {
          id: nil,
          tags: [0, 0]
        }

        result = described_class.send(:decode_properties, feature, layer)

        expect(result).not_to have_key('code')
        expect(result['prefecture']).to eq('東京都')
      end
    end

    context 'タグが空の場合' do
      it 'ID のみを返すこと' do
        feature = {
          id: 13_101,
          tags: []
        }

        result = described_class.send(:decode_properties, feature, layer)

        expect(result).to eq({ 'code' => '13101' })
      end
    end

    context '値オブジェクトが nil の場合' do
      it '空文字列を使用すること' do
        layer_with_nil = {
          keys: ['prefecture'],
          values: [nil]
        }
        feature = {
          id: 13_101,
          tags: [0, 0]
        }

        result = described_class.send(:decode_properties, feature, layer_with_nil)

        expect(result['prefecture']).to eq('')
      end
    end
  end

  describe '.read_tile' do
    let(:temp_dir) { Dir.mktmpdir }
    let(:tile_path) { File.join(temp_dir, '10', '904', '403.pbf') }

    after do
      FileUtils.rm_rf(temp_dir)
    end

    context 'ファイルが存在しない場合' do
      it '空配列を返すこと' do
        result = described_class.read_tile('/nonexistent/path.pbf', 904, 403, 10)

        expect(result).to eq([])
      end
    end

    context 'ファイルが存在するがパースエラーの場合' do
      it '空配列を返し、警告を出すこと' do
        FileUtils.mkdir_p(File.dirname(tile_path))
        File.write(tile_path, 'invalid binary data')

        expect do
          result = described_class.read_tile(tile_path, 904, 403, 10)
          expect(result).to eq([])
        end.to output(/Failed to read PBF tile/).to_stderr
      end
    end

    context '有効なPBFデータの場合' do
      it 'SimplePbfParser.parse を呼び出すこと' do
        FileUtils.mkdir_p(File.dirname(tile_path))
        File.write(tile_path, "\x00\x00", mode: 'wb')

        allow(PbfReverseGeocoder::SimplePbfParser).to receive(:parse)
          .and_return({ layers: [] })

        described_class.read_tile(tile_path, 904, 403, 10)

        expect(PbfReverseGeocoder::SimplePbfParser).to have_received(:parse)
      end
    end

    context 'japanese-admins レイヤーが存在する場合' do
      it 'フィーチャーをデコードして返すこと' do
        FileUtils.mkdir_p(File.dirname(tile_path))
        File.write(tile_path, "\x00\x00", mode: 'wb')

        mock_tile = {
          layers: [
            {
              name: 'japanese-admins',
              features: [
                {
                  id: 13_101,
                  tags: [0, 0, 1, 1],
                  type: 3,
                  geometry: [9, 100, 68]
                }
              ],
              keys: %w[prefecture city],
              values: [
                { string_value: '東京都' },
                { string_value: '千代田区' }
              ]
            }
          ]
        }

        allow(PbfReverseGeocoder::SimplePbfParser).to receive(:parse)
          .and_return(mock_tile)
        allow(PbfReverseGeocoder::GeometryDecoder).to receive(:decode)
          .and_return([[139.7671, 35.6812]])

        result = described_class.read_tile(tile_path, 904, 403, 10)

        expect(result.length).to eq(1)
        expect(result.first[:properties]).to include(
          'prefecture' => '東京都',
          'city' => '千代田区',
          'code' => '13101'
        )
        expect(result.first[:geometry]).to eq([[139.7671, 35.6812]])
      end
    end

    context '該当レイヤーが存在しない場合' do
      it '空配列を返すこと' do
        FileUtils.mkdir_p(File.dirname(tile_path))
        File.write(tile_path, "\x00\x00", mode: 'wb')

        mock_tile = {
          layers: [
            {
              name: 'other-layer',
              features: []
            }
          ]
        }

        allow(PbfReverseGeocoder::SimplePbfParser).to receive(:parse)
          .and_return(mock_tile)

        result = described_class.read_tile(tile_path, 904, 403, 10)

        expect(result).to eq([])
      end
    end
  end
end

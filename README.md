# PbfReverseGeocoder

日本の行政区域情報を取得するための軽量なリバースジオコーディングライブラリです。Mapbox Vector Tiles (PBF形式) を使用して、緯度経度から都道府県・市区町村を高速に検索します。

[@geolonia/open-reverse-geocoder](https://github.com/geolonia/open-reverse-geocoder) のRuby実装版です。

## 特徴

- **軽量**: 外部APIやデータベース不要
- **高速**: ローカルのPBFタイルから直接検索
- **依存性なし**: 標準ライブラリのみで動作
- **オフライン対応**: インターネット接続不要
- **純粋Ruby実装**: ネイティブ拡張不要で簡単にインストール可能

## インストール

Gemfileに追加:

```ruby
gem 'pbf_reverse_geocoder'
```

コマンドラインからインストール:

```bash
gem install pbf_reverse_geocoder
```

## 使い方

### クイックスタート

```ruby
require 'pbf_reverse_geocoder'

# タイルディレクトリのパスを指定
tiles_dir = './tiles'  # ダウンロードしたタイルの場所

# 緯度経度から行政区域情報を取得（東京駅の例）
result = PbfReverseGeocoder.reverse_geocode(139.7671, 35.6812, tiles_dir)

puts result
# => { "prefecture" => "東京都", "city" => "千代田区", "code" => "13101" }
```

### より詳しい使用例

```ruby
require 'pbf_reverse_geocoder'

# 複数の地点を検索
locations = [
  { name: '東京駅', lng: 139.7671, lat: 35.6812 },
  { name: '大阪城', lng: 135.5258, lat: 34.6873 },
  { name: '札幌駅', lng: 141.3506, lat: 43.0686 }
]

tiles_dir = './tiles'

locations.each do |loc|
  result = PbfReverseGeocoder.reverse_geocode(loc[:lng], loc[:lat], tiles_dir)

  if result
    puts "#{loc[:name]}: #{result['prefecture']} #{result['city']} (#{result['code']})"
  else
    puts "#{loc[:name]}: 該当する行政区域が見つかりません"
  end
end

# 出力:
# 東京駅: 東京都 千代田区 (13101)
# 大阪城: 大阪府 大阪市中央区 (27128)
# 札幌駅: 北海道 札幌市北区 (01102)
```

### Railsでの使用例

```ruby
# config/initializers/reverse_geocoder.rb
TILES_DIR = Rails.root.join('public', 'tiles').to_s

# app/controllers/locations_controller.rb
class LocationsController < ApplicationController
  def reverse_geocode
    lng = params[:lng].to_f
    lat = params[:lat].to_f

    result = PbfReverseGeocoder.reverse_geocode(lng, lat, TILES_DIR)

    if result
      render json: result
    else
      render json: { error: 'Not found' }, status: :not_found
    end
  end
end
```

### タイルデータの準備

このgemを使用するには、事前にPBF形式のタイルデータを準備する必要があります。

以下の2つの方法があります：

#### 方法1: Geoloniaのリポジトリから取得

[@geolonia/open-reverse-geocoder](https://github.com/geolonia/open-reverse-geocoder)のリポジトリから直接タイルを取得できます。

```bash
# Geoloniaのリポジトリをクローン（タイルのみ）
git clone --depth 1 --filter=blob:none --sparse \
  https://github.com/geolonia/open-reverse-geocoder.git

cd open-reverse-geocoder
git sparse-checkout set docs/tiles

# タイルをホスティング用のディレクトリに配置
cp -r docs/tiles /path/to/hosting/directory
```

> **💡 配置例**
> - **Webサーバ**: `public/tiles`（Rails/Nginxなど）
> - **共有ストレージ**: NFS/S3マウントポイントなど
> - **アプリケーション内蔵**: `vendor/tiles`
> - タイルは約560個、合計サイズは数十MB程度です
> 
> **ホスティングのポイント**:
> - タイルデータは全サーバで共有可能（読み取り専用）
> - CDN経由での配信も可能（PBFファイルはバイナリ）
> - コンテナ環境ではボリュームマウントで共有

#### 方法2: ソースデータから自分でビルド（最新データが必要な場合）

国土数値情報から最新の行政区域データを使って、自分でタイルをビルドすることもできます。

**🔧 必要なツール:**
- [ogr2ogr](https://gdal.org/programs/ogr2ogr.html) - GDALツール（GeoJSON変換用）
- [Tippecanoe](https://github.com/felt/tippecanoe) - Mapboxのタイル生成ツール
- [mb-util](https://github.com/mapbox/mbutil) - MBTiles変換ツール

**macOSの場合:**

```bash
# 必要なツールをインストール
brew install gdal tippecanoe
pip install mbutil
```

**🏗️ ビルド手順:**

```bash
# 1. 元のリポジトリをクローン（ビルドスクリプトを使用）
git clone https://github.com/geolonia/open-reverse-geocoder.git
cd open-reverse-geocoder

# 2. 依存関係をインストール
npm install

# 3. タイルをビルド（国土数値情報から自動ダウンロード＆ビルド）
npm run build:tiles

# 4. ビルドされたタイルをコピー
cp -r docs/tiles /path/to/your/project/tiles
```

**ビルドプロセスの詳細:**

1. 国土数値情報から最新の[行政区域データ](https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-N03-v2_4.html)をダウンロード
2. `ogr2ogr`でShapefileをGeoJSONに変換
3. プロパティ調整スクリプトを実行（prefecture, city, codeフィールドを整形）
4. `tippecanoe`でMBTilesを生成（非圧縮で出力）
5. `mb-util`でタイルを分解して静的ファイル化


> 詳細は[@geolonia/open-reverse-geocoder](https://github.com/geolonia/open-reverse-geocoder#%E3%82%BF%E3%82%A4%E3%83%AB%E3%81%AE%E3%83%93%E3%83%AB%E3%83%89%E6%96%B9%E6%B3%95)のREADMEを参照してください。

#### ディレクトリ構造

タイルは以下の構造で配置してください:

```
tiles/
└── 10/              # ズームレベル
    ├── 896/
    │   ├── 396.pbf
    │   └── 397.pbf
    ├── 904/
    │   ├── 403.pbf  # 例: 東京周辺
    │   └── 404.pbf
    └── 926/
        └── 413.pbf
```

#### タイルの範囲について

- **ズームレベル10固定**: このライブラリは @geolonia/open-reverse-geocoder と同じくズームレベル10のタイルのみを使用します（約30km四方）
- **日本全体**: X座標 896-926、Y座標 396-413の範囲で日本全国をカバー
- **個別地域**: 必要な地域のタイルのみをダウンロードすることも可能

### 戻り値

成功時:
```ruby
{
  "prefecture" => "東京都",
  "city" => "千代田区",
  "code" => "13101"  # 全国地方公共団体コード
}
```

該当する行政区域が見つからない場合は `nil` を返します。

## 仕組み

1. **タイル座標計算**: 緯度経度からズームレベル10のタイル座標を計算
2. **PBFパース**: 該当タイルのPBFファイルを読み込んで解析
3. **ジオメトリデコード**: Mapbox Vector Tileのジオメトリを緯度経度に変換
4. **Point-in-Polygon判定**: Ray Casting Algorithmで位置を判定

## API ドキュメント

### `PbfReverseGeocoder.reverse_geocode(lng, lat, tiles_dir)`

指定された緯度経度の行政区域情報を取得します。

**パラメータ:**
- `lng` (Float): 経度 (-180 ~ 180)
- `lat` (Float): 緯度 (-90 ~ 90)
- `tiles_dir` (String): タイルディレクトリのパス

**戻り値:**
- Hash: 行政区域情報 (`{ "prefecture" => ..., "city" => ..., "code" => ... }`)
- nil: 該当する行政区域が見つからない場合

## 開発

```bash
# リポジトリをクローン
git clone https://github.com/yourusername/pbf_reverse_geocoder.git
cd pbf_reverse_geocoder

# 依存関係をインストール
bundle install

# テストを実行
bundle exec rspec

# RuboCopを実行
bundle exec rubocop
```

## ライセンス

MIT License

## クレジット

このライブラリは以下のプロジェクトにインスパイアされています:
- [@geolonia/open-reverse-geocoder](https://github.com/geolonia/open-reverse-geocoder)
- [Mapbox Vector Tile Specification](https://github.com/mapbox/vector-tile-spec)

## Contributing

バグ報告やプルリクエストは大歓迎です。GitHubリポジトリでお待ちしています。

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
# => {
#      "prefecture" => "東京都",
#      "city" => "千代田区",
#      "municipality" => "千代田区",
#      "code" => "13101"
#    }
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

### 取得できる情報

`reverse_geocode` は行政区域の階層を加工せず返します。N03の元プロパティも保持したまま、以下のキーを追加で正規化しています。

- `prefecture`: 都道府県 (`N03_001`)
- `sub_prefecture`: 支庁/振興局など (`N03_002`)
- `county`: 郡 (`N03_003`)
- `municipality`: 市区町村 (`N03_004`)
- `ward`: 政令市の行政区 (`N03_005` がある場合)
- `city`: `municipality` と `ward` を連結した互換用フィールド
- `code`: 全国地方公共団体コード (`N03_007` を5桁でゼロ埋め)

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

国土交通省の最新行政区域データ（例: [N03-2025](https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-N03-2025.html)）を、そのままの属性でタイル化して利用します。リポジトリ直下に `N03-20250101_GML.zip` と展開済みの `N03-20250101_GML/` を配置済みです。

**必要なツール**
- [tippecanoe](https://github.com/felt/tippecanoe)（必須）
- [ogr2ogr](https://gdal.org/programs/ogr2ogr.html)（GeoJSON が同梱されていない場合のみ）

**データの取得例**

```bash
# 2025年版N03データをダウンロード（約数百MB）
curl -LO https://nlftp.mlit.go.jp/ksj/gml/data/N03/N03-2025/N03-20250101_GML.zip
unzip N03-20250101_GML.zip
```

**タイル作成（加工なし）**

```bash
# 2025年版N03データをタイル化する例
ruby scripts/build_tiles.rb --source N03-20250101_GML --tiles-dir ./tiles --layer N03
```

- ズームレベルは `--zoom` で変更可能（デフォルト10固定の全国範囲）
- GeoJSONを直接使う場合は `--geojson path/to/N03.geojson` を指定
- GeoJSON が無い場合、Shapefile から `ogr2ogr` で自動変換します

**動作確認コマンド**

```bash
ruby scripts/reverse_geocode.rb --tiles-dir ./tiles --lng 139.7671 --lat 35.6812
```
東京駅周辺なら東京都千代田区（コード13101）が返る想定です。

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

※ `tiles/` は `.gitignore` 済みです。生成物はコミット不要です。

#### タイルの範囲について

- **ズームレベル10固定**: このライブラリは @geolonia/open-reverse-geocoder と同じくズームレベル10のタイルのみを使用します（約30km四方）
- **日本全体**: X座標 896-926、Y座標 396-413の範囲で日本全国をカバー（N03公式データに基づく）
- **個別地域**: 必要な地域のタイルのみをダウンロードすることも可能

> 既存の Geolonia タイル（layer: `japanese-admins`）も互換性のため読み込めますが、最新データを使う場合は上記のN03公式データを推奨します。

### 戻り値

成功時:
```ruby
{
  "prefecture" => "北海道",
  "sub_prefecture" => "石狩振興局",
  "city" => "札幌市中央区",
  "municipality" => "札幌市",
  "ward" => "中央区",
  "code" => "01101"  # 全国地方公共団体コード（5桁ゼロ埋め）
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

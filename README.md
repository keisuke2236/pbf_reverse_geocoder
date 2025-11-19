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

### 基本的な使用方法

```ruby
require 'pbf_reverse_geocoder'

# タイルディレクトリのパスを指定
tiles_dir = '/path/to/tiles'

# 緯度経度から行政区域情報を取得
result = PbfReverseGeocoder.reverse_geocode(139.7671, 35.6812, tiles_dir)

puts result
# => { "prefecture" => "東京都", "city" => "千代田区", "code" => "13101" }
```

### タイルデータの準備

このgemを使用するには、事前にPBF形式のタイルデータを準備する必要があります。

#### 方法1: ビルド済みタイルをダウンロード（推奨）

Geoloniaが提供するビルド済みのタイルデータを使用できます：

```bash
# タイル格納ディレクトリを作成
mkdir -p tiles

# 必要な範囲のタイルをダウンロード
# 例: 東京周辺 (z=10, x=904, y=403)
mkdir -p tiles/10/904
curl -o tiles/10/904/403.pbf \
  "https://cdn.geolonia.com/tiles/japanese-admins/10/904/403.pbf"
```

**全国のタイルを一括ダウンロード:**

このリポジトリに含まれるスクリプトを使用できます：

```bash
# リポジトリをクローン（または直接スクリプトをダウンロード）
git clone https://github.com/keisuke2236/pbf_reverse_geocoder.git
cd pbf_reverse_geocoder

# スクリプトを実行
./scripts/download_tiles.sh tiles

# または、カスタムディレクトリを指定
./scripts/download_tiles.sh /path/to/custom/tiles
```

手動でダウンロードする場合：

```bash
#!/bin/bash
# download_tiles.sh - 日本全国のタイルをダウンロード

BASE_URL="https://cdn.geolonia.com/tiles/japanese-admins"
ZOOM=10
OUTPUT_DIR="tiles"

# 日本全体をカバーする範囲（ズームレベル10）
# X: 896-926, Y: 396-413

for x in {896..926}; do
  for y in {396..413}; do
    mkdir -p "$OUTPUT_DIR/$ZOOM/$x"
    echo "Downloading tile $ZOOM/$x/$y..."
    curl -f -o "$OUTPUT_DIR/$ZOOM/$x/$y.pbf" \
      "$BASE_URL/$ZOOM/$x/$y.pbf" 2>/dev/null || echo "Skip $x/$y"
  done
done

echo "Download complete!"
```

#### 方法2: ソースデータから自分でビルド

より詳細な制御が必要な場合は、自分でタイルをビルドできます。

**必要なツール:**
- [Tippecanoe](https://github.com/felt/tippecanoe) - Mapboxのタイル生成ツール
- [japanese-admins](https://github.com/geolonia/japanese-admins) - 日本の行政区域データ

**手順:**

```bash
# 1. Tippecanoeをインストール（macOS）
brew install tippecanoe

# または、Linuxの場合
git clone https://github.com/felt/tippecanoe.git
cd tippecanoe
make -j
sudo make install

# 2. japanese-adminsリポジトリをクローン
git clone https://github.com/geolonia/japanese-admins.git
cd japanese-admins

# 3. GeoJSONデータを取得
# READMEの指示に従ってデータを準備

# 4. Tippecanoeでタイルを生成
tippecanoe -o admins.mbtiles \
  --maximum-zoom=10 \
  --minimum-zoom=10 \
  --base-zoom=10 \
  --layer=japanese-admins \
  --drop-densest-as-needed \
  --extend-zooms-if-still-dropping \
  data.geojson

# 5. MBTilesからPBFファイルを抽出
mkdir -p tiles/10
tile-join --no-tile-compression \
  --output-to-directory=tiles \
  admins.mbtiles
```

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

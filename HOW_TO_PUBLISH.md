# Gem公開手順

## 1. gemspecの情報を更新

`pbf_reverse_geocoder.gemspec` の以下の項目を実際の情報に変更してください：

```ruby
spec.email = ['your-email@example.com']  # 実際のメールアドレス
spec.homepage = 'https://github.com/yourusername/pbf_reverse_geocoder'  # GitHubリポジトリURL
```

## 2. GitHubリポジトリの作成

```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/yourusername/pbf_reverse_geocoder.git
git push -u origin main
```

## 3. gemのビルドとインストール（ローカルテスト）

```bash
# gemをビルド
gem build pbf_reverse_geocoder.gemspec

# ローカルにインストールしてテスト
gem install ./pbf_reverse_geocoder-0.1.0.gem --user-install
```

## 4. RubyGems.orgへの公開

### 初回のみ: RubyGemsアカウントの作成とAPI keyの設定

1. https://rubygems.org/ でアカウント作成
2. API keyを取得

```bash
# API keyを設定（初回のみ）
gem push --help  # 認証情報を入力
```

### gem公開

```bash
# RubyGems.orgに公開
gem push pbf_reverse_geocoder-0.1.0.gem
```

## 5. 公開後の使用方法

他のユーザーは以下のようにインストールできます：

```bash
gem install pbf_reverse_geocoder
```

または Gemfile に追加：

```ruby
gem 'pbf_reverse_geocoder'
```

## バージョンアップ時

1. `lib/pbf_reverse_geocoder/version.rb` でバージョン番号を更新
2. `CHANGELOG.md` に変更内容を記載
3. git commit & push
4. 再ビルド & 公開

```bash
gem build pbf_reverse_geocoder.gemspec
gem push pbf_reverse_geocoder-0.x.x.gem
```

## ディレクトリ構成

```
pbf_reverse_geocoder/
├── .gitignore
├── CHANGELOG.md
├── Gemfile
├── LICENSE.txt
├── README.md
├── Rakefile
├── example.rb
├── pbf_reverse_geocoder.gemspec
├── lib/
│   ├── pbf_reverse_geocoder.rb          # メインエントリーポイント
│   └── pbf_reverse_geocoder/
│       ├── version.rb
│       ├── geometry_decoder.rb
│       ├── pbf_tile_reader.rb
│       ├── point_in_polygon.rb
│       ├── simple_pbf_parser.rb
│       └── tile_calculator.rb
└── vendor/                              # bundleでインストールしたgem（.gitignore済み）
```

## 注意事項

- 古いRubyファイル（ルートディレクトリの `*.rb`）は削除可能です
- `vendor/bundle/` は `.gitignore` に含まれています
- gemをビルドする際は開発依存関係は不要です

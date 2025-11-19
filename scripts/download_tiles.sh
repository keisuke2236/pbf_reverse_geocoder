#!/bin/bash
# タイルダウンロードスクリプト
# 日本全国の行政区域タイル（ズームレベル10）をダウンロード

set -e

BASE_URL="https://cdn.geolonia.com/tiles/japanese-admins"
ZOOM=10
OUTPUT_DIR="${1:-tiles}"

# 色付き出力用
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}  日本全国の行政区域タイルをダウンロード${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""
echo -e "出力ディレクトリ: ${GREEN}$OUTPUT_DIR${NC}"
echo -e "ズームレベル: ${GREEN}$ZOOM${NC}"
echo ""

# 日本全体をカバーする範囲（ズームレベル10）
# 北海道から沖縄まで
X_MIN=896
X_MAX=926
Y_MIN=396
Y_MAX=413

total_tiles=$(( (X_MAX - X_MIN + 1) * (Y_MAX - Y_MIN + 1) ))
current=0
success=0
skipped=0

echo -e "${YELLOW}ダウンロード開始...${NC}"
echo ""

for x in $(seq $X_MIN $X_MAX); do
  for y in $(seq $Y_MIN $Y_MAX); do
    current=$((current + 1))
    dir="$OUTPUT_DIR/$ZOOM/$x"
    file="$dir/$y.pbf"
    
    # ディレクトリがなければ作成
    mkdir -p "$dir"
    
    # 既にファイルが存在する場合はスキップ
    if [ -f "$file" ]; then
      echo -e "[${current}/${total_tiles}] ${YELLOW}スキップ${NC}: $ZOOM/$x/$y (既に存在)"
      skipped=$((skipped + 1))
      continue
    fi
    
    # タイルをダウンロード
    if curl -f -s -o "$file" "$BASE_URL/$ZOOM/$x/$y.pbf" 2>/dev/null; then
      echo -e "[${current}/${total_tiles}] ${GREEN}成功${NC}: $ZOOM/$x/$y"
      success=$((success + 1))
    else
      echo -e "[${current}/${total_tiles}] ${YELLOW}該当なし${NC}: $ZOOM/$x/$y"
      rm -f "$file"  # 空ファイルを削除
      skipped=$((skipped + 1))
    fi
  done
done

echo ""
echo -e "${BLUE}==================================================${NC}"
echo -e "${GREEN}ダウンロード完了！${NC}"
echo -e "${BLUE}==================================================${NC}"
echo -e "成功: ${GREEN}${success}${NC} タイル"
echo -e "スキップ/該当なし: ${YELLOW}${skipped}${NC} タイル"
echo -e "合計: ${total_tiles} タイル"
echo ""
echo -e "タイルの場所: ${GREEN}$OUTPUT_DIR${NC}"

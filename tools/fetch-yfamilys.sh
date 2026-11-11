#!/usr/bin/env bash
# 把 https://yfamilys.com/shadowrocket 上的配置和模块原文镜像到 reference/yfamilys/，供本地检索用。
# 用法：bash tools/fetch-yfamilys.sh        （在仓库根目录运行，可重复运行以刷新）
# 产物：reference/yfamilys/{module,config}/<原文件名>，以及 reference/yfamilys/INDEX.tsv（文件名、站点上的中文名、来源 URL）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/reference/yfamilys"
INDEX_URL="https://yfamilys.com/shadowrocket"
UA="Shadowrocket/2.2"

mkdir -p "$OUT/module" "$OUT/config"
html="$(curl -fsSL -m 30 -A "$UA" "$INDEX_URL")"

# 每个条目形如 <a href="https://yfamilys.com/module/x.module"><button class="myButton">中文名</button></a>
pairs="$(printf '%s\n' "$html" \
  | grep -oE 'href="https://yfamilys\.com/(module|config)/[^"]+"><button[^>]*>[^<]*' \
  | sed -E 's#href="([^"]+)"><button[^>]*>(.*)#\1\t\2#')"

{
  printf 'file\tname\turl\n'
  printf '%s\n' "$pairs" | while IFS=$'\t' read -r url name; do
    printf '%s\t%s\t%s\n' "${url#https://yfamilys.com/}" "$name" "$url"
  done
} > "$OUT/INDEX.tsv"

printf '%s\n' "$pairs" | cut -f1 | sort -u | while read -r url; do
  rel="${url#https://yfamilys.com/}"
  printf '%s\t%s\n' "$url" "$OUT/$rel"
done | xargs -P 8 -L 1 sh -c 'curl -fsSL -m 30 -A "'"$UA"'" -o "$1" "$0" || echo "FAILED $0" >&2'

echo "done: $(($(wc -l < "$OUT/INDEX.tsv") - 1)) entries -> $OUT"

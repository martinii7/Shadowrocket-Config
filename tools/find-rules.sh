#!/usr/bin/env bash
# 在本地镜像 reference/yfamilys/ 里按关键字查规则，去重后按"代价"分组输出，方便挑出最小的那几条。
# 用法：bash tools/find-rules.sh <正则> [--splash]
#   <正则>    匹配主机名或接口名，如 'guide-acs\.m\.taobao' 或 'mtop\.taobao\.'
#   --splash  只保留看起来与开屏/启动/广告有关的行
# 输出分组（代价从低到高）：
#   [Rule]        域名级规则，哈希匹配，无需 MITM
#   [URL Rewrite] 正则重写，HTTPS 需要对该主机开 MITM
#   [Body/Map]    改写响应体，需要 MITM + 缓冲整个响应
#   [Script]      执行 JS，需要 MITM + 缓冲响应 + 跑脚本，最贵
#   [MITM]        与关键字匹配、需要解密的主机名
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/reference/yfamilys"
[ -d "$DIR" ] || { echo "先运行 bash tools/fetch-yfamilys.sh" >&2; exit 1; }
[ $# -ge 1 ] || { sed -n '2,11p' "$0"; exit 1; }

export PAT="$1" SPLASH="${2:-}"
export SRE='splash|startup|start_?ad|launch|welcome|getadv|advert|[/.]ads?[/.?_]|开屏|启动'

cd "$DIR"
mapfile -t files < <(find module config -type f \( -name '*.module' -o -name '*.sgmodule' -o -name '*.conf' \) | sort)

# 正则经 ENVIRON 传入，避免 awk -v 处理反斜杠
awk '
  BEGIN { pat = ENVIRON["PAT"]; splash = ENVIRON["SPLASH"]; sre = ENVIRON["SRE"] }
  { sub(/\r$/, "") }
  FNR == 1 { sec = ""; f = FILENAME; sub(/^\xef\xbb\xbf/, "") }
  /^[ \t]*\[[^]]+\][ \t]*$/ { sec = $0; gsub(/[ \t]/, "", sec); next }
  /^[ \t]*(#|;|\/\/)/ || /^[ \t]*$/ { next }
  sec == "[MITM]" {
    if ($0 !~ /^[ \t]*hostname/) next
    line = $0; sub(/^[^=]*=/, "", line); gsub(/%APPEND%|%INSERT%/, "", line)
    n = split(line, hs, ",")
    for (i = 1; i <= n; i++) { h = hs[i]; gsub(/^[ \t]+|[ \t]+$/, "", h)
      if (h != "" && h ~ pat && index(mitm[h], f) == 0) mitm[h] = mitm[h] (mitm[h] ? ", " : "") f }
    next
  }
  {
    line = $0
    # 规则原文里的点号多被转义成 \.，去掉反斜杠再匹配，用户写 taobao\.com 或 taobao.com 都能命中
    norm = line; gsub(/\\/, "", norm)
    if (norm !~ pat) next
    if (splash != "" && tolower(norm) !~ sre) next
    g = (sec == "[Rule]") ? 1 : (sec == "[URLRewrite]") ? 2 : (sec ~ /Body|MapLocal|Header/) ? 3 : (sec == "[Script]") ? 4 : 5
    key = g SUBSEP line
    if (!(key in seen)) { order[++cnt] = key; seen[key] = f; secname[key] = sec }
    else if (index(seen[key], f) == 0) seen[key] = seen[key] ", " f
  }
  function short(s) { return length(s) > 70 ? substr(s, 1, 67) "..." : s }
  END {
    split("[Rule] 域名级，哈希匹配，无需 MITM|[URL Rewrite] 正则，HTTPS 需 MITM|[Body/Map] 改响应体，需 MITM+缓冲|[Script] 跑 JS，最贵|其他段", names, "|")
    for (k = 1; k <= 5; k++) {
      hdr = 0
      for (i = 1; i <= cnt; i++) { split(order[i], p, SUBSEP)
        if (p[1] != k) continue
        if (!hdr) { print "\n== " names[k]; hdr = 1 }
        print p[2]; print "      <- " (k == 5 ? secname[order[i]] " " : "") short(seen[order[i]]) }
    }
    hdr = 0
    for (h in mitm) { if (!hdr) { print "\n== [MITM] 匹配的主机名"; hdr = 1 } print h "   <- " short(mitm[h]) }
  }' "${files[@]}"

#!/usr/bin/env bash
# ============================================================
# render_wavedrom.sh — Wavedrom 波形图渲染流水线（.json → .html + .svg）
# ============================================================
# @file    render_wavedrom.sh
# @brief   从 Wavedrom JSON 源文件重新生成仓库 .html 与 .svg 资产，
#          保证三者版本一致——.json 是唯一事实源，改完必须重跑本脚本
# @usage   render_wavedrom.sh <xxx.json>
# @args    <xxx.json>  Wavedrom 波形源文件（signal/head/foot/config）
# @env     CHROME      可选：chrome 可执行文件路径（默认自动探测
#                      ~/.cache/puppeteer 下的 chrome-linux64，取最新版）
# @exit_code 0 渲染成功 / 1 参数缺失、文件不存在、chrome 缺失或渲染失败
#
# 渲染链路：
#   1. 本地 wavedrom 2.6.8 JS（首次自动下载到 ~/.cache/wavedrom-2.6.8）
#   2. 生成仓库 .html（CDN 引用，Obsidian/浏览器可直接打开）
#   3. 生成本地渲染 HTML（file:// 引用本地 JS，离线可渲染）
#   4. chrome --headless --dump-dom 执行渲染
#   5. 从 DOM 提取 svgcontent_0 写入 .svg，并做 XML 良构校验
#
# Wavedrom 绘制规则（CLAUDE.md §2，2026-09-02 固化）：
#   - 连续同电平段必须用 '.' 重复——显式重复（0000/1111）会在每个
#     周期边界渲染出尖刻（0m0/1m1 图元）
#   - data 标签只能挂在 '2'（低电平带标签）/ '3'（高电平带标签）字符
#   - '=' 是总线值字符，单比特标志信号禁止使用
# ============================================================
set -euo pipefail

JSON_FILE="${1:?用法: render_wavedrom.sh <xxx.json>}"
[[ -f "$JSON_FILE" ]] || { echo "错误: $JSON_FILE 不存在" >&2; exit 1; }

DIR="$(cd "$(dirname "$JSON_FILE")" && pwd)"
BASE="$(basename "$JSON_FILE" .json)"
HTML_FILE="$DIR/$BASE.html"
SVG_FILE="$DIR/$BASE.svg"

# ----- 1. 定位 chrome（puppeteer 缓存，取版本号最新的一个）-----
CHROME="${CHROME:-}"
if [[ -z "$CHROME" ]]; then
    CHROME=$(ls -1 "$HOME"/.cache/puppeteer/chrome/*/chrome-linux64/chrome 2>/dev/null \
             | sort -V | tail -1 || true)
fi
[[ -n "$CHROME" && -x "$CHROME" ]] || { echo "错误: 未找到 chrome（可用 CHROME 环境变量指定）" >&2; exit 1; }

# ----- 2. 准备本地 wavedrom JS（首次下载，之后复用缓存）-----
JS_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/wavedrom-2.6.8"
mkdir -p "$JS_DIR"
[[ -f "$JS_DIR/wavedrom.min.js" ]] || \
    curl -sL -o "$JS_DIR/wavedrom.min.js" https://cdnjs.cloudflare.com/ajax/libs/wavedrom/2.6.8/wavedrom.min.js
[[ -f "$JS_DIR/default.js" ]] || \
    curl -sL -o "$JS_DIR/default.js" https://cdnjs.cloudflare.com/ajax/libs/wavedrom/2.6.8/skins/default.js

# ----- 3. 生成仓库 .html（CDN 引用，Obsidian/浏览器直接打开）-----
{
    echo '<!DOCTYPE html>'
    echo '<html><head><meta charset="utf-8">'
    echo '<style>body { margin: 20px; background: #fff; }</style>'
    echo '<script src="https://cdnjs.cloudflare.com/ajax/libs/wavedrom/2.6.8/skins/default.js"></script>'
    echo '<script src="https://cdnjs.cloudflare.com/ajax/libs/wavedrom/2.6.8/wavedrom.min.js"></script>'
    echo '</head><body onload="WaveDrom.ProcessAll()">'
    echo '<script type="WaveDrom">'
    cat "$JSON_FILE"
    echo '</script>'
    echo '</body></html>'
} > "$HTML_FILE"

# ----- 4. 本地渲染 HTML（file:// 引用本地 JS，离线可渲染）-----
RENDER_HTML=$(mktemp --suffix=.html)
{
    echo '<!DOCTYPE html>'
    echo '<html><head><meta charset="utf-8">'
    echo '<style>body { margin: 20px; background: #fff; }</style>'
    echo "<script src=\"file://$JS_DIR/default.js\"></script>"
    echo "<script src=\"file://$JS_DIR/wavedrom.min.js\"></script>"
    echo '</head><body onload="WaveDrom.ProcessAll()">'
    echo '<script type="WaveDrom">'
    cat "$JSON_FILE"
    echo '</script>'
    echo '</body></html>'
} > "$RENDER_HTML"

# ----- 5. chrome headless 渲染，提取 svgcontent_0 并校验良构 -----
DUMP=$(mktemp --suffix=.html)
"$CHROME" --headless --disable-gpu --no-sandbox --dump-dom "file://$RENDER_HTML" > "$DUMP" 2>/dev/null
python3 - "$DUMP" "$SVG_FILE" <<'PYEOF'
# 提取渲染出的 WaveDrom SVG：svgscontent_0 是 Wavedrom 生成的唯一顶层 svg
import re, sys
import xml.etree.ElementTree as ET
dump, svg_out = sys.argv[1], sys.argv[2]
html = open(dump, encoding='utf-8').read()
m = re.search(r'<svg[^>]*id="svgcontent_0".*?</svg>', html, re.S)
if not m:
    sys.exit("错误: 渲染结果中未找到 svgcontent_0（chrome 渲染失败？）")
svg = m.group(0)
ET.fromstring(svg)   # XML 良构校验，失败则抛异常退出
open(svg_out, 'w', encoding='utf-8').write(svg)
print(f"OK: {svg_out} ({len(svg)} 字节)")
PYEOF
rm -f "$RENDER_HTML" "$DUMP"
echo "完成: $JSON_FILE -> $HTML_FILE + $SVG_FILE"

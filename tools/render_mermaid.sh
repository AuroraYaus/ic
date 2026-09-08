#!/usr/bin/env bash
# ============================================================
# render_mermaid.sh — Mermaid 框图渲染管线（.mmd → .svg）
# ============================================================
# @file    render_mermaid.sh
# @brief   从 Mermaid 源文件（.mmd）重新生成仓库 .svg 资产，保证二者
#          版本一致——.mmd 是唯一事实源，改完必须重跑本脚本（CLAUDE.md §2）
# @usage   render_mermaid.sh <xxx.mmd> [<yyy.mmd> ...]
# @args    <xxx.mmd>  Mermaid 图源文件（支持内嵌 %%{init} 主题声明）
# @env     CHROME     可选：浏览器可执行文件路径（默认自动探测：
#                     ~/.cache/puppeteer 下的 chrome → Windows 常见路径下
#                     的 msedge.exe / chrome.exe）
# @exit_code 0 全部渲染成功 / 1 参数缺失、文件不存在、浏览器缺失或渲染失败
#
# 渲染链路（与 render_wavedrom.sh 同构，2026-09-08 固化）：
#   1. 本地 mermaid 9.4.3 UMD JS（首次自动下载到 ~/.cache/mermaid-9.4.3）——
#      v10 起改 ESM，file:// 直开无法执行，必须锁定 v9 UMD classic script
#   2. node 将 .mmd 源码 JSON 转义内嵌，生成临时渲染 HTML
#   3. 浏览器 headless --dump-dom（--virtual-time-budget 等异步渲染完成）
#   4. 提取首个 <svg>，把 HTML 序列化残留的裸 <br> 修正为 <br/>
#      （Obsidian 的 <img> 按 XML 解析，裸 <br> 会导致图片加载失败）
#   5. 对产物 .svg 二次 dump 做 XML 良构校验，通过后输出 OK
# 依赖：node（渲染/提取/校验宿主）、curl（首次下载 mermaid JS）
# ============================================================
set -euo pipefail

[[ $# -ge 1 ]] || { echo "用法: render_mermaid.sh <xxx.mmd> [...]" >&2; exit 1; }

# git-bash 下把 MSYS 风格绝对路径（/c/...）转成原生 Windows 路径（C:/...），
# 供原生 node / 浏览器使用；非 cygpath 环境（Linux/WSL）原样直传
winpath() {
    if [[ "$1" == /* ]] && command -v cygpath >/dev/null 2>&1; then
        cygpath -m "$1"
    else
        echo "$1"
    fi
}

# ----- 1. 浏览器探测：CHROME 环境变量 → puppeteer 缓存 → Windows 常见路径 -----
BROWSER="${CHROME:-}"
if [[ -z "$BROWSER" ]]; then
    for c in "$HOME"/.cache/puppeteer/chrome/*/chrome-linux64/chrome; do
        [[ -x "$c" ]] && { BROWSER="$c"; break; }
    done
fi
if [[ -z "$BROWSER" ]]; then
    for c in \
        "/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" \
        "/c/Program Files/Microsoft/Edge/Application/msedge.exe" \
        "/c/Program Files/Google/Chrome/Application/chrome.exe" \
        "/c/Program Files (x86)/Google/Chrome/Application/chrome.exe"; do
        [[ -x "$c" ]] && { BROWSER="$c"; break; }
    done
fi
[[ -n "$BROWSER" ]] || { echo "错误: 未找到浏览器（可用 CHROME 环境变量指定 msedge/chrome 路径）" >&2; exit 1; }
BROWSER="$(winpath "$BROWSER")"
echo "[1/3] 浏览器: $BROWSER"

# ----- 2. mermaid v9 UMD 库（首次下载，之后复用缓存）-----
LIB_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/mermaid-9.4.3"
mkdir -p "$LIB_DIR"
LIB="$LIB_DIR/mermaid.min.js"
if [[ ! -s "$LIB" ]]; then
    echo "[2/3] 首次下载 mermaid 9.4.3（~/.cache/mermaid-9.4.3）..."
    curl -fsSL -o "$LIB" https://cdn.jsdelivr.net/npm/mermaid@9.4.3/dist/mermaid.min.js
    [[ -s "$LIB" ]] || { echo "错误: mermaid JS 下载失败" >&2; exit 1; }
fi
LIB="$(winpath "$LIB")"

# ----- 3. 逐个 .mmd 渲染 -----
FAIL=0
for MMD in "$@"; do
    [[ -f "$MMD" ]] || { echo "错误: $MMD 不存在" >&2; FAIL=1; continue; }
    MMD="$(winpath "$MMD")"
    # 注意：heredoc 不能与 "; then" 同行（bash 语法错误），then 必须独立成行
    if node - "$MMD" "$BROWSER" "$LIB" <<'NODEEOF'
'use strict';
// 单文件渲染：临时 HTML(JSON 转义内嵌 mmd) → 浏览器 dump → 提取+修 <br> → 二次校验
const fs = require('fs'), os = require('os'), path = require('path'), cp = require('child_process');
const [mmd, browser, lib] = process.argv.slice(2);
const svgOut = mmd.replace(/\.mmd$/i, '.svg');
const src = fs.readFileSync(mmd, 'utf8');
const ws = fs.mkdtempSync(path.join(os.tmpdir(), 'mmd-r-'));   // 临时工作区（Windows 原生路径）
const toUrl = p => 'file:///' + p.replace(/\\/g, '/');          // C:\... → file:///C:/...
function dump(url, budget) {                                    // headless 取 DOM 序列化
  const args = ['--headless', '--disable-gpu', '--no-sandbox',
                '--user-data-dir=' + path.join(ws, 'profile'),
                '--dump-dom', url];
  if (budget) args.splice(4, 0, '--virtual-time-budget=' + budget);
  return cp.execFileSync(browser, args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'],
                                          maxBuffer: 64 * 1024 * 1024 });
}
try {
  // 与已验证方案同构：v9 UMD + JSON.stringify 内嵌源码（规避 file:// 下 ESM 不可用）
  const page =
    '<!DOCTYPE html><html><head><meta charset="utf-8"></head><body>' +
    '<script src="' + toUrl(path.resolve(lib)) + '"></script>' +
    '<script>window.onerror=function(m){document.title="ERR:"+m;};' +
    'const src=' + JSON.stringify(src) + ';' +
    'mermaid.initialize({startOnLoad:false,theme:"default"});' +
    'mermaid.render("my-svg",src,function(svg){document.body.innerHTML=svg;document.title="MMD_DONE";});' +
    '</script></body></html>';
  const html = path.join(ws, 'render.html');
  fs.writeFileSync(html, page);
  const dump1 = dump(toUrl(html), 15000);                        // 虚拟时间预算等 mermaid 异步渲染
  if (!dump1.includes('MMD_DONE')) {
    const e = dump1.match(/ERR:([^\n<]*)/);
    throw new Error(e ? '页面脚本错误: ' + e[1] : 'mermaid 渲染未在预算内完成（dump 中无 MMD_DONE）');
  }
  const m = dump1.match(/<svg[\s\S]*?<\/svg>/);                  // 提取渲染出的唯一顶层 svg
  if (!m) throw new Error('dump 中未找到 <svg>（渲染失败？）');
  const svg = m[0].replace(/<br(?![^>]*\/>)/gi, '<br/>');        // HTML 序列化残留裸 <br> → XML 合法 <br/>
  fs.writeFileSync(svgOut, svg);
  const dump2 = dump(toUrl(path.resolve(svgOut)));               // 二次 dump：按 XML 解析校验
  if (!dump2.includes('<svg') || dump2.includes('This page contains')) {
    throw new Error('XML 良构校验未通过（浏览器按 XML 解析报错，请检查 dump）');
  }
  console.log('[3/3] OK: ' + svgOut + '（' + svg.length + ' 字节，含 ' +
              (svg.match(/<text/g) || []).length + ' 处文本，XML 校验通过）');
} catch (err) {
  console.error('错误: ' + mmd + ' → ' + err.message);
  process.exitCode = 1;
} finally {
  fs.rmSync(ws, { recursive: true, force: true });              // 清理临时工作区
}
NODEEOF
    then
        :   # node 已打印 OK/错误；exit 0 分支无附加动作
    else
        FAIL=1
    fi
done
exit $FAIL

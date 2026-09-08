---
name: cross-platform-dual-env
description: 仓库在 Windows + Ubuntu 双环境迭代——行尾/LF 统一、大小写敏感、脚本可执行位、渲染字体差异、python3 商店桩等跨平台坑（CLAUDE.md §13）
metadata:
  type: feedback
---

仓库同时在 Windows（git-bash + Claude Code）与 Ubuntu 上开发迭代（2026-09-08 用户确立）。

**Why:** 本会话实证的跨平台坑：1) Windows `core.autocrlf=true` 在 status/diff 时刷 "LF will be replaced by CRLF" 警告并产生统计性虚 M（静态时序分析.md 虚 M 两次）；2) 新增 render_mermaid.sh 提交后是 100644（`core.filemode=false` 下 chmod 不入库），而老脚本 render_wavedrom.sh 是 100755——Ubuntu 检出后行为不一致；3) Windows 无 puppeteer 缓存，render_wavedrom.sh 原探测逻辑找不到浏览器（msedge 需显式探测）；4) Windows `python3` 可能是商店桩（Permission denied / exit 126），render_wavedrom.sh 依赖 python3 会莫名失败；5) SVG 文本布局依赖字体度量，两平台字体不同 → 同一 .mmd 跨机重渲染产生布局 diff。

**How to apply:** 见 CLAUDE.md §13 六条硬性规则。要点：`.gitattributes` 全文本 `eol=lf`（已入库，两端检出均为 LF）；大小写逐字节一致（Ubuntu 断链）；`.sh` 用 `git update-index --chmod=+x` 保 100755；渲染脚本三级浏览器探测 + `winpath()`（cygpath，非 Windows 直传）；python3 桩须装真 Python；改图固定单环境重渲染并核对 git diff。关联 [[windows-bash-cjk]]、[[mermaid-svg-xml-fix]]、[[sync-before-edit]]。

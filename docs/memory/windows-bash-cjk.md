---
name: windows-bash-cjk
description: Windows 下 Claude Code 的 Bash 命令含字面中文会解析破坏（exit 127），须用 glob/转义或专用工具
metadata:
  type: feedback
---

Windows（git-bash + Claude Code）下，Bash 命令行文本中出现字面中文（典型：中文文件名路径）时，命令在传递层被按非 UTF-8 代码页破坏解析，表现 exit 127 与怪异报错（整行命令被当命令名报告 `No such file or directory`）。

**Why:** 2026-09-08 实测确诊——命令文本在到达 bash 前经过中间解析层（`$?` 被提前展开为 0 是铁证）；同一命令用 `printf '\xe8\xae\xbe\xe8\xae\xa1'` 字节构造文件名后完全正常，证明通道按字节透传无损、破坏只发生在字面文本解析；Read/Write/Grep/Glob 等专用工具不受影响。

**How to apply:** Bash 命令一律不写字面中文——中文文件名用 glob（`RTL*.md`）或 `$(printf '\x..')` 构造；中文内容读写走专用工具；复杂逻辑写 `.sh` 临时脚本再执行（Write 工具写入 UTF-8 无损）。规则已固化于 [[CLAUDE.md]] 第 12 条。

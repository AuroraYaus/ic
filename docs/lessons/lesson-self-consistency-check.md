# lesson-self-consistency-check

> 文档自指性检查——README等自描述文件必须与实际仓库状态一致

# 文档自指性检查

任何描述项目本身的文件（README、入口页、MOC）中的目录结构、文件统计、链接列表，必须与仓库实际状态一致。

## 检查项

- 目录树文件名 vs 实际文件名（含中英文、扩展名）
- 文件统计数字 vs 实际计数
- 链接列表 vs 实际文件（新增已列入、删除已移除）

## 触发时机

每次批量增删文件后必须执行。审计 Agent 的检查清单应包含此项——审计盲区高发地带。

**Why:** 审计覆盖了结构和内容，但漏了"文档描述与实际的 diff"——README 写 46 文件实为 52，写英文文件名实为中文。

**How to apply:** 审计时必做：自指性文件内容 vs 仓库文件列表的 diff 检查。

**Related:** [[code-documentation-standards]] [[qa-pipeline]]

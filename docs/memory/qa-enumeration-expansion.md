---
name: qa-enumeration-expansion
description: Q&A 回答中列出的分解维度枚举必须逐个展开讲解，不得只列名
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ec9a0039-11b8-4f25-a678-f5b356dc34c0
  modified: 2026-08-29T08:56:50.961Z
---

用户追问"组合逻辑和非组合逻辑功耗怎么没讲呢"——上一轮回答"按分解维度"只列了类型名（组合逻辑/时序单元/时钟树/memory/IO）未展开，被当场指出缺口，随后补写"组合逻辑与时序逻辑的功耗特征"章节。

**Why:** 用户提问是回答的入口而非边界（ic/CLAUDE.md 第 9.0 条），枚举即承诺——列出维度却跳过某几项，读者立刻发现缺口并追问；"列了就得讲"是回答完整性的底线。

**How to apply:** 回答中任何"按 X 维度"的枚举（功耗分组、时钟域、测试模式、工艺角等）必须逐项展开一段说明；展开不了的项目不列。写入文件前自查枚举完整性——每个列出的项在正文中必须有对应段落。关联 [[qa-pipeline]]、[[markdown-bold-flanking]]。

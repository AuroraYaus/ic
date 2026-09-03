---
name: synthesizable-only-rtl
description: 知识库 RTL 代码必须是可综合的，禁止展示不可综合写法
metadata: 
  node_type: memory
  type: project
  originSessionId: 79863066-e95e-4bb3-8432-fdbc9a85cfcd
---

# RTL 可综合约束

**知识库中所有 RTL 代码示例必须是可综合的（Synthesizable）。禁止展示或教授不可综合的写法。**

## 绝对禁止的不可综合结构

- 时序控制：`#N`、`wait`、`forever`
- 仿真过程：`initial`、`final`、`fork/join`、`disable`
- 系统任务：`$display`/`$monitor`/`$random`/`$stop`/`$finish` 等（`$clog2` 例外）
- 层次引用：XMR、`force`/`release`
- 动态类型：`class`、`dynamic array`、`queue`、`string`、`real`
- 验证专用：`mailbox`、`semaphore`、`virtual interface`
- 无界循环：`while`、`do...while`

## 危险模式必须标注

锁存器推断、组合环路、多驱动、混合赋值——综合通过但行为错误，展示时必须加 `// ❌` 标注。

## 仿真代码必须标注

`initial`/`class`/系统任务等仅仿真代码必须标注 `// 仅仿真`。

**Why:** 知识库是学习资源——不可综合的代码误导学习者写出只能在仿真中运行、无法流片的 RTL。

**How to apply:** 编写 RTL 代码块前，确认每一行都能回答"这个对应什么硬件？"——答不上来的就是不可综合。参见 CLAUDE.md Rule 3.2 和 SystemVerilog.md 中的"可综合子集边界"章节。

**Related:** [[code-documentation-standards]]

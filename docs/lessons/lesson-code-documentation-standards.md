# lesson-code-documentation-standards

> 知识库代码块必须逐行中文注释，函数/任务须用 DOXYGEN 风格注释

# 知识库代码文档标准

数字IC知识库中的所有代码块必须遵循以下标准：

## 核心原则

**本项目是知识库，不是工程手册——代码块必须能让初学者独立理解每一行。** 禁止"裸代码"（仅有上方概述性注释而无行内细节的代码块）。

## 具体要求

1. **逐行解释**：任何代码块（SystemVerilog / Verilog / TCL / Python / Shell / Perl / C / Makefile 等）中的关键关键字、运算符、系统函数必须有行内中文注释
2. **语法拆解**：复杂语法结构必须逐层拆解，说明每个子句的语义
3. **DOXYGEN 风格注释**：所有 `function` 和 `task` 声明必须使用 `/** ... */` 注释，包含：
   - 首行功能描述（必需）
   - 详细说明 ≥2 段（必需）
   - `@param` 每个参数（必需）
   - `@return` 返回值（必需，有返回值时）
   - `@note`/`@warning`/`@see`（推荐）
4. **注释语言**：全部使用中文

**Why:** 用户发现 verification/concepts/SVA断言.md 中的 SystemVerilog 代码缺少行内解释，对初学者不友好。作为知识库而非工程代码仓库，可读性优先级高于简洁性。

**How to apply:** 编写或修改任何包含代码块的概念文件时，检查每个代码块是否有逐行中文注释。编写 function/task 时使用 DOXYGEN 风格模板。参见 CLAUDE.md Rule 3.1。可参考 verification/concepts/SVA断言.md 中已修改的代码块作为示例。

**Related:** [[qa-pipeline]]

---
type: concept
aliases:
  - Makefile 规则详解
  - Makefile target prerequisite recipe
tags:
  - tools
  - makefile
  - asic
source_spec: "GNU Make Manual: Rule Syntax, Rule Introduction, Multiple Targets in a Rule, Phony Targets, Rules without Recipes or Prerequisites, Double-Colon Rules; POSIX make specification"
queries: 1
---

# 03 — Makefile规则详解

## 学习目标

本篇对 Makefile 的**规则（Rule）**做完整解剖。读完本篇后，你将能够：

1. 精确区分四种目标类型（真实文件目标、伪目标、纯依赖目标、目录目标）及其决策逻辑
2. 理解 Make 如何选择默认目标——不仅是"第一个目标"，包括 `.DEFAULT_GOAL` 覆盖和边缘情况
3. 掌握多目标规则的语义陷阱和 Grouped Targets（`&:`）的根本区别
4. 写出依赖层级正确的、包含 5+ 条规则的多目标 Makefile

规则是 Makefile 的最小工程单元。变量、函数、条件、模式规则——最终都服务于规则，告诉 Make "什么需要重建，如何重建"。

## 前置知识

- 已阅读 [[tools/concepts/01-Makefile解决的问题与第一个例子|01 — 第一个例子]]：目标、前置条件、配方三要素
- 已阅读 [[tools/concepts/02-Makefile心智模型与历史|02 — 心智模型]]：DAG 和二阶段执行

后续：[[tools/concepts/04-Makefile配方与Shell|04 — 配方与 Shell]]（配方的执行层）、[[tools/concepts/12-Makefile模式规则|12 — 模式规则]]。

## 最小可运行例子

### 例子 1：五类规则的完整展示

```makefile
# ===== 例子 1：五类规则的完整演示 =====
# 类型 1 — 纯依赖规则（有目标+前置条件，无配方）：只声明"all 完成后才算完成"
all: app.bin report.txt                # all 是伪目标入口，依赖两个产物

# 类型 2 — 真实文件规则（有目标+前置条件+配方）：描述如何从 main.c 生成 app.bin
app.bin: main.c                        # app.bin 由 main.c 编译而来
	@printf 'linking %s -> %s\n' "$<" "$@" > "$@"  # 模拟编译和链接

# 类型 3 — 目录目标（目标名恰好是一个目录名）
build:                                 # build 目录不存在时创建
	@mkdir -p "$@"                     # $@ = build

# 类型 4 — 无前置条件规则（只有目标+配方）：文件缺失时生成
main.c:                                # main.c 不存在时自动生成（真实项目通常手写）
	@printf 'int main(void) { return 0; }\n' > "$@"  # 创建最小 C 文件

# 类型 5 — 纯配方规则（.PHONY + 目标+配方）：永远执行
.PHONY: clean                          # clean 永远不会被"已最新"跳过
clean:
	@rm -rf app.bin report.txt main.c build

# 额外：多目标规则 — 一条规则声明两个目标共享同一组前置条件和配方
stamp.a stamp.b: main.c                # stamp.a 和 stamp.b 都由 main.c 生成
	@printf 'stamp from %s\n' "$<" > stamp.a
	@cp stamp.a stamp.b                # 复制为第二个 stamp
```

执行：

```shell
make clean && make --trace
touch main.c && make --trace           # 修改 main.c 后观察哪些目标重建
printf 'not a target\n' > clean && make clean  # .PHONY 防冲突验证
```

**五类目标的决策逻辑对照表：**

| 目标 | 类型 | 不存在时 | 前置条件更新时 | 已有且最新时 |
|:---|:---|:---|:---|:---|
| `app.bin` | 真实文件 | 执行配方 | 执行配方 | 跳过 |
| `main.c` | 无前置文件 | 执行配方 | N/A（无前置条件） | 跳过 |
| `build` | 目录目标 | 执行 `mkdir` | N/A（无前置条件） | 跳过 |
| `all` | 纯依赖 | N/A | 检查前置条件链 | 前置条件全部最新时跳过 |
| `clean` | 伪目标 | 总是执行 | 总是执行 | 总是执行 |

### 例子 2：多目标规则的陷阱与修复

```makefile
# 例子 2a：有缺陷的多目标规则 —— 配方只写入 stamp.a
stamp.a stamp.b: input.txt            # 等价于 stamp.a: input.txt 和 stamp.b: input.txt
	@printf 'generate from %s\n' "$<" > stamp.a
# 当 Make 要构建 stamp.b 时，也执行这条配方——但配方只创建了 stamp.a！

# 例子 2b：Grouped Targets（&:）—— GNU Make 4.3+
# 告诉 Make "一次配方执行同时生成所有目标"
stamp.a stamp.b &: input.txt          # amp;: 表示一次配方运行同时产出两个文件
	@printf 'stamp from %s\n' "$<" > stamp.a
	@cp stamp.a stamp.b                # 确保 stamp.b 也被创建
```

```shell
make stamp.b     # 例子 2a：stamp.b 仍然不存在！Make 认为配方已执行但文件未生成
make stamp.b     # 例子 2b：正确——一次配方生成了两个文件
```

**选择指南：** 多目标规则仅当配方对每个目标**独立正确**时才安全（如 `$(OBJS): %.o: %.c` 静态模式规则——每个目标的 `$@` 不同）。一次配方生成多文件 → 用 Grouped Targets（`&:`）。

## 语法拆解

### 规则的形式化定义

```text
targets [targets...] : [normal-prerequisites] [| order-only-prerequisites] [; recipe]
<TAB>recipe-line-1
<TAB>recipe-line-2
```

**逐元素拆解：**

| 元素 | 必需 | 示例 | 约束 |
|:---|:---|:---|:---|
| targets | **是** | `app.bin`、`clean`、`%.o` | 至少一个，不含 `:` 或 TAB |
| `:` | **是** | 分隔符 | 前后可有空格 |
| normal-prerequisites | 否 | `main.c utils.h` | 空格分隔 |
| `|` | 否 | 分隔符 | 引导 order-only 前置条件 |
| order-only-prerequisites | 否 | `build`、`log/` | 仅检查存在性，不比较时间戳 |
| `; recipe` | 否 | `; @echo hi` | 与目标同行——实践中很少使用 |
| recipe lines | 否 | TAB 开头的 Shell 命令 | 每行独立 TAB |

### 四种规则形态的完整语义

| 形态 | 语义 | 触发重建条件 | 典型场景 |
|:---|:---|:---|:---|
| `T: P` + 配方 | "T 由 P 通过配方生成" | T 不存在，或 P 比 T 新 | 编译/仿真/报告 |
| `T: P` 无配方 | "T 的完成依赖于 P 的完成" | P 被更新 | `all: prog`（纯入口） |
| `T:` + 配方   | "T 只在不存在时生成" | T 文件不存在 | 默认配置文件 |
| `.PHONY: T` + 配方 | "T 是动作，不是文件" | 每次请求 | `clean`、`test`、`install` |

### 默认目标的选择算法

Make 选择默认目标的完整规则：

1. 按读取顺序提取**第一个不以 `.` 开头的目标**（`.DEFAULT`、`.PHONY`、`.SUFFIXES` 被跳过）
2. 模式规则中的 `%` 目标不算普通目标（`%.o:` 被跳过）
3. 伪目标**可以**是默认目标——如果它在 `.PHONY` 声明中且是第一个普通目标
4. **`.DEFAULT_GOAL` 覆盖一切**：

```makefile
.DEFAULT_GOAL := all                  # 无论 all 在第几行，它成为默认目标
other-first:                          # 不再是默认目标
	@echo "not default"
all:
	@echo "this IS the default"
```

### `.PHONY` 的三种作用

| 作用 | 机制 | 典型场景 |
|:---|:---|:---|
| **防文件名冲突** | Make 不检查是否有同名文件 | `clean`、`test`、`install` |
| **跳过时间戳检查** | 伪目标永远"需要更新" | 所有动作入口 |
| **作为触发器** | 伪目标作为前置条件 → 下游总是重建 | `force-rebuild` 模式 |

```makefile
.PHONY: force
app.bin: main.c force                 # force 永远"更新" → app.bin 每次重建
	@printf 'rebuilding\n' > "$@"
```

## 执行轨迹

### `make --trace` 输出与 DAG 遍历对照

从空目录运行例 1 的 `make --trace`：

```text
# Make 找到默认目标 all → 需要先满足 app.bin 和 report.txt

# 步骤 1：检查 app.bin → 需要 main.c
Makefile:13: target 'main.c' does not exist
#            无前置条件、文件不存在 → 执行主配方  ← Make 总是先深入最深的叶子节点

# 步骤 2：main.c 生成完毕 → 返回到 app.bin
Makefile:7: update target 'app.bin' due to: main.c
#            main.c 刚生成 → app.bin 需要重建

# 步骤 3：app.bin 完成 → 检查 report.txt（类似流程）
# 步骤 4：所有前置条件满足 → all 完成
```

**遍历顺序永远是从最深叶子开始的后序遍历，不是文件中的书写顺序。**

## 工程化写法

### 规则层次化组织

```makefile
# Layer 1: 用户入口（全部伪目标）
.PHONY: all test clean
all: build/program
test: build/program
	@build/program --test
clean:
	rm -rf build/

# Layer 2: 最终产物（真实文件）
build/program: $(OBJS)
	@mkdir -p $(@D)                   # $(@D) = build/
	$(CC) $^ -o $@

# Layer 3-4: 中间产物和源文件由模式规则管理（后续篇章）
```

### 数字IC 规则层次

```makefile
.PHONY: sim sta all clean
sim: logs/smoke.log
sta: reports/timing.rpt
all: sim sta

logs/smoke.log: $(RTL) filelist.f
	vcs -f filelist.f -l $@

reports/timing.rpt: syn/netlist.v constraints.sdc
	primetime -f sta.tcl
```

## 常见错误

### 错误 1：默认目标偏移

**现象：** `make` 执行了错误的第一个目标。

**修复：** 把 `all` 放第一行，或用 `.DEFAULT_GOAL := all`。

### 错误 2：多目标规则未更新全部目标

**现象：** `a b: input` 配方只写入 `a`——`b` 永远无法被创建。

**修复：** Grouped Targets（`&:`）或静态模式规则。

### 错误 3：伪目标忘记 `.PHONY` 声明

**现象：** 偶然创建了同名文件后 `make clean` 再也不工作。

**预防：** 所有动作目标（`clean`、`test`、`install`、`run`、`help`）一律声明 `.PHONY`。

### 错误 4：配方悬挂——属于错误的规则

**现象：** 规则间有空行——配方脱离了目标。

**修复：** 规则之间不要有空行，或确保空行前后没有孤立的 TAB 行。

## 关键要点

1. **规则 = 目标 + 前置条件 + 配方。** 只有目标是必需的。
2. **默认目标是第一个不以 `.` 开头的目标。** 用 `.DEFAULT_GOAL` 覆盖。
3. **`.PHONY` 有三个作用：防冲突、跳过时间戳、作为触发器。**
4. **多目标规则（`a b: ...`）对每个目标独立执行配方。** 配方须对每个目标正确——否则用 `&:`。
5. **Make 按 DAG 后序遍历执行规则，不按书写顺序。**
6. **所有动作目标一律加 `.PHONY`——不依赖"目录中没有同名文件"的假设。**

## 与其他概念的关系

- [[tools/concepts/02-Makefile心智模型与历史|02 — 心智模型]]：DAG 的节点=目标，边=前置条件
- [[tools/concepts/04-Makefile配方与Shell|04 — 配方与 Shell]]：深入规则的配方执行层
- [[tools/concepts/12-Makefile模式规则|12 — 模式规则]]：从显式规则到 `%` 模式
- [[tools/concepts/15-Makefile高级依赖|15 — 高级依赖]]：双冒号规则和 order-only 的完整讨论

## 小练习

1. **预测默认目标：** 写一个包含 5 个目标的 Makefile：`.SILENT:`、`%.o:`、`alpha:`、`beta:`、`.PHONY: gamma`。预测默认目标，运行验证。
2. **重现多目标陷阱：** 写 `a b: input`，配方只生成 `a`。运行 `make a && make b`，观察 `b` 的行为。用 `&:` 修复。
3. **设计规则层级：** 为一个三步 IC 流程（仿真→综合→STA）写规则骨架，确保 `make sta` 自动触发综合和仿真。

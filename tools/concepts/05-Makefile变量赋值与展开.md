---
type: concept
aliases:
  - Makefile 变量赋值与展开
  - Makefile variable flavor expansion
tags:
  - tools
  - makefile
  - asic
source_spec: "GNU Make Manual 6.2: The Two Flavors of Variables, 6.5: Setting Variables, 6.6: Appending More Text, 6.13: Shell Function; POSIX make specification"
queries: 1
---

# 05 — Makefile变量赋值与展开

## 学习目标

本篇是 Makefile 变量系统的核心章节。读完本篇后，你将能：

1. 精确区分五种赋值操作符（`=`、`:=`、`?=`、`+=`、`!=`）的展开时机和语义
2. 用 `$(shell date +%N)` 这类可观测的实验，自己动手验证展开时机的差异
3. 理解 `+=` 在不同基础 flavor 上的展开差异——这是实战中最容易踩的坑
4. 用 `$(info ...)` 和 `$(flavor ...)` 诊断变量的最终值和类型

**本篇与 [[tools/concepts/02-Makefile心智模型与历史|02 — 心智模型]] 的二阶段模型紧密绑定。** 变量行为的根源是读阶段 vs 目标更新阶段的展开时机——五种赋值操作符的本质区别就是这个时机的选择。

## 前置知识

- [[tools/concepts/02-Makefile心智模型与历史|02 — 心智模型]]：二阶段执行模型
- [[tools/concepts/04-Makefile配方与Shell|04 — 配方与 Shell]]：配方中的 `$` 展开

后续：[[tools/concepts/06-Makefile高级变量|06 — 高级变量]]（自动变量、target-specific、`$(origin)`/`$(flavor)`/`$(value)`）。

## 最小可运行例子

### 例子 1：用 `date +%N` 观察展开时机——眼见为实

```makefile
# ===== 例子 1：五种赋值的展开时机实验 =====
# $(shell date +%N) 返回纳秒——每次执行结果不同——观察展开了几次

# 1. = 递归展开：每次引用都重新执行 date
NOW_REC  = $(shell date +%N)         # 读阶段：只保存文本，不执行 date

# 2. := 简单展开：读阶段执行一次，结果缓存
NOW_SIMPLE := $(shell date +%N)      # 读阶段：立即执行 date 并保存纳秒值

# 3. ?= 条件赋值：只在变量未定义时生效
MODE ?= debug                        # 用户可通过 make MODE=release 覆盖

# 4. != Shell 赋值：读阶段运行命令并保存标准输出
HOST != uname -s                     # 等价于 HOST := $(shell uname -s)

# 5. += 追加：保留原值，展开时机取决于原变量的 flavor
CFLAGS := -Wall                      # 简单展开
CFLAGS += -O2                        # += 在简单展开变量上：追加立即展开

# === 验证实验 ===
.PHONY: all
all:
	@printf '=== RECURSIVE (=) ===\n'
	@printf '  1st: %s\n' '$(NOW_REC)'  # 第一次引用——执行 date
	@sleep 0.1
	@printf '  2nd: %s\n' '$(NOW_REC)'  # 第二次引用——再次执行 date——值不同！
	@printf '\n=== SIMPLE (:=) ===\n'
	@printf '  1st: %s\n' '$(NOW_SIMPLE)'  # 读阶段缓存的值
	@sleep 0.1
	@printf '  2nd: %s\n' '$(NOW_SIMPLE)'  # 相同——缓存不变
	@printf '\nMODE=%s, HOST=%s, CFLAGS=%s\n' '$(MODE)' '$(HOST)' '$(CFLAGS)'
```

执行：

```shell
make                          # 观察 NOW_REC 两次引用值不同——递归展开证据
make MODE=release             # 命令行覆盖 ?=
```

**预期：** `NOW_REC` 两次输出不同纳秒值；`NOW_SIMPLE` 两次相同。

### 例子 2：`+=` 的展开时机陷阱

```makefile
# ===== 例子 2：+= 的行为取决于原变量的 flavor =====
A := initial                    # A = 简单展开（simply expanded）
A += $(shell date +%s)          # += 在简单展开变量上：date 立即执行

B  = initial                    # B = 递归展开（recursively expanded）
B += $(shell date +%s)          # += 在递归展开变量上：date 延迟到引用时

.PHONY: all
all:
	@printf 'A 1st=%s\n' '$(A)'; sleep 2; @printf 'A 2nd=%s\n' '$(A)'  # A 两次相同
	@printf 'B 1st=%s\n' '$(B)'; sleep 2; @printf 'B 2nd=%s\n' '$(B)'  # B 两次不同！
```

**核心结论：`+=` 不改变 flavor——追加文本的展开时机由原变量决定。**

## 语法拆解

### 五种赋值完整语义表

| 操作符 | 名称 | 展开时机 | 适用场景 | 陷阱 |
|:---|:---|:---|:---|:---|
| `=` | 递归展开 | **每次引用时**重新展开 | 需要反映运行时最新值的变量 | `$(shell ...)` 用 `=` → 性能灾难 |
| `:=` | 简单展开 | **赋值瞬间**（读阶段） | 固定值、缓存 Shell 结果 | 不能引用文件后面才定义的变量 |
| `?=` | 条件赋值 | 赋值瞬间（仅未定义时） | 默认值——允许命令行覆盖 | "已定义但为空"≠"未定义" |
| `!=` | Shell 赋值 | 赋值瞬间（读阶段） | `HOST != uname -s`——等价于 `:= $(shell ...)` | GNU Make ≥4.0 |
| `+=` | 追加 | **取决于原 flavor** | 追加编译选项、文件列表 | 用 `=` 定义的变量上 `+=` → 延迟展开 |

### 递归展开（`=`）的精确行为

```makefile
# = 保存未展开文本——每次引用时：
#   1. 展开文本中的所有变量引用
#   2. 展开所有函数调用
#   3. 如果展开结果仍含变量引用 → 继续展开（递归）

# 优势：能引用后面才定义的变量
CFLAGS = -Wall $(EXTRA_CFLAGS)     # EXTRA_CFLAGS 可能在后面才定义
EXTRA_CFLAGS = -DDEBUG             # 引用 $(CFLAGS) 时会自动包含 -DDEBUG

# 危险：无限循环
X = $(Y); Y = $(X)                 # 引用 X 或 Y 时触发循环检测
#   *** Recursive variable 'X' references itself (eventually).  Stop.
```

### 简单展开（`:=`）的精确行为

```makefile
# := 在读阶段：立即展开右侧所有变量和函数 → 保存结果字符串
# 之后引用 → 直接返回字符串，不再展开

# 优势：性能确定——昂贵操作只执行一次
SRCS := $(shell find . -name '*.c')    # find 读阶段执行一次

# 劣势：不能引用"尚未到达"的变量
BAR := $(FOO)                           # FOO 尚未定义 → BAR = 空
FOO := hello                            # FOO 此时才定义——BAR 仍是空
```

### `?=` 条件赋值

```makefile
FOO ?= default                    # FOO 未定义 → 赋 default
BAR  =                            # BAR 已定义（值为空）
BAR ?= default                    # 不生效——BAR 已定义
# ?= 检查"是否已定义"，不是"是否为空"
# 用 $(origin VAR) 诊断：返回 undefined 时才触发
```

### `!=` Shell 赋值（GNU Make ≥4.0）

```makefile
HOSTNAME != hostname              # 等价于 HOSTNAME := $(shell hostname)
GIT_HASH != git rev-parse --short HEAD 2>/dev/null || echo "unknown"
```

## 执行轨迹

### 用 `$(info ...)` 追踪展开时机

```makefile
$(info [READ PHASE] Starting...)

VAR1 := $(shell echo "VAR1 expanded" >&2)       # := 读阶段展开
VAR2  = $(shell echo "VAR2 expanded" >&2)       # =  不展开——保存文本
VAR3 != echo "VAR3 expanded" >&2                # != 读阶段展开

$(info [READ PHASE] Done.)

.PHONY: all
all:
	@printf 'VAR1=%s\n' '$(VAR1)'
	@printf 'VAR2=%s\n' '$(VAR2)'                # VAR2 此时才展开！
	@printf 'VAR3=%s\n' '$(VAR3)'
```

```shell
make
# 输出顺序：
# [READ PHASE] Starting...
# VAR1 expanded        ← := 在读阶段
# VAR3 expanded        ← != 在读阶段
# [READ PHASE] Done.
# VAR2 expanded        ← =  在配方阶段——在 "Done" 之后！
```

## 工程化写法

### 赋值选择决策树

```text
要赋什么值？
├─ 固定字符串（"gcc"、"debug"） → :=
├─ 含 $(shell ...) 或 $(wildcard ...) → := （缓存！）
├─ 需要引用后面才定义的变量 → = （但整理顺序更好）
├─ 用户可从命令行覆盖的默认值 → ?=
├─ 追加到已有变量 → += ——但先搞清楚原变量的 flavor！
└─ shell 命令的单次结果 → != 或 := $(shell ...)
```

### 工程模板

```makefile
# ===== 工程 Makefile 变量组织模式 =====
# 1. 工具链——固定路径
CC       := gcc
AR       := ar

# 2. 编译选项——:= + ?= + += 组合
CFLAGS   := -Wall -Wextra
CFLAGS   += -O2
DEBUG    ?= 0
ifeq ($(DEBUG),1)
CFLAGS   += -g -O0 -DDEBUG
endif

# 3. 源文件扫描——昂贵，:= 缓存
SRCS     := $(wildcard src/*.c)
OBJS     := $(SRCS:.c=.o)

# 4. 平台检测——!= 一次执行
PLATFORM != uname -s
ifeq ($(PLATFORM),Darwin)
LDFLAGS  += -framework CoreFoundation
endif

# 5. 版本信息——运行时可能变化，用 =
VERSION   = $(shell git describe --tags 2>/dev/null || echo "dev")
```

## 常见错误

### 错误 1：`$(shell find ...)` 用 `=` 定义

**现象：** make 极慢，find 被执行 N 次。

**修复：** `SRCS := $(shell find . -name '*.c')`

### 错误 2：`+=` 在 `=` 变量上追加 `$(shell ...)` 导致重复执行

**修复：** 先确保基础变量是 `:=` 再 `+=`。

### 错误 3：`?=` 不生效——变量已定义为空

**现象：** `make FOO=` 后 `FOO ?= default` 不生效。

**修复：** 需要空值默认时用 `ifeq ($(FOO),) FOO := default endif`。

### 错误 4：`:=` 变量的顺序依赖

**现象：** `BAR := $(FOO)` 得到空，但 `FOO` 在下面。

**修复：** 把被引用的变量放在引用它的 `:=` 前面。

## 关键要点

1. **`=` vs `:=` 的核心差异是展开时机，不是"是否递归"。**
2. **`+=` 不改变原变量的 flavor。** 在 `=` 变量上 `+=` → 追加也延迟展开。
3. **昂贵操作（`$(shell ...)`、`$(wildcard ...)`）一律用 `:=` 缓存。**
4. **`?=` 检查"是否已定义"，不是"是否为空"。**
5. **`!=` 是 `:= $(shell ...)` 的语法糖——GNU Make ≥4.0。**
6. **`$(flavor VAR)` 和 `$(origin VAR)` 是诊断变量的两个核心工具。**

## 与其他概念的关系

- [[tools/concepts/02-Makefile心智模型与历史|02 — 心智模型]]：二阶段模型是变量展开的元理论
- [[tools/concepts/06-Makefile高级变量|06 — 高级变量]]：自动变量、target-specific、诊断函数
- [[tools/concepts/10-Makefile条件判断|10 — 条件判断]]：条件在读阶段求值——`=` 变量的延迟影响条件结果
- [[tools/concepts/19-Makefile调试与性能|19 — 调试与性能]]：`$(shell ...)` 性能的系统化诊断

## 小练习

1. **验证展开时机：** 运行例 1，确认 `NOW_REC` 两次值不同而 `NOW_SIMPLE` 两次相同。
2. **重现 `+=` 陷阱：** 运行例 2，观察 A 和 B 的差异。
3. **用 `$(flavor)` 诊断：** 插入 `$(info flavor A = $(flavor A))`，验证 `+=` 不改变 flavor。
4. **测试 `?=` 空值：** `make BAR= && make`，观察 `BAR ?= default` 是否生效。
5. **性能对比：** `FILES = $(shell find /usr -name '*.h')` vs `:=`——用 `time make` 测差异。

---
type: concept
aliases:
  - Makefile Conditions and Functions
  - make 条件与函数
tags:
  - tools
  - makefile
  - build-system
  - gnu-make
source_spec: "GNU Make Manual, Chapters 7-8: Conditional Parts of Makefiles, Functions for Transforming Text"
queries: 1
---

# Makefile 条件与函数

条件判断（Conditionals）和函数调用（Functions）是 Makefile 从"简单的编译脚本"升级为"自动化构建系统"的关键能力。条件判断让 Makefile 根据环境、变量值、目标平台做出差异化选择；函数库则提供了字符串处理、文件名变换、列表操作等文本变换能力——这两者组合后，Makefile 可以像编程语言一样表达复杂的构建逻辑。

Makefile 的函数模型与大多数编程语言不同：所有函数都是**纯文本变换**——输入一段文本，输出一段文本，没有副作用，没有状态。这是 Make 设计的精妙之处：它保持了声明式构建系统的本质（描述"什么取决于什么"），同时提供了足够的表达能力来应对真实项目的复杂性。

## 原理

### 条件判断

Makefile 的条件语法分为两类：**Make 级条件**（在 Make 读取 Makefile 时求值，控制哪些规则和变量被解析）和**Shell 级条件**（在配方执行时求值，控制 Shell 命令的执行流）。前者的关键特性是——条件判断发生在 Make 的读取阶段，因此可以根据条件**排除整段规则定义**。

```makefile
# ===== Make 级条件判断语法 =====
# ifeq/ifneq — 比较两个字符串是否相等/不相等
# ifdef/ifndef — 检查变量是否已定义
# else / endif — 条件语句必须显式终止
# 语法要点：ifeq/ifneq 不能缩进！缩进会破坏条件结构

# --- 示例 1：根据 DEBUG 变量选择编译选项 ---
ifeq ($(DEBUG), 1)         # DEBUG=1 时启用调试
CFLAGS := -g -O0 -DDEBUG   # -g: 调试符号, -O0: 禁用优化, -DDEBUG: 定义 DEBUG 宏
else
CFLAGS := -O2 -DNDEBUG     # -O2: 优化级 2, -DNDEBUG: 定义 NDEBUG（禁用 assert）
endif

# --- 示例 2：平台检测 ---
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S), Linux)
    LDFLAGS += -ldl        # Linux 需要显式链接 libdl（动态加载库）
endif
ifeq ($(UNAME_S), Darwin)
    LDFLAGS += -framework CoreFoundation  # macOS 用 framework 而非 .so
endif

# --- 示例 3：ifdef/ifndef 检查变量是否定义 ---
ifdef V                    # make V=1 时启用详细输出
Q :=                       # Q 为空——不抑制命令输出
else
Q := @                     # Q 为 @——配方前加 @ 抑制回显
endif
# 使用：$(Q)gcc -c $< -o $@   ——当 Q=@ 时变成 @gcc ... 不打印命令本身
```

**条件语法对比：**

| 语法 | 用途 | 示例 |
|:---|:---|:---|
| `ifeq (A, B)` | 两个字符串相等 | `ifeq ($(CC), gcc)` |
| `ifneq (A, B)` | 两个字符串不相等 | `ifneq ($(wildcard config.h), )` |
| `ifdef VAR` | 变量已定义（即使值为空） | `ifdef FEATURE_X` |
| `ifndef VAR` | 变量未定义 | `ifndef PREFIX` |
| `else` | 条件分支中的"否则" | — |
| `endif` | 终止条件块（必需！） | — |

**条件判断的常见陷阱：**

1. **`ifdef` 检查的是"定义"而非"非空"**——`FOO =`（赋空值）仍然算已定义，`ifdef FOO` 为真
2. **条件不能缩进**——`ifeq`、`else`、`endif` 必须从行首开始，缩进会导致解析错误
3. **条件作用于 Makefile 解析层**——不能根据配方执行结果做条件分叉（那些用 Shell 的 `if`）

### 内建函数总览

GNU Make 提供了约 24 个内建函数，按用途可分为四类。函数调用语法为 `$(function arguments)`，多个参数用逗号分隔。

**函数调用语法要点：**

```makefile
# ===== 函数调用的基本形式 =====
# $(函数名 参数1, 参数2, ...)
#  ^nospace
#  函数名和第一个参数之间没有逗号！只有空格。后续参数之间用逗号分隔

# 示例：$(subst .c,.o,$(SRCS))  中的 "subst .c,.o,$(SRCS)"
#       函数名 = subst
#       参数们 = .c  .o  $(SRCS)（空格分隔 A 和 B，逗号分隔 B 和 C）
```

#### 字符串函数

```makefile
# ===== 字符串变换函数 =====
SRCS := main.c utils.c io/file.c

# 1. $(subst FROM, TO, TEXT) — 字面量替换
CLEAN_SRCS := $(subst .c,.o,$(SRCS))   # 结果: main.o utils.o io/file.o

# 2. $(patsubst PATTERN, REPLACEMENT, TEXT) — 模式替换
#    % 匹配任意非空字符串，在 REPLACEMENT 中用同样的 % 引用匹配内容
OBJS := $(patsubst %.c, %.o, $(SRCS))  # 结果: main.o utils.o io/file.o
# patsubst = pattern substitute

# 3. $(strip STRING) — 去除首尾空格 + 压缩内部多余空格为单个空格
STR := $(strip   hello   world   )      # 结果: "hello world"

# 4. $(filter PATTERN..., TEXT) — 保留匹配模式的词
C_SRCS := $(filter %.c, $(SRCS) readme.txt)   # 结果: main.c utils.c io/file.c

# 5. $(filter-out PATTERN..., TEXT) — 移除匹配模式的词
NON_C := $(filter-out %.c, $(SRCS) readme.txt) # 结果: readme.txt
```

**`filter` vs `filter-out` 的工程场景：**

| 场景 | 用法 |
|:---|:---|
| 从混合文件列表中提取源文件 | `$(filter %.c %.cpp, $(ALL_FILES))` |
| 排除不需要编译的文件 | `SRCS := $(filter-out test_%, $(wildcard *.c))` |
| 分离头文件和源文件 | `HDRS := $(filter %.h, $(FILES)); SRCS := $(filter %.c, $(FILES))` |

#### 文件名函数

```makefile
# ===== 文件名操作函数 =====
SRC := src/main.c

# $(dir NAMES...)      — 提取目录部分（含最后的 /）
DIR  := $(dir $(SRC))       # 结果: src/

# $(notdir NAMES...)   — 提取文件名部分（去掉目录）
FILE := $(notdir $(SRC))    # 结果: main.c

# $(suffix NAMES...)   — 提取后缀（含 .）
SUF  := $(suffix $(SRC))    # 结果: .c

# $(basename NAMES...) — 去掉后缀
BASE := $(basename $(SRC))  # 结果: src/main

# --- addprefix / addsuffix：给列表中每个词加前缀/后缀 ---
OBJS := $(addsuffix .o, $(basename $(SRC)))  # 结果: src/main.o
DIRS := $(addprefix -I, src lib)             # 结果: -Isrc -Ilib
```

#### 高级函数

```makefile
# ===== foreach/call/eval/shell 四大高级函数 =====

# 1. $(foreach VAR, LIST, TEXT) — 遍历列表
#    对 LIST 中每个词，将其赋给 VAR，展开 TEXT，所有结果用空格拼接
DIRS := src lib test
MKDIR_CMDS := $(foreach d, $(DIRS), mkdir -p $d;)
#  展开过程：d=src→mkdir -p src; d=lib→mkdir -p lib; d=test→mkdir -p test;

# 2. $(call VARIABLE, PARAM1, PARAM2, ...) — 调用"函数"
#    把 VARIABLE 的值当作模板，将其中的 $(1)$(2)... 替换为参数
#    本质上是一个"参数化的变量"机制——Makefile 没有真正的函数，这是最接近的东西
# --- 定义可复用的编译规则模板 ---
compile = $(CC) $(CFLAGS) -c $(1) -o $(2)
#         $(1) = 第一个参数（源文件）, $(2) = 第二个参数（目标文件）

main.o: main.c
	$(call compile, $<, $@)   # 展开为: gcc -Wall -c main.c -o main.o

# 3. $(eval TEXT) — 动态生成 Makefile 代码
#    将 TEXT 的内容作为 Makefile 语法求值——可以在运行时"写 Makefile"
#    这是 Makefile 最强大也最危险的函数——调试极其困难
# --- 自动为每个目录生成构建规则 ---
define GENERATE_RULES        # define...endef: 定义多行变量（宏）
$(1)_SRCS := $$(wildcard $(1)/*.c)   # $$ 转义——第一次展开时只展开 $(1)
$(1)_OBJS := $$(patsubst %.c,%.o,$$($(1)_SRCS))
$(1).a: $$($(1)_OBJS)                # 为每个目录生成 .a 的构建规则
	$(AR) rcs $$@ $$^
endef

DIRS := src lib test
$(foreach d, $(DIRS), $(eval $(call GENERATE_RULES, $(d))))
#  展开过程：foreach d=src → call GENERATE_RULES, src → eval 结果
#  效果：为 src/ lib/ test/ 三个目录各生成一组构建规则

# 4. $(shell COMMAND) — 执行 Shell 命令并返回输出
GIT_HASH := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
DATE     := $(shell date +%Y-%m-%d)
# ⚠️ $(shell ...) 每次都执行——如果变量用 =（递归展开）定义，每次引用都重新执行！
#    正确做法：用 := 让它只执行一次
```

**四大高级函数对比：**

| 函数 | 作用 | 类比 |
|:---|:---|:---|
| `$(foreach ...)` | 遍历列表，逐项变换 | Python 列表推导 `[f(x) for x in list]` |
| `$(call ...)` | 参数化模板展开 | C 宏 `#define` |
| `$(eval ...)` | 动态生成 Makefile 语法 | Lisp `eval`——运行时元编程 |
| `$(shell ...)` | 调用外部命令 | Python `subprocess.run()` |

## 关键要点

1. **条件判断在 Make 读取阶段求值**——不能根据配方执行结果做分支，那是 Shell `if` 的工作
2. **`ifeq/else/endif` 不能有前导空格**——必须顶格写，缩进会被当作配方的一部分导致语法错误
3. **`$(shell ...)` 必须用 `:=` 赋值**——用 `=` 会导致每次引用都重新执行 Shell 命令，性能灾难
4. **`filter/filter-out` 是管理文件列表的核心工具**——几乎所有项目都需要从混合文件列表中提取特定类型
5. **`eval` 是最后手段，不是首选**——能用 `foreach` + `call` 解决的问题不要上 `eval`，`eval` 生成的代码调试极其困难
6. **函数调用不改变原变量**——所有函数都是纯文本变换，返回新值，不修改输入

## 与其他概念的关系

- [[tools/concepts/Makefile基础语法|Makefile 基础语法]]——本文依赖变量系统和 `:=`/`=` 展开时机的理解
- [[tools/concepts/Makefile模式与依赖|Makefile 模式与依赖]]——`patsubst` 和 `foreach` 是模式规则和 VPATH 管理的基础工具
- [[tools/concepts/Makefile实战项目|Makefile 实战项目]]——`eval` + `call` 组合是大型项目 Makefile 的核心架构模式

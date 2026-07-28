---
type: concept
aliases:
  - Makefile 文本变换函数
  - subst patsubst filter sort word
tags:
  - tools
  - makefile
  - asic
source_spec: "GNU Make Manual 8.2: Functions for String Substitution and Analysis"
queries: 1
---

# 07 — Makefile文本变换函数

## 学习目标

Makefile 的函数全部是**纯文本变换**：输入一段文本，输出一段文本。没有副作用，没有状态。

本篇覆盖 GNU Make 的 13 个文本变换函数，每个给出工程场景示例。读完本篇后，你将能在 Makefile 中自由操控文件名列表、编译选项和路径——从"写死文件名"升级到"自动化构建系统"的关键一步。

**Make 的词表模型：所有变量值都是空格分隔的词（word）列表——这是所有文本函数操作的基本单元。**

## 前置知识

- [[tools/concepts/05-Makefile变量赋值与展开|05 — 变量赋值与展开]]：函数的展开时机（`$(call ...)` / `$(shell ...)` 在各自赋值风格下的展开时刻）
- Make 的函数调用语法：`$(function arguments...)`——函数名和第一个参数之间是空格，不是逗号

## 替换与变换函数

```makefile
# 1. $(subst FROM,TO,TEXT) — 字面量替换（literal substitution）
SRCS := main.c util.c test.c
OBJS := $(subst .c,.o,$(SRCS))        # main.o util.o test.o
#       替换所有出现的 ".c" → ".o"，大小写敏感——不管位置，全部替换

# 2. $(patsubst PATTERN,REPLACEMENT,TEXT) — 模式替换（pattern substitution）
#    % 匹配任意非空字符串——是 pattern 中最强大的一个字符
OBJS := $(patsubst %.c,%.o,$(SRCS))   # main.o util.o test.o
#       简写形式（只替换后缀时推荐）：
OBJS := $(SRCS:.c=.o)                 # 等价于上面的 patsubst
# 带路径的替换：
SRCS := src/main.c lib/util.c
OBJS := $(patsubst %.c,build/%.o,$(SRCS))
#       → build/src/main.o build/lib/util.o（一次完成后缀+路径迁移）

# 3. $(strip STRING) — 去除首尾空白 + 内部多余空格归一化
TEXT := $(strip   hello   world   )   # "hello world"
#       主要用于清理 $(shell ...) 返回值中的换行和多余空格
GIT_HASH := $(strip $(shell git rev-parse HEAD))
#            strip 去掉 git 输出末尾的换行符

# 4. $(findstring FIND,IN) — 查找子串
ifeq ($(findstring debug,$(MODE)),debug)
CFLAGS += -g                           # MODE 包含 "debug" → 添加调试选项
endif
#     findstring 返回找到的子串（"debug"）或空——配合 ifeq 最常用
```

## 过滤与排序函数

```makefile
# 5/6. $(filter PATTERN...,TEXT) — 保留匹配 / $(filter-out ...) — 移除匹配
FILES := main.c util.c readme.txt Makefile
SRCS  := $(filter %.c,$(FILES))        # main.c util.c ——仅保留 .c
OTHER := $(filter-out %.c,$(FILES))    # readme.txt Makefile ——移除 .c

# filter 支持多模式同时过滤：
ALL_SRC := $(filter %.c %.cpp %.s,$(FILES))   # C + C++ + 汇编

# 7. $(sort LIST) — 排序 + 去重（词级别）
DUPS := a b a c b
UNIQ := $(sort $(DUPS))               # a b c
#       sort 自动去重——工程中常用于去重文件列表、库列表、选项列表
CFLAGS := -Wall -O2 -Wall -g          # -Wall 重复了
CFLAGS := $(sort $(CFLAGS))           # -O2 -Wall -g（排序+去重）

# 8-12. 词索引函数族
LIST  := one two three four five
FIRST := $(firstword $(LIST))          # one
LAST  := $(lastword $(LIST))           # five
COUNT := $(words $(LIST))              # 5（词的数量）
THIRD := $(word 3,$(LIST))             # three（从 1 开始——不是从 0！）
# $(wordlist S,E,TEXT) — 取子范围（从第 S 个到第 E 个，含两端）
MID   := $(wordlist 2,4,$(LIST))       # two three four

# 13. $(join LIST1,LIST2) — 交错拼接
A := a b c
B := 1 2 3
J := $(join $(A),$(B))                # a1 b2 c3
#   LIST2 比 LIST1 长 → 多余部分直接追加到结果末尾
```

## 工程场景示例

```makefile
# 场景 1：从混合目录提取特定类型文件
ALL_FILES := $(wildcard src/*)         # 目录下所有文件（含非源码）
C_SRCS     := $(filter %.c,$(ALL_FILES))
HEADERS    := $(filter %.h,$(ALL_FILES))
SCRIPTS    := $(filter-out %.c %.h %.o,$(ALL_FILES))

# 场景 2：生成构建目录下的对象文件路径
SRCS := main.c util.c io/file.c
OBJS := $(patsubst %.c,build/obj/%.o,$(SRCS))
#       → build/obj/main.o build/obj/util.o build/obj/io/file.o

# 场景 3：从目录列表生成编译器 -I 选项
SRC_DIRS := $(sort $(dir $(wildcard src/*/)))  # 去重后的源码目录
INCLUDES := $(addprefix -I,$(SRC_DIRS))        # -Isrc/lib/ -Isrc/app/

# 场景 4：条件编译特性检测
ifeq ($(findstring coverage,$(MAKECMDGOALS)),coverage)
CFLAGS += --coverage
endif

# 场景 5：IC 仿真文件列表处理
RTL_FILES := $(filter %.sv %.v %.vhd,$(ALL_FILES))
TB_FILES  := $(filter %_tb.sv,$(RTL_FILES))
DUT_FILES := $(filter-out %_tb.sv,$(RTL_FILES))
```

## 关键要点

1. **所有函数都是纯文本变换——输入文本、输出文本。无副作用，无状态。**
2. **`$(patsubst ...)` 是模式替换标准工具——`$(VAR:.c=.o)` 是其简写（仅后缀替换场景）。**
3. **`$(filter ...)` / `$(filter-out ...)` 是管理混合文件列表的核心工具。**
4. **`$(sort ...)` 自动去重——处理重复的编译选项、库路径、文件列表。**
5. **空格分隔的词表模型是所有函数的基础——理解"词"的概念。**
6. **`$(findstring ...)` 最常用于 `ifeq` 条件中做子串检测。**

## 与其他概念的关系

- [[tools/concepts/08-Makefile路径与文件函数|08 — 路径与文件函数]]：目录/文件名操作——文本变换的下游
- [[tools/concepts/09-Makefile控制函数与诊断函数|09 — 控制与诊断函数]]：`$(foreach)` 和 `$(eval)` 与文本函数组合
- [[tools/concepts/14-Makefile依赖与自动生成|14 — 依赖与自动生成]]：`$(patsubst ...)` 在 .d 路径换算中的应用

## 小练习

1. **文件分类：** `$(wildcard ...)` + `$(filter ...)` 分离 `.c`、`.h` 和 `Makefile`。
2. **路径迁移：** 用 `$(patsubst ...)` 将 `src/*.c` 映射到 `build/obj/*.o`。
3. **去重+排序：** 含重复词的列表用 `$(sort ...)` 处理后输出。
4. **findstring 条件：** `make debug` 时用 `$(findstring ...)` 检测并添加 `-g`。

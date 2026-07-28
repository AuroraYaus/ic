---
type: concept
aliases:
  - Makefile 路径与文件函数
  - dir notdir wildcard realpath file
tags:
  - tools
  - makefile
  - asic
source_spec: "GNU Make Manual 8.3: Functions for File Names, 8.4: The wildcard Function, 8.6: The file Function"
queries: 1
---

# 08 — Makefile路径与文件函数

## 学习目标

本篇覆盖 GNU Make 的路径操作和文件系统函数。读完本篇后，你将能：

1. 用 `$(dir)`/`$(notdir)`/`$(basename)`/`$(suffix)` 拆解和重组文件路径
2. 正确使用 `$(wildcard ...)` 进行 Make 级别的文件扫描——区别于 Shell 的 `*` 通配符
3. 用 `$(realpath)`/`$(abspath)` 获取规范化路径
4. 用 `$(file ...)`（GNU Make ≥4.0）直接从 Makefile 读写文件——不 fork Shell 进程

## 前置知识

- [[tools/concepts/07-Makefile文本变换函数|07 — 文本变换函数]]：`$(addprefix)`/`$(addsuffix)` 与路径函数天然搭配
- Make 的词表模型：路径的每个目录段是独立的词

## 路径拆解函数

```makefile
# 1/2. $(dir NAMES...) — 提取目录 / $(notdir NAMES...) — 提取文件名
SRC := src/lib/util.c
DIR  := $(dir $(SRC))                 # src/lib/
FILE := $(notdir $(SRC))              # util.c
# 常用组合：从全路径列表中提取纯文件名
SRCS      := $(wildcard src/**/*.c)
BASENAMES := $(notdir $(SRCS))        # main.c util.c io.c

# 3/4. $(suffix NAMES...) — 后缀 / $(basename NAMES...) — 去后缀
SUF  := $(suffix $(SRC))              # .c
BASE := $(basename $(SRC))            # src/lib/util
# 工程组合：去掉后缀 → 换输出目录 → 加新后缀
OBJS := $(addsuffix .o,$(basename $(SRCS)))  # main.o util.o

# 5/6. $(addprefix PREFIX,LIST) / $(addsuffix SUFFIX,LIST)
DIRS  := src lib test
IFLAGS := $(addprefix -I,$(DIRS))     # -Isrc -Ilib -Itest
OBJS   := $(addsuffix .o,main util)   # main.o util.o
```

## 文件系统函数

```makefile
# 7. $(wildcard PATTERN) — Make 级别的通配符展开
#    区别于 Shell 的 *：wildcard 在读阶段由 Make 展开，不是传给 Shell
SRCS := $(wildcard src/*.c)            # 读阶段扫描 src/ 下所有 .c 文件
# ⚠️ 如果不加 wildcard：SRCS = src/*.c 的字面值就是 "src/*.c"——不是文件列表！

# 支持多模式同时扫描：
ALL_CODE := $(wildcard src/*.c lib/*.cpp test/*.c)

# 8/9. $(realpath NAMES...) / $(abspath NAMES...)
#      realpath：解析符号链接 → 真实绝对路径（文件必须存在）
#      abspath：  纯字符串拼接 → 规范化绝对路径（文件不必存在）
ROOT  := $(realpath .)                 # /home/user/project
BUILD := $(abspath build/output)       # /home/user/project/build/output（不检查存在）

# 10. $(file OP FILENAME [,TEXT]) — GNU Make ≥4.0
#     直接从 Makefile 读写文件——不 fork 额外 Shell 进程
$(file > build/version.txt,$(VERSION))      # 覆盖写入
$(file >> build/log.txt,Build started)       # 追加
CONFIG := $(file < config.ini)              # 读取全部内容到变量
# ⚠️ $(file < ...) 在读阶段执行——文件必须在 make 启动时就存在
# 性能：$(file ...) 是 Make 内置操作，比 $(shell echo ... > file) 快得多
```

## 工程场景

```makefile
# 场景 1：自动发现源码 → 迁移到构建目录
SRCS := $(wildcard src/*.c src/**/*.c)      # 递归发现
OBJS := $(patsubst src/%.c,build/%.o,$(SRCS))
DEPS := $(OBJS:.o=.d)                        # .d 依赖文件路径

# 场景 2：构建目录自动创建（classic pattern）
BUILD_DIRS := $(sort $(dir $(OBJS)))         # 去重的构建子目录
$(BUILD_DIRS):
	@mkdir -p $@
$(OBJS): | $(BUILD_DIRS)                      # order-only：目录时间戳不影响 .o

# 场景 3：跨平台项目根路径
PROJ_ROOT := $(abspath .)
BUILD_DIR := $(PROJ_ROOT)/build
# 用 abspath 而非相对路径——递归 Make 中路径不会漂移

# 场景 4：IC — RTL 文件自动发现
RTL_ROOT := $(abspath ../rtl)
RTL_SV   := $(wildcard $(RTL_ROOT)/*.sv)
RTL_V    := $(wildcard $(RTL_ROOT)/*.v)
FILELIST := $(RTL_SV) $(RTL_V)
```

## 关键要点

1. **`$(wildcard ...)` 是 Make 级通配符——在读阶段展开，返回真实文件列表。** 不加则返回字面字符串。
2. **`$(realpath ...)` 需要文件存在；`$(abspath ...)` 纯字符串拼接——根路径用后者。**
3. **`$(file ...)` 替代 `$(shell echo ... > file)`——不 fork 进程，性能更好。**
4. **`$(dir ...)` + `$(sort ...)` → 去重目录列表 → order-only 前置条件——经典模式。**
5. **`$(notdir ...)` + `$(basename ...)` 是文件列表批量处理的基础组合。**

## 与其他概念的关系

- [[tools/concepts/07-Makefile文本变换函数|07 — 文本变换函数]]：`$(addprefix)`/`$(addsuffix)` 与路径函数配合
- [[tools/concepts/15-Makefile高级依赖|15 — 高级依赖]]：order-only 前置条件——目录创建的标准写法
- [[tools/concepts/14-Makefile依赖与自动生成|14 — 依赖与自动生成]]：`.d` 文件路径映射

## 小练习

1. **路径拆解：** `src/lib/util.c` 分别提取 `$(dir)`/`$(notdir)`/`$(basename)`/`$(suffix)`。
2. **wildcard vs 字面量：** 对比 `$(wildcard *.md)` 和直接赋值 `*.md`。
3. **构建目录自动创建：** 生成 `build/obj/` 和 `build/lib/` 的目录规则。
4. **$(file ...) 写文件：** 用 `$(file ...)` 写入包含日期的 `build-info.txt`。

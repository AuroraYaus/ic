---
type: concept
aliases:
  - Makefile 控制函数与诊断函数
  - if or and foreach shell error warning info
tags:
  - tools
  - makefile
  - asic
source_spec: "GNU Make Manual 8.4-8.8: Conditional Functions, foreach, call, eval, shell, error, warning, info"
queries: 1
---

# 09 — Makefile控制函数与诊断函数

## 学习目标

本篇覆盖 Makefile 的流程控制函数和诊断函数——让 Makefile 从"声明式配置"进阶到"编程式表达"。读完本篇后，你将能：

1. 用 `$(if)`/`$(or)`/`$(and)` 做变量级条件选择——区别于 `ifeq` 条件指令
2. 掌握 `$(foreach)`——Makefile 的唯一循环机制
3. 理解 `$(shell ...)` 的正确姿势与性能陷阱
4. 用 `$(error)`/`$(warning)`/`$(info)` 做构建前/中的诊断输出

> **注意：** `$(call)` 和 `$(eval)` 的深入讨论在 [[tools/concepts/11-Makefile宏与元编程|11 — 宏与元编程]]——本篇只介绍基本用法和风险边界。

## 前置知识

- [[tools/concepts/05-Makefile变量赋值与展开|05 — 变量赋值与展开]]：展开时机决定 `$(shell ...)` 的行为
- [[tools/concepts/07-Makefile文本变换函数|07 — 文本变换函数]]：`$(foreach)` 输出常由文本函数处理

## 条件函数：`$(if)` / `$(or)` / `$(and)`

```makefile
# 1. $(if CONDITION,THEN[,ELSE]) — 条件选择（变量级，非规则级）
MODE := debug
MSG  := $(if $(filter debug,$(MODE)),debug build,release build)

# 2. $(or ARG1,ARG2,...) — 返回第一个非空参数（短路求值）
#    典型用途：编译器回退链
CC := $(or $(CROSS_COMPILE)gcc,$(or $(shell which clang 2>/dev/null),gcc))
#      先交叉编译器 → 再 clang → 最后 gcc

# 3. $(and ARG1,ARG2,...) — 全部非空返回最后一个，否则空
CHECK := $(and $(CC),$(CFLAGS))
#        CC 和 CFLAGS 都非空 → 返回 CFLAGS；任一为空 → 空

# ⚠️ $(if) vs ifeq：$(if) 在变量展开时求值，ifeq 在读阶段求值
#   $(if ...) → 可以嵌入配方行中
#   ifeq ...  → 只能控制 Makefile 结构（哪些规则被解析）
```

## 遍历：`$(foreach)` — Makefile 的循环

```makefile
# $(foreach VAR,LIST,TEXT)
# 对 LIST 中每个词，将 VAR 绑定到该词，展开 TEXT，空格拼接所有结果

DIRS := src lib test
MKDIRS := $(foreach d,$(DIRS),mkdir -p $d;)
# 展开：mkdir -p src; mkdir -p lib; mkdir -p test;

# 工程用法：从源文件批量生成带路径的对象文件
SRCS := main.c util.c io/file.c
OBJS := $(foreach s,$(SRCS),build/obj/$(s:.c=.o))
#       → build/obj/main.o build/obj/util.o build/obj/io/file.o
```

## Shell 集成：`$(shell ...)`

```makefile
# $(shell COMMAND) — 执行 Shell 命令，返回标准输出（自动去末尾换行）
GIT_HASH := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
DATE     := $(shell date +%Y-%m-%d)

# ⚠️ 性能关键：用 := 赋值（一次执行），不要用 =（每次引用都执行）
# 错误：FILES  = $(shell find . -name '*.c')  ← 每次 $(FILES) 都重新 find！
# 正确：FILES := $(shell find . -name '*.c')  ← 读阶段执行一次，缓存

# $(shell ...) 的替代品——$(file ...) 写文件不 fork 进程：
$(file > build/version.txt,$(VERSION))     # 比 $(shell echo ... > ...) 快
```

## 诊断函数：`$(info)` / `$(warning)` / `$(error)`

```makefile
# 1. $(info TEXT...) — stdout，继续执行（读阶段输出）
$(info === Building project ===)       # make -n 也会输出！

# 2. $(warning TEXT...) — stderr，继续执行
ifndef CC
$(warning CC is not defined, using gcc)
CC := gcc
endif

# 3. $(error TEXT...) — stderr，**立即终止 make**
ifndef RTL_DIR
$(error RTL_DIR is required. Usage: make RTL_DIR=path/to/rtl)
endif
#                          ^^^^^^ make 在此中止——不执行任何配方

# $(info) vs @echo：
#   $(info ...)  → 读阶段输出，make -n 也输出
#   @echo "..."  → 配方中输出，make -n 不输出
```

## 工程场景

```makefile
# 场景 1：编译器回退链
CC := $(or $(CROSS_COMPILE)gcc,$(or $(shell which clang 2>/dev/null),gcc))

# 场景 2：foreach 批量生成简单规则（eval 的轻度替代——详见 11）
TARGETS := sim syn sta
$(foreach t,$(TARGETS),$(eval $(t): ; @printf 'running $(t)\n'))

# 场景 3：构建前强制参数校验
ifndef DESIGN_TOP
$(error DESIGN_TOP is required. Usage: make DESIGN_TOP=my_top)
endif

# 场景 4：调试开关
ifdef V
$(info [DEBUG] CC=$(CC) CFLAGS=$(CFLAGS))
endif
# make V=1 → 诊断输出；make → 静默

# 场景 5：条件编译选项
CFLAGS += $(if $(filter 1,$(DEBUG)),-g -O0 -DDEBUG,-O2 -DNDEBUG)
```

## `$(eval)` 风险边界（概要）

```makefile
# $(eval TEXT) — 将 TEXT 作为 Makefile 语法求值——元编程
# 能力：在运行时动态生成规则、变量、条件
# 风险：$$ 双重展开、难以调试、容易制造不可维护的 Makefile

# 最小安全用法——配合 foreach 生成规则（详见 11 篇）
DIRS := src lib test
$(foreach d,$(DIRS),$(eval $(d)_SRCS := $$(wildcard $(d)/*.c)))
# 为每个目录定义一个 src_/lib_/test_SRCS 变量
```

## 关键要点

1. **`$(if ...)` 返回字符串——不执行配方。`ifeq` 控制规则结构——在读阶段求值。**
2. **`$(or ...)` 短路求值——最常用于工具链回退（交叉→本地→默认）。**
3. **`$(foreach ...)` 是 Makefile 的唯一循环——生成拼接文本（不是执行配方）。**
4. **`$(shell ...)` 必须 `:=` 赋值——`=` 导致每次引用重新 fork。**
5. **`$(info)` 读阶段输出（`make -n` 也输出），`@echo` 配方阶段输出（`make -n` 不输出）。**
6. **`$(error ...)` 是最强的前置条件校验——比配方中的 `exit 1` 更早失败。**
7. **`$(eval ...)` 是最后手段——能用 `$(foreach)`+`$(call)` 解决就不上 `$(eval)`。**
8. **GNU Make ≥4.4 的 `$(let ...)` 和 `$(intcmp ...)` 是版本特性——仅在明确标注时使用。**

## 与其他概念的关系

- [[tools/concepts/07-Makefile文本变换函数|07 — 文本变换函数]]：`$(foreach)` 的输出常由文本函数后续处理
- [[tools/concepts/10-Makefile条件判断|10 — 条件判断]]：`$(if)` vs `ifeq`——函数 vs 指令、展开时 vs 读阶段
- [[tools/concepts/11-Makefile宏与元编程|11 — 宏与元编程]]：`$(call)` 和 `$(eval)` 的完整讨论
- [[tools/concepts/19-Makefile调试与性能|19 — 调试与性能]]：诊断输出的系统化方法和 V=1 模式

## 小练习

1. **回退链：** 用 `$(or ...)` 实现"有 CLANG 用 clang，否则用 gcc"。
2. **foreach 路径迁移：** 用 `$(foreach ...)` 从 `src/*.c` 生成 `build/obj/*.o` 列表。
3. **$(info) vs @echo：** 分别用两种方式输出诊断信息，运行 `make -n` 对比差异。
4. **前置校验：** 用 `$(error ...)` 在构建前确保 `CONFIG` 变量已定义。

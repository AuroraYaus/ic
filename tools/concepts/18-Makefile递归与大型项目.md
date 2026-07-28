---
type: concept
aliases: [Makefile 递归与大型项目, Recursive make include-style]
tags: [tools, makefile, asic]
source_spec: "GNU Make Manual 5.7; Miller 'Recursive Make Considered Harmful'"
queries: 1
---

# 18 — Makefile递归与大型项目

## 学习目标

大型项目的 Makefile 有两种架构：递归式（每个子目录独立 make）和 include 式（所有规则在同一进程）。本篇覆盖两种架构的完整实现和选择策略。

## 前置知识

- [[tools/concepts/17-Makefile内置变量与命令行|Makefile内置变量与命令行]]：`$(MAKE)`、`$(MAKEFLAGS)`、`$(MAKELEVEL)`

## 递归式 Make

```makefile
# ===== 顶层 Makefile =====
export CC := gcc                       # export 传递到子 Make
export CFLAGS := -Wall -O2
export BUILD_DIR := $(CURDIR)/build

SUBDIRS := lib src test                # 顺序：先 lib → src → test

.PHONY: all clean $(SUBDIRS)
all: $(SUBDIRS)
$(SUBDIRS): ; $(MAKE) -C $@            # -C 切换目录；$(MAKE) 传递标志
clean:
	for d in $(SUBDIRS); do $(MAKE) -C $$d clean; done
	rm -rf $(BUILD_DIR)

# ===== lib/Makefile =====
SRCS := $(wildcard *.c); OBJS := $(SRCS:.c=.o)
LIB  := $(BUILD_DIR)/lib/libutils.a
$(LIB): $(OBJS); @mkdir -p $(@D); $(AR) rcs $@ $^
%.o: %.c; $(CC) $(CFLAGS) -c $< -o $@

# ===== src/Makefile =====
SRCS := $(wildcard *.c); OBJS := $(SRCS:.c=.o)
PROG := $(BUILD_DIR)/program
$(PROG): $(OBJS) $(BUILD_DIR)/lib/libutils.a
	$(CC) $^ -o $@
%.o: %.c; $(CC) $(CFLAGS) -c $< -o $@
```

## Include 式 Make

```makefile
# ===== 顶层 Makefile =====
BUILD_DIR := $(CURDIR)/build
include lib/module.mk                  # 所有 .mk 在同一进程——全局命名空间
include src/module.mk

# ===== lib/module.mk =====
lib_SRCS := $(wildcard lib/*.c)        # 前缀防冲突：lib_  src_  test_
lib_OBJS := $(patsubst lib/%.c,$(BUILD_DIR)/lib/%.o,$(lib_SRCS))
lib_LIB  := $(BUILD_DIR)/lib/libutils.a
$(lib_LIB): $(lib_OBJS); $(AR) rcs $@ $^

# ===== src/module.mk =====
src_SRCS := $(wildcard src/*.c)
src_OBJS := $(patsubst src/%.c,$(BUILD_DIR)/src/%.o,$(src_SRCS))
$(BUILD_DIR)/program: $(src_OBJS) $(lib_LIB)  # 跨目录依赖直接声明！
	$(CC) $^ -o $@
```

## 两种架构对比

| 维度 | 递归式 | Include 式 |
|:---|:---|:---|
| 命名空间 | 隔离——无冲突 | 全局——需前缀约定 |
| 跨目录依赖 | 间接（lib 构建→src 重链） | 直接声明 |
| 增量粒度 | 目录级 | 文件级 |
| 并行度 | 进程级（粗） | 目标级（细） |
| 团队扩展 | 好——子目录独立 | 需全局命名协调 |
| IC 适用 | IP 库独立维护 | 顶层流程编排 |

## 选择策略

| 条件 | 推荐 |
|:---|:---|
| <10 子目录 + 跨目录依赖多 | Include |
| >20 子目录 + 子目录独立 | 递归 |
| IC IP 库独立维护 | 递归——每 IP 自己 Makefile |
| IC 统一顶层流程 | Include + `config.mk` |

## IC 混合架构

```makefile
# 顶层 include + IP 层递归——兼顾全局依赖和模块隔离
export DESIGN_TOP ?= top
include ips/*/module.mk                # 各 IP 声明 RTL 文件
include flows/sim.mk flows/syn.mk      # 流程入口

.PHONY: sim syn all
sim: log/smoke.log
all: sim syn
```

## 关键要点

1. **`$(MAKE) -C` + `export` = 递归 Make 标准模式。**
2. **递归式 = 隔离+简单；include 式 = 全局依赖图+精确增量。**
3. **混合架构最常见：顶层 include 全局 + IP 层递归隔离。**
4. **out-of-source build：所有产物在 `$(BUILD_DIR)`——源目录清洁。**

## 与其他概念的关系

- [[tools/concepts/17-Makefile内置变量与命令行|Makefile内置变量与命令行]]
- [[tools/concepts/23-MakefileIC项目构建实战|MakefileIC项目构建实战]]

## 小练习

1. 建 lib/ src/ 子目录，分别写递归 Makefile
2. 改为 include 式对比
3. 改 lib 的一个 .c——递归式 vs include 式重建范围对比

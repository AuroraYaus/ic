---
type: concept
aliases:
  - Makefile 条件判断
  - ifeq ifneq ifdef ifndef else endif
tags:
  - tools
  - makefile
  - asic
source_spec: "GNU Make Manual 7: Conditional Parts of Makefiles"
queries: 1
---

# 10 — Makefile条件判断

## 学习目标

本篇覆盖 Makefile 的条件判断体系。读完本篇后，你将能根据变量值、平台类型、构建模式做出差异化的规则和变量定义，并区分 Make 条件（读阶段求值）与 Shell `if`（配方中求值）的根本差异。

## 前置知识

- [[tools/concepts/05-Makefile变量赋值与展开|Makefile变量赋值与展开]]：条件在读阶段求值——`=` 变量的延迟展开影响条件结果
- [[tools/concepts/09-Makefile控制函数与诊断函数|Makefile控制函数与诊断函数]]：`$(if ...)` 函数级条件 vs 本篇 `ifeq` 指令级条件

## 语法全解

```makefile
# 1/2. ifeq/ifneq — 比较两个字符串
ifeq ($(DEBUG),1)                      # DEBUG 等于 "1" ?
CFLAGS := -g -O0 -DDEBUG
else
CFLAGS := -O2 -DNDEBUG
endif

# 参数可以用括号、引号或花括号——完全等价：
# ifeq ($(CC),gcc)     ← 推荐：清晰
# ifeq '$(CC)' 'gcc'    ← 等价
# ifeq {$(CC)} {gcc}    ← 等价

# 3/4. ifdef/ifndef — 检查变量是否已定义
ifdef V                                # 用户定义了 V？（不管值是什么）
Q :=                                   # V 存在 → 不回显命令
else
Q := @                                 # V 不存在 → @ 前缀抑制回显
endif
# ⚠️ 陷阱：ifdef 检查"已定义"——不是"非空"！
# FOO  =            ← 已定义（值为空）——ifdef FOO 为真
# 检查空值用：ifeq ($(FOO),)
```

## 工程场景

```makefile
# 场景 1：平台检测
PLATFORM != uname -s
ifeq ($(PLATFORM),Linux)
  LDFLAGS += -ldl -lpthread -lrt
else ifeq ($(PLATFORM),Darwin)
  LDFLAGS += -framework CoreFoundation
endif

# 场景 2：调试/发布双模式
DEBUG ?= 0
ifeq ($(DEBUG),1)
CFLAGS := -g -O0 -DDEBUG -fsanitize=address
else
CFLAGS := -O2 -DNDEBUG
endif

# 场景 3：可选特性开关
ifdef ENABLE_OPENMP
CFLAGS  += -fopenmp
LDFLAGS += -fopenmp
endif

# 场景 4：IC — EDA 工具选择
SIMULATOR ?= questa
ifeq ($(SIMULATOR),vcs)
  SIM_CMD := vcs -sverilog -full64
else ifeq ($(SIMULATOR),xcelium)
  SIM_CMD := xrun -sv
else
  SIM_CMD := vsim -c
endif

# 场景 5：必需变量校验
ifndef DESIGN_TOP
$(error DESIGN_TOP is required. Example: make DESIGN_TOP=my_module)
endif
```

## Make 条件 vs Shell if —— 不可互换

```makefile
# Make 条件（读阶段）——控制 Makefile 结构
ifeq ($(DEBUG),1)
CFLAGS := -g                          # DEBUG≠1 时这整个定义不存在
endif

# Shell if（配方阶段）——控制配方执行流
build:
	if [ -f config.h ]; then \
		gcc -DHAS_CONFIG -c main.c; \
	else \
		gcc -c main.c; \
	fi

# 错误：把 Make 条件放进配方
# build:
# 	ifeq ...                          ← 读阶段就处理——不属于配方！
#      条件指令不能缩进！ifeq/else/endif 必须从行首开始
```

## 常见错误

| 错误 | 根因 | 修复 |
|:---|:---|:---|
| `ifeq` 缩进导致解析失败 | 条件指令从行首开始——不能缩进 | 顶格写 `ifeq`/`else`/`endif` |
| `ifdef FOO` 为真但 FOO 为空 | `ifdef` 检查"已定义"，不是"非空" | 空值检查用 `ifeq ($(FOO),)` |
| 条件依赖配方产物 | `$(wildcard ...)` 在读阶段展开——配方还没跑 | 放 Shell `if` 中 |

## 关键要点

1. **条件判断在读阶段求值——不能基于配方执行结果。**
2. **`ifeq`/`endif` 必须顶格写——不能缩进。**
3. **`ifdef` 检查"已定义"而非"非空"。空值用 `ifeq ($(VAR),)`。**
4. **Make 条件控制 Makefile 结构；Shell `if` 控制配方流。不可互换。**
5. **条件中可用 `$(shell ...)`/`$(wildcard ...)`——它们在读阶段就执行。**

## 与其他概念的关系

- [[tools/concepts/09-Makefile控制函数与诊断函数|Makefile控制函数与诊断函数]]：`$(if)` vs `ifeq`
- [[tools/concepts/05-Makefile变量赋值与展开|Makefile变量赋值与展开]]：延迟展开影响条件结果
- [[tools/concepts/19-Makefile调试与性能|Makefile调试与性能]]：`--warn-undefined-variables`

## 小练习

1. 用 `ifeq` 实现 `DEBUG=1` 和默认模式编译选项切换。
2. 用 `uname -s` + `ifeq` 区分 Linux/macOS 设置 `LDFLAGS`。
3. 测试 `make FOO=` 时 `ifdef FOO` vs `ifeq ($(FOO),)` 的差异。
4. 用 `ifndef` + `$(error)` 校验必需变量。

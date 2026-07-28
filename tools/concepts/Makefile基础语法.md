---
type: concept
aliases:
  - Makefile Basic Syntax
  - make 基础语法
tags:
  - tools
  - makefile
  - build-system
  - gnu-make
source_spec: "GNU Make Manual, Chapters 1-6: An Introduction to Makefiles, Writing Rules, Writing Recipes, How to Use Variables, Using Wildcard Characters, Using Automatic Variables"
queries: 1
---

# Makefile 基础语法

Makefile 是 GNU Make 工具的配置文件，定义了软件项目中源文件到目标文件的**构建规则（Build Rules）**和**依赖关系（Dependencies）**。它通过比较目标文件和源文件的最后修改时间（Timestamp），判断哪些文件需要重新构建，从而实现**增量编译（Incremental Build）**——只重新编译被修改过的部分，大幅节省大型项目的构建时间。Make 最初由 Stuart Feldman 于 1976 年在贝尔实验室开发，GNU Make 是当今 Unix/Linux 系统上的标准实现。

Makefile 的核心思想极其简单：一个 Makefile 就是一组**规则（Rule）**的集合，每条规则描述三件事——(1) 目标是什么 (2) 目标的依赖是谁 (3) 如何从依赖生成目标。Make 在执行时将这组规则展开为一棵**有向无环图（Directed Acyclic Graph, DAG）**，然后从用户指定的最终目标出发，自顶向下检查每个节点的依赖是否比目标新，决定该节点是否需要重新构建。

## 原理

### 规则的三要素

一条 Makefile 规则由三部分组成：**目标（Target）**、**前置条件（Prerequisites）**和**配方（Recipe）**。

```makefile
# ===== Makefile 规则的基本结构 =====
# target: prerequisites
# <TAB>recipe
#   ^^^^
#   必须是制表符（TAB），不能用空格！这是 Makefile 最常见的语法陷阱

# --- 示例：从 C 源文件编译目标文件 ---
# hello.o: 目标文件——make 要生成的产品
# hello.c: 前置条件——生成目标所需的输入文件
hello.o: hello.c
	gcc -c hello.c -o hello.o
#   ^^^
#   配方行必须以 TAB 开头（不是 8 个空格！）
```

**Make 的执行流程（两步展开法）：**

1. **读取阶段（Read Phase）**：Make 读取所有 Makefile 文件，解析规则、变量定义和指令，建立内部的依赖图（DAG）。这一步**不执行任何配方**。
2. **目标更新阶段（Target Update Phase）**：Make 从命令行指定的目标（或默认的第一个目标）开始，递归地检查每个节点的前置条件：
   - 如果前置条件本身也是某条规则的目标 → 先递归更新前置条件
   - 如果前置条件比目标文件新（或目标文件不存在）→ 执行配方重建目标
   - 如果目标比所有前置条件都新 → 跳过（无需重建）

这个"时间戳比对"是 Make 增量构建的根本原理——只重建真正过期的文件。

### 变量系统

Makefile 有四种变量赋值方式，区别在于**展开时机（Expansion Timing）**。

```makefile
# ===== Makefile 四种变量赋值方式对比 =====

# 1. VAR = value — 递归展开（Recursively Expanded）
#    变量在被使用时才展开，每次引用都重新求值
#    陷阱：可能导致无限循环（FOO = $(BAR); BAR = $(FOO)）
CC  = gcc                  # 编译器变量——后面还可以引用其他变量
CFLAGS = -Wall -O2        # 编译选项——可以使用未定义的变量（使用时展开）
LDFLAGS = $(CFLAGS)       # 链接选项——展开时 CFLAGS 已有了最终值

# 2. VAR := value — 简单展开（Simply Expanded）
#    赋值瞬间展开所有引用，之后不再变化
#    安全：不会循环引用，行为可预测
VERSION := $(shell git describe --tags 2>/dev/null || echo "unknown")
#          ^^^^^^
#          立即执行 shell 命令获取版本号，不会每次引用都重新执行

# 3. VAR ?= value — 条件赋值（Conditional）
#    仅当 VAR 尚未定义时才赋值
#    典型用途：允许用户在命令行覆盖默认值
CC      ?= gcc             # 如果 CC 未在命令行指定，默认用 gcc
PREFIX  ?= /usr/local      # 安装路径——用户可以通过 make PREFIX=/opt 覆盖

# 4. VAR += value — 追加赋值（Append）
#    向已有变量追加内容（自动添加一个空格分隔符）
CFLAGS += -g               # 在已有编译选项后追加调试选项
CFLAGS += -DDEBUG          # 继续追加宏定义——等价于 CFLAGS = -Wall -O2 -g -DDEBUG
```

**展开时机的工程意义：**

| 赋值符 | 展开时机 | 适用场景 |
|:---|:---|:---|
| `=` | 引用时（延迟求值） | 需要引用尚未定义的变量，或希望反映运行时最终值 |
| `:=` | 赋值瞬间 | 固定值、一次性的 `$(shell ...)` 调用、避免重复计算 |
| `?=` | 未定义时才赋值 | 默认值——允许命令行/环境变量覆盖 |
| `+=` | 取决于原变量的类型 | 追加编译选项、源文件列表 |

### 自动变量

自动变量（Automatic Variables）是 Makefile 中最常用的语法糖——在配方中，Make 根据当前规则的目标和前置条件自动填充它们的值。

```makefile
# ===== 自动变量：配方中无需重复写文件名 =====
# $@ — 当前规则的目标文件名（"at" 的助记：target → @）
# $< — 第一个前置条件的文件名（"<" 的助记：less → first → 第一个）
# $^ — 所有前置条件的列表（去重，空格分隔）
# $? — 所有比目标新的前置条件列表
# $* — 模式规则中匹配的茎（stem）——即 % 匹配的部分

# --- 示例：编译 C 文件 ---
hello: hello.o utils.o     # 目标 hello 依赖两个 .o 文件
	gcc $^ -o $@
#        ^^    ^^
#         $^ = hello.o utils.o（所有依赖）
#              $@ = hello（目标名）

# --- 等效于手写 ---
# gcc hello.o utils.o -o hello

# --- 从 .c 编译 .o ---
%.o: %.c                   # 模式规则：%.o 依赖于同名的 %.c
	gcc -c $< -o $@
#           ^^    ^^
#            $< = %.c（第一个也是唯一的依赖）
#                 $@ = %.o（目标）
```

### .PHONY 虚假目标

`.PHONY` 是 Makefile 中最容易被忽视但实际最重要的特殊目标（Special Target）之一——它声明某些目标名字**不代表文件**，Make 永远执行其配方。

```makefile
# ===== .PHONY 虚假目标声明 =====
# 问题：如果当前目录下碰巧有一个名为 "clean" 的文件，
#       没有 .PHONY 声明时，make clean 会认为 "clean 文件已存在且是最新的"，
#       直接跳过——clean 目标永远不会被执行！
# 解决：.PHONY 告诉 Make "这些名字不是文件，每次请求都执行配方"

.PHONY: all clean install  # 声明 all/clean/install 为虚假目标

all: program               # all 是默认目标（Makefile 的第一个目标）

program: main.o lib.o
	gcc $^ -o $@

clean:
	rm -f *.o program      # 删除所有生成文件——无论是否有同名文件都执行

install:
	cp program /usr/local/bin/
```

**常见 .PHONY 目标清单：**

| 目标 | 用途 |
|:---|:---|
| `all` | 默认构建目标——构建项目中的所有可执行文件 |
| `clean` | 清理所有构建产物（`.o`、`.a`、可执行文件等） |
| `install` | 将构建产物安装到系统目录 |
| `dist` | 创建源代码发布包（tarball 等） |
| `test` | 运行测试套件 |
| `check` | 运行构建后检查（如内存泄漏检测） |

### 通配符

Makefile 支持两种通配符机制：

```makefile
# ===== 1. 配方中的 Shell 通配符（由 Shell 展开）=====
#    配方行传给 /bin/sh 执行，Shell 认识 *, ?, [] 等通配符
clean:
	rm -f *.o *.d          # Shell 展开 *.o → 所有 .o 文件列表

# ===== 2. Makefile 上下文中的 wildcard 函数 =====
#    变量定义和前置条件列表中，Make 不会自动展开通配符——需要 wildcard 函数
SRCS := $(wildcard *.c)    # 简单展开：将当前目录所有 .c 文件名赋给 SRCS
OBJS := $(patsubst %.c, %.o, $(SRCS))  # 模式替换：.c → .o
#               ^^^————^^^
#               patsubst: pattern substitute，见"条件与函数"篇

# ⚠️ 常见错误——这样写不会展开！
# SRCS = *.c               # 错误：SRCS 的值是字面量 "*.c"，不是文件列表！
```

## 关键要点

1. **配方行必须是 TAB，不是空格**——这是 Makefile 历史最悠久的设计缺陷，IDE 的"TAB 转空格"功能是 Makefile 的头号杀手
2. **`=` 和 `:=` 的本质区别是展开时机**——`=` 延迟展开（类似"指针"），`:=` 立即展开（类似"值拷贝"）；大部分场景用 `:=` 更安全
3. **`?=` 是设置默认值的最规范方式**——不要用 `ifeq($(origin VAR),undefined)` 替代，`?=` 更简洁
4. **自动变量只存在于配方中**——`$@`、`$<`、`$^` 不能用于变量定义或条件判断
5. **每个配方的第一行必须以 TAB 开头**——包括 `if`/`for`/`while` Shell 语句中的嵌套行（每行一个配方行，每行一个 TAB）
6. **永远把 `all` 作为第一个目标**——Make 的默认目标是 Makefile 中的第一个目标，将 `all` 放在第一行确保 `make` 不带参数时构建整个项目
7. **`.PHONY` 是防止"文件名与目标名冲突"的唯一手段**——你应该把所有不生成同名文件的目标都声明为 .PHONY

## 与其他概念的关系

- [[tools/concepts/Makefile条件与函数|Makefile 条件与函数]]——本文介绍了变量系统，下一篇深入条件判断和文本变换函数
- [[tools/concepts/Makefile模式与依赖|Makefile 模式与依赖]]——本文提及了模式规则的基本用法，下一篇完整展开模式规则和自动依赖生成
- [[concepts/数制|数制（Number Systems）]]——Makefile 中不涉及数制，但了解基础知识有助于理解编译链接过程

---
type: concept
aliases:
  - Makefile Pattern Rules and Dependencies
  - make 模式与依赖
tags:
  - tools
  - makefile
  - build-system
  - gnu-make
source_spec: "GNU Make Manual, Chapters 4, 10: Using Implicit Rules, Using Pattern Rules; Chapter 4.14: Generating Prerequisites Automatically"
queries: 1
---

# Makefile 模式与依赖

模式规则（Pattern Rules）和自动依赖生成（Automatic Dependency Generation）是 Makefile 从"手动编写每条规则"到"自动化构建系统"的里程碑。模式规则让你用一条规则描述"所有 .c 到 .o 的编译方式"而非为每个源文件写一条规则；自动依赖让 Make 自动发现 `.c` 文件 `#include` 了哪些 `.h` 文件——当某个头文件被修改时，所有间接依赖它的源文件都会自动重新编译。

这两项能力的组合解决了手工维护 Makefile 最大的两个痛点：(1) 源文件数量的增长导致规则数量线性膨胀 (2) 头文件依赖关系的人工维护极易遗漏（"改了 .h 但忘了重编"是增量构建中最隐蔽的 bug）。

## 原理

### 模式规则

模式规则（Pattern Rule）用 `%` 通配符描述目标和前置条件的命名关系，一条规则覆盖无限个文件名匹配。

```makefile
# ===== 模式规则：一条规则编译任意 .c → .o =====
# %.o: %.c  的含义：
#   目标模式 %.o 匹配任何以 .o 结尾的文件名
#   前置模式 %.c 中的 % 与目标模式中的 % 匹配相同的字符串
#   $< = 第一个前置条件（匹配的 .c 文件）
#   $@ = 目标文件（匹配的 .o 文件）
#   $* = 茎（stem）——% 匹配的部分（如 main.o 的茎是 main）

%.o: %.c                    # 模式规则：任意 .o 依赖于同名的 .c
	$(CC) $(CFLAGS) -c $< -o $@
#                       ^^    ^^
#                        $< = 对应的 .c 文件
#                             $@ = 对应的 .o 文件

# --- 完整示例：模式规则驱动的 Makefile ---
CC      := gcc
CFLAGS  := -Wall -O2
TARGET  := program
OBJS    := main.o utils.o io.o  # 列出所有 .o 文件

$(TARGET): $(OBJS)             # 链接规则
	$(CC) $^ -o $@             # $^ = main.o utils.o io.o

%.o: %.c                       # 一条规则编译所有 .c → .o
	$(CC) $(CFLAGS) -c $< -o $@

.PHONY: clean
clean:
	rm -f $(TARGET) $(OBJS)
```

**静态模式规则（Static Pattern Rules）：**

静态模式规则将模式匹配的范围限制在**明确列出的目标列表**中——既有模式规则的简洁语法，又有显式规则的安全性。

```makefile
# ===== 静态模式规则：$(TARGETS) : %.pattern : %.prereq =====
# $(TARGETS)  — 目标列表（显式枚举，而非所有匹配文件）
# %.o         — 目标模式
# %.c         — 前置模式

OBJS := main.o utils.o io.o  # 只有这三个文件

# 静态模式规则：仅对 OBJS 列表中的三个 .o 文件应用此规则
$(OBJS): %.o: %.c             # 语法：目标列表 : 目标模式 : 前置模式
	$(CC) $(CFLAGS) -c $< -o $@

# ⚠️ 与普通模式规则的区别：
#   %.o: %.c  → 对任何 .o 文件生效（包括将来被依赖的其他 .o）
#   $(OBJS): %.o: %.c → 仅对 $(OBJS) 中的文件生效
```

**VPATH — 多源文件目录：**

```makefile
# ===== VPATH：跨目录搜索源文件 =====
VPATH := src:lib:include  # 目录列表（冒号分隔，空格也行）
#  Make 搜索顺序：当前目录 → src/ → lib/ → include/

# src/main.c  + lib/utils.c → OBJS = main.o utils.o
SRCS := $(wildcard src/*.c) $(wildcard lib/*.c)
OBJS := $(notdir $(SRCS:.c=.o))  # main.o utils.o（不包含目录前缀）

program: $(OBJS)
	$(CC) $^ -o $@

%.o: %.c                    # 仅需一条规则
	$(CC) $(CFLAGS) -c $< -o $@
# Make 在构建 main.o 时的搜索过程：
#   1. 模式规则 %.o → 前置条件 %.c → 搜索 main.c
#   2. 当前目录：没有 main.c
#   3. VPATH src/: 找到了！→ $< = src/main.c
```

### 自动依赖生成

头文件依赖是 C/C++ 项目中最容易出错的环节——修改了 `config.h`，但 `main.c` 没有重新编译，因为 Makefile 中只有 `main.o: main.c` 而没有 `main.o: config.h`。

**解决方案：编译器自动生成依赖 + `include` 指令。**

```makefile
# ===== 三步法自动依赖系统 =====

# 步骤 1：编译器生成依赖文件（.d）
#   gcc -MM main.c: 输出 main.o 的完整头文件依赖链
#   -MM: 只输出用户头文件（不包含系统头文件如 <stdio.h>）
#   -MF main.d: 将输出写入 main.d 而非 stdout
#   -MT main.o: 自定义目标名

# 步骤 2：用 include 将所有 .d 文件嵌入 Makefile

# 步骤 3：为 .d 文件写一条生成规则

# ===== 完整实现 =====
SRCS  := $(wildcard *.c)          # main.c utils.c
OBJS  := $(SRCS:.c=.o)            # main.o utils.o
DEPS  := $(SRCS:.c=.d)            # main.d utils.d

program: $(OBJS)
	$(CC) $^ -o $@

# -include: 前缀 - 表示文件不存在时不报错
-include $(DEPS)

# 模式规则：编译 .c → .o （同时生成 .d 依赖文件）
%.o: %.c
	$(CC) -MM -MF $(@:.o=.d) -MT $@ $(CFLAGS) -c $< -o $@
#        ^^^^^^^^^^^^^^^^^^^
#        -MM:  仅输出用户头文件依赖
#        -MF:  指定输出文件名（$(@:.o=.d) = 将 $@ 中的 .o 替换为 .d）
#        -MT $@: 指定依赖行的目标名

# --- gcc 依赖生成相关的标志总结 ---
# -M:   输出所有 #include 的依赖（含系统头文件）
# -MM:  仅输出用户头文件依赖（忽略系统头文件）→ 推荐用于 Makefile
# -MF:  输出到指定文件（而非 stdout）
# -MT:  指定输出的目标名（而非默认的隐含目标名）

.PHONY: clean
clean:
	rm -f program $(OBJS) $(DEPS)
```

**首次构建时的依赖解析流程：**

1. `make` 读取 Makefile
2. 遇到 `-include $(DEPS)` → 尝试读入 `main.d`、`utils.d`
3. 文件不存在，但不报错（`-include` 的 `-` 前缀）
4. Make 检查是否有规则可以生成这些 `.d` 文件
5. 发现 `%.o: %.c` 规则，执行 → 编译 `.c` 的同时生成 `.d`
6. **下一次** `make` 时，`-include $(DEPS)` 成功读入所有 `.d` 文件
7. 此后修改任何头文件 → 依赖链自动触发所有相关 `.o` 的重新编译

### 并行构建

`-j` 选项启用并行构建——Make 在依赖图允许的范围内同时执行多个配方。

```makefile
# make -j4:  最多同时运行 4 个配方
# make -j:   不限制并发数
# make -j$(nproc):  自动检测 CPU 核数（Linux）

# Makefile 本身不需要特殊写法——Make 根据依赖 DAG 自动判断哪些目标可以并行
# 前提：你的 Makefile 的依赖声明必须正确！

# ⚠️ 并行构建的常见陷阱：
#   如果两个目标语法上无共享依赖，Make 认为可以并行执行两者
#   但若两者的配方有副作用竞争（如写入同一个临时文件），就会出 bug
#   解决：声明隐式依赖（order-only prerequisite 用 | 分隔）或 .NOTPARALLEL
```

## 关键要点

1. **模式规则 `%.o: %.c` 是 Makefile 的核心抽象**——一条规则覆盖所有同类文件的编译，是 DRY 原则在 Makefile 中的最佳实践
2. **`-include` 是自动依赖的标准入口**——`-` 前缀允许 `.d` 首次缺失时不报错，是增量依赖系统的基石
3. **自动依赖三步法不可拆分**——`-MM` 生成 + `.d` 文件 + `-include` 三者必须同时到位
4. **`VPATH` 解决源文件分散问题**——不必在模式规则中写死路径
5. **静态模式规则比普通模式规则更安全**——显式限定了目标列表，避免误匹配
6. **`-j` 的正确性完全依赖依赖声明的准确度**——依赖图遗漏 = 并行竞态 bug

## 与其他概念的关系

- [[tools/concepts/Makefile条件与函数|Makefile 条件与函数]]——`$(SRCS:.c=.d)` 模式替换是自动依赖系统的基础语法
- [[tools/concepts/Makefile实战项目|Makefile 实战项目]]——模式规则 + VPATH + 自动依赖是实战 Makefile 的三大支柱
- [[tools/concepts/Makefile仿真回归|Makefile 仿真回归（IC 实战）]]——`-j` 并行在仿真回归中是核心性能优化手段

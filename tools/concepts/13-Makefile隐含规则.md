---
type: concept
aliases: [Makefile 隐含规则, Implicit rules make -p suffix rules]
tags: [tools, makefile, asic]
source_spec: "GNU Make Manual 10: Using Implicit Rules"
queries: 1
---

# 13 — Makefile隐含规则

## 学习目标

GNU Make 自带一套庞大的**隐含规则数据库（Implicit Rule Database）**——即使你的 Makefile 只有 `program: main.o`（没有 `%.o: %.c`），Make 也知道如何从 `.c` 编译 `.o`。这既是便利也是陷阱。读完本篇，你将能：

1. 用 `make -p` 查看完整的隐含规则数据库
2. 理解隐含规则链——一个 `.c` 如何经过多步变成可执行文件
3. 用 `make -r` 禁用隐含规则——大型项目的标准做法
4. 识别旧式后缀规则（`.c.o:`）并转换为现代写法

## 前置知识

- [[tools/concepts/12-Makefile模式规则|12 — 模式规则]]：隐含规则是 Make 预定义的模式规则
- [[tools/concepts/06-Makefile高级变量|06 — 高级变量]]：`$(origin CC)` → `default`

## 查看隐含规则数据库

```shell
make -p | head -100                   # 打印 Make 全部内置规则（数千行）
make -p | grep -A3 '^%.o.*:.*%.c'     # 只看 .c → .o 的隐含规则
```

```text
# 典型输出（简化）：
%.o: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -c      # Make 内置的 .c → .o 规则
%: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) $^ $(LDLIBS) -o $@  # .c → 可执行
```

**关键发现：** 即使你的 Makefile 只有 `program: main.o`，Make 也能通过内置规则编译——但这是双刃剑。

## 隐含变量

```makefile
# 隐含规则使用的变量及其默认值
CC       = cc                           # 默认 C 编译器（不是 gcc！）
CXX      = g++                          # C++ 编译器
CFLAGS   = （空）                        # 编译选项——无默认值
LDFLAGS  = （空）                        # 链接选项
LDLIBS   = （空）                        # 链接库

# 最简单的覆盖方式——在你的 Makefile 中定义：
CC      := gcc
CFLAGS  := -Wall -Wextra -O2
LDFLAGS := -lm                          # 链接数学库
```

## 隐含规则链

```makefile
# Make 可以将多个隐含规则串联
# 只需这一行 Makefile：
CC := gcc
program: main.o util.o                  # 只声明依赖——没有 %.o: %.c

# make 通过隐含规则链完成：
# 步骤 1：program 需要 main.o → %.o: %.c → gcc -c main.c → main.o
# 步骤 2：需要 util.o → %.o: %.c → gcc -c util.c → util.o
# 步骤 3：program → %: %.o → gcc main.o util.o -o program

# ⚠️ 中间文件 .o 会被自动删除——Make 认为它们是"中间产物"
# 保留中间文件：.SECONDARY: 或显式将它们列为目标
```

## 后缀规则（历史遗产）

```makefile
# 后缀规则：模式规则的前身——老 Makefile 中常见
.c.o:                                  # 等价于 %.o: %.c（旧式写法）
	$(CC) $(CFLAGS) -c $< -o $@

.SUFFIXES: .c .o .s                    # 声明已知后缀
.SUFFIXES:                              # 清空 = 禁用所有后缀规则

# ⚠️ 新代码不要写 .c.o: —— 一律用 %.o: %.c
```

## 控制隐含规则

```makefile
# 1. 禁用所有内置隐含规则——大型项目标准做法
MAKEFLAGS += -r                        # 或用 make -r

# 2. 只禁用隐含变量（保留规则）
MAKEFLAGS += -R                        # 不预定义 CC/CFLAGS 等

# 3. 覆盖特定规则——用同名模式规则替代
%.o: %.c                                # 会覆盖 Make 内置的 %.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# 4. 删除特定隐含规则——声明无配方的同名规则
%.o: %.s                                # 取消内置的 .s → .o 规则

# 推荐组合：
MAKEFLAGS += -r --warn-undefined-variables
%.o: %.c; $(CC) $(CFLAGS) -c $< -o $@  # 显式：清晰、可预测
%: %.o; $(CC) $(LDFLAGS) $^ $(LDLIBS) -o $@
```

## 关键要点

1. **GNU Make 自带庞大的隐含规则数据库——`make -p` 查看。**
2. **隐含变量 `CC`=`cc`（不是 `gcc`）——覆盖它们来定制。**
3. **隐含规则链让极简 Makefile 也能工作——但行为不够透明。**
4. **大型项目建议 `make -r` 禁用隐含——可预测性 > 便利性。**
5. **`.c.o:` 是历史遗留——新代码一律用 `%.o: %.c`。**
6. **中间文件默认被删除——`.SECONDARY:` 可保留它们。**

## 与其他概念的关系

- [[tools/concepts/12-Makefile模式规则|12 — 模式规则]]
- [[tools/concepts/06-Makefile高级变量|06 — 高级变量]]
- [[tools/concepts/19-Makefile调试与性能|19 — 调试与性能]]

## 小练习

1. **空 Makefile 实验：** 创建 `main.c`，写只含 `program:` 的 Makefile。`make program` 能成功吗？为什么？
2. **查看隐含规则：** `make -p | grep '^%.o'`——列出所有生成 .o 的规则。
3. **禁用隐含：** `make -r` 后同样的 Makefile 为什么失败？
4. **覆盖隐含变量：** `CC := gcc` + `CFLAGS := -Wall`。

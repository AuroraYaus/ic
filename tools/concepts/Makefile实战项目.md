---
type: concept
aliases:
  - Makefile Real Project
  - make 实战项目
tags:
  - tools
  - makefile
  - build-system
  - gnu-make
source_spec: "GNU Make Manual, Chapter 5.7: Recursive Use of Make; Chapter 16: Makefile Conventions"
queries: 1
---

# Makefile 实战项目

本文用一个完整的 C 项目将前三篇的理论知识串成一个完整的构建系统。项目结构模拟真实场景：多级目录、静态库、可执行文件、单元测试、自动依赖。

## 项目结构

```
project/
├── Makefile              # 顶层 Makefile（递归入口）
├── src/
│   ├── Makefile          # src 子目录 Makefile
│   ├── main.c            # 主程序入口
│   ├── server.c          # 服务端逻辑
│   └── server.h          # 服务端头文件
├── lib/
│   ├── Makefile          # lib 子目录 Makefile
│   ├── utils.c           # 工具函数
│   ├── utils.h           # 工具函数头文件
│   └── math/
│       ├── Makefile      # 数学子库 Makefile
│       ├── vector.c
│       └── vector.h
├── test/
│   ├── Makefile          # 测试目录 Makefile
│   └── test_utils.c      # 单元测试
└── build/                # 构建产物统一输出目录
    ├── obj/              # .o 文件 + .d 依赖文件
    └── lib/              # .a 静态库文件
```

## 原理

### 顶层 Makefile：递归构建的总调度

```makefile
# ===== 顶层 Makefile：递归构建入口 =====
# 职责：(1) export 全局变量给子 Make (2) 按序递归调用子目录 Makefile
#       (3) 提供 clean / install 标准目标

# --- 全局变量（export 传递给子 Make） ---
export CC       := gcc              # 编译器
export CFLAGS   := -Wall -Wextra -O2  # -Wall(所有警告) -Wextra(额外) -O2(优化)
export AR       := ar               # ar(Archive): 将 .o 打包为 .a 静态库
export ARFLAGS  := rcs              # r(替换/插入) c(创建) s(索引)
export BUILD_DIR := $(CURDIR)/build  # CURDIR: Make 内建变量——当前 Makefile 绝对路径
#                       ^^^^^^
#                       绝对路径：防止子目录中相对路径混乱

# --- 子目录列表 ---
SUBDIRS := lib src test              # 构建顺序：先 lib（被 src 依赖），再 src

# --- .PHONY: 所有非文件目标 ---
.PHONY: all clean $(SUBDIRS)

# --- 默认目标 ---
all: $(SUBDIRS)                      # 递归构建所有子目录

# --- 递归规则：对每个子目录调用 make ---
$(SUBDIRS):
	$(MAKE) -C $@
#        ^^  ^^
#        $(MAKE): 当前 make 路径——传递命令行选项（如 -j）给子 Make
#        -C $@:   切换到子目录执行 Make（等价于 cd $@ && make）

# --- 清理 ---
clean:
	for dir in $(SUBDIRS); do \
		$(MAKE) -C $$dir clean; \     # 各子目录清理各自产物
	done
	rm -rf $(BUILD_DIR)               # 清理统一输出目录

# --- 安装 ---
install: all                          # install 依赖 all——先构建再安装
	install -d $(PREFIX)/bin          # install -d: 创建目录（等同于 mkdir -p）
	install -m 755 $(BUILD_DIR)/server $(PREFIX)/bin/
#             ^^^^
#             -m 755: 设置文件权限为 rwxr-xr-x
```

### 静态库目录：Makefile + 自动依赖

```makefile
# ===== lib/Makefile：构建静态库 =====
SRCS := $(wildcard *.c math/*.c)     # 当前目录 + math/ 子目录的所有 .c
OBJS := $(SRCS:.c=.o)                # 同名 .o 文件列表
DEPS := $(SRCS:.c=.d)                # 同名 .d 依赖文件列表
LIB  := $(BUILD_DIR)/lib/libutils.a  # 输出的静态库路径
#        ^^^^^^^^^^
#        顶层 Makefile export 的全局变量

# --- 目标：构建静态库 ---
$(LIB): $(OBJS)                      # 依赖所有 .o 文件
	@mkdir -p $(dir $@)              # $(dir $@): 提取目标的目录部分
	$(AR) $(ARFLAGS) $@ $^           # ar rcs libutils.a *.o——打包静态库

# --- 编译 + 自动依赖生成 ---
%.o: %.c
	@mkdir -p $(BUILD_DIR)/obj/$(dir $<)
	$(CC) -MM -MF $(BUILD_DIR)/obj/$(<:.c=.d) -MT $@ $(CFLAGS) -c $< -o $@
#        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#        自动依赖：-MM(仅用户头文件) -MF(输出到.d) -MT(指定目标名)
	$(CC) $(CFLAGS) -c $< -o $@

# --- 引入自动依赖 ---
-include $(addprefix $(BUILD_DIR)/obj/, $(DEPS))
#         ^^^^^^^^
#         所有 .d 文件在 BUILD_DIR/obj/ 下——addprefix 拼接路径

.PHONY: clean
clean:
	rm -f $(OBJS) $(LIB)
```

### 源文件目录：编译可执行文件

```makefile
# ===== src/Makefile：编译可执行文件 =====
SRCS   := $(wildcard *.c)
OBJS   := $(SRCS:.c=.o)
DEPS   := $(SRCS:.c=.d)
TARGET := $(BUILD_DIR)/server       # 输出目录下的可执行文件

# --- 链接：可执行文件依赖 src 下的 .o + 静态库 ---
$(TARGET): $(OBJS) $(BUILD_DIR)/lib/libutils.a
#                        ^^^^^^^^^^^^^^^^^^^^^^^^^
#                        显式依赖静态库——库文件更新时程序重新链接
	@mkdir -p $(dir $@)
	$(CC) $^ -o $@ -lpthread
#        ^^         ^^^^^^^^^
#        $^ = 所有 .o + .a    -lpthread: 链接多线程库

# --- 编译 .c → .o ---
%.o: %.c
	@mkdir -p $(BUILD_DIR)/obj/src
	$(CC) -MM -MF $(@:.o=.d) -MT $@ $(CFLAGS) -I../lib -c $< -o $@
#                                                   ^^^^^^
#                                                   -I: 添加头文件搜索路径
	$(CC) $(CFLAGS) -I../lib -c $< -o $@

-include $(DEPS)

.PHONY: clean
clean:
	rm -f $(OBJS) $(DEPS) $(TARGET)
```

### 测试目录：构建 + 执行一体

```makefile
# ===== test/Makefile：构建并运行测试 =====
SRCS     := $(wildcard *.c)
OBJS     := $(SRCS:.c=.o)
DEPS     := $(SRCS:.c=.d)
TEST_BIN := $(BUILD_DIR)/test_runner

$(TEST_BIN): $(OBJS) $(BUILD_DIR)/lib/libutils.a
	@mkdir -p $(dir $@)
	$(CC) $^ -o $@

%.o: %.c
	@mkdir -p $(BUILD_DIR)/obj/test
	$(CC) -MM -MF $(@:.o=.d) -MT $@ $(CFLAGS) -I../lib -c $< -o $@
	$(CC) $(CFLAGS) -I../lib -c $< -o $@

-include $(DEPS)

# test 目标：构建 → 运行 → 报告
.PHONY: test
test: $(TEST_BIN)                    # test 依赖可执行文件——确保先构建
	@echo "Running tests..."
	$(TEST_BIN)                      # 执行测试可执行文件

.PHONY: clean
clean:
	rm -f $(OBJS) $(DEPS) $(TEST_BIN)
```

### 调试技巧

```bash
# ===== Makefile 调试命令清单 =====

# 1. -n / --just-print: 只打印命令，不执行（dry-run）
make -n            # 输出所有将执行的命令——验证配方展开结果
# 用途：在执行破坏性操作前预览 Makefile 逻辑

# 2. -p / --print-data-base: 打印 Make 完整内部数据库
make -p | grep '^CFLAGS'   # 提取变量 CFLAGS 的值
# 用途：调试"变量的最终值为什么不是我想的那样？"

# 3. -d / --debug: 极其详细的决策日志
make -d 2>&1 | grep "main.o"   # 只看 main.o 的决策过程
# 用途：Debug "为什么这个目标没有被重新构建？"

# 4. --warn-undefined-variables: 警告使用了未定义的变量
make --warn-undefined-variables
# 用途：防止拼写错误导致的空值替换

# 5. info/warning/error 函数：在 Makefile 中嵌入诊断
$(info BUILD_DIR = $(BUILD_DIR))       # info: 打印消息，继续
$(warning CFLAGS = $(CFLAGS))          # warning: 打印警告，继续
$(error CC not defined)               # error: 打印错误并中止 Make
# 用途：在 Make 读取阶段打印中间变量值，快速定位展开逻辑错误
```

## 关键要点

1. **递归 Makefile 用 `$(MAKE) -C` 而非 `cd && make`**——`$(MAKE)` 传递命令行选项（如 `-j`），确保子 Make 共享并行度控制
2. **`export` 是递归 Make 的黏合剂**——不加 export 的变量子目录 Make 看不到
3. **`$(CURDIR)` 优于 `$(PWD)`**——`CURDIR` 是 Make 内建变量，不受 Shell 环境干扰
4. **构建产物统一输出到 `build/` 目录**——保持源文件目录清洁，`clean` 只需删一个目录
5. **`-include` 永远用 `-` 前缀**——首次构建和 `clean` 之后 `.d` 文件不存在是正常情况
6. **`install -m 755` 比 `cp` + `chmod` 更可靠**——一步到位，原子操作
7. **`make -n` 是调试 Makefile 的第一步**——在执行破坏性操作前预览配方展开结果

## 与其他概念的关系

- [[tools/concepts/Makefile基础语法|Makefile 基础语法]]——整合了变量系统、自动变量、`.PHONY` 等基础语法
- [[tools/concepts/Makefile条件与函数|Makefile 条件与函数]]——`$(wildcard ...)`、`$(dir ...)`、`$(addprefix ...)` 贯穿全文
- [[tools/concepts/Makefile模式与依赖|Makefile 模式与依赖]]——`-MM` + `-include` 自动依赖 + 模式规则是本文核心技术栈
- [[tools/concepts/Makefile项目构建|Makefile 项目构建（IC 实战）]]——递归 Make 和层次化组织是 IC 项目级 Makefile 的基础

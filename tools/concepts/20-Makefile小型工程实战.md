---
type: concept
aliases: [Makefile 小型工程实战, C socket ARM x86 cross-compile]
tags: [tools, makefile, asic]
source_spec: "GNU Make Manual; GCC Cross-Compiler; POSIX Socket API"
queries: 1
---

# 20 — Makefile小型工程实战

## 学习目标

以一个完整的 TCP Echo Server/Client 网络服务项目为载体，演示生产级 Makefile 的完整构建体系——x86 本地编译 + ARM 交叉编译 + 调试 + 发布 + 测试 + 覆盖率。读完本篇，你应能直接拿这个 Makefile 改写成自己的项目。

## 项目结构

```
echod/
├── Makefile
├── src/server/main.c src/client/main.c src/common/netutils.c
├── include/netutils.h
├── test/test_netutils.c
└── build/{obj/,lib/,bin/}            # 所有产物
```

## 完整 Makefile

```makefile
# ===== echod/Makefile =====
# 1. 工具链——ARCH 驱动 x86/ARM 切换
ARCH ?= x86_64
ifeq ($(ARCH),aarch64)
  CROSS_COMPILE := aarch64-linux-gnu-
  SYSROOT      ?= /opt/aarch64-sysroot
  CFLAGS       += --sysroot=$(SYSROOT)
else
  CROSS_COMPILE :=
endif
CC      := $(CROSS_COMPILE)gcc
AR      := $(CROSS_COMPILE)ar
CFLAGS  := -Wall -Wextra -Werror
LDFLAGS := -lpthread

# 2. 双模式
DEBUG ?= 0
ifeq ($(DEBUG),1)
  CFLAGS += -g -O0 -DDEBUG -fsanitize=address
  LDFLAGS += -fsanitize=address
else
  CFLAGS += -O2 -DNDEBUG
endif

# 3. 目录
BUILD_DIR := build; OBJ_DIR := $(BUILD_DIR)/obj
LIB_DIR := $(BUILD_DIR)/lib; BIN_DIR := $(BUILD_DIR)/bin

# 4. 源文件
COMMON_SRCS := $(wildcard src/common/*.c)
SERVER_SRCS := $(wildcard src/server/*.c)
CLIENT_SRCS := $(wildcard src/client/*.c)
COMMON_OBJS := $(patsubst src/%.c,$(OBJ_DIR)/%.o,$(COMMON_SRCS))
SERVER_OBJS := $(patsubst src/%.c,$(OBJ_DIR)/%.o,$(SERVER_SRCS))
CLIENT_OBJS := $(patsubst src/%.c,$(OBJ_DIR)/%.o,$(CLIENT_SRCS))
DEPS := $(COMMON_OBJS:.o=.d) $(SERVER_OBJS:.o=.d) $(CLIENT_OBJS:.o=.d)

# 5. 产物
LIB   := $(LIB_DIR)/libnetutils.a
SERVER := $(BIN_DIR)/echod; CLIENT := $(BIN_DIR)/echoc

.PHONY: all; all: $(SERVER) $(CLIENT)

# 6. 库+可执行
$(LIB): $(COMMON_OBJS) | $(LIB_DIR); $(AR) rcs $@ $^
$(SERVER): $(SERVER_OBJS) $(LIB) | $(BIN_DIR)
	$(CC) $(SERVER_OBJS) $(LIB) $(LDFLAGS) -o $@
$(CLIENT): $(CLIENT_OBJS) $(LIB) | $(BIN_DIR)
	$(CC) $(CLIENT_OBJS) $(LIB) $(LDFLAGS) -o $@

# 7. 编译 + 自动依赖
$(OBJ_DIR)/%.o: src/%.c | $$(@D)
	$(CC) -MMD -MP -MF $(@:.o=.d) -MT $@ $(CFLAGS) -Isrc/common -c $< -o $@
-include $(DEPS)

# 8. 平台适配
PLATFORM != uname -s
ifeq ($(PLATFORM),Linux);  LDFLAGS += -lrt; endif
ifeq ($(PLATFORM),Darwin); CFLAGS += -D_DARWIN_C_SOURCE; endif

# 9. 目录创建
$(OBJ_DIR) $(LIB_DIR) $(BIN_DIR) $(OBJ_DIR)/common $(OBJ_DIR)/server $(OBJ_DIR)/client:
	@mkdir -p $@

# 10. 测试
TEST_BIN := $(BIN_DIR)/test_runner
.PHONY: test; test: $(TEST_BIN); @$(TEST_BIN)
$(TEST_BIN): $(wildcard test/*.c) $(LIB) | $(BIN_DIR)
	$(CC) $(filter %.c,$^) $(LIB) $(LDFLAGS) -o $@

# 11. 安装/打包
PREFIX ?= /usr/local
.PHONY: install uninstall
install: all; install -d $(PREFIX)/bin; install -m 755 $(SERVER) $(CLIENT) $(PREFIX)/bin/
uninstall:; rm -f $(PREFIX)/bin/echod $(PREFIX)/bin/echoc

.PHONY: dist; dist: clean; tar czf echod-$(VERSION).tar.gz --exclude=.git .

# 12. 覆盖率
.PHONY: coverage; coverage: CFLAGS += --coverage; coverage: LDFLAGS += --coverage
coverage: clean test; gcovr -r . --html -o $(BUILD_DIR)/coverage/index.html

# 13. 清理
.PHONY: clean; clean:; rm -rf $(BUILD_DIR)
```

## 使用方式

```shell
make; make ARCH=aarch64; make DEBUG=1  # x86/ARM/debug
make test; make coverage               # 测试+覆盖率
make install PREFIX=/opt; make dist VERSION=1.0.0
```

## 关键设计

| 决策 | 理由 |
|:---|:---|
| `ARCH` + `CROSS_COMPILE` 前缀 | 单文件 x86/ARM 切换 |
| `build/` 集中输出 | 源目录零污染 |
| `-MMD -MP` 一步 | 自动依赖 |
| `| $$(@D)` order-only | 目录 mtime 不影响 .o |
| `DEBUG ?= 0` | 双模式 |
| `PLATFORM != uname -s` | Linux/macOS 适配 |

## 关键要点

1. **`CROSS_COMPILE` 前缀模式——ARM/x86 一文件切换。**
2. **`ARCH` 驱动 `--sysroot` 和工具链选择。**
3. **`| $$(@D)` order-only 目录是标准写法。**
4. **所有产物在 `build/`——清洁源目录。**
5. **`-fsanitize=address` ASAN 内存检测——调试模式标配。**

## 与其他概念的关系

- [[tools/concepts/14-Makefile依赖与自动生成|Makefile依赖与自动生成]] `-MMD -MP`
- [[tools/concepts/10-Makefile条件判断|Makefile条件判断]] `ifeq` 平台判断
- [[tools/concepts/18-Makefile递归与大型项目|Makefile递归与大型项目]] out-of-source build

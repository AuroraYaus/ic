---
type: concept
aliases: [Makefile 内置变量与命令行, MAKEFLAGS MAKECMDGOALS MAKELEVEL]
tags: [tools, makefile, asic]
source_spec: "GNU Make Manual 5.7, 9.7, 4.8; GNU Make 4.3 --help output"
queries: 1
---

# 17 — Makefile内置变量与命令行

## 学习目标

本篇是内置变量和命令行选项的完全参考。读完本篇，你应能：

1. 在递归 Make 中正确使用 `$(MAKE)`、`$(MAKEFLAGS)`、`$(MAKELEVEL)`
2. 用 `$(MAKECMDGOALS)` 判断用户意图实现条件构建
3. 用 `$(.FEATURES)` 编写跨版本兼容 Makefile
4. 掌握 20+ 命令行选项的分类和使用场景

## Part A：内置变量详解

### 递归 Make 三件套

```makefile
# $(MAKE) — 递归 Make 核心。永远用 $(MAKE) 而非硬编码 make
subdir:
	$(MAKE) -C subdir                 # 自动传递 -j/-n/-k 等标志和 jobserver

# $(MAKEFLAGS) — 命令行标志传递链
$(info MAKEFLAGS = $(MAKEFLAGS))       # 例：j4 --no-print-directory

# $(MAKELEVEL) — 递归深度
$(info MAKELEVEL = $(MAKELEVEL))       # 顶层=0，子=1，孙=2...
```

### 构建控制变量

```makefile
# $(MAKECMDGOALS) — 用户请求的目标列表
# make clean all → "clean all"; make → ""（空=默认目标）
ifneq ($(filter clean,$(MAKECMDGOALS)),)
$(info clean was requested)            # 用户请求了 clean
endif

# $(MAKEFILE_LIST) — 已读取的 Makefile 列表
CURRENT_DIR := $(dir $(lastword $(MAKEFILE_LIST)))  # 当前 Makefile 所在目录
```

### 路径与 Shell 变量

```makefile
# $(CURDIR) vs $(PWD)
# CURDIR = Make 记录的绝对工作目录——确定性，不受配方 cd 影响
# PWD    = Shell 环境变量——可能被配方中的 cd 改变
BUILD_ROOT := $(CURDIR)

# $(SHELL) / $(.SHELLFLAGS)
SHELL := /bin/bash                     # 切换 Shell（默认 /bin/sh）
.SHELLFLAGS := -ec                     # -e=errexit, -c=执行命令字符串
```

### 版本与能力检测

```makefile
# $(.FEATURES) — GNU Make 编译特性列表——跨版本兼容的唯一依据
# 检测示例：
ifeq ($(filter grouped-target,$(.FEATURES)),grouped-target)
# 有 grouped-target → GNU Make ≥ 4.3 → 可以使用 &:
else
# 回退方案
endif
# 关键特性：grouped-target(4.3+), second-expansion, order-only, oneshell, load

# $(.VARIABLES) — 所有已定义变量名的完整列表（调试用）
# $(.RECIPEPREFIX) — 当前配方前缀字符（默认 TAB）
```

### 命令行覆盖相关

```makefile
# $(MAKEOVERRIDES) — 命令行变量传递机制
# 陷阱：命令行 `make VAR=val` 通过此变量传给子 Make→覆盖子 Make 的 ?=
# 清除：MAKEOVERRIDES :=  # 阻止命令行变量传入子 Make

# $(MAKE_RESTARTS) — remake 重启次数（详见 14 篇）
```

## Part B：命令行选项分类手册

### 构建控制

| 选项 | 含义 | 典型场景 |
|:---|:---|:---|
| `-j [N]` | 并行 jobs | `make -j$(nproc)` |
| `-l [N]` | 负载阈值 | `make -j8 -l 6` |
| `-k` | 错误后继续 | `make -j8 -k` CI 标准 |
| `-n` / `--dry-run` | 只打印不执行 | 预演验证 |
| `-B` / `--always-make` | 无条件重建 | 强制全量 |
| `-o FILE` | 假设 FILE 旧 | 选择性跳过 |
| `-W FILE` | 假设 FILE 新 | 模拟影响 |
| `--shuffle` | 打乱顺序 | ≥4.4 竞态检测 |

### 目录/文件

| 选项 | 含义 |
|:---|:---|
| `-C DIR` | 切换目录 |
| `-f FILE` | 指定 Makefile |
| `-I DIR` | include 搜索路径 |

### 调试/信息

| 选项 | 含义 |
|:---|:---|
| `--debug=FLAGS` | a=all, b=basic, v=verbose, i=implicit, j=jobs, m=remake |
| `-p` | 打印完整数据库 |
| `--trace` | 实时触发原因 |
| `-s` | 静默 |
| `--warn-undefined-variables` | 未定义变量警告 |

### 隐含规则控制

| 选项 | 含义 |
|:---|:---|
| `-r` / `--no-builtin-rules` | 禁用内置规则 |
| `-R` / `--no-builtin-variables` | 不预定义隐含变量 |

### 环境/变量

| 选项 | 含义 |
|:---|:---|
| `-e` / `--environment-overrides` | 环境变量覆盖 Makefile |
| `-E STRING` | ⚠️ **不是**环境覆盖！`-E` = `--eval=STRING` |

### 其他

| 选项 | 含义 |
|:---|:---|
| `--output-sync[=TYPE]` | 并行输出同步 (none/line/target/recurse) |
| `--no-print-directory` | 不打印目录进入/离开 |
| `-v` / `-h` | 版本/帮助 |

## Part C：实战技法

```makefile
# 技法 1：命令行变量覆盖
# make CC=clang → 覆盖 Makefile CC（优先级高于 ?=，低于 override）

# 技法 2：条件感知构建
ifneq ($(filter debug,$(MAKECMDGOALS)),)
CFLAGS += -g -O0                      # 用户请求 debug → 挂调试选项
endif

# 技法 3：版本检测 + 条件启用
ifeq ($(filter oneshell,$(.FEATURES)),oneshell)
.ONESHELL:                             # 仅在支持时启用
endif

# 技法 4：递归 Make 骨架
export CC CFLAGS                       # 导出跨子目录共享的变量
SUBDIRS := lib src test
.PHONY: all clean $(SUBDIRS)
all: $(SUBDIRS)
$(SUBDIRS): ; $(MAKE) -C $@            # $(MAKE) 自动传递 -j/-n/-k
clean: ; for d in $(SUBDIRS); do $(MAKE) -C $$d clean; done
```

## 关键要点

1. **永远用 `$(MAKE)` 而非 `make`——保证 jobserver 和标志传递。**
2. **`MAKEFLAGS` 自动传递——子 Make 继承几乎所有命令行选项。**
3. **`$(MAKECMDGOALS)` + `$(filter ...)` 实现用户意图感知。**
4. **`$(.FEATURES)` 是跨版本兼容的唯一可靠方式。**
5. **`-e` = 环境覆盖；`-E STRING` = `--eval`——易混淆。**
6. **`--warn-undefined-variables` 建议常年开启——捕拼写错误。**
7. **`-j$(nproc) -k` 是 CI 的标准组合——尽快发现所有错误。**

## 与其他概念的关系

- [[tools/concepts/18-Makefile递归与大型项目|18]]
- [[tools/concepts/19-Makefile调试与性能|19]]
- [[tools/concepts/06-Makefile高级变量|06]]
- [[tools/concepts/16-Makefile特殊目标手册|16]]

## 小练习

1. `make -p | head -200` — 窥探内置数据库
2. `$(MAKECMDGOALS)` 实现 `make debug` 切换
3. `$(.FEATURES)` 检测 grouped-target
4. `make -e CC=clang` vs `make CC=clang` 优先级对比

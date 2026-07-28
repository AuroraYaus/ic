---
type: concept
aliases:
  - Makefile 高级变量
  - Makefile automatic target-specific origin flavor value
tags:
  - tools
  - makefile
  - asic
source_spec: "GNU Make Manual 6.14: Automatic Variables, 6.11: Target-specific, 6.12: Pattern-specific, 7.2-7.5: origin/flavor/value Functions"
queries: 1
---

# 06 — Makefile高级变量

## 学习目标

本篇覆盖变量系统的三类进阶机制：

1. **自动变量完整手册** — 8 个自动变量（`$@`、`$<`、`$^`、`$?`、`$*`、`$%`、`$+`、`$|`）的精确语义和组合用法
2. **作用域变量** — Target-specific / Pattern-specific：让同一变量在不同目标下有不同值
3. **诊断三件套** — `$(origin)`/`$(flavor)`/`$(value)`：回答"从哪来、什么类型、原始文本是什么"

读完本篇后，你应该能诊断任何变量问题：拼写错误 → `$(origin)` 返回 `undefined`；覆盖失败 → 检查 `override` 和优先级链；`?=` 不生效 → `$(origin)` 告诉你变量已在别处定义。

## 前置知识

- [[tools/concepts/05-Makefile变量赋值与展开|Makefile变量赋值与展开]]：五种赋值操作符和二阶段展开
- [[tools/concepts/03-Makefile规则详解|Makefile规则详解]]：配方上下文——自动变量只在配方中有效

## 最小可运行例子

### 例子 1：所有自动变量在配方中的值

```makefile
all: lib.a app.bin

lib.a: math.o util.o
	@printf 'target(\044@) =%s\n' '$@'       # $@ = lib.a
	@printf 'first(\044<)  =%s\n' '$<'       # $< = math.o（第一个前置条件）
	@printf 'all(\044^)    =%s\n' '$^'       # $^ = math.o util.o（全部，去重）
	@printf 'newer(\044?)  =%s\n' '$?'       # $? = 比目标新的前置条件
	@printf 'all+(\044+)   =%s\n' '$+'       # $+ = math.o util.o（含重复）
	@printf 'pipe(\044|)   =%s\n' '$|'       # $| = order-only 前置条件

app.bin: main.o | build
	@printf 'target(\044@) =%s\n' '$@'       # $@ = app.bin

math.o util.o main.o:; @touch '$@'
build:; @mkdir -p build

.PHONY: clean; clean:; @rm -f *.o *.a *.bin; rm -rf build
```

### 例子 2：Target-specific 变量——不同目标用不同选项

```makefile
CFLAGS := -Wall -O2                        # 全局默认

debug.o: CFLAGS := -g -O0 -DDEBUG         # 仅对 debug.o 及其前置条件生效
debug.o: debug.c
	@printf 'debug.o   CFLAGS=%s\n' '$(CFLAGS)' > '$@'

release.o: release.c
	@printf 'release.o CFLAGS=%s\n' '$(CFLAGS)' > '$@'

debug.c release.c:; @touch '$@'

.PHONY: all clean; all: debug.o release.o; clean:; rm -f *.o *.c
```

**关键特性：** Target-specific 变量**传播**到该目标的所有前置条件配方中。如果 `debug.o` 依赖 `debug-utils.o`，后者也继承 `CFLAGS := -g -O0 -DDEBUG`。

### 例子 3：诊断三件套

```makefile
A := hello                               # 简单展开——file/simple
B  = world                               # 递归展开——file/recursive
override C := forced                      # override——命令行无法覆盖

.PHONY: all
all:
	@printf '%-6s origin=%-18s flavor=%-10s value="%s"\n' \
		'A' '$(origin A)'  '$(flavor A)'  '$(value A)'
	@printf '%-6s origin=%-18s flavor=%-10s value="%s"\n' \
		'B' '$(origin B)'  '$(flavor B)'  '$(value B)'
	@printf '%-6s origin=%-18s\n' 'PATH' '$(origin PATH)'
```

```shell
make                     # A: file/simple, B: file/recursive, PATH: environment
make A=cmdline           # A: command line/recursive——命令行赋值的默认flavor是recursive
```

## 语法拆解

### 自动变量速查

| 变量 | 含义 | 助记 | 典型用途 |
|:---|:---|:---|:---|
| `$@` | 当前目标 | **@**=at=target | `-o $@` |
| `$<` | **第一个**前置条件 | **<**=first | `-c $<` |
| `$^` | 所有前置条件（**去重**） | **^**=all | `$^ -o $@` |
| `$?` | 所有**比目标新**的前置条件 | **?**=newer | `ar r $@ $?` |
| `$+` | 所有前置条件（**含重复**） | **+**=all+dupes | 库链接顺序 |
| `$*` | 模式规则的茎 | **\***=stem | `%` 匹配部分 |
| `$%` | 库成员名 | **%**=member | `.a(member.o)` |
| `$|` | Order-only 前置条件 | **\|**=pipe | `mkdir -p $|` |

### $(origin) — 来源判定

| 返回值 | 含义 |
|:---|:---|
| `undefined` | 从未定义 → 拼写错误 |
| `default` | GNU Make 内置（如 `CC`=cc） |
| `environment` | 环境变量（`PATH`、`HOME`） |
| `environment override` | `-e` 覆盖的环境变量 |
| `file` | Makefile 中定义 |
| `command line` | `make VAR=val` 传入 |
| `override` | `override` 指令 |
| `automatic` | 自动变量（`$@` 等） |

### $(flavor) — 展开类型

| 返回值 | 含义 |
|:---|:---|
| `undefined` | 未定义 |
| `recursive` | `=` 定义 |
| `simple` | `:=` 定义（或 `override`） |

### $(value) — 查看原始文本

```makefile
B = $(shell date)
$(info value = $(value B))         # $(shell date) ——未展开
$(info B     = $(B))               # Mon Jul 28... ——展开后
```

### 变量优先级链

```
override > 命令行 > target-specific > pattern-specific > 全局(file) > 环境变量 > 内置默认
```

## 工程化写法

### 通用变量诊断目标

```makefile
# 用法：make print-var-CFLAGS
print-var-%:
	@printf '%-20s origin=%-18s flavor=%-10s value="%s"\n' \
		'$*' '$(origin $*)' '$(flavor $*)' '$(value $*)'
```

### IC 场景：不同测试用不同 UVM 详细度

```makefile
test_smoke.vsim:  UVM_VERBOSITY := UVM_LOW
test_sanity.vsim: UVM_VERBOSITY := UVM_MEDIUM
test_stress.vsim: UVM_VERBOSITY := UVM_NONE

%.vsim: $(RTL) $(TB)
	vsim -c +UVM_VERBOSITY=$(UVM_VERBOSITY)
```

## 常见错误

### 错误 1：变量定义中引用自动变量

**现象：** `TARGET = $@` → `$(TARGET)` 总是空。

**根因：** 自动变量只在配方中有效——变量定义时没有"当前目标"绑定。

### 错误 2：拼写错误被静默忽略

**现象：** `$(CFLAG)` 总是空字符串。

**诊断：** `$(origin CFLAG)` → `undefined`。启用 `--warn-undefined-variables`。

### 错误 3：命令行赋值的 flavor 变化

**现象：** `make A=hello` 后 `$(flavor A)` 返回 `recursive`，即使 Makefile 中 `A := hello`。

**根因：** 命令行覆盖的变量默认是 `recursive` flavor。

**修复：** `override A := hello` 阻止命令行覆盖同时锁定 simple flavor。

## 关键要点

1. **自动变量只在配方中有效——不能用于变量定义或条件判断。**
2. **Target-specific 变量传播到前置条件配方中。**
3. **`$(origin)`=来源，`$(flavor)`=类型，`$(value)`=原始文本。**
4. **优先级：override > 命令行 > target-specific > pattern-specific > 全局 > 环境 > 内置默认。**
5. **`--warn-undefined-variables` 是最好的拼写错误检测。**

## 与其他概念的关系

- [[tools/concepts/05-Makefile变量赋值与展开|Makefile变量赋值与展开]]：五种赋值——本篇的自动变量和诊断函数建立在其上
- [[tools/concepts/12-Makefile模式规则|Makefile模式规则]]：`$*` 和 Pattern-specific 的主战场
- [[tools/concepts/19-Makefile调试与性能|Makefile调试与性能]]：诊断函数系统化使用
- [[tools/concepts/17-Makefile内置变量与命令行|Makefile内置变量与命令行]]：`$(MAKE)` 等内置变量

## 小练习

1. **打印所有自动变量：** 多前置条件规则中打印 `$@/$</$^/$?`，`touch` 一个依赖后观察 `$?` 变化。
2. **Target-specific 继承：** `a.o: b.o` 链中对 `a.o` 设 target-specific，验证 `b.o` 也受影响。
3. **诊断未知变量：** 使用 `$(call_me_maybe)` + `--warn-undefined-variables`。
4. **对比 `$(value)` vs `$(VAR)`：** 对 `=` 变量分别输出二者差异。

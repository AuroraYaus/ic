---
type: concept
aliases: [Makefile 模式规则, Pattern rules static pattern VPATH vpath grouped targets]
tags: [tools, makefile, asic]
source_spec: "GNU Make Manual 10.5: Pattern Rules, 4.12: Static Pattern Rules, 4.5: VPATH; GNU Make 4.3 Grouped Targets"
queries: 1
---

# 12 — Makefile模式规则

## 学习目标

模式规则（Pattern Rules）是 Makefile 从"手动为每个文件写规则"到"一条规则覆盖无限文件"的里程碑。读完本篇，你将能：

1. 用 `%.o: %.c` 替代 N 条编译规则
2. 用静态模式规则精确限定范围
3. 用 `VPATH`/`vpath` 管理多源目录搜索
4. 理解 Grouped Targets（`&:`）解决"一次配方多产物"

## 前置知识

- [[tools/concepts/03-Makefile规则详解|03 — 规则详解]]：显式规则是模式规则的特例
- [[tools/concepts/06-Makefile高级变量|06 — 高级变量]]：`$*` 在模式规则中 = stem

## 模式规则基础

```makefile
# %.o: %.c —— 最经典的 Makefile 模式规则
# % 匹配任意非空字符串（茎 stem）——目标/前置中的 % 匹配相同文本
%.o: %.c                               # 对任意 .o → 同名的 .c
	$(CC) $(CFLAGS) -c $< -o $@        # $< = 匹配的 .c, $@ = 匹配的 .o

OBJS := main.o util.o io/file.o
program: $(OBJS)                       # 链接
	$(CC) $^ -o $@
# Make 发现 main.o 需要构建 → 搜索规则 → 命中 %.o: %.c → 执行配方

# 多目录映射：
build/%.o: src/%.c                     # build/main.o ← src/main.c
	@mkdir -p $(@D)                    # $(@D) = 目标目录 = build/
	$(CC) -c $< -o $@

# 多个模式规则竞争时——Make 选 stem 最短的
```

## 静态模式规则

```makefile
# $(TARGETS) : %.target : %.prereq —— 只在 $(TARGETS) 范围内生效
OBJS := main.o util.o io.o
$(OBJS): %.o: %.c                      # 仅对 $(OBJS) 列表中的文件生效
	$(CC) $(CFLAGS) -c $< -o $@
# 比普通 %.o: %.c 更安全——不会意外匹配其他 .o 文件

# vs 普通模式规则：
# %.o: %.c       → 任何 .o 都匹配
# $(OBJS): %.o: %.c → 只有 OBJS 列表中的 .o 匹配
```

## VPATH / vpath

```makefile
VPATH := src:lib:include                # 搜索前置条件的目录列表
# Make 搜索顺序：当前目录 → src/ → lib/ → include/

# 完整示例：
VPATH := src:lib
SRCS := $(wildcard src/*.c) $(wildcard lib/*.c)
OBJS := $(notdir $(SRCS:.c=.o))        # main.o util.o ——不包含目录
%.o: %.c                                # Make 在 VPATH 中找 .c
	$(CC) -c $< -o $@                  # $< = src/main.c（含路径）

# vpath：按模式指定路径——更精确
vpath %.c src                           # .c → src/
vpath %.h include                       # .h → include/
vpath %.sv rtl                          # IC: SystemVerilog → rtl/

# ⚠️ VPATH 陷阱：同名文件取第一个匹配——可能不是想要的
```

## Grouped Targets（`&:`，GNU Make ≥4.3）

```makefile
# 普通多目标：每个目标独立执行一次配方——"一次生成多文件"无法实现
%.o %.d: %.c                           # 错误：%.d 需要构建时也执行这个配方
	$(CC) -c $< -o $@                  # 但 $@ 此时 = .o——.d 未被创建！

# Grouped Targets：声明一次配方同时产出所有目标
%.o %.d &: %.c                         # 一次配方调用产出 .o 和 .d
	$(CC) -MMD -MF $(@D)/$(*F).d -c $< -o $(@D)/$(*F).o
# 这是自动依赖生成的标准实现——见 14 篇
```

## 工程场景

```makefile
# C/C++：多源目录 → 统一构建目录
SRCS := $(wildcard src/*.c lib/*.c)
OBJS := $(patsubst %.c,build/%.o,$(notdir $(SRCS)))
VPATH := src lib
$(OBJS): %.o: %.c; $(CC) -c $< -o $@

# IC：RTL 编译到仿真库
RTL := $(wildcard rtl/*.sv)
LIBS := $(patsubst rtl/%.sv,work/%.so,$(RTL))
$(LIBS): work/%.so: rtl/%.sv; vlog -work work $<
```

## 关键要点

1. **`%.o: %.c` 是 Makefile 工程化的转折点——一条规则替代 N 条。**
2. **静态模式 = 模式规则的表达式 + 显式列表的安全性。**
3. **`VPATH` 按序搜索——同名取首（陷阱）。`vpath` 按类型精确控制。**
4. **Grouped Targets 解决"一次多产物"——GNU Make ≥4.3。**
5. **模式规则中的 `$*` = stem（`%` 匹配的文本）。**

## 与其他概念的关系

- [[tools/concepts/03-Makefile规则详解|03 — 规则详解]]
- [[tools/concepts/13-Makefile隐含规则|13 — 隐含规则]]
- [[tools/concepts/14-Makefile依赖与自动生成|14 — 依赖与自动生成]]

## 小练习

1. 用 `%.o: %.c` 替代手写编译规则。
2. 静态模式：仅对 `OBJS := a.o b.o` 生效。
3. VPATH：`src/main.c` 和当前 `main.c` 共存。
4. Grouped Targets 实现 .o + .d 同生。

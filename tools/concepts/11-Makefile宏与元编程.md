---
type: concept
aliases:
  - Makefile 宏与元编程
  - define endef call eval
tags:
  - tools
  - makefile
  - asic
source_spec: "GNU Make Manual 6.8: Defining Multi-Line Variables, 8.9: The call Function, 8.10: The eval Function"
queries: 1
---

# 11 — Makefile宏与元编程

## 学习目标

本篇覆盖 Makefile 中最强大也最危险的机制：`define`/`endef` 多行变量、`$(call)` 参数化模板和 `$(eval)` 元编程。读完本篇后，你将能：

1. 用 `define` 定义多行配方模板——Makefile 的"函数"
2. 用 `$(call ...)` 参数化调用模板——消除重复代码
3. 理解 `$(eval ...)` 的能力边界和风险——只在必要场景使用

**核心原则：能用模式规则和静态模式规则解决的问题，不上 `$(eval)`。`$(eval)` 是最后手段。**

## 前置知识

- [[tools/concepts/09-Makefile控制函数与诊断函数|09 — 控制与诊断函数]]：`$(foreach)` 常与 `$(eval)` 组合
- [[tools/concepts/05-Makefile变量赋值与展开|05 — 变量赋值与展开]]：`$$` 双重展开是 `$(eval)` 的关键

## `define`/`endef` — 多行变量

```makefile
# define 允许变量值跨越多行——含换行符、TAB 配方、变量引用
define compile_template                 # 模板开始
$(CC) $(CFLAGS) -c $(1) -o $(2)       # $(1)=源文件, $(2)=目标文件
endef                                   # 模板结束
# 使用：$(call compile_template, main.c, main.o)

# 也可用于多行配方
define build_steps
	@printf 'Step 1: preprocessing\n'
	$(CC) -E $(CFLAGS) $(1) -o $(2).i
	@printf 'Step 2: compilation\n'
	$(CC) -c $(CFLAGS) $(2).i -o $(2)
endef
```

## `$(call)` — 参数化调用

```makefile
# $(call VARIABLE,PARAM1,PARAM2,...)
# 将 VARIABLE 的值作为模板——$(1)$(2)... 替换为对应参数

compile = $(CC) $(CFLAGS) -c $(1) -o $(2)
link    = $(CC) $(LDFLAGS) $(1) $(2) -o $(3)

main.o: main.c
	$(call compile,$<,$@)                # → gcc -Wall -c main.c -o main.o

program: main.o lib/libutils.a
	$(call link,$^,lib/libutils.a,$@)

# $(call ...) + $(foreach ...) —— 批量生成变量
DIRS := src lib test
$(foreach d,$(DIRS),$(eval $(d)_SRCS := $$(wildcard $(d)/*.c)))
# 为每个目录定义 src_SRCS / lib_SRCS / test_SRCS
#              $$ 是双重转义——eval 读到 $(wildcard ...)
```

## `$(eval)` — 运行时生成 Makefile 代码

```makefile
# $(eval TEXT) — 将 TEXT 作为 Makefile 语法求值——元编程
# 这是 Makefile 最强大、也是最难调试的功能

# === 最小安全示例：foreach + eval 批量生成规则 ===
TARGETS := sim syn sta
define TARGET_TEMPLATE
$(1):
	@printf 'Running $(1)...\n'
endef
$(foreach t,$(TARGETS),$(eval $(call TARGET_TEMPLATE,$(t))))
# 生成三条独立规则：sim:、syn:、sta:

# === $$ 转义层次（eval 内最关键的概念） ===
# $(VAR)     → eval 执行前先展开（由 foreach/call 处理）
# $$(VAR)    → eval 读到 $(VAR) → 求值为 Make 变量
# $$$$(VAR)  → eval 读到 $$(VAR) → 展开为 $(VAR) → 留给配方阶段

# === 工程场景：为多个目录生成完整构建规则 ===
DIRS := src lib test
define DIR_RULES
$(1)_SRCS := $$(wildcard $(1)/*.c)
$(1)_OBJS := $$(patsubst %.c,build/%.o,$$($(1)_SRCS))
build/$(1).a: $$($(1)_OBJS)
	$$(AR) rcs $$@ $$^
endef
$(foreach d,$(DIRS),$(eval $(call DIR_RULES,$(d))))
```

## `$(eval)` 的风险边界

```makefile
# ❌ 不该用 eval：模式规则能解决的（%.o: %.c）
# ❌ 不该用 eval：foreach 本身能解决的
# ❌ 不该用 eval：静态模式规则能解决的（$(OBJS): %.o: %.c）

# ✅ eval 的合理场景：
# 1. 需要为目标列表生成多组完整的变量+规则+伪目标
# 2. 不同类型的目标需要不同结构的规则
# 3. 代码生成量确实值得引入的复杂度

# 调试技巧：先用 $(info ...) 看 call 的输出，确认后再给 eval
$(info eval result: $(call TARGET_TEMPLATE,sim))
# 确定输出是预期的 Makefile 语法 → 再包裹 $(eval ...)
```

## 工程场景：IC 测试规则批量生成

```makefile
TEST_LIST := smoke sanity stress corner_ff corner_ss
define TEST_RULE
test_$(1).log: $(RTL) $(TB) filelist.f
	$(SIM_CMD) +testname=$(1) -f filelist.f -l $$@
.PHONY: test_$(1)
test_$(1): test_$(1).log
endef
$(foreach t,$(TEST_LIST),$(eval $(call TEST_RULE,$(t))))
# 生成 5 个 test_<name>.log 规则 + 5 个 test_<name> 伪目标
# make test_smoke  test_sanity  test_stress ...
```

## 关键要点

1. **`define`/`endef` 定义多行变量——可包含换行、TAB、变量。**
2. **`$(call ...)` 参数化展开——`$(1)`/`$(2)` 在调用时替换。**
3. **`$(eval ...)` 是运行时 Makefile 代码生成——最后手段。**
4. **`$$` 在 eval 内是基本转义单元——嵌套越深 `$$` 越多。**
5. **调试：先 `$(info $(call ...))`，确认无误再 `$(eval ...)`。**
6. **模式规则 > 静态模式 > foreach+call > foreach+eval ——这个优先级顺序。**

## 与其他概念的关系

- [[tools/concepts/09-Makefile控制函数与诊断函数|09 — 控制与诊断函数]]：`$(foreach)` + `$(eval)` 标准组合
- [[tools/concepts/12-Makefile模式规则|12 — 模式规则]]：优先于 eval
- [[tools/concepts/19-Makefile调试与性能|19 — 调试与性能]]：eval 代码的调试方法

## 小练习

1. **define + call：** 定义 `link_template`, 用 `$(call ...)` 链接程序。
2. **foreach + eval：** 为 `alpha beta gamma` 生成三条伪目标规则。
3. **$$ 层次实验：** eval 内用 `$(VAR)` / `$$(VAR)` / `$$$$`，`$(info)` 观察每层值。
4. **IC 场景：** 为 5 个测试用例用 foreach+eval 生成仿真规则。

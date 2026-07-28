---
type: concept
aliases: [Makefile 高级依赖, order-only double-colon second-expansion]
tags: [tools, makefile, asic]
source_spec: "GNU Make Manual 4.3, 4.13, 3.9"
queries: 1
---

# 15 — Makefile高级依赖

## 学习目标

本篇覆盖 Makefile 依赖管理的三种进阶机制：Order-Only 前置条件（`|`）、双冒号规则（`::`）和二次展开（`.SECONDEXPANSION`）。

## 前置知识

- [[tools/concepts/03-Makefile规则详解|03 — 规则详解]]
- [[tools/concepts/14-Makefile依赖与自动生成|14 — 依赖与自动生成]]

## Order-Only 前置条件：`|`

```makefile
# 普通前置条件：比目标新 → 触发重建
# Order-Only（| 右边）：只检查"是否存在"——不比较时间戳

# 经典场景：构建目录
build/%.o: src/%.c | build/           # build/ 在 | 右边 → order-only
	$(CC) -c $< -o $@                  # build/ 存在即可——不因其时间戳触发重建

build/:
	@mkdir -p $@

# ⚠️ 不用的后果：build/ 是普通前置条件
#   → 每次在 build/ 中创建文件 → build/ 的 mtime 改变 → 所有 .o 重新编译！

# $| 自动变量：配方中引用所有 order-only 前置条件
deploy: app.bin | /var/www/
	cp $< $|                           # $| = /var/www/
```

## 双冒号规则：`::`

```makefile
# 同一目标的多个独立规则——各检查各自的前置条件

log.txt :: $(SIM_LOG)                 # 仿真日志存在时更新
	cp $< $@

log.txt :: $(SYN_LOG)                 # 综合日志存在时也更新
	cat $< >> $@                        # 追加内容

# 极其罕见——99% 场景用普通 : 规则即可
```

## 二次展开：`.SECONDEXPANSION`

```makefile
.SECONDEXPANSION:                      # 前置条件展开两次——第二次在目标更新阶段

# 根据目标的 stem 选择不同的前置条件
SRCS_main := main.c config.c
SRCS_test := test_main.c test_util.c

main: $$(SRCS_$$*)                     # $$* → stem=main → $(SRCS_main)
test: $$(SRCS_$$*)                     # $$* → test → $(SRCS_test)

# 能用 target-specific 变量解决的，不用二次展开
# main: SRCS := main.c config.c        ← 更清晰
```

## 工程决策

| 需求 | 方案 | 优先级 |
|:---|:---|:---|
| 目录存在不触发重建 | Order-Only `|` | ⭐ 标准 |
| 同目标多更新源 | 双冒号 `::` | 极少 |
| stem驱动前置条件 | Target-specific | ⭐ 优先 |
| | `.SECONDEXPANSION` | 最后 |

## 关键要点

1. **Order-Only 仅检查存在性——不比较时间戳。目录创建的标准方案。**
2. **`$|` 在配方中引用 order-only 前置条件。**
3. **双冒号极少使用——99% 场景用 `:` 即可。**
4. **二次展开能用 target-specific 变量替代就不上。**

## 与其他概念的关系

- [[tools/concepts/03-Makefile规则详解|03 — 规则详解]]
- [[tools/concepts/14-Makefile依赖与自动生成|14 — 依赖与自动生成]]
- [[tools/concepts/06-Makefile高级变量|06 — 高级变量]]

## 小练习

1. 有/无 `|` 时mkdir后touch目录内容——观察重建差异。
2. 双冒号两条规则分别触发和同时触发。
3. `$$(SRCS_$$*)` 实现目标驱动的前置条件选择。

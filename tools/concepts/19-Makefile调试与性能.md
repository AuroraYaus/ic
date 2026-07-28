---
type: concept
aliases: [Makefile 调试与性能, trace debug performance shuffle]
tags: [tools, makefile, asic]
source_spec: "GNU Make Manual 9.7, 12.1; --debug --trace --shuffle documentation"
queries: 1
---

# 19 — Makefile调试与性能

## 学习目标

Makefile 没有断点和单步执行——你需要用 `--trace`、`--debug`、诊断函数和性能工具来追踪行为。读完本篇，你应能：

1. 用 `--trace` 和 `--debug` 追踪任何目标的决策过程
2. 嵌入 `$(warning)`/`$(info)` 诊断——区分读阶段和配方阶段
3. 诊断 `$(shell ...)` 的性能开销并优化
4. 用 `--shuffle` 检测并行竞态（GNU Make ≥4.4）
5. 编写跨平台可移植的 Makefile

## `--trace` — 逐规则追踪

```shell
make --trace               # 每条规则执行前打印文件和行号 + 触发原因
```

## `--debug` — 多维度诊断

```shell
make --debug=b             # basic——基本决策
make --debug=v             # verbose——读入了哪些文件
make --debug=i             # implicit——隐含规则搜索
make --debug=j             # jobs——并行 job 管理  
make --debug=m             # remake——依赖文件重建
make --debug=vi            # 组合：verbose + implicit
# 避免 --debug=a ——输出极多，非必要时不用
```

## 嵌入诊断

```makefile
# 读阶段诊断——make -n 也输出
$(info === Building ===)
$(warning CC=$(CC))                  # stderr

# 配方阶段诊断——make -n 不输出
build:
	@printf 'CC=%s\n' '$(CC)'

# 条件式详细输出——V=1 模式
ifdef V
$(info [DEBUG] RTL=$(RTL_FILES))
endif
# make V=1 → 详细；make → 静默
```

## `$(shell ...)` 性能优化

```makefile
# 优化 1：:= 缓存——最常见
SRCS := $(shell find . -name '*.c')    # 一次执行

# 优化 2：$(file ...) 替代 $(shell echo ...)——不 fork
$(file > build/version.txt,$(VERSION))

# 优化 3：合并多次调用为单次
DIRS := $(shell ls src lib)            # 而非两次 $(shell ls ...)
```

## `--shuffle` — 并行竞态检测

```shell
make -j4 --shuffle              # 随机打乱构建顺序——GNU Make ≥4.4
# 正常构建成功 + --shuffle 失败 = 有未声明的依赖
```

## 跨平台可移植性

```makefile
PLATFORM != uname -s                   # Linux / Darwin
ifeq ($(PLATFORM),Darwin)
  NPROC := $(shell sysctl -n hw.ncpu)  # macOS 无 nproc
else
  NPROC := $(shell nproc)
endif
SED_INPLACE := $(if $(filter Darwin,$(PLATFORM)),sed -i '',sed -i)
```

## 调试清单

```text
☐ make --trace         — 为什么（没）被重建？
☐ make --debug=vim     — 读了什么文件？隐含规则匹配？
☐ make -n              — 将执行什么配方？
☐ make -p              — 变量的最终值？
☐ --warn-undefined-variables — 拼写错误？
☐ $(info ...) 嵌入     — 关键位置诊断信息
☐ make -j4 --shuffle   — 并行竞态检测
```

## 关键要点

1. **`--trace` 是第一调试工具——回答"为什么重建/不重建"。**
2. **`--debug=FLAGS` 分类诊断——选对 flag，不 dump `--debug=a`。**
3. **`$(info)` 读阶段，`@echo` 配方阶段——时机不同。**
4. **`$(shell ...)` 用 `:=` 缓存——Make 慢的最常见原因。**
5. **`$(file ...)` 替代 `$(shell echo ...)`——不 fork。**
6. **`--shuffle` + 多次运行 = 竞态检测（GNU Make ≥4.4）。**
7. **`uname -s` 检测平台——命令差异封装到变量。**

## 与其他概念的关系

- [[tools/concepts/09-Makefile控制函数与诊断函数|09]]
- [[tools/concepts/05-Makefile变量赋值与展开|05]]
- [[tools/concepts/04-Makefile配方与Shell|04]]

## 小练习

1. `make --trace` 追踪多目标项目
2. `$(shell ...)` `=` vs `:=`——`time make` 对比
3. `--shuffle` 重复 10 次——检查非确定性故障
4. 检测你的平台：`uname -s` + 默认 `SHELL`

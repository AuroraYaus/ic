---
type: concept
aliases: [Makefile 常见错误50例, error catalog]
tags: [tools, makefile, asic]
source_spec: "GNU Make Manual; collective Makefile debugging experience"
queries: 1
---

# 24 — Makefile常见错误50例

## 第一类：语法/格式（10例）

| # | 现象 | 根因 | 修复 |
|:---|:---|:---|:---|
| 1 | `missing separator` | 空格非TAB | 用TAB；`cat -A`检查 |
| 2 | IDE TAB→空格 | 编辑器设置 | `noexpandtab` |
| 3 | `ifeq` 被当配方 | 条件缩进了 | 顶格写 |
| 4 | 续行`\`后有空格 | 不可见字符 | `cat -A` |
| 5 | `$VAR` 空 | 漏`()` | `$(VAR)` |
| 6 | 变量名含空格 | `= ? +`前有空格 | 紧接操作符 |
| 7 | define内TAB乱 | 模板TAB被吃 | 检查define块 |
| 8 | 配方间空行含TAB | Make视为空配方 | 完全空行 |
| 9 | 末行无换行 | 最后一行被忽略 | 加末尾空行 |
| 10 | `#`评论在配方 | Make不做注释 | 行首或用`: 'comment'` |

## 第二类：变量展开（12例）

| # | 现象 | 根因 | 修复 |
|:---|:---|:---|:---|
| 11 | 递归死循环 | X=$(Y); Y=$(X) | 用`:=`或重排 |
| 12 | `$(shell)`执行N次 | 用`=`定义 | 改用`:=` |
| 13 | `+=`也延迟 | 基础变量是`=` | 改基础为`:=` |
| 14 | `$@`在定义中空 | 自动变量仅配方有效 | 配方或target-specific |
| 15 | 拼写错误静默 | `$(CFLAG)`≠`$(CFLAGS)` | `--warn-undefined-variables` |
| 16 | export泄露 | 全局export | 仅export需共享的 |
| 17 | 命令行覆盖失败 | 用了override | override阻止覆盖 |
| 18 | 条件中未定义变量 | `ifeq ($(UNDEF),val)` | 先定义或检测`$(origin)` |
| 19 | origin返回值误读 | `environment`≠`environment override` | -e才返回后者 |
| 20 | `$$`层数错 | eval内需`$$$$` | 逐层加倍 |
| 21 | target-specific意外传播 | 传播到前置条件 | pattern-specific |
| 22 | `$<`取第一个 | 多前置条件 | 用`$^`取全部 |

## 第三类：依赖/目标（10例）

| # | 现象 | 根因 | 修复 |
|:---|:---|:---|:---|
| 23 | 目标与目录同名跳过 | 无.PHONY | 加.PHONY |
| 24 | clean被跳过 | 忘.PHONY | 所有动作加.PHONY |
| 25 | order-only写普通| `|`写成空格 | 目录用`| dir/` |
| 26 | `%`匹配不该匹配的 | 规则太宽 | 静态模式 |
| 27 | 隐含规则悄悄编译 | 未禁用 | `make -r` |
| 28 | VPATH选错同名文件 | 搜索序+同名 | `vpath`精确 |
| 29 | 循环依赖 | DAG建模错 | 加中间目标 |
| 30 | 不存在的头文件报错 | 忘`-MP` | 加`-MP` |
| 31 | .d+目标同配方失败 | 配方半途失败 | 两步或`&:` |
| 32 | include remake后不一致 | 旧缓存 | 检查MAKE_RESTARTS |

## 第四类：并行陷阱（8例）

| # | 现象 | 根因 | 修复 |
|:---|:---|:---|:---|
| 33 | 竞争写同一文件 | 未声明依赖 | 加依赖或.NOTPARALLEL |
| 34 | mkdir竞态 | 并发mkdir | order-only目录 |
| 35 | ar索引损坏 | 并发ar | 串行化 |
| 36 | .NOTPARALLEL误全局 | 全局禁用 | 特定目标禁用 |
| 37 | 输出交错乱码 | 无output-sync | `--output-sync=target` |
| 38 | clean+编译并发 | 删在用文件 | 不并行clean |
| 39 | shell并行序不定 | 执行序不确定 | `:=`缓存 |
| 40 | 子Make丢`-j` | 硬编码make | 用`$(MAKE)` |

## 第五类：跨平台（5例）

| # | 现象 | 根因 | 修复 |
|:---|:---|:---|:---|
| 41 | `sed -i`不同 | macOS需`-i ''` | 变量封装 |
| 42 | 路径分隔符 | Windows `\` | 始终`/` |
| 43 | `echo -n`差异 | POSIX非标准 | 用`printf` |
| 44 | /bin/sh差异 | dash≠bash | `SHELL:=/bin/bash` |
| 45 | 大小写 | macOS不敏感 | 统一小写 |

## 第六类：性能（5例）

| # | 现象 | 根因 | 修复 |
|:---|:---|:---|:---|
| 46 | find每次扫描 | `=`延迟展开 | `:=` |
| 47 | eval在配方内 | 每次执行eval | eval放读阶段 |
| 48 | -j过大I/O颠簸 | 并行度>带宽 | `-l 6`限制 |
| 49 | 不必要递归序列化 | 架构选错 | include式 |
| 50 | wildcard频繁调用 | 每次引用重扫 | `:=`缓存 |

## 关键要点

1. 50例6类：语法10+变量12+依赖10+并行8+跨平台5+性能5
2. TAB和`$$`是最高频根因
3. `:=` vs `=` 是第二高频——`$(shell)`性能问题几乎都源于此
4. `.PHONY` 忘记是第三高频
5. `--warn-undefined-variables` + `--trace` + `make -n` = 80%诊断覆盖

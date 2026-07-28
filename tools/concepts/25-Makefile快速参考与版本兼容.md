---
type: concept
aliases: [Makefile 快速参考与版本兼容, cheat-sheet]
tags: [tools, makefile, asic]
source_spec: "GNU Make Manual; GNU Make 4.3/4.4 changelog; BSD/POSIX make"
queries: 1
---

# 25 — Makefile快速参考与版本兼容

## 变量类型

| 符 | 名称 | 展开时机 |
|:---|:---|:---|
| `=` | 递归 | 每次引用 |
| `:=` | 简单 | 赋值瞬间 |
| `?=` | 条件 | 仅未定义时 |
| `!=` | Shell | 赋值瞬间(≥4.0) |
| `+=` | 追加 | 取决于原flavor |

## 自动变量

| 变量 | 展开为 | 助记 |
|:---|:---|:---|
| `$@` | 目标 | @=target |
| `$<` | 首前置 | <=first |
| `$^` | 全部(去重) | ^=all |
| `$?` | 更新的那些 | ?=newer |
| `$+` | 全部(含重复) | +=all+dupes |
| `$*` | 茎(stem) | *=stem |
| `$%` | 库成员 | %=member |
| `$|` | Order-only | \|=pipe |

## 函数速查

**文本：** `subst` `patsubst` `strip` `findstring` `filter` `filter-out` `sort` `word` `wordlist` `words` `firstword` `lastword` `join`

**路径：** `dir` `notdir` `suffix` `basename` `addprefix` `addsuffix` `wildcard` `realpath` `abspath` `file`

**控制：** `if` `or` `and` `foreach` `call` `eval` `shell`

**诊断：** `info` `warning` `error` `origin` `flavor` `value`

## 特殊目标

| 目标 | 作用 |
|:---|:---|
| `.PHONY` | 伪目标 |
| `.ONESHELL` | 单Shell |
| `.DELETE_ON_ERROR` | 失败删目标 |
| `.NOTPARALLEL` | 禁用并行 |
| `.SECONDARY` | 保留中间文件 |
| `.SECONDEXPANSION` | 二次展开 |
| `.PRECIOUS` | 保留+失败不删 |
| `.DEFAULT` | 默认回退配方 |

## 命令行选项

| 选项 | 作用 |
|:---|:---|
| `-j [N]` | 并行 |
| `-k` | 错误后继续 |
| `-n` | dry-run |
| `-B` | 无条件重建 |
| `-C dir` | 切目录 |
| `-f file` | 指定Makefile |
| `-e` | 环境覆盖 |
| `-r/-R` | 禁用隐含规则/变量 |
| `--trace` | 逐规则追踪 |
| `--debug=F` | b/v/i/j/m |
| `-p` | 打印数据库 |
| `--warn-undefined-variables` | 未定义警告 |
| `--output-sync` | 并行输出同步 |
| `--shuffle` | 打乱(≥4.4) |

## 版本兼容

| 特性 | GNU 4.3 | ≥4.4 | BSD | POSIX |
|:---|:---|:---|:---|:---|
| `:=` `?=` `!=` | ✅ | ✅ | ✅ | ❌ |
| `$(shell)` | ✅ | ✅ | ✅ | ❌ |
| `$(file)` | ✅ | ✅ | ❌ | ❌ |
| `$(eval)` | ✅ | ✅ | ❌ | ❌ |
| `&:` grouped | ≥4.3 | ✅ | ❌ | ❌ |
| `.ONESHELL` | ✅ | ✅ | ❌ | ❌ |
| `.SECONDEXPANSION` | ✅ | ✅ | ❌ | ❌ |
| `--shuffle` | ❌ | ✅ | ❌ | ❌ |
| `$(origin)` `$(flavor)` | ✅ | ✅ | ❌ | ❌ |
| `VPATH` `.PHONY` `%` | ✅ | ✅ | ✅ | ✅ |

## 常用模板

```makefile
# C编译+自动依赖
%.o: %.c; $(CC) -MMD -MP -MF $(@:.o=.d) -MT $@ $(CFLAGS) -c $< -o $@

# 递归Make
$(SUBDIRS): ; $(MAKE) -C $@

# IC仿真
log/%.log: $(RTL) filelist.f
	@mkdir -p log
	$(SIM_CMD) +testname=$* +seed=$(SEED) -f filelist.f -l $@ \
		&& printf 'PASS\n' >> $@ || { printf 'FAIL\n' >> $@; exit 1; }

# 变量诊断
print-var-%: ; @printf '%s=%s\n' '$*' '$($*)'

# 帮助
help: ; @grep '^\.PHONY:' Makefile | sed 's/\.PHONY: //'
```

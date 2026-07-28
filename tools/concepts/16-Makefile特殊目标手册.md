---
type: concept
aliases: [Makefile 特殊目标手册, Special targets .PHONY .ONESHELL .DELETE_ON_ERROR]
tags: [tools, makefile, asic]
source_spec: "GNU Make Manual 4.9: Special Built-in Target Names"
queries: 1
---

# 16 — Makefile特殊目标手册

## 学习目标

GNU Make 提供 13 个特殊目标（以 `.` 开头），每个改变 Make 的全局行为。本篇逐一讲解用法、触发条件和误用。

## 完整清单

| 特殊目标 | 作用 | 常用度 |
|:---|:---|:---|
| `.PHONY` | 声明伪目标——永远执行 | ⭐⭐⭐⭐⭐ |
| `.ONESHELL` | 一个 Shell 执行整条规则配方 | ⭐⭐⭐ |
| `.DELETE_ON_ERROR` | 构建失败自动删除目标 | ⭐⭐⭐⭐ |
| `.NOTPARALLEL` | 禁用并行（全局/特定目标） | ⭐⭐ |
| `.SECONDARY` | 保留中间文件（失败仍删除） | ⭐⭐ |
| `.PRECIOUS` | 保留中间文件（失败不删除） | ⭐ |
| `.INTERMEDIATE` | 标记为中间文件 | ⭐ |
| `.DEFAULT` | 无规则匹配时的默认配方 | ⭐ |
| `.IGNORE` | 全局忽略错误 | ❌ 危险 |
| `.SILENT` | 全局静默 | ❌ 调试不便 |
| `.SUFFIXES` | 后缀规则声明 | 遗留 |
| `.POSIX` | 严格 POSIX 模式 | 极少 |
| `.RECIPEPREFIX` | 换配方前缀字符 | 极少 |

## 重点展开

### `.DELETE_ON_ERROR`
```makefile
.DELETE_ON_ERROR:                      # 全局启用——推荐
# 任何目标构建失败 → 自动删除目标文件
# 防止残次文件被误判为"已最新"→ 下次 make 跳过
```

### `.NOTPARALLEL`
```makefile
.NOTPARALLEL:                          # 全局禁用 -j
.NOTPARALLEL: slow-db slow-net         # 仅这些目标串行
```

### `.PRECIOUS` vs `.SECONDARY`
```makefile
# .PRECIOUS: 保留 + 配方失败也不删除（保护现有版本）
.PRECIOUS: %.o

# .SECONDARY: 保留 + 配方失败仍删除（不留残次品）← 一般推荐
.SECONDARY: %.o
```

### `.DEFAULT`
```makefile
.DEFAULT:
	@printf 'No rule for %s\n' '$@'   # Make 找不到任何规则时的回退
```

## 推荐组合

```makefile
.DELETE_ON_ERROR:                      # 清理残次产物——推荐所有项目使用
# .ONESHELL 仅在确实需要时启用——且必须配 .SHELLFLAGS := -ec
# .NOTPARALLEL 仅在特定目标需要独占资源时使用
```

## 关键要点

1. `.PHONY` / `.DELETE_ON_ERROR` / `.ONESHELL` 最常用
2. `.DELETE_ON_ERROR` 推荐全局启用——零代价
3. `.ONESHELL` 必须配 `-e`（errexit）
4. `.NOTPARALLEL` 可作用于特定目标——比全局禁用更精确
5. `.SECONDARY` 优先于 `.PRECIOUS`——安全性更好
6. `.IGNORE` / `.SILENT` 几乎从不使用

## 与其他概念的关系

- [[tools/concepts/01-Makefile解决的问题与第一个例子|01]] — `.PHONY`
- [[tools/concepts/04-Makefile配方与Shell|04]] — `.ONESHELL` `.DELETE_ON_ERROR`
- [[tools/concepts/13-Makefile隐含规则|13]] — `.SUFFIXES`

## 小练习

1. `.DELETE_ON_ERROR` 有/无时失败配方的目标残留对比
2. `.NOTPARALLEL` 特定目标串行验证
3. `.SECONDARY` vs `.PRECIOUS`——失败时行为差异

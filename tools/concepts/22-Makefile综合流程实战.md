---
type: concept
aliases: [Makefile 综合流程实战, DC Genus multi-corner synthesis]
tags: [tools, makefile, asic]
source_spec: "Synopsys DC User Guide; Cadence Genus User Guide"
queries: 1
---

# 22 — Makefile综合流程实战

## 学习目标

ASIC 综合流的 Makefile 封装——DC/Genus 命令封装、多 Corner 并行、报告自动化、ECO 回注。默认 mock 命令。

## Mock 骨架

```makefile
SYNTH := dc_shell                      # dc_shell / genus
CORNERS := typ_1p2 slow_0p9 fast_1p3
DESIGN ?= top
RTL := $(wildcard rtl/*.sv)

# 每个 Corner 的产物
NETLISTS  := $(patsubst %,syn/%/$(DESIGN).v,$(CORNERS))
QOR_RPTS  := $(patsubst %,syn/%/qor.rpt,$(CORNERS))
AREA_RPTS := $(patsubst %,syn/%/area.rpt,$(CORNERS))
TIME_RPTS := $(patsubst %,syn/%/timing.rpt,$(CORNERS))

.PHONY: all syn reports eco clean
all: syn
syn: $(NETLISTS)                        # 所有 Corner 并行

# 每个 Corner 独立综合——无共享依赖 → -j 安全
syn/%/$(DESIGN).v: $(RTL) constraints/%.sdc scripts/syn.tcl
	@mkdir -p $(@D)
	$(SYNTH) -f scripts/syn.tcl \
		-x "set DESIGN $(DESIGN); set CORNER $*; set OUTDIR $(@D)" \
		> $(@D)/syn.log 2>&1 \
		&& printf 'PASS\n' >> $(@D)/syn.log \
		|| { printf 'FAIL\n' >> $(@D)/syn.log; exit 1; }

# 报告——每个 Corner 提取
syn/%/qor.rpt syn/%/area.rpt syn/%/timing.rpt: syn/%/$(DESIGN).v
	@printf 'report for $(DESIGN) @ $*\n' > $@

reports: $(QOR_RPTS) $(AREA_RPTS) $(TIME_RPTS)
	@printf 'Reports done for %d corners\n' $(words $(CORNERS))

# ECO 回注
eco: ECO_SCRIPT ?= scripts/eco.tcl
eco: syn/eco/$(DESIGN).v
syn/eco/$(DESIGN).v: syn/typ_1p2/$(DESIGN).v $(ECO_SCRIPT)
	@mkdir -p $(@D); $(SYNTH) -f $(ECO_SCRIPT) > $(@D)/eco.log 2>&1

clean:; rm -rf syn/
```

## 使用

```shell
make syn -j4                    # 4 Corner 并行
make reports                    # 汇总报告
make eco ECO_SCRIPT=scripts/fix.tcl
make DESIGN=alu CORNERS="typ slow" syn
```

## 工程要点

| 要点 | 实现 |
|:---|:---|
| 多 Corner 并行 | 各 Corner 独立目录——`-j` 安全 |
| 报告自动化 | `$(patsubst ...)` 批量生成报告路径 |
| ECO 增量 | 依赖已有综合结果 |
| Mock | `$(SYNTH)` → `echo` 可 dry-run |

## 关键要点

1. 独立输出目录 = 并行安全 + 无冲突
2. `$*` = Corner 名——匹配约束文件
3. `$(patsubst ...)` 批量生成路径
4. ECO 依赖基线综合——增量构建
5. Mock 无工具可验证

## 与其他概念的关系

- [[tools/concepts/12-Makefile模式规则|Makefile模式规则]] `$*` 模式匹配
- [[tools/concepts/21-Makefile仿真回归实战|Makefile仿真回归实战]] 并行模式
- [[tools/concepts/23-MakefileIC项目构建实战|MakefileIC项目构建实战]] 流程集成

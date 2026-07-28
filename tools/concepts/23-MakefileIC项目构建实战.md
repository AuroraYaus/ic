---
type: concept
aliases: [Makefile IC项目构建, ASIC project IP management config.mk]
tags: [tools, makefile, asic]
source_spec: "EDA flow integration practices"
queries: 1
---

# 23 — MakefileIC项目构建实战

## 学习目标

层次化 IC 项目的 Makefile 框架：IP 库管理、跨 IP 依赖、统一流程入口、`.config.mk` 配置模式和 CI 退出码规范。

## 项目结构

```
chip/
├── Makefile                     # 顶层流程入口
├── .config.mk                   # 全局配置
├── ips/{cpu,gpu,uart}/module.mk # 各 IP 声明 RTL
└── flows/{sim,syn,sta}.mk       # 流程定义
```

## `.config.mk`

```makefile
DESIGN_TOP ?= top_chip
SIMULATOR  ?= questa
TECH_NODE  ?= 28nm
ENABLED_IPS := cpu gpu uart dma
```

## 顶层 Makefile

```makefile
include .config.mk
include $(patsubst %,ips/%/module.mk,$(ENABLED_IPS))
include flows/sim.mk flows/syn.mk flows/sta.mk

.PHONY: sim syn sta all clean release
sim: log/smoke.log; syn: syn/$(DESIGN_TOP).v; sta: sta/timing.rpt
all: sim syn sta

# 版本发布
VERSION ?= $(shell git describe --tags 2>/dev/null || echo "0.0.0")
release: all
	@mkdir -p releases/$(VERSION)
	@cp syn/$(DESIGN_TOP).v sta/timing.rpt releases/$(VERSION)/

# CI 退出码：0=通过 1=失败 2=环境错误
check-env:
	@which $(SIMULATOR) >/dev/null 2>&1 || { printf 'ERROR: not found\n'; exit 2; }

clean:; rm -rf log/ syn/ sta/ cov/ releases/
```

## IP 模块定义

```makefile
# ips/cpu/module.mk
cpu_RTL := ips/cpu/rtl/cpu_core.sv ips/cpu/rtl/cpu_alu.sv
cpu_TB  := ips/cpu/tb/cpu_tb.sv
cpu_DEPS := ips/gpu/module.mk           # 跨 IP 依赖
```

## 流程定义

```makefile
# flows/sim.mk
ALL_RTL := $(foreach ip,$(ENABLED_IPS),$($(ip)_RTL))
FILELIST := filelist.f
$(FILELIST): $(ALL_RTL); @for f in $^; do echo $$f >> $@; done
log/smoke.log: $(FILELIST)
	@mkdir -p log; vsim -c -f $< -l $@ && printf 'PASS\n' >> $@
```

## 使用

```shell
make check-env && make sim
make all -j8
make ENABLED_IPS="cpu uart" sim
make release VERSION=1.0.0
```

## 关键要点

1. **`.config.mk` 单一配置源——所有变量和开关集中管理。**
2. **IP 模块化——增删 IP 只改 `ENABLED_IPS` 列表。**
3. **`$(foreach ip,$(ENABLED_IPS),$($(ip)_RTL))`——动态收集所有 IP 文件。**
4. **流程独立文件——可单独测试。**
5. **CI 退出码三态——环境错误(2) ≠ 构建失败(1)。**

## 与其他概念的关系

- [[tools/concepts/18-Makefile递归与大型项目|Makefile递归与大型项目]]
- [[tools/concepts/21-Makefile仿真回归实战|Makefile仿真回归实战]]
- [[tools/concepts/22-Makefile综合流程实战|Makefile综合流程实战]]

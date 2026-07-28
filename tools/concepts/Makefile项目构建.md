---
type: concept
aliases:
  - Makefile SoC Project Build
  - make 项目构建
  - Makefile for IC Project
tags:
  - tools
  - makefile
  - asic-flow
  - verification
  - project-management
source_spec: "GNU Make Manual Chapter 5.7: Recursive Use of Make; Synopsys DC User Guide; uvm-memory and axi4-interconnect project Makefiles"
queries: 1
---

# Makefile 项目构建

SoC 项目通常包含多个子系统：RTL 设计、验证环境、综合脚本、形式验证、DFT 插入、后端物理设计等。每个子系统有自己的文件集、工具链和执行流程。如果所有流程的 Makefile 杂糅在一个文件中，很快就会成为无法维护的"意大利面条式 Makefile"。

本文介绍数字IC项目的层次化 Makefile 架构——如何用**递归 Make** + **统一入口**的模式组织项目级构建系统，使仿真工程师、综合工程师、验证工程师各自维护自己子系统的 Makefile，同时整个项目可通过顶层 `make` 一键构建。

## 原理

### 层次化 Makefile 架构

```
project/
├── Makefile                  # 顶层统一入口
├── sim/
│   ├── Makefile              # 仿真子系统
│   ├── Makefile.vcs          # VCS 专用配置（被 include 引入）
│   ├── Makefile.questa       # Questa 专用配置
│   └── tests/
│       └── Makefile          # 测试列表 + 回归规则
├── syn/
│   ├── Makefile              # 综合子系统
│   ├── scripts/
│   │   ├── syn_common.tcl
│   │   └── constraints/      # SDC 约束文件
│   └── outputs/              # 综合产物输出目录
├── formal/
│   └── Makefile              # 形式验证子系统
├── dft/
│   └── Makefile              # DFT 子系统
├── rtl/
│   └── filelist.f            # RTL 文件列表（所有子系统 include 同一个文件）
└── scripts/
    ├── common.mk             # 共享变量和函数定义
    └── check_env.py          # 环境检查脚本
```

### 顶层 Makefile：统一入口

```makefile
# ===== 顶层 Makefile：SoC 项目构建统一入口 =====
# 职责：(1) 环境检查 (2) 导出全局变量 (3) 按需分发到子系统

# --- include 共享配置 ---
include scripts/common.mk             # 所有子系统共享的变量和函数

# --- 全局变量 ---
export TOP_MODULE := chip_top         # 顶层模块名（传给 sim/syn 的 TCL 脚本）
export RTL_DIR     := $(CURDIR)/rtl   # RTL 源文件根目录
export OUT_BASE    := $(CURDIR)/outputs  # 统一输出根目录

# --- 环境检查 ---
.PHONY: check_env
check_env:
	@python3 scripts/check_env.py     # 检查 DC/Questa/VCS 是否在 PATH 中
#       如果工具缺失，打印错误并 exit 1 → Make 在构建前终止

# --- 子系统分发 ---
.PHONY: all clean

all: sim syn formal dft              # 一键构建所有子系统

sim: check_env                       # sim 依赖环境检查
	$(MAKE) -C sim                    # 进入 sim/ 目录执行 Make

syn: sim                             # syn 依赖 sim 先通过（门控：仿真不过不跑综合）
	@echo "=== Starting synthesis flow ==="
	$(MAKE) -C syn

formal: syn                          # formal 依赖 syn（需要综合后的门级网表）
	$(MAKE) -C formal

dft: syn                             # DFT 依赖 syn（在门级网表上插入扫描链）
	$(MAKE) -C dft

# --- 递归清理 ---
clean:
	for dir in sim syn formal dft; do \
		$(MAKE) -C $$dir clean; \
	done
	rm -rf $(OUT_BASE)
```

### 共享配置文件

```makefile
# ===== scripts/common.mk：全局共享变量和函数 =====
# 被所有子系统 Makefile include 引入
# 核心理念：DRY——RTL_FILELIST 在项目中只定义一次

# --- 项目级参数 ---
TOP_MODULE    ?= chip_top             # 顶层模块名（可在命令行覆盖）
CLK_PERIOD_NS ?= 2.0                  # 默认时钟周期 2.0ns（500MHz）
RTL_FILELIST  := $(CURDIR)/rtl/filelist.f  # RTL 文件列表——所有工具共用

# --- 工具链检测（自动选择可用的仿真器） ---
HAS_VCS    := $(shell which vcs 2>/dev/null)
HAS_QUESTA := $(shell which vsim 2>/dev/null)

ifeq ($(HAS_VCS),)
    ifeq ($(HAS_QUESTA),)
        SIMULATOR ?= verilator         # 都没有 → 开源 Verilator
    else
        SIMULATOR ?= questa            # Questa 可用
    endif
else
    SIMULATOR ?= vcs                   # VCS 可用（优先级最高）
endif

# --- 时间戳（用于报告文件命名） ---
TIMESTAMP := $(shell date +%Y%m%d_%H%M%S)

# --- 颜色化输出 ---
C_GREEN  := \033[32m                   # ANSI 绿色
C_RED    := \033[31m                   # ANSI 红色
C_RESET  := \033[0m                    # 重置颜色

# --- 阶段报告函数 ---
define phase_report
	@echo "$(C_GREEN)[$(1)]$(C_RESET) Starting at $$(date)"
endef
# 用法: $(call phase_report, SIM) → 打印 "[SIM] Starting at Mon Jul 28 14:30:00"
```

### 仿真子系统 Makefile

```makefile
# ===== sim/Makefile：仿真子系统 =====
include ../scripts/common.mk

# include 工具链专用配置（按 SIMULATOR 变量选择）
ifeq ($(SIMULATOR), vcs)
    include Makefile.vcs               # VCS 命令行参数和流程
else ifeq ($(SIMULATOR), questa)
    include Makefile.questa            # Questa 命令行参数和流程
else
    include Makefile.verilator         # Verilator 命令行参数和流程
endif
# 各工具链片段导出统一的目标名 SIM_TARGET 和 SIM_CMD

RTL_SRCS := $(shell cat $(RTL_FILELIST))  # 从文件列表读入所有 RTL 源文件
TB_SRCS  := $(wildcard tb_*.sv)
TESTS    := $(shell grep -v '^#' tests/testlist.txt)

.PHONY: regress
regress: $(SIM_TARGET)
	$(MAKE) -C tests -j$(NPROC)        # 递归到 tests/ 并行运行

.PHONY: test_%
test_%: $(SIM_TARGET)                  # make test_basic 启动单个测试
	$(SIM_CMD) +UVM_TESTNAME=$*

.PHONY: clean
clean:
	rm -rf simv* work obj_dir *.log *.ucdb
```

### 综合子系统 Makefile

```makefile
# ===== syn/Makefile：综合子系统 =====
include ../scripts/common.mk

DC_SHELL   := dc_shell -64bit
RTL_SRCS   := $(shell cat $(RTL_FILELIST))
CORNERS    := ss_0p81v_m40c tt_0p90v_25c ff_0p99v_125c
NETLISTS   := $(foreach c, $(CORNERS), outputs/corner_$(c)_syn.v)

.PHONY: all
all: $(NETLISTS) check_all_timing

# 模式规则：一个 Corner → 一个综合目标
outputs/corner_%_syn.v: $(RTL_SRCS) scripts/constraints/%.sdc
	@$(call phase_report, SYN:$*)
	export CORNER=$*; \
	$(DC_SHELL) -f scripts/syn_common.tcl | tee outputs/logs/syn_$*.log

# 跨 Corner 时序汇总
.PHONY: check_all_timing
check_all_timing: $(NETLISTS)
	@python3 ../scripts/summarize_timing.py outputs/reports/*_timing.rpt

.PHONY: clean
clean:
	rm -rf outputs/
```

### 依赖关系管理：工作流约束

```makefile
# ===== 子系统间依赖体现了项目工作流约束 =====
# sim → syn:   RTL 必须通过仿真验证才能开始综合
# syn → formal: 形式验证需要综合后的门级网表
# syn → dft:   DFT 插入在综合后的网表上进行

# 依赖是 AND 逻辑——如果 sim 失败，syn 不会执行
# 这正是正确的门控行为：不通过仿真的 RTL 不应该被综合

# --- 快速模式：跳过门控（调试用） ---
# make syn FAST=1 → 跳过 sim 依赖（用于调试综合脚本本身）
ifeq ($(FAST),)
syn: sim             # 默认模式：sim 是 syn 的前置条件
else
syn:                 # FAST=1 时 syn 独立构建，无前置条件
endif
```

## 关键要点

1. **统一 RTL 文件列表是减少配置漂移的唯一方式**——所有子系统 include 同一个 `filelist.f`，新增文件只需改一处
2. **顶层 Makefile 是"交通指挥"而非"执行者"**——不写具体工具命令，只做 `$(MAKE) -C <subsystem>`
3. **子系统间依赖体现了工作流约束**——`sim → syn → formal/dft`，Make 保证不合规代码不流入下一阶段
4. **工具链配置隔离到独立文件**——`Makefile.vcs` / `Makefile.questa` 分别 include，按 `SIMULATOR` 变量选择
5. **`include common.mk` 是 DRY 的核心**——项目级变量只定义一次
6. **环境检查是鲁棒性的第一道防线**——`check_env.py` 在一切开始前验证工具链可用性
7. **提供"快速模式"绕过不必要的门控**——`make syn FAST=1` 用于调试脚本而非正常流程

## 与其他概念的关系

- [[tools/concepts/Makefile实战项目|Makefile 实战项目]]——递归 Make 和层次化组织是本文的通用基础
- [[tools/concepts/Makefile仿真回归|Makefile 仿真回归]]——sim/ 子系统是仿真回归篇的实例化
- [[tools/concepts/Makefile综合流程|Makefile 综合流程]]——syn/ 子系统是综合流程篇的实例化
- [[asic-flow/ASIC流程|ASIC 实现流程]]——`sim → syn → dft → formal` 对应 ASIC 实现的标准阶段顺序

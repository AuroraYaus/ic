---
type: concept
aliases:
  - Makefile Simulation Regression
  - make 仿真回归
  - Makefile for EDA Simulation
tags:
  - tools
  - makefile
  - verification
  - simulation
  - regression
source_spec: "Synopsys VCS User Guide; Mentor Questa SIM User Manual; Verilator Manual"
queries: 1
---

# Makefile 仿真回归

仿真回归（Simulation Regression）是数字IC验证中最耗时的环节——每次 RTL 修改后，成千上万个测试用例需要重新运行以确保没有引入新的功能缺陷。Makefile 是整个回归流程的**调度引擎**：它决定哪些测试因为 RTL 变更需要重新运行（增量回归），并行启动多个仿真进程（`-j`），收集每个测试的结果，最后汇总覆盖率。

与 C 项目 Makefile 的"编译→链接→执行"不同，IC 仿真 Makefile 的核心任务是**管理依赖链和调度异构工具**——同样的 RTL 代码可能需要在 VCS、Questa、Verilator 三个仿真器上运行，每个工具的命令行参数、波形格式、覆盖率数据库完全不同。

## 原理

### 仿真回归的依赖模型

```makefile
# ===== 仿真回归的依赖模型 =====
# 核心依赖链：
#   仿真日志(.log) ← 仿真可执行文件(simv) ← 编译后设计库 ← RTL源文件(.sv/.v)
#
# 增量回归的判断逻辑：
#   如果 RTL 源文件比仿真日志新 → 重新编译 + 重新运行此测试
#   如果 RTL 源文件没变 → 跳过（日志文件已是最新）
```

### 多工具链 Makefile 模板

```makefile
# ===== 多工具链仿真回归 Makefile =====
# 支持 VCS（Synopsys）、Questa（Mentor/Siemens）、Verilator（开源）
# 通过 SIMULATOR 变量切换，默认用 VCS

# --- 工具链配置 ---
SIMULATOR ?= vcs                    # 默认仿真器（make SIMULATOR=questa 覆盖）

# --- VCS 配置 ---
VCS      := vcs                     # VCS 编译命令
VCS_OPTS := -sverilog -full64 -ntb_opts uvm-1.2 +define+SIMULATION
#           ^^^^^^^^^  ^^^^^^  ^^^^^^^^^^^^^^^^^  ^^^^^^^^^^^^^^^^
#           SV支持      64-bit  UVM 1.2库         预定义宏（在RTL中用于ifdef）
SIMV     := ./simv                  # VCS 生成的可执行仿真文件

# --- Questa 配置 ---
VSIM     := vsim                   # Questa 仿真命令
VLOG     := vlog                   # Questa 编译命令
VLOG_OPTS := -sv -lint=all +define+SIMULATION

# --- Verilator 配置 ---
VERILATOR := verilator
VERILATOR_OPTS := --cc --sv --timing --build --Mdir obj_dir

# --- 设计源文件 ---
RTL_DIR  := ../rtl
TB_DIR   := .
RTL_SRCS := $(wildcard $(RTL_DIR)/*.sv $(RTL_DIR)/*.v)
TB_SRCS  := $(wildcard $(TB_DIR)/tb_*.sv)
ALL_SRCS := $(RTL_SRCS) $(TB_SRCS)

# --- 测试用例列表 ---
TESTS    := test_basic test_burst test_error test_random
LOGS     := $(addsuffix .log, $(TESTS))  # test_basic.log test_burst.log ...

# --- 默认目标 ---
.PHONY: all
all: $(LOGS)                        # 运行所有测试
	@python3 ./regress_report.py *.log  # Python 汇总报告

# ===== VCS 流程 =====
ifeq ($(SIMULATOR), vcs)
# VCS 编译：所有 RTL + TB 源文件 → simv
$(SIMV): $(ALL_SRCS)
	$(VCS) $(VCS_OPTS) -o $(SIMV) $(ALL_SRCS)

# 对每个测试，运行 simv +UVM_TESTNAME=xxx → 重定向到 .log
%.log: $(SIMV)
	$(SIMV) +UVM_TESTNAME=$(basename $@) -l $@
#            ^^^^^^^^^^^^^^^^^^^^^^^^^ ^^   ^^
#            UVM运行时指定test类名        -l: VCS日志重定向
endif

# --- Questa 流程 ---
ifeq ($(SIMULATOR), questa)
work/_vmake: $(ALL_SRCS)
	$(VLOG) $(VLOG_OPTS) $(ALL_SRCS)

%.log: work/_vmake
	$(VSIM) -c -do "run -all; quit" $(basename $@) | tee $@
#         ^^                    ^^
#         -c: 命令行模式（无GUI）  -do "...": TCL脚本——运行后退出
endif

# --- Verilator 流程 ---
ifeq ($(SIMULATOR), verilator)
obj_dir/Vtop: $(ALL_SRCS)
	$(VERILATOR) $(VERILATOR_OPTS) $(ALL_SRCS)

%.log: obj_dir/Vtop
	./obj_dir/Vtop +UVM_TESTNAME=$(basename $@) | tee $@
endif

# ===== 覆盖率合并与报告 =====
.PHONY: coverage
coverage:
ifeq ($(SIMULATOR), vcs)
	urg -dir simv.vdb -report coverage_report
#       ^^^^^^^^^^^^^  ^^^^^^^^^^^^^^^^^^^^^^^
#       VCS覆盖数据库    输出报告目录（HTML + 文本）
else ifeq ($(SIMULATOR), questa)
	vcover merge merged.ucdb *.ucdb       # 合并各测试覆盖率数据库
	vcover report -html merged.ucdb        # 生成 HTML 报告
endif

# ===== 清理 =====
.PHONY: clean
clean:
	rm -rf simv* *.log *.ucdb coverage_report obj_dir work *.vcd *.fsdb
```

### 并行回归与结果收集

```makefile
# ===== 并行回归 + 结果汇总 =====

# 各测试的 .log 文件之间无依赖关系——可以完全并行
# make -j8: 同时运行 8 个测试
# make -j$(nproc): 自动使用全部 CPU 核

# --- 结果收集：Makefile 调度 + Python 分析 ---
# 正确分工：
#   Makefile → 决定"运行哪些测试"和"以什么顺序/并行度运行"
#   Python/Perl → 解析日志文本、统计错误、生成报告
#
# 为什么不在 Makefile 中做文本分析？
#   $(shell grep ...) 返回值有长度限制、条件逻辑弱、格式化困难
#   正确的分工：Makefile 负责调度，脚本语言负责数据分析
```

### 增量回归策略

```makefile
# ===== 增量回归 =====
# 策略 1：基于 Make 依赖的自然增量（推荐日常使用）
#   Make 自动比较 .log 和 RTL .sv 的时间戳：
#   RTL 改了 → $(SIMV) 重建 → 所有 $(LOGS) 重建
#   仅改了某个 test → 仅该 test.log 重建
#   无需额外代码——Make 依赖 DAG 已编码此逻辑

# 策略 2：仅重跑失败测试（快速迭代）
FAILED_LIST := .failed_tests

retest: $(SIMV)
	@if [ -f $(FAILED_LIST) ]; then \
		for t in $$(cat $(FAILED_LIST)); do \
			$(MAKE) $$t.log; \         # 逐个运行失败测试
		done; \
	else \
		$(MAKE) all; \                 # 首次运行——全量回归
	fi
```

## 关键要点

1. **Makefile 负责调度，Python 负责数据分析**——不要在 Makefile 里做复杂文本处理
2. **多工具链用 `ifeq ($(SIMULATOR), ...)` 分支**——一套 Makefile 覆盖 VCS/Questa/Verilator
3. **仿真日志是回归的目标文件**——`.log` 文件时间戳是判断"是否需要重新运行"的唯一依据
4. **`-j` 并行回归的前提是各测试 .log 之间无依赖关系**——Make 依赖图保证这一点
5. **覆盖率合并是回归的收尾步骤**——`urg`（VCS）或 `vcover merge`（Questa）
6. **增量回归 = 正确的依赖链声明**——`RTL .sv → simv → .log` 链条正确，Make 自动增量
7. **不要用 `xargs make` 替代 Make 内建依赖管理**——绕过时间戳比对，丢失增量能力

## 与其他概念的关系

- [[verification/concepts/UVM方法学|UVM 方法学]]——`+UVM_TESTNAME` 是 UVM 测试选择机制的标准入口
- [[verification/concepts/覆盖率模型|覆盖率模型（Coverage Model）]]——回归的核心输出是覆盖率，合并与报告是 CDV 闭环
- [[tools/concepts/Makefile模式与依赖|Makefile 模式与依赖]]——并行回归的 `-j` 机制依赖模式规则和依赖图

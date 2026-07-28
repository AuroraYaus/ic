---
type: concept
aliases:
  - Makefile Synthesis Flow
  - make 综合流程
  - Makefile for DC Genus
tags:
  - tools
  - makefile
  - asic-flow
  - synthesis
  - sta
source_spec: "Synopsys Design Compiler User Guide; Cadence Genus User Guide; Synopsys PrimeTime User Guide"
queries: 1
---

# Makefile 综合流程

数字IC的综合流程（Synthesis）和静态时序分析（Static Timing Analysis, STA）是多 Corner、多 Mode 的参数空间遍历过程——同样的 RTL 需要在慢速/典型/快速（SS/TT/FF）三种 PVT Corner 下各自综合，每个 Corner 还需要覆盖功能模式（Func）和测试模式（DFT），外加多电压域的 UPF 场景。手工逐个运行 TCL 脚本是灾难——代码重复、漏跑、结果不一致。

Makefile 的作用是**将 EDA 工具（DC/Genus/PrimeTime）的 TCL 脚本包装为 Make 目标**，用 `foreach` + 配置模板自动遍历所有 Corner × Mode × Scenario 的组合，用 Make 的依赖机制管理各阶段的输出文件（`.ddc` → `.v` → `.sdf` → `.rpt`），用 `-j` 并行跑独立 Corner。

## 原理

### Corner 遍历的核心模式

```makefile
# ===== 多 Corner 综合 Makefile =====
# 每个 Corner 的综合是一个独立的 Make 目标
# foreach 遍历 Corner 列表 → 生成一组独立的规则

# --- Corner 定义 ---
CORNERS := ss_0p81v_m40c tt_0p90v_25c ff_0p99v_125c
#          ^^^^^^^^^^^^^^  ^^^^^^^^^^^^^  ^^^^^^^^^^^^^^^
#          慢速/低压/低温    典型/典型/室温   快速/高压/高温

# --- EDA 工具路径 ---
DC_SHELL := dc_shell -64bit       # Synopsys Design Compiler 命令行模式

# --- RTL 源文件 ---
RTL_SRCS := $(wildcard ../rtl/*.sv ../rtl/*.v)

# --- 输出产物目录 ---
OUT_DIR := outputs

# ===== 自动生成每个 Corner 的构建目标 =====
SYN_NETLISTS := $(foreach c, $(CORNERS), $(OUT_DIR)/corner_$(c)_syn.v)
# foreach 展开：outputs/corner_ss_0p81v_m40c_syn.v
#              outputs/corner_tt_0p90v_25c_syn.v
#              outputs/corner_ff_0p99v_125c_syn.v

.PHONY: all
all: $(SYN_NETLISTS)

# ===== 单个 Corner 的综合流程 =====
# 依赖链：门级网表(.v) ← DC综合 ← RTL文件 + 约束(.sdc) + 库(.db) + TCL脚本
# Make 增量：RTL/约束/TCL 任何一项改了 → 重新综合该 Corner
$(OUT_DIR)/corner_%_syn.v: $(RTL_SRCS) scripts/syn_common.tcl scripts/constraints/%.sdc
	@mkdir -p $(OUT_DIR)
	$(DC_SHELL) -f scripts/syn_common.tcl \
#                   ^^^^^^^^^^^^^^^^^^^^^
#                   -f: 执行 TCL 脚本文件
	            -x "set CORNER $*; set OUT_DIR $(OUT_DIR)"
#                   ^^^^^  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#                   -x: 执行单行 TCL 命令（在 -f 脚本执行前设置变量）
#                   $*: 模式规则中 % 匹配的茎（corner 名称）
```

### TCL 脚本的 Makefile 包装模式

```makefile
# ===== Makefile 与 TCL 脚本的协同 =====
# Makefile 的责任：
#   1. 决定"什么时候跑"（依赖管理 + 增量）
#   2. 决定"用什么参数跑"（Corner/Mode 配置）
#   3. 并行调度（-j）
#
# TCL 脚本的责任：
#   1. 所有 EDA 工具命令（read_verilog、compile_ultra、report_timing等）
#   2. 报告格式化
#   3. 环境设置（search_path、target_library、link_library）

# --- TCL 脚本中通过环境变量接收参数 ---
# syn_common.tcl:
#   set corner $::env(CORNER)        # 读取 Makefile export 的 CORNER
#   set out_dir $::env(OUT_DIR)      # 读取输出目录
# 为什么用环境变量而非命令行参数？
#   DC 的 -x 只能执行单行 TCL——多参数传递用环境变量更可靠

# --- 带质量检查的综合目标 ---
$(OUT_DIR)/corner_%_syn.v: $(RTL_SRCS) scripts/syn.tcl scripts/constraints/%.sdc
	@echo "=== Synthesizing for corner $* ==="
	@mkdir -p $(OUT_DIR)/logs
	export CORNER=$*; \
	export OUT_DIR=$(OUT_DIR); \
	$(DC_SHELL) -f scripts/syn.tcl \
	    | tee $(OUT_DIR)/logs/syn_$*.log
#           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#           tee: 同时输出到终端和日志文件
	@# 质量门禁：综合后自动检查时序
	@./scripts/check_timing.py $(OUT_DIR)/reports/$*_timing.rpt || \
	    (echo "ERROR: Timing violation in corner $*" && false)
#                                            ^^^^^^^^^^^^^^^^^
#                                            exit 1 → Make 报告构建失败
```

### STA 分析与 ECO 迭代

```makefile
# ===== STA 分析 + ECO 迭代流 =====
# ECO（Engineering Change Order）：时序违规后的增量修复
# 流程：综合 → STA → 违规？→ ECO脚本修改 → 重新综合 → 再 STA → 直到收敛

# --- 多 Corner STA 分析 ---
$(OUT_DIR)/corner_%_sta.rpt: $(OUT_DIR)/corner_%_syn.v scripts/constraints/%.sdc
	export CORNER=$*; \
	export NETLIST=$<; \              # $< = 对应的门级网表
	pt_shell -f scripts/sta.tcl | tee $(OUT_DIR)/logs/sta_$*.log
#       ^^^^^^^^
#       PrimeTime Shell——Synopsys 静态时序分析工具命令行模式

# --- 时序违规检查 ---
.PHONY: check_timing
check_timing: $(addprefix $(OUT_DIR)/corner_, $(addsuffix _sta.rpt, $(CORNERS)))
	@echo "=== Checking timing across all corners ==="
	@python3 scripts/summarize_timing.py $(OUT_DIR)/reports/*_timing.rpt
#  脚本输出：最差负余量（Worst Negative Slack, WNS）汇总表
#  WNS < 0 → 存在违规 → exit 1 → Make 报告失败

# --- ECO 迭代 ---
# 如果 STA 发现违规 → 修改约束/网表 → 网表比 STA 报告新 → Make 自动重跑 STA
```

### 多 Mode × 多 Corner 的二维遍历

```makefile
# ===== 二维参数空间：Mode × Corner =====
# 综合不仅跑多 Corner（PVT），还要跑多 Mode（功能/DFT/低功耗）
# foreach 嵌套遍历所有组合

MODES   := func dft lp              # func(功能) dft(测试) lp(低功耗)
CORNERS := ss_0p81v_m40c tt_0p90v_25c

# define 定义模板宏 → 双重 foreach 展开
define gen_syn_targets
$(OUT_DIR)/$(1)/corner_$(2)_syn.v: $$(RTL_SRCS) scripts/$(1).tcl
	@mkdir -p $(OUT_DIR)/$(1)
	export MODE=$(1); \
	export CORNER=$(2); \
	$$(DC_SHELL) -f scripts/$(1).tcl | tee $(OUT_DIR)/$(1)/logs/syn_$(2).log
endef

# 双重 foreach + eval：生成 3 mode × 2 corner = 6 条独立规则
$(foreach m, $(MODES), \
    $(foreach c, $(CORNERS), \
        $(eval $(call gen_syn_targets, $(m), $(c)))))
```

## 关键要点

1. **Makefile 做调度，TCL 做工具命令**——不要在 Makefile 里写 `read_verilog` 等 EDA 命令
2. **`foreach` + `eval` + `call` 是遍历参数空间的标配**——Mode × Corner × Scenario 笛卡尔积用三重 foreach
3. **环境变量是 Makefile → TCL 传参的标准方式**——`export CORNER=$*` → TCL 中 `$::env(CORNER)` 接收
4. **每条规则生成一个明确的输出文件**——`.v`、`.rpt` 是 Make 增量机制的基础
5. **质量门禁：综合后自动检查时序**——`check_timing.py` 发现违规应让 Make 报告失败
6. **`tee` 同时输出终端和日志**——终端看实时进度，日志用于离线分析
7. **ECO 迭代的正确依赖是 STA 报告 → 网表**——STA 报告旧于网表 → 需重跑，Make 自动调度

## 与其他概念的关系

- [[asic-flow/concepts/逻辑综合|逻辑综合（Logic Synthesis）]]——DC/Genus 的 `compile_ultra` 等命令由 Makefile 封装的 TCL 脚本执行
- [[asic-flow/concepts/静态时序分析|静态时序分析（STA）]]——PrimeTime STA 是 Makefile 调度的"多 Corner 检查"环节
- [[asic-flow/concepts/签核|签核（Signoff）]]——多 Corner 遍历的最终目标是所有 Corner × Mode 的时序签核
- [[tools/concepts/Makefile条件与函数|Makefile 条件与函数]]——`foreach` + `eval` + `call` 是遍历参数空间的核心机制

---
type: concept
aliases: [Makefile 仿真回归实战, Simulation regression Questa VCS Xcelium]
tags: [tools, makefile, asic, verification]
source_spec: "Questa/VCS/Xcelium Command Reference"
queries: 1
---

# 21 — Makefile仿真回归实战

## 学习目标

本篇覆盖 EDA 仿真回归流的 Makefile 封装：Questa/VCS/Xcelium 命令封装、种子管理、并行仿真调度、覆盖率合并、失败重跑。默认 mock 命令——无商业 EDA 工具也能 dry-run 验证。

## Mock 基础骨架

```makefile
SIMULATOR ?= questa                     # questa / vcs / xcelium
ifeq ($(SIMULATOR),vcs)
  SIM_CMD := vcs -sverilog -full64
else ifeq ($(SIMULATOR),xcelium)
  SIM_CMD := xrun -sv
else
  SIM_CMD := vsim -c -do 'run -all; quit'
endif

# 种子管理
SEED ?= $(shell date +%s)              # 默认随机，可固定复现：make SEED=42
export SEED

# 测试列表
TESTS := smoke sanity stress corner_ff corner_ss
TEST_LOGS := $(patsubst %,log/%.log,$(TESTS))

.PHONY: all regress cov rerun clean
all: regress
regress: $(TEST_LOGS)
	@printf 'Regression: %d/%d passed\n' \
		$$(grep -l PASS $^ 2>/dev/null | wc -l) $$(echo $^ | wc -w)

# 单个测试——成功写 PASS，失败写 FAIL 但保留 .log 诊断
log/%.log: $(RTL_FILES) filelist.f
	@mkdir -p log
	$(SIM_CMD) +testname=$* +seed=$(SEED) -f filelist.f -l $@ \
		&& printf 'PASS\n' >> $@ \
		|| { printf 'FAIL\n' >> $@; exit 1; }

# 覆盖率
cov: cov/merged.ucdb
cov/merged.ucdb: $(patsubst %,cov/%.ucdb,$(TESTS))
	@mkdir -p cov; vcover merge $@ $^

# 失败重跑——只重跑 FAIL 的测试（新种子）
rerun:
	@for log in $$(grep -l FAIL log/*.log 2>/dev/null); do \
		t=$$(basename $$log .log); $(MAKE) log/$$t.log SEED=$$(date +%s); done

clean:; rm -rf log/ cov/
```

## 使用

```shell
make regress -j8       # 8 并行（各测试独立无共享依赖）
make SEED=42 regress   # 固定种子复现
make cov               # 覆盖率
make rerun             # 仅重跑失败（新种子）
```

## 工程要点

| 要点 | 实现 |
|:---|:---|
| Mock 优先 | 替换 `$(SIM_CMD)` 为 `echo` 即可无工具验证 |
| 种子管理 | `?=` + `$(shell date +%s)`——默认随机、可固定 |
| 并行安全 | 各测试无共享依赖 → `-j` 安全 |
| 失败日志 | `|| { printf FAIL; exit 1; }`——保留日志诊断 |
| 重跑 | grep FAIL → 新种子 → 只重跑失败项 |

## 关键要点

1. `SEED ?= $(shell date +%s)`——随机稳定两全
2. 失败保留日志——`|| { printf FAIL; exit 1; }`
3. 测试独立无共享 → `make -j` 安全并行
4. `make rerun` 仅重跑失败——grep FAIL
5. Mock 命令 → 无 EDA 可验证

## 与其他概念的关系

- [[tools/concepts/07-Makefile文本变换函数|07]] `$(patsubst %)`
- [[tools/concepts/17-Makefile内置变量与命令行|17]] `-j` 并行
- [[tools/concepts/09-Makefile控制函数与诊断函数|09]] `$(shell ...)`

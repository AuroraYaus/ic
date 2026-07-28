# Makefile 系统学习讲义 v3 — Design Spec

> **背景：** 项目中已有 7 个 Makefile 概念文件（4 通用 + 3 IC 实战），用户认为内容太肤浅、覆盖太不全，要求做一套科学、全面、由浅入深、面向初学者的 Makefile 讲义。

## 总体目标

构建一份从零到生产级 Makefile 的完整知识体系，总计 25 个文件，约 200KB，分 10 个 Part。

- **面向读者：** 数字IC初学者 + 任何想系统掌握 Makefile 的工程师
- **质量标准：** 每文件 200-500 行，原理 2-3 段实质性内容，关键要点 ≥5 条，与其他概念的关系 ≥2 个 wikilink
- **代码规范：** 所有 Makefile 代码块逐行注释（中文），解释每个关键字/符号的含义

## 文件结构

### Part 0 — 导论（2 文件）

| # | 文件名 | 核心内容 |
|:---|:---|:---|
| 1 | `Makefile概述与历史.md` | Make 历史（贝尔实验室 1976 → GNU Make），Make vs CMake/Ninja/Bazel 对比，GNU Make vs BSD Make vs NMAKE 方言，为什么 Make 50 年后仍在数字IC领域占主导 |
| 2 | `Makefile入门与心智模型.md` | 安装，Hello World，DAG 有向无环图心智模型，**二阶段执行模型**（Read Phase vs Target Update Phase）完整推导——这是理解 Makefile 一切行为的基石 |

### Part 1 — 规则与配方（2 文件）

| # | 文件名 | 核心内容 |
|:---|:---|:---|
| 3 | `Makefile规则详解.md` | Target/Prerequisite/Recipe 三要素深度剖析，依赖图展开算法（DAG 遍历），通配符（Make 级 `wildcard` vs Shell 级 `*`），`.PHONY` 深入（为什么需要、与文件的冲突场景） |
| 4 | `Makefile配方与Shell.md` | TAB vs `.RECIPEPREFIX`，`@`/`-`/`+` 前缀语义，`SHELL` 变量控制，`.ONESHELL` 行为，行延续 `\`，错误处理（`-` 前缀、`.IGNORE`、`.DELETE_ON_ERROR`、`-k`），配方中 `cd` 陷阱与正确做法 |

### Part 2 — 变量系统（2 文件）

| # | 文件名 | 核心内容 |
|:---|:---|:---|
| 5 | `Makefile变量赋值与展开.md` | `=`/`:=`/`?=`/`+=`/`!=` 五种赋值，二阶段展开完整推导（读阶段展开 vs 目标更新阶段展开），递归展开死循环检测，`+=` 在不同基础展开类型下的行为差异 |
| 6 | `Makefile高级变量.md` | 自动变量完整列表（`$@`/`$<`/`$^`/`$?`/`$*`/`$%`/`$+`/`$|`），Target-specific / Pattern-specific 变量，`override` 指令，`export`/`unexport`，环境变量继承（`-e`），`$(origin)`/`$(flavor)`/`$(value)` 诊断三件套，`$(.VARIABLES)` |

### Part 3 — 函数库（3 文件）

| # | 文件名 | 核心内容 |
|:---|:---|:---|
| 7 | `Makefile文本变换函数.md` | `subst`/`patsubst`/`strip`/`findstring`/`filter`/`filter-out`/`sort`/`word`/`wordlist`/`words`/`firstword`/`lastword`/`join`，每个函数至少一个工程场景示例。filter/filter-out 的多个模式参数行为 |
| 8 | `Makefile路径与文件函数.md` | `dir`/`notdir`/`suffix`/`basename`/`addprefix`/`addsuffix`/`wildcard`/`realpath`/`abspath`/`file`（GNU Make 4.0+），`$(file)` 的读取/写入/追加三种模式 |
| 9 | `Makefile高级控制函数.md` | `$(if)`/`$(or)`/`$(and)` 条件函数，`$(foreach)` 循环遍历，`$(call)` 参数化模板宏，`$(eval)` 元编程完整案例（从简单到复杂的渐进示例），`$(shell)` 的正确使用与性能陷阱，`$(let)`/`$(intcmp)`（GNU Make 4.4+），`$(error)`/`$(warning)`/`$(info)` 诊断函数 |

### Part 4 — 条件与控制流（2 文件）

| # | 文件名 | 核心内容 |
|:---|:---|:---|
| 10 | `Makefile条件判断.md` | `ifeq`/`ifneq`/`ifdef`/`ifndef`/`else`/`endif` 完整语法，嵌套条件，条件中变量的展开时机（读阶段评估），与 Shell `if` 的根本区别，实战平台检测/调试开关/特性门控模板 |
| 11 | `Makefile宏与元编程.md` | `define`/`endef` 多行变量定义，`$(call)` 参数化模板进阶（默认参数、嵌套 call），`$(eval)` 元编程完整剖析（`$$` 双重展开、`foreach` + `eval` 组合模式、生成规则与变量），元编程的调试方法和陷阱 |

### Part 5 — 模式与隐含规则（2 文件）

| # | 文件名 | 核心内容 |
|:---|:---|:---|
| 12 | `Makefile模式规则.md` | `%` 通配符完整语义，模式规则 vs 显式规则优先级，静态模式规则（`$(OBJS): %.o: %.c`），`VPATH`/`vpath` 搜索机制与优先级，Grouped Targets（`&:`，GNU Make 4.3+） |
| 13 | `Makefile隐含规则.md` | `make -p` 解读隐含规则数据库（含实际输出注释），后缀规则（`.SUFFIXES`，历史兼容），隐含变量表（`$(CC)`/`$(CFLAGS)`/`$(CXX)`/`$(LDFLAGS)` 等），规则链（Chain of Implicit Rules），`make -r` 禁用隐含规则，`.SUFFIXES:` 清除后缀规则 |

### Part 6 — 依赖管理（2 文件）

| # | 文件名 | 核心内容 |
|:---|:---|:---|
| 14 | `Makefile依赖与自动生成.md` | `include` 指令完整行为（读阶段嵌入、搜索路径、`MAKEFILE_LIST`），`-include`（`sinclude`）语义，自动依赖 `.d` 三步法完整剖析，`-M`/`-MM`/`-MF`/`-MT`/`-MP`/`-MD`/`-MQ` 编译器选项对比，依赖文件重建（remake）触发条件与 `$(MAKE_RESTARTS)` |
| 15 | `Makefile高级依赖.md` | Order-Only 前置条件（`|`）——目录创建和锁文件的正确姿势，双冒号规则（`::`）——同一目标的多个独立更新，二次展开（`.SECONDEXPANSION`）——在依赖列表中引用自动变量，`$(MAKE_RESTARTS)` 与 remake 循环检测 |

### Part 7 — 特殊目标与内置变量（2 文件）

| # | 文件名 | 核心内容 |
|:---|:---|:---|
| 16 | `Makefile特殊目标手册.md` | `.PHONY`/`.DEFAULT`/`.IGNORE`/`.SILENT`/`.PRECIOUS`/`.INTERMEDIATE`/`.SECONDARY`/`.DELETE_ON_ERROR`/`.NOTPARALLEL`/`.ONESHELL`/`.POSIX`/`.RECIPEPREFIX`/`.SUFFIXES`——逐一讲解触发条件、正确用法和常见误用 |
| 17 | `Makefile内置变量与命令行.md` | **Part A — 内置变量详解（逐个深度剖析）**：`$(MAKE)` — 递归 Make 的核心、为什么必须用 `$(MAKE)` 而非 `make`、传递命令行参数的机制。`$(MAKECMDGOALS)` — 捕获用户命令行目标、条件构建的依据、多目标场景。`$(MAKEFLAGS)` — 命令行标志的完整传递链、`-` 前缀式结构解析、常见陷阱（`$(MAKEFLAGS)` 中的 `--`）。`$(MAKELEVEL)` — 递归深度感知、防止无限递归、条件导出。`$(MAKEFILE_LIST)` — Makefile 文件加载顺序、定位当前 Makefile 所在目录（`$(dir $(lastword $(MAKEFILE_LIST)))`）、多个 `-f` 时的行为。`$(MAKE_RESTARTS)` — remake 重启动计数器、控制重生成逻辑。`$(CURDIR)` vs `$(PWD)` — 绝对路径的确定性与 Shell 环境的不可靠性。`$(.FEATURES)` — 检测 GNU Make 版本能力（`target-specific`/`second-expansion`/`order-only`/`grouped-target`/`load`/`oneshell`/`shortest-stem`）、编写跨版本兼容 Makefile 的依据。`$(.VARIABLES)` — 列出所有已定义变量名的完整列表、调试工具。`$(.RECIPEPREFIX)` — 检测当前配方前缀字符。`$(MAKEOVERRIDES)` — 命令行变量覆盖传递的机制与陷阱。`$(SHELL)`/`$(.SHELLFLAGS)` — 控制配方使用的 Shell 及其参数。**Part B — 命令行选项完全手册（分类详解，每个选项含：语义、典型场景、示例命令、注意事项）**：构建控制组（`-j [N]`/`-l [N]`/`-k`/`-n`/`-t`/`-q`/`-B`/`--always-make`/`-o FILE`/`-W FILE`/`--shuffle`）；调试/信息组（`-d`/`--debug[=FLAGS]`/`-p`/`--print-data-base`/`--trace`/`-s`/`--warn-undefined-variables`/`--eval`）；目录/文件组（`-C DIR`/`-f FILE`/`-I DIR`/`--include-dir`）；隐含规则控制组（`-r`/`-R`/`--no-builtin-rules`/`--no-builtin-variables`）；环境/变量组（`-e`/`-E`/`--environment-overrides`）；兼容性组（`--posix`/`-S`/`--no-keep-going`/`--output-sync`）；版本/帮助组（`-v`/`-h`）。**Part C — 实战技法**：命令行变量覆盖模式（`make VAR=val` vs `?=` vs `override`），多目标并发构建（`make all test`），并行度的工程化配置（`make -j$(nproc)`），条件式 dry-run（`--dry-run` 的流水线化使用），文件搜索路径的灵活控制（`-I` 的应用场景） |

### Part 8 — 架构与工程化（2 文件）

| # | 文件名 | 核心内容 |
|:---|:---|:---|
| 18 | `Makefile递归与大型项目.md` | `$(MAKE) -C` 递归模式，`export` 变量传播与 `unexport` 隔离，`MAKEFLAGS` 传递机制，`$(MAKELEVEL)` 层级感知，构建产物隔离（out-of-source build），`include` 式 vs 递归式架构对比与选择策略，子目录 Makefile 的统一模板 |
| 19 | `Makefile调试与性能.md` | `--debug` 完整模式解析（`a`全部/`b`基础/`v`冗长/`i`隐含/`j`作业/`m`remake/`n`不执行），`--trace` 实时追踪，`--shuffle` 并行竞态检测，`$(warning)`/`$(info)` 诊断嵌入，`$(shell)` 性能开销与优化（`:=` 即时求值、`$(file)` 替代品），`-j` 并行度调优，`$(MAKEFLAGS)` 传递调试选项，跨平台（Linux/macOS/Windows）可移植性问题与 `uname` 检测模式 |

### Part 9 — 实战（4 文件）

| # | 文件名 | 核心内容 |
|:---|:---|:---|
| 20 | `Makefile网络服务实战.md` | **项目：TCP Echo Server/Client 网络服务项目**。以完整的 Socket 网络应用（IPv4/IPv6 双栈、多进程/多线程并发模型、连接池）为载体，演示生产级 Makefile 的完整构建体系。**结构**：多级目录（`src/server/`、`src/client/`、`src/common/`）、静态库（libcommon.a）+ 可执行文件（server/client）、自动头文件依赖、单元测试目录。**核心内容**：(1) **x86-64 本地编译** — GCC/Clang 标准编译、`-Wall -Wextra -Werror` 严格警告体系、Debug/Release 双模式、ASAN（Address Sanitizer）内存检测集成 (2) **ARM 交叉编译** — `aarch64-linux-gnu-gcc` 工具链切换、`SYSROOT` 系统根配置、`ARCH` 变量驱动的条件编译、静态链接 vs 动态链接在 ARM 上的选择 (3) **交叉编译工具链管理** — 用条件判断自动检测交叉编译器是否存在、优雅降级到本地编译、`CROSS_COMPILE` 前缀模式 (4) **平台适配** — `uname -m` 自动检测、`-D_XOPEN_SOURCE` 等宏的条件定义、Linux vs macOS 的 Socket API 差异（`SO_REUSEPORT` 等）(5) **完整工程化** — 安装/卸载、打包（tar.gz）、测试自动化、覆盖率目标（gcov/lcov）、CI 就绪的退出码管理。整合前 19 个文件的所有理论知识，做到"看完就能拿去改写成自己的项目"。 |
| 21 | `Makefile仿真回归实战.md` | EDA 仿真回归流：Questa/VCS/Xcelium 封装，种子管理与随机化，并行仿真调度（`-j` + `.NOTPARALLEL` 精控），覆盖率合并（UCIS/UCDB），失败重跑（regression rerun），日志聚合与失败分类 |
| 22 | `Makefile综合流程实战.md` | ASIC 综合流：DC/Genus 封装，多 Corner 并行，层次化编译策略，报告自动化（时序/QoR/面积/功耗），ECO 回注（增量综合），Checkpoint 管理 |
| 23 | `MakefileIC项目构建实战.md` | 层次化 IC 项目 Makefile 框架：IP 库管理，跨 IP 依赖跟踪，版本发布（tag → release），仿真/综合/STA/DFT 统一入口，可复用模板设计，`.config.mk` 配置模式 |

### Part 10 — 附录（2 文件）

| # | 文件名 | 核心内容 |
|:---|:---|:---|
| 24 | `Makefile常见错误50例.md` | 50 个最常犯的 Makefile 错误分类整理：语法错误（TAB 陷阱/续行空格/缩进条件）、变量陷阱（递归死循环/括号遗漏/`@` vs `$`）、依赖错误（遗漏依赖/虚假依赖/循环依赖）、并行陷阱（竞态条件/破坏性并发）、跨平台陷阱 |
| 25 | `Makefile快速参考.md` | 速查表：全变量类型汇总 / 全自动变量表 / 全内建函数分类表（含签名和一行说明）/ 全特殊目标表 / 全命令行选项表 / 常见 Makefile 模板片段（编译模板、库模板、递归模板、测试模板） |

## 实施约束

1. **必须替换现有文件，不能保留旧内容**：现有的 7 个 Makefile 文件将全部重写
2. **新文件命名规范**：`Makefile<主题>.md`，中文简洁标题
3. **wikilink 网络**：文件之间的引用用 `[[tools/concepts/文件名\|显示名]]` 格式
4. **MOC 更新**：`tools/工具与脚本.md` 的概念索引和学习路线图需更新
5. **入口更新**：`数字IC入口.md` 中 tools 领域的新增文件链接需更新
6. **代码注释标准**：所有代码块逐行中文注释，不能有裸代码
7. **内容质量标准**：同项目 CLAUDE.md 中的规则——每文件 200-500 行，原理 2-3 段，关键要点 ≥5 条，wikilink ≥2 个，首次术语标注中英文

## 实施顺序

按 Part 0 → 1 → 2 → ... → 10 顺序编写，确保每一篇引用的前置知识已在之前的文件中建立。每个 Part 内部的文件也按序号顺序撰写。

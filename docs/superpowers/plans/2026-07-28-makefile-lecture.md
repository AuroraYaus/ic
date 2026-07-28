# Makefile 系统学习讲义 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the existing shallow 7-file Makefile notes into a 25-file beginner-friendly, verifiable, IC-oriented Makefile lecture system.

**Architecture:** The final knowledge system lives under `tools/concepts/`, with `tools/工具与脚本.md` as the tools MOC and `数字IC入口.md` as the global entry. Work proceeds in four stages: create the complete file set and safe navigation, write the main tutorial path, write advanced and IC-practical material, then run global link/version/content audits.

**Tech Stack:** Markdown, Obsidian wikilinks, Mermaid, GNU Make 4.3, shell, C/golden-model examples, mock EDA command wrappers.

## Global Constraints

- Source spec: `docs/superpowers/specs/2026-07-28-makefile-lecture-v3.md`.
- Default environment: GNU Make 4.3; all mainline examples must be verifiable on GNU Make 4.3.
- Version strategy: GNU Make 4.4+, BSD Make, NMAKE, and POSIX Make differences must be marked as version/dialect compatibility notes.
- Content scale: main tutorial files 100-300 lines; advanced manual and appendix files 200-450 lines.
- Code rule: every Makefile, shell, C, and TCL code block must have line-by-line Chinese comments explaining key syntax, variables, symbols, expansion timing, and execution stage.
- Verification rule: each concept file must include at least one copyable minimal example and at least one verification command such as `make -n`, `make --trace`, `make -p`, or `make --warn-undefined-variables`.
- Link rule: use `[[tools/concepts/文件名|显示名]]` only for real `.md` files; create all target files before adding cross-file wikilinks.
- Diagram rule: durable diagrams must use fenced Mermaid blocks and include `%%{init: {'theme': 'default'}}%%`.
- Frontmatter rule: every concept file must contain `type`, `aliases`, `tags`, `source_spec`, and `queries`.
- Existing 7 Makefile concept files must be fully replaced, not lightly edited.

---

## File Structure

**Delete after replacement content is ready:**

- `tools/concepts/Makefile基础语法.md`
- `tools/concepts/Makefile条件与函数.md`
- `tools/concepts/Makefile模式与依赖.md`
- `tools/concepts/Makefile实战项目.md`
- `tools/concepts/Makefile仿真回归.md`
- `tools/concepts/Makefile综合流程.md`
- `tools/concepts/Makefile项目构建.md`

**Create under `tools/concepts/`:**

- `Makefile解决的问题与第一个例子.md`
- `Makefile心智模型与历史.md`
- `Makefile规则详解.md`
- `Makefile配方与Shell.md`
- `Makefile变量赋值与展开.md`
- `Makefile高级变量.md`
- `Makefile文本变换函数.md`
- `Makefile路径与文件函数.md`
- `Makefile控制函数与诊断函数.md`
- `Makefile条件判断.md`
- `Makefile宏与元编程.md`
- `Makefile模式规则.md`
- `Makefile隐含规则.md`
- `Makefile依赖与自动生成.md`
- `Makefile高级依赖.md`
- `Makefile特殊目标手册.md`
- `Makefile内置变量与命令行.md`
- `Makefile递归与大型项目.md`
- `Makefile调试与性能.md`
- `Makefile小型工程实战.md`
- `Makefile仿真回归实战.md`
- `Makefile综合流程实战.md`
- `MakefileIC项目构建实战.md`
- `Makefile常见错误50例.md`
- `Makefile快速参考与版本兼容.md`

**Modify indexes:**

- `tools/工具与脚本.md`
- `数字IC入口.md`

## Shared Document Template

Every new concept file must use this structure, adapted to the file topic:

```markdown
---
type: concept
aliases:
  - Makefile <topic alias>
tags:
  - tools
  - makefile
  - asic
source_spec: "GNU Make Manual; POSIX make specification; relevant EDA tool manuals where applicable"
queries: 1
---

# Makefile<主题>

## 学习目标

## 前置知识

## 最小可运行例子

## 语法拆解

## 执行轨迹

## 工程化写法

## 常见错误

## 关键要点

## 与其他概念的关系

## 小练习
```

## Task 1: Replace File Set And Safe Navigation

**Files:**

- Delete after creating replacements: the 7 old Makefile concept files listed in “File Structure”.
- Create: all 25 new concept files listed in “File Structure”.
- Modify: `tools/工具与脚本.md`
- Modify: `数字IC入口.md`

**Interfaces:**

- Consumes: v3 spec file list and shared document template.
- Produces: complete real file targets so later tasks can add valid wikilinks without creating empty Obsidian nodes.

- [ ] **Step 1: Snapshot current Makefile docs before editing**

Run:

```bash
find tools/concepts -maxdepth 1 -type f -name 'Makefile*.md' | sort
```

Expected output contains exactly the current 7 old files before replacement:

```text
tools/concepts/Makefile仿真回归.md
tools/concepts/Makefile基础语法.md
tools/concepts/Makefile实战项目.md
tools/concepts/Makefile条件与函数.md
tools/concepts/Makefile模式与依赖.md
tools/concepts/Makefile综合流程.md
tools/concepts/Makefile项目构建.md
```

- [ ] **Step 2: Create the 25 new files with real section structure**

For each new file, write frontmatter and all sections from “Shared Document Template”. Do not leave files with only a title. Each file must include a learning goal paragraph and a source-specific `source_spec`.

- [ ] **Step 3: Remove the 7 old files once matching replacements exist**

Run:

```bash
rm tools/concepts/Makefile基础语法.md \
   tools/concepts/Makefile条件与函数.md \
   tools/concepts/Makefile模式与依赖.md \
   tools/concepts/Makefile实战项目.md \
   tools/concepts/Makefile仿真回归.md \
   tools/concepts/Makefile综合流程.md \
   tools/concepts/Makefile项目构建.md
```

Expected: command exits with status 0.

- [ ] **Step 4: Rewrite the tools MOC to list all 25 files**

Update `tools/工具与脚本.md` so the Makefile section has Part 0 through Part 10 subsections and links every new file using `[[tools/concepts/<filename>|<display>]]`.

- [ ] **Step 5: Update the global entry**

Update `数字IC入口.md` so the tools row says the Makefile area contains a 25-file system lecture, with the primary link still pointing to `[[tools/工具与脚本|工具与脚本 MOC]]`.

- [ ] **Step 6: Verify file count and old-file removal**

Run:

```bash
find tools/concepts -maxdepth 1 -type f -name 'Makefile*.md' | sort | wc -l
```

Expected:

```text
25
```

Run:

```bash
find tools/concepts -maxdepth 1 -type f \( -name 'Makefile基础语法.md' -o -name 'Makefile条件与函数.md' -o -name 'Makefile模式与依赖.md' -o -name 'Makefile实战项目.md' -o -name 'Makefile仿真回归.md' -o -name 'Makefile综合流程.md' -o -name 'Makefile项目构建.md' \)
```

Expected: no output.

- [ ] **Step 7: Commit the file-set change**

```bash
git add tools/concepts tools/工具与脚本.md 数字IC入口.md
git commit -m "docs: replace makefile lecture structure"
```

## Task 2: Write Part 0-1 Beginner Foundation

**Files:**

- Modify: `tools/concepts/Makefile解决的问题与第一个例子.md`
- Modify: `tools/concepts/Makefile心智模型与历史.md`
- Modify: `tools/concepts/Makefile规则详解.md`
- Modify: `tools/concepts/Makefile配方与Shell.md`
- Modify: `tools/工具与脚本.md`

**Interfaces:**

- Consumes: complete file set from Task 1.
- Produces: the reader’s foundation for targets, prerequisites, recipes, timestamps, DAG, two-phase execution, and shell boundaries.

- [ ] **Step 1: Write `Makefile解决的问题与第一个例子.md`**

Include a minimal `hello.txt` example with a Makefile that builds a file from an input. Explain default target, timestamp comparison, target/prerequisite/recipe, and why Make is not just a shell script. Include `make -n`, `make --trace`, first run, second run, and changed input demonstrations.

- [ ] **Step 2: Write `Makefile心智模型与历史.md`**

Include a Mermaid DAG showing target dependencies and a Mermaid flowchart for Read Phase versus Target Update Phase. Put history and Make/CMake/Ninja/Bazel comparison after the mental model, not before it. Add a version/dialect table covering GNU Make, BSD Make, NMAKE, and POSIX Make.

- [ ] **Step 3: Write `Makefile规则详解.md`**

Cover explicit rules, default target selection, multiple targets, target files versus phony targets, `.PHONY` minimal use, and target/prerequisite/recipe vocabulary. Include one example where a directory named `clean` or `build` causes a target conflict, then fix it with `.PHONY`.

- [ ] **Step 4: Write `Makefile配方与Shell.md`**

Cover TAB, `.RECIPEPREFIX`, `@`, `-`, `+`, `SHELL`, `$(.SHELLFLAGS)`, per-line shell behavior, `.ONESHELL`, line continuation, `cd` pitfalls, and failure handling. Include one failing recipe and compare normal failure, `-` prefix, and `.DELETE_ON_ERROR`.

- [ ] **Step 5: Verify Part 0-1 examples**

For each of the four files, copy the minimal example into `/tmp/makefile-lecture-check/<file-topic>/` and run the documented command sequence. At minimum run:

```bash
make -n
make --trace
make
make
```

Expected: the second plain `make` shows the target is up to date or performs no unnecessary rebuild.

- [ ] **Step 6: Commit Part 0-1**

```bash
git add tools/concepts/Makefile解决的问题与第一个例子.md \
        tools/concepts/Makefile心智模型与历史.md \
        tools/concepts/Makefile规则详解.md \
        tools/concepts/Makefile配方与Shell.md \
        tools/工具与脚本.md
git commit -m "docs: write makefile beginner foundation"
```

## Task 3: Write Part 2-4 Variables, Functions, Conditions, And Macros

**Files:**

- Modify: `tools/concepts/Makefile变量赋值与展开.md`
- Modify: `tools/concepts/Makefile高级变量.md`
- Modify: `tools/concepts/Makefile文本变换函数.md`
- Modify: `tools/concepts/Makefile路径与文件函数.md`
- Modify: `tools/concepts/Makefile控制函数与诊断函数.md`
- Modify: `tools/concepts/Makefile条件判断.md`
- Modify: `tools/concepts/Makefile宏与元编程.md`

**Interfaces:**

- Consumes: two-phase execution model from Task 2.
- Produces: a consistent explanation of variable flavor, expansion timing, function word-list semantics, and controlled use of `$(eval)`.

- [ ] **Step 1: Write variable assignment and expansion**

In `Makefile变量赋值与展开.md`, cover `=`, `:=`, `?=`, `+=`, and `!=`. Demonstrate repeated `$(shell date +%s%N)` under `=` versus cached evaluation under `:=`. Explain that `+=` preserves existing value; the important difference is when the appended text is expanded.

- [ ] **Step 2: Write advanced variables**

In `Makefile高级变量.md`, cover automatic variables, target-specific variables, pattern-specific variables, `override`, `export`, `unexport`, `-e`, `$(origin)`, `$(flavor)`, `$(value)`, and `$(.VARIABLES)`. Include a diagnostic Makefile that prints variable origin and flavor.

- [ ] **Step 3: Write text transformation functions**

In `Makefile文本变换函数.md`, explain Make’s whitespace-separated word-list model before listing functions. Cover all functions from the spec and include engineering examples such as filtering test files, converting source lists to object lists, and normalizing option lists.

- [ ] **Step 4: Write path and file functions**

In `Makefile路径与文件函数.md`, distinguish `$(wildcard ...)` from shell `*`, explain path split/recombine functions, and demonstrate `$(file >...)`, `$(file >>...)`, and `$(file <...)`.

- [ ] **Step 5: Write control and diagnostic functions**

In `Makefile控制函数与诊断函数.md`, cover `$(if)`, `$(or)`, `$(and)`, `$(foreach)`, `$(shell)`, `$(error)`, `$(warning)`, and `$(info)`. Mention `$(let)` and `$(intcmp)` only in a GNU Make 4.4+ compatibility note.

- [ ] **Step 6: Write conditionals**

In `Makefile条件判断.md`, cover `ifeq`, `ifneq`, `ifdef`, `ifndef`, `else`, and `endif`. Include a paired example that shows Make conditionals are evaluated while reading the Makefile, while shell `if` runs inside the recipe.

- [ ] **Step 7: Write macros and metaprogramming**

In `Makefile宏与元编程.md`, cover `define`/`endef`, `$(call)`, and `$(eval)`. Include the double-dollar rule with a small generated-rule example, and include a warning that metaprogramming should be used only after simpler pattern rules are insufficient.

- [ ] **Step 8: Verify Part 2-4 examples**

For each of the seven files, copy the minimal Makefile example to `/tmp/makefile-lecture-check/<file-topic>/` and run at least:

```bash
make --warn-undefined-variables
make -n
make --trace
```

Expected: examples run on GNU Make 4.3; any GNU Make 4.4+ section is marked as not part of the default runnable path.

- [ ] **Step 9: Commit Part 2-4**

```bash
git add tools/concepts/Makefile变量赋值与展开.md \
        tools/concepts/Makefile高级变量.md \
        tools/concepts/Makefile文本变换函数.md \
        tools/concepts/Makefile路径与文件函数.md \
        tools/concepts/Makefile控制函数与诊断函数.md \
        tools/concepts/Makefile条件判断.md \
        tools/concepts/Makefile宏与元编程.md
git commit -m "docs: write makefile variables and functions"
```

## Task 4: Write Part 5-6 Patterns, Implicit Rules, And Dependencies

**Files:**

- Modify: `tools/concepts/Makefile模式规则.md`
- Modify: `tools/concepts/Makefile隐含规则.md`
- Modify: `tools/concepts/Makefile依赖与自动生成.md`
- Modify: `tools/concepts/Makefile高级依赖.md`

**Interfaces:**

- Consumes: functions and variables from Task 3.
- Produces: the dependency-management foundation required by all practical engineering examples.

- [ ] **Step 1: Write pattern rules**

In `Makefile模式规则.md`, cover `%`, stem, explicit rule precedence, static pattern rules, `VPATH`, `vpath`, and grouped targets `&:` as GNU Make 4.3+ behavior. Include a source-to-object example with `$(OBJS): %.o: %.c`.

- [ ] **Step 2: Write implicit rules**

In `Makefile隐含规则.md`, show how to inspect built-in rules with `make -p`, explain suffix rules, implicit variables, implicit rule chains, `make -r`, `make -R`, and `.SUFFIXES:`. Include annotated excerpts rather than a large raw `make -p` dump.

- [ ] **Step 3: Write generated dependency management**

In `Makefile依赖与自动生成.md`, cover `include`, `-include`, `sinclude`, `MAKEFILE_LIST`, `.d` file generation, and GCC/Clang options `-M`, `-MM`, `-MF`, `-MT`, `-MP`, `-MD`, and `-MQ`. Include a small C project example that rebuilds when a header changes.

- [ ] **Step 4: Write advanced dependencies**

In `Makefile高级依赖.md`, cover order-only prerequisites, directory creation, double-colon rules, `.SECONDEXPANSION`, automatic variables in prerequisite lists, and remake loop detection. Include a directory target example that uses `|`.

- [ ] **Step 5: Verify dependency examples**

Create `/tmp/makefile-lecture-check/deps/`, copy the documented C/header example, and run:

```bash
make clean
make --trace
touch include/example.h
make --trace
```

Expected: touching the header rebuilds the affected object or target; touching the build directory does not force rebuild when order-only prerequisites are used.

- [ ] **Step 6: Commit Part 5-6**

```bash
git add tools/concepts/Makefile模式规则.md \
        tools/concepts/Makefile隐含规则.md \
        tools/concepts/Makefile依赖与自动生成.md \
        tools/concepts/Makefile高级依赖.md
git commit -m "docs: write makefile patterns and dependencies"
```

## Task 5: Write Part 7-8 Special Targets, CLI, Architecture, Debugging, And Performance

**Files:**

- Modify: `tools/concepts/Makefile特殊目标手册.md`
- Modify: `tools/concepts/Makefile内置变量与命令行.md`
- Modify: `tools/concepts/Makefile递归与大型项目.md`
- Modify: `tools/concepts/Makefile调试与性能.md`

**Interfaces:**

- Consumes: dependency and function knowledge from Tasks 3-4.
- Produces: engineering-level guidance for large projects, recursive Make, debugging, command-line operation, and performance.

- [ ] **Step 1: Write special target manual**

In `Makefile特殊目标手册.md`, cover each special target from the spec with trigger condition, correct use, misuse, and a small example. Cross-reference earlier explanations instead of repeating basic `.PHONY` theory.

- [ ] **Step 2: Write built-in variables and command line**

In `Makefile内置变量与命令行.md`, cover the listed built-in variables and command-line option groups. Correctly state that `-e` is environment override and `-E STRING` is `--eval=STRING`.

- [ ] **Step 3: Write recursion and large project architecture**

In `Makefile递归与大型项目.md`, cover `$(MAKE) -C`, `MAKEFLAGS`, `$(MAKELEVEL)`, variable propagation, out-of-source build, include-style architecture, recursive architecture, and a subdirectory Makefile template.

- [ ] **Step 4: Write debugging and performance**

In `Makefile调试与性能.md`, cover `--debug`, `--trace`, `--warn-undefined-variables`, `$(warning)`, `$(info)`, `$(shell)` cost, `:=` caching, `$(file)`, `-j`, `--output-sync`, and cross-platform command differences. Mark `--shuffle` as GNU Make 4.4+.

- [ ] **Step 5: Verify GNU Make 4.3 compatibility claims**

Run:

```bash
make --version | sed -n '1p'
make --help | rg -- '--trace|--output-sync|-E STRING|--environment-overrides'
```

Expected: version is GNU Make 4.3; help output confirms documented GNU Make 4.3 options. `--shuffle` must not be presented as a GNU Make 4.3 command.

- [ ] **Step 6: Commit Part 7-8**

```bash
git add tools/concepts/Makefile特殊目标手册.md \
        tools/concepts/Makefile内置变量与命令行.md \
        tools/concepts/Makefile递归与大型项目.md \
        tools/concepts/Makefile调试与性能.md
git commit -m "docs: write makefile engineering reference"
```

## Task 6: Write Part 9 Practical Engineering And IC Flow

**Files:**

- Modify: `tools/concepts/Makefile小型工程实战.md`
- Modify: `tools/concepts/Makefile仿真回归实战.md`
- Modify: `tools/concepts/Makefile综合流程实战.md`
- Modify: `tools/concepts/MakefileIC项目构建实战.md`

**Interfaces:**

- Consumes: all earlier Makefile concepts.
- Produces: practical examples showing how Makefile knowledge transfers into C/golden-model builds and digital IC flow automation.

- [ ] **Step 1: Write small C/golden-model engineering case**

In `Makefile小型工程实战.md`, build a small multi-directory C or golden-model project with `src/`, `include/`, `build/`, `lib/`, and `test/`. Include static library, executable, automatic dependencies, Debug/Release, ASAN, test, install, uninstall, package, and coverage entry targets.

- [ ] **Step 2: Write simulation regression case**

In `Makefile仿真回归实战.md`, cover Questa/VCS/Xcelium command wrapping, seed management, test lists, filelists, mock dry-run commands, parallel simulation, coverage merge, rerun, log aggregation, and failure classification. Ensure the default example runs without commercial EDA tools by echoing or wrapping mock commands.

- [ ] **Step 3: Write synthesis flow case**

In `Makefile综合流程实战.md`, cover DC/Genus wrapping, multi-corner parallelism, hierarchical compile, report collection, QoR/area/power directories, ECO feedback, and checkpoint management. Include a mock dry-run target that creates representative report files.

- [ ] **Step 4: Write layered IC project framework**

In `MakefileIC项目构建实战.md`, cover IP library management, cross-IP dependencies, release tagging, unified targets for simulation/synthesis/STA/DFT, reusable include fragments, `.config.mk`, CI exit codes, and artifact directory conventions.

- [ ] **Step 5: Verify practical examples without commercial EDA**

For the four practical files, copy each mock example to `/tmp/makefile-lecture-check/practice/<topic>/` and run:

```bash
make -n
make --trace
make dry-run
```

Expected: commands complete without requiring Questa, VCS, Xcelium, DC, or Genus. Real tool commands are documented as optional substitutions.

- [ ] **Step 6: Commit Part 9**

```bash
git add tools/concepts/Makefile小型工程实战.md \
        tools/concepts/Makefile仿真回归实战.md \
        tools/concepts/Makefile综合流程实战.md \
        tools/concepts/MakefileIC项目构建实战.md
git commit -m "docs: write makefile practical ic flows"
```

## Task 7: Write Part 10 Appendix And Version Compatibility

**Files:**

- Modify: `tools/concepts/Makefile常见错误50例.md`
- Modify: `tools/concepts/Makefile快速参考与版本兼容.md`

**Interfaces:**

- Consumes: all previous concept files.
- Produces: compact lookup material and a corrective index for common failures.

- [ ] **Step 1: Write 50 common errors**

In `Makefile常见错误50例.md`, organize 50 errors by syntax/format, variable expansion, dependency/target, parallel build, portability, and performance. Each error must have symptom, root cause, fix, prevention, and related chapter link.

- [ ] **Step 2: Correct known misleading error descriptions**

Ensure the appendix states that `+=` preserves prior value and differs by expansion timing. Ensure it states that `$(eval ...)` in recipes runs during recipe expansion and is risky because of timing and diagnosability, not because Make re-reads the entire Makefile in a normal execution loop.

- [ ] **Step 3: Write quick reference and compatibility table**

In `Makefile快速参考与版本兼容.md`, include tables for variable flavors, automatic variables, functions, special targets, command-line options, templates, and GNU Make 4.3 / GNU Make 4.4+ / BSD Make / NMAKE / POSIX Make compatibility.

- [ ] **Step 4: Verify appendix links**

Run:

```bash
rg -n '\[\[tools/concepts/Makefile' tools/concepts/Makefile常见错误50例.md tools/concepts/Makefile快速参考与版本兼容.md
```

Expected: links point only to files created in Task 1.

- [ ] **Step 5: Commit Part 10**

```bash
git add tools/concepts/Makefile常见错误50例.md \
        tools/concepts/Makefile快速参考与版本兼容.md
git commit -m "docs: write makefile appendix and compatibility"
```

## Task 8: Global Link, Index, And Content Audit

**Files:**

- Modify: `tools/工具与脚本.md`
- Modify: `数字IC入口.md`
- Modify when an audit command reports a violation: the exact 25 `tools/concepts/Makefile*.md` files listed in “File Structure”.

**Interfaces:**

- Consumes: all completed content.
- Produces: final navigable, internally consistent, non-empty Makefile lecture system.

- [ ] **Step 1: Verify no empty documents**

Run:

```bash
for f in tools/concepts/Makefile*.md; do lines=$(wc -l < "$f"); printf '%s %s\n' "$lines" "$f"; done | sort -n
```

Expected: no concept file is below 100 lines; advanced/reference files are within 200-450 lines where applicable.

- [ ] **Step 2: Verify required sections**

Run:

```bash
for f in tools/concepts/Makefile*.md; do
  for h in '## 学习目标' '## 最小可运行例子' '## 语法拆解' '## 执行轨迹' '## 常见错误' '## 关键要点' '## 与其他概念的关系'; do
    rg -q "^$h$" "$f" || printf 'missing %s in %s\n' "$h" "$f"
  done
done
```

Expected: no output.

- [ ] **Step 3: Verify Mermaid init lines**

Run:

```bash
rg -n '```mermaid' tools/concepts tools/工具与脚本.md 数字IC入口.md
```

For every Mermaid block found, confirm the next non-empty line is:

```text
%%{init: {'theme': 'default'}}%%
```

- [ ] **Step 4: Verify wikilinks are real files**

Run a link audit script or manually inspect:

```bash
rg -o '\[\[[^]|#]+' tools/concepts tools/工具与脚本.md 数字IC入口.md | sed 's/.*\\[\\[//' | sort -u
```

Expected: every `tools/concepts/...` link resolves to an existing `.md` file relative to the vault root.

- [ ] **Step 5: Verify GNU Make 4.3 examples**

Run the representative examples from at least these five files:

```text
tools/concepts/Makefile解决的问题与第一个例子.md
tools/concepts/Makefile变量赋值与展开.md
tools/concepts/Makefile依赖与自动生成.md
tools/concepts/Makefile调试与性能.md
tools/concepts/Makefile仿真回归实战.md
```

Expected: documented default commands run on GNU Make 4.3; 4.4+ commands are explicitly marked as version-specific.

- [ ] **Step 6: Verify MOC and global entry**

Run:

```bash
rg -n 'Makefile' tools/工具与脚本.md 数字IC入口.md
find tools/concepts -maxdepth 1 -type f -name 'Makefile*.md' | wc -l
```

Expected: MOC references all 25 Makefile files; global entry points to the tools MOC; file count is 25.

- [ ] **Step 7: Commit final audit fixes**

```bash
git add tools/concepts tools/工具与脚本.md 数字IC入口.md
git commit -m "docs: audit makefile lecture links and examples"
```

## Self-Review Checklist

- Spec coverage: Tasks 1-8 cover the v3 file set, teaching structure, version policy, code comment policy, Mermaid policy, wikilink policy, MOC update, entry update, and final audits.
- Scope: This is one documentation system, but implementation is split by learning stage so each task produces a reviewable deliverable.
- Verification: Each task has concrete commands and expected outcomes; practical EDA examples are required to have mock/dry-run paths.
- Known technical corrections: `-e` versus `-E STRING`, `+=` expansion timing, `$(eval ...)` recipe timing, and GNU Make 4.4+ `--shuffle` are explicitly covered.

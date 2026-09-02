---
type: concept
aliases:
  - Shell Script in EDA_Shell脚本实战
tags:
  - asic
  - tools
  - shell
source_spec: "POSIX Shell Command Language（IEEE 1003.1）；GNU Bash Manual"
queries: 1
---
# Shell脚本实战

Shell 脚本是 IC 流程的**胶水语言**——把仿真器、综合器、解析器串成一条流水线：逐阶段执行工具、检查退出码、搬运文件、归档日志。流程脚本的正确性标准不是"语法能跑"，而是**失败可检测、日志可诊断、重跑幂等**。本文聚焦 IC 流程脚本的三个核心：退出码与 set -e、变量与循环、一个仿真回归驱动骨架。

## 原理

### 退出码与 set -e：失败必须可见

EDA 工具失败时返回非零退出码——流程脚本必须在每一站检查，否则"综合失败了还继续跑布线"的静默错误会浪费一整天：

```shell
#!/bin/bash
# 流程脚本头部惯例：退出即失败 + 未定义变量报错 + 打印命令（逐行说明）
set -euo pipefail
# set -e  任何命令失败（非零退出码）立即终止脚本——默认行为是继续执行，静默失败是流程大忌
# set -u  引用未定义变量即报错——变量名拼写错误（如 $TOP_MOULE）当场暴露而非产生空字符串
# set -o pipefail  管道中任一环节失败都算失败——默认只检查管道最后一个命令的退出码

log() { echo "[$(date +%H:%M:%S)] $*"; }  # log 函数：时间戳 + 参数——流程日志必须带时间定位

log "综合开始: $TOP"
dc_shell -f scripts/synth.tcl > logs/synth.log 2>&1   # 综合：stdout/stderr 都进日志（2>&1 合并）
log "综合完成: 退出码 $?"
# $? 上一条命令的退出码——set -e 已兜底非零即停，这里只为日志留痕
```

**要点**：（1）`set -euo pipefail` 三件套是流程脚本的默认配置——任何静默失败都会放大为签核事故；（2）日志带时间戳、工具输出全量落盘——事后定位"哪一步几点钟挂了"全靠日志；（3）退出码契约：脚本内部命令失败要向上传递非零码，让上层 Makefile 能感知失败。

### 变量、循环与文件操作

流程脚本的第二层是路径变量化与批量操作：

```shell
#!/bin/bash
# 仿真回归驱动骨架（逐行说明）
set -euo pipefail
SIM=./simv                      # 仿真器可执行文件：路径变量化
TC_DIR=testcases                # 测试用例目录
PASS=0; FAIL=0                  # 计数器：回归必须汇总通过/失败数

for tc in "$TC_DIR"/*.sv; do    # 遍历全部用例文件：通配符展开、引号防空格路径
    name=$(basename "$tc" .sv)  # basename 去目录去后缀：取用例名作为结果文件前缀
    if "$SIM" +UVM_TESTNAME="$name" -l "logs/$name.log"; then  # 运行仿真：退出码 0 为通过
        PASS=$((PASS + 1))      # $(( )) 算术展开：计数器自增
    else
        FAIL=$((FAIL + 1))
        cp "logs/$name.log" "logs/FAIL_$name.log"  # 失败日志打标归档：回归跑完再逐个排查
        echo "FAILED: $name" >> logs/fail_summary.txt   # >> 追加失败摘要：多次运行不覆盖
    fi
done
echo "回归完成: PASS=$PASS FAIL=$FAIL"     # 汇总输出：一眼看到本次回归结论
[ "$FAIL" -eq 0 ] || exit 1               # 有失败则脚本以非零退出：上层流程据此判定回归不通过
```

**要点**：（1）**遇错不中断**——回归要"跑完全部再汇总"，与普通流程脚本的 set -e 相反，这里刻意不 set -e（失败分支自己处理）；（2）失败日志打标归档（FAIL_ 前缀 + 摘要文件）——跑完几百个用例后再逐个定位；（3）汇总退出码向上传递——回归脚本的退出码是 CI 与 Makefile 的判定依据。

### 与 Makefile 的分工

Shell 与 Makefile（见 [[tools/concepts/20-Makefile小型工程实战|Makefile小型工程实战]]）的分工原则：**Makefile 管"依赖与增量"（什么变了要重跑），Shell 管"过程与流程"（怎么跑、失败怎么办）**。Makefile 目标里调用 Shell 脚本、Shell 脚本里不再嵌套 make——单一方向调用避免循环。常用命令组合：`find ... -name '*.log' -newer` 做增量判断、`xargs -P` 并行跑批、`tar` 归档结果目录。

## 关键要点

- **set -euo pipefail 是流程脚本默认配置**：静默失败是流程脚本第一杀手——综合失败继续布线浪费一整天
- **回归脚本例外：遇错不中断**：跑完全部用例再汇总——失败日志打标归档（FAIL_ 前缀）、摘要追加
- **日志三要素**：时间戳、工具全量输出、退出码留痕——事后定位全靠日志
- **变量路径化与引号**：路径含空格必须引号——通配符展开与 `basename` 处理批量文件
- **退出码是脚本契约**：回归有失败必须非零退出——上层 Makefile/CI 据此判定，输出再漂亮退出码 0 也是假通过
- **与 Makefile 单向分工**：Makefile 管依赖增量、Shell 管过程流程——不互相嵌套调用

## 与其他概念的关系

- [[tools/工具与脚本|工具与脚本]] — Shell 在工具链中的胶水定位：串接仿真器/综合器/解析器的流水线
- [[tools/concepts/20-Makefile小型工程实战|Makefile小型工程实战]] — 依赖与增量的分工：Makefile 目标内调用 Shell 脚本的单向关系
- [[tools/concepts/21-Makefile仿真回归实战|Makefile仿真回归实战]] — 回归的两种组织方式：Makefile 目标驱动 vs Shell 循环驱动
- [[tools/concepts/Python脚本实战|Python脚本实战]] — Shell 编排流程、Python 做数据解析——报告处理交给 Python

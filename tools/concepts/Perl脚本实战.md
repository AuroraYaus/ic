---
type: concept
aliases:
  - Perl in EDA_Perl脚本实战
tags:
  - asic
  - tools
  - perl
source_spec: "Programming Perl (4th Ed., O'Reilly)；perlre 官方正则文档"
queries: 1
---
# Perl脚本实战

Perl 在数字 IC 工程中的定位是**存量生态与正则文本处理**——EDA 行业的流程脚本在 1990-2010 年代以 Perl 为主力，今天大量仍在服役的网表改写、报告转换、格式拼接脚本都是 Perl 写的；新脚本已逐渐由 Python 取代（见 [[tools/concepts/Python脚本实战|Python脚本实战]]），但**读懂与维护存量 Perl 脚本是 IC 工程师的基本功**。Perl 的强项：正则直接内置于语言、`-p/-n/-e` 单行处理、文本管线极简。本文聚焦读维护场景：单行处理模式、正则、IC 常见存量脚本模式。

## 原理

### 单行处理模式：-n -p -e

Perl 的杀手特性是命令行单行文本处理——`-e` 执行代码、`-n` 逐行读入、`-p` 逐行读入并默认打印：

```shell
# Perl 单行处理三例（shell 命令，逐行说明）
perl -ne 'print if /slack\s+\(-[\d.]+\)/' timing.rpt
# -n   逐行读入文件并执行代码（不默认打印）——文件行存入特殊变量 $_
# /.../ 正则匹配 $_（当前行）——匹配到含 "slack (-负值)" 的行
# print if ...  后置条件语法：匹配才打印——效果等于 grep 负 slack 行

perl -pe 's/\.v\b/.sv/g' filelist.f > filelist.sv
# -p   逐行读入并默认打印（处理完自动输出 $_）
# s///g  替换操作：行内全部 .v 后缀换成 .sv——\b 词边界防止匹配 .vdd 之类
# >     重定向输出——-p 模式配合重定向即"过滤转换"

perl -ne 'END { print "$n lines\n" } ++$n' netlist.v
# 单行计数：每行 ++$n，END 块在文件结束后执行——不写中间变量到外面
```

**要点**：`$_` 是隐式当前行、`/.../` 与 `s///` 默认作用于 `$_`——单行 Perl 的高密度正来源于这套隐式约定；`-i` 选项可以原地改写文件（`perl -pi -e 's/a/b/' file`），存量流程脚本大量使用 `-pi` 做批量网表改写。

### 正则与文本字段处理

Perl 的正则能力是 TCL/Python 正则的源头（语法互通，见 [[tools/concepts/TCL脚本实战|TCL脚本实战]]）。IC 场景的典型模式——从报告文本中按字段提取：

```perl
#!/usr/bin/perl
## @brief 解析功耗报告的层次统计，输出按功耗降序的模块表
## @usage perl power_parse.pl power.rpt
## @exit_code 0 成功

use strict;         # strict：强制变量先声明——存量脚本常缺失，维护时建议补上但注意兼容
use warnings;       # warnings：开启警告——未初始化变量等隐患当场暴露

my %power;          # my 词法变量声明（strict 要求）；% 前缀表哈希：模块名 → 功耗值
while (my $line = <>) {            # <> 钻石操作符：读命令行参数文件（无参数则读 stdin）
    if ($line =~ /^(\S+)\s+(\d+\.\d+)\s+mW/) {   # 正则捕获：模块名 + 数值 + 单位 mW
        # ^ 行首、(\S+) 非空白串（模块名）、(\d+\.\d+) 浮点数（功耗）、\s+ 空白分隔
        $power{$1} = $2;           # $1 $2 捕获组：存入哈希——同名模块多次出现取最后一次
    }
}
foreach my $mod (sort { $power{$b} <=> $power{$a} } keys %power) {
    # 按功耗数值降序排序模块：<=> 数值比较（cmp 是字符串比较，别用错）
    printf "%-20s %8.2f mW\n", $mod, $power{$mod};  # printf 对齐输出：模块名 20 列左对齐
}
```

**要点**：（1）`use strict; use warnings;` 是新脚本标配——存量脚本没有也不影响运行，但维护时加 strict 前先评估兼容性（旧脚本可能依赖未声明变量）；（2）哈希 + 排序输出是 Perl 报告统计的经典模式；（3）`<=>` 数值比较 vs `cmp` 字符串比较——比较运算符用错是存量脚本最常见的维护 bug。

### 存量流程脚本的典型模式

存量 Perl 流程脚本的三种高频模式：（1）**网表文本改写**——`-pi -e 's///'` 批量替换端口名/模块名（重命名、层级调整）；（2）**报告格式转换**——把工具报告转成表格/CSV 供下游工具（比对流程的中间格式）；（3）**日志聚合**——跨文件统计违例数、聚合各阶段报告。维护要点：改正则前先备份原文并抽样验证（正则改错静默漏行比报错更危险）；Perl 版本的语法差异（5.8 vs 5.30+）——升级解释器前检查存量脚本的依赖特性。

## 关键要点

- **Perl 的定位是存量生态**：新脚本用 Python，但读懂维护 1990-2010 年代的存量流程脚本是基本功
- **-n -p -e 单行处理是 Perl 招牌**：`$_` 隐式当前行、正则默认作用于 `$_`——高密度文本管线
- **-pi 原地改写**：批量网表/文件列表改写的存量惯用法——改动前备份，正则改错静默漏行比报错危险
- **use strict 与 use warnings**：新脚本标配；给存量脚本补 strict 前先评估兼容性
- **比较运算符坑**：数值用 `<=>`、字符串用 `cmp`——用错是维护存量脚本的第一常见 bug
- **捕获组与哈希统计**：`$1/$2` + 哈希 + sort 排序输出——报告统计的 Perl 经典范式

## 与其他概念的关系

- [[tools/工具与脚本|工具与脚本]] — Perl 在工具链中的存量位置：与新脚本（Python）的交接关系
- [[tools/concepts/Python脚本实战|Python脚本实战]] — 新老脚本语言的分工：Python 做新开发、Perl 做存量维护——正则语法互通
- [[tools/concepts/TCL脚本实战|TCL脚本实战]] — 正则同源：Perl 正则与 TCL regexp 语法互通，报告解析的两种实现
- [[tools/concepts/Shell脚本实战|Shell脚本实战]] — 单行处理与 Shell 管线的配合：perl -ne 常嵌在 Shell 管道中做过滤转换

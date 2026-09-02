---
type: concept
aliases:
  - Python in EDA_Python脚本实战
tags:
  - asic
  - tools
  - python
source_spec: "Python 3.11 官方文档；PEP 8 风格指南"
queries: 1
---
# Python脚本实战

Python 在数字 IC 工程中的角色是**数据面脚本**——流程控制交给 Makefile 与 Shell（见 [[tools/concepts/Shell脚本实战|Shell脚本实战]]），文本解析与数据统计交给 Python：时序/功耗/覆盖率报告的抓取汇总、网表与约束文件的批量改写、验证平台外围的数据生成。选择 Python 的原因：正则与字典表驱动、标准库够用、可读性好——一个 50 行的报告解析器比同功能的 Perl 好维护一个数量级。

## 原理

### 报告解析：正则 + 字典表驱动

IC 工具的报告是半结构化文本——用正则抓取关键字段、用字典聚合是标准范式。解析时序报告中最差路径的 Slack：

```python
#!/usr/bin/env python3
"""@brief 解析 PrimeTime 时序报告，按路径组统计最差 Slack
@usage  python3 parse_timing.py timing.rpt
@exit_code 0 成功；1 报告格式不匹配"""

import re
import sys
from collections import defaultdict

def parse_timing_report(rpt_file):
    """@brief 扫描时序报告，抓取每条路径的 Path Group 与 Slack 值
    @param rpt_file 报告文件路径（PrimeTime report_timing 文本输出）
    @return 字典 {路径组: 最差 slack 列表}
    @note  正则按报告字段行匹配——工具版本升级时需回归验证匹配模式"""
    pattern = re.compile(
        r'^\s*(?P<group>\w+)\s+.*?slack\s+\((?P<slack>-?[\d.]+)\)',  # 行首组名 + slack (数值)
        re.IGNORECASE)                                              # 大小写不敏感：工具输出风格差异
    result = defaultdict(list)          # 默认字典：首次访问自动建空列表——省去初始化判断
    with open(rpt_file, encoding='utf-8') as f:   # 显式 UTF-8：报告含中文注释时避免解码错误
        for line in f:                  # 逐行流式读取：报告可达 GB 级，不能 read() 全载入
            m = pattern.match(line)     # 行首匹配：只匹配字段行，跳过路径明细行
            if m:
                result[m.group('group')].append(float(m.group('slack')))  # 命名分组取值：可读性优先
    return {g: min(slacks) for g, slacks in result.items()}   # 每组取最差值：min 即最负 slack

if __name__ == '__main__':              # 脚本入口守卫：被 import 时不执行——便于复用为模块
    if len(sys.argv) != 2:
        sys.exit('用法: parse_timing.py <报告文件>')   # 参数校验：脚本必须给出明确用法提示
    groups = parse_timing_report(sys.argv[1])
    for group, worst in sorted(groups.items(), key=lambda kv: kv[1]):  # 按 slack 升序：最差组排最前
        print(f'{group:12s}  worst slack: {worst:>8.3f}')  # 对齐输出：组名 12 列、slack 右对齐 3 位小数
```

**要点**：（1）正则用命名分组（`?P<group>`）——字段多了以后 `m.group(3)` 的数字索引不可维护；（2）流式逐行读取——GB 级报告不能整体载入；（3）`defaultdict` 与字典推导——IC 脚本的数据聚合九成是"分组取最值"模式。

### 文件批处理：网表与约束改写

批量改写是 Python 的第二个主场——例如给约束文件批量追加多周期约束、网表端口重命名：

```python
"""@brief 批量为约束文件追加 set_multicycle_path 约束
@usage  python3 add_mcp.py constraints.sdc list.txt
@note   改动前写备份——约束文件的错误改动会导致整个签核无效"""
import sys
from pathlib import Path

def add_multicycle(sdc_file, pairs_file):
    """@brief 读取路径对列表，向 SDC 追加保持时间配套约束
    @param sdc_file  待修改的 SDC 约束文件
    @param pairs_file 路径对列表（每行: from_clk to_clk N）
    @return 追加的约束行数"""
    sdc = Path(sdc_file)
    backup = sdc.with_suffix('.sdc.bak')        # 备份后缀：改动前必须留退路
    sdc.replace(backup)                          # 原文件改名备份
    added = 0
    with open(backup, encoding='utf-8') as src, open(sdc, 'w', encoding='utf-8') as dst:
        for line in src:                         # 流式复制：先原样拷贝全部旧内容
            dst.write(line)
        for pair in open(pairs_file, encoding='utf-8'):   # 逐对追加约束
            frm, to, n = pair.split()            # 空格分割：from 时钟 / to 时钟 / 周期数
            dst.write(f'set_multicycle_path {n} -setup -from [get_clocks {frm}] '
                      f'-to [get_clocks {to}]\n')            # Setup 多周期约束
            dst.write(f'set_multicycle_path {int(n)-1} -hold -from [get_clocks {frm}] '
                      f'-to [get_clocks {to}]\n')            # Hold 配套 N-1：漏配是经典错误
            added += 2
    return added

if __name__ == '__main__':
    print(f'追加 {add_multicycle(sys.argv[1], sys.argv[2])} 行约束')
```

**要点**：（1）改文件先备份——SDC 改错会让整个签核失效，备份是最便宜的保险；（2）f-string 生成约束行——注意 TCL 的 `[]` 与 `{}` 在 Python 字符串里是普通字符，生成 TCL/SDC 内容时不要误用 Python 转义。

### 与 EDA 工具的集成

Python 与工具链的三种集成方式：（1）**命令行工具**——独立脚本被 Makefile/Shell 调用（见 [[tools/concepts/Shell脚本实战|Shell脚本实战]]），输入输出全是文件，零耦合；（2）**生成 TCL**——Python 生成 TCL 脚本内容再喂给 DC/PT（批量约束、批量报告最常用）；（3）**数据管道**——CSV/JSON 中转报告数据给表格与看板。保持"文件进文件出"的纯数据面定位——流程控制永远留给 Makefile。

## 关键要点

- **Python 定位是数据面**：报告解析、批量改写、数据聚合——流程调度归 Makefile/Shell，不要用 Python 重造流程
- **正则命名分组 + 流式读取**：GB 级报告逐行处理，命名分组比数字索引可维护
- **分组取最值是 IC 脚本的主模式**：defaultdict + min/max + sorted 三件套覆盖九成报告统计
- **改文件先备份**：SDC/网表的错误改动代价极高——备份一行代码、省一次事故
- **生成 TCL 时注意转义**：Python 字符串里的 `[]` `{}` 是 TCL 语法不是 Python 语法——用 f-string 原样输出
- **脚本入口带用法说明**：`__main__` 守卫 + argv 校验 + 明确 exit_code——流程脚本被下一个人调用时不靠猜

## 与其他概念的关系

- [[tools/工具与脚本|工具与脚本]] — Python 在工具链中的数据面定位：与 TCL（工具内）、Shell（流程胶水）的分工
- [[tools/concepts/TCL脚本实战|TCL脚本实战]] — 生成 TCL/解析 TCL 输出的配对关系：Python 生成批量约束、TCL 在工具内执行
- [[tools/concepts/Shell脚本实战|Shell脚本实战]] — 脚本调度的上下游：Shell 编排流程调用 Python 解析器
- [[tools/concepts/C语言在数字IC中的应用|C语言在数字IC中的应用]] — C 模型与 Python 的配合：重计算用 C、轻解析用 Python

# Plan: C 语言章节补齐（缺口清单第 1 项）
_Locked via grill — by Claude + AuroraYaus（2026-09-01）_

> 前序任务（review/ 复习自测题库 9 篇）已完成并验证（113 链接零死链、合规扫描零违例）。本计划为待补考点清单第 1 项。

## Goal

补齐 tools/ 域的 C 语言缺口——按"数字IC工程师全场景 C"定位分两篇：

1. `tools/concepts/C语言在数字IC中的应用.md` — 位运算/指针/链表/宏（笔试高频）+ 寄存器访问与 volatile/位域/大小端
2. `verification/concepts/DPI-C接口.md` — SystemVerilog 与 C 的双向接口（import/export、类型映射、上下文、编译链接），与 UVM/验证平台章节闭环

完成后为 `review/工具脚本自测题.md` 补 C 语言自测题，并从 `review/复习自测入口.md` 待补清单移除第 1 项。

## Approach

1. 两篇均按概念文件规范：frontmatter（type: concept、tags、source_spec 真实来源 K&R / IEEE 1800-2017 LRM）、100-400 行、术语首现标注、代码块逐行中文注释 + 函数 DOXYGEN 注释（中文）
2. 读者假设：已有 C 基础语法（变量/控制流/函数），章首一句话声明，不重复 C 教科书
3. 挂载：`tools/工具与脚本.md` 概念索引加 C 语言条目；`verification/功能验证.md` 概念索引加 DPI-C 条目
4. `review/工具脚本自测题.md` 补 4 题（位运算、指针/链表、宏、volatile/寄存器访问）；`review/复习自测入口.md` 待补清单移除第 1 项、索引表同步
5. 终验：wikilink 零死链 + 圈号/加黑定界扫描

## Key decisions & tradeoffs

- **范围 = IC 全场景 C**（含 DPI-C），不是纯笔试向——与库内验证章节闭环，符合知识库定位
- **两篇分域**：C 语言篇放 tools/（效能工具箱定位）、DPI-C 篇放 verification/（与 UVM/验证平台 wikilink 就近）——单篇 400 行装不下 DPI-C 细节
- **读者假设**：有基础语法，聚焦 IC 场景化要点——库是 IC 知识库不是 C 教程

## Risks / open questions

- DPI-C 类型映射表以 IEEE 1800 为标准，仿真器差异（VCS/Questa）只写主流用法
- 后续缺口项（经典设计题例 → 脚本实战 → JTAG → LEC → DSP → PCIe → DDR）仍按清单逐项推进

## Out of scope

- C 语言基础语法教程（变量/控制流/函数定义不展开）
- 嵌入式 RTOS/驱动深度内容（只覆盖寄存器访问层面的 IC 交叉点）
- C++（class/模板）——验证平台 OOP 由 SystemVerilog 覆盖


---

## 进度记录（2026-09-01）

- [x] C 语言两篇（本计划主体）——已完成
- [x] 经典设计题例（rtl-design/concepts/经典设计题例.md + 编程自测 3 题）
- [x] 脚本实战四篇（TCL/Python/Shell/Perl + 工具自测 8 题）
- [x] JTAG 边界扫描（可测试性设计扩充 + ASIC流程自测 1 题）
- [x] LEC（asic-flow/concepts/逻辑等价性检查.md + ASIC流程自测 1 题）
- [x] DSP 算法 IP（rtl-design/concepts/DSP算法IP.md + RTL设计自测 3 题）
- [x] PCIe 协议（architecture/concepts/PCIe协议.md + 体系结构自测 1 题）
- [x] DDR PHY 训练（architecture/concepts/DDR接口与PHY训练.md + 体系结构自测 1 题）
- [x] 终验：全库 wikilink 零真实死链（误报均定性：行内代码 `[[ ]]`/规则示例字符/记忆镜像链接）、圈号/加黑定界零违例

待补考点清单全部清零（review/复习自测入口.md 已更新为"全部缺口已补齐"）。遗留备忘：tools/工具与脚本.md "待扩展"仍列 Git（未纳入本轮清单，后续可立为新缺口项）。

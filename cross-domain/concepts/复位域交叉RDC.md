---
type: concept
aliases:
  - Reset Domain Crossing_RDC
  - RDC
  - 复位域交叉
tags:
  - asic
  - cross-domain
  - reset
  - cdc
  - verification
source_spec: "Synopsys SpyGlass RDC / VC Formal RDC User Guide；Cadence Conformal RDC；Cummings, 'Asynchronous & Synchronous Reset Design Techniques', SNUG 2002/2003；Keating et al., Low Power Methodology Manual"
queries: 1
---
# 复位域交叉（Reset Domain Crossing, RDC）

复位域交叉（Reset Domain Crossing, RDC）指**信号从一个复位域穿越到另一个复位域**的路径及其带来的可靠性问题。它是跨时钟域（CDC）在复位维度上的对偶问题：CDC 关心时钟域边界上采样的亚稳态风险，RDC 关心复位域边界上**复位释放时刻**的采样正确性——尤其是恢复时间（Recovery）与移除时间（Removal）违例、以及复位释放顺序失配导致的偶发功能错误。现代多核 SoC 中功能复位、调试复位、电源管理复位、扫描复位并存，复位域交叉问题从"边角案例"变成必须系统检查的工程约束。

与 CDC 的"概率性失效"（亚稳态取决于相位差与噪声）类似，RDC 失效在硅片上表现为**偶发、难复现**的功能异常——仿真中可能完全正常，只在特定复位释放时序组合下才出现，因此静态 RDC 分析是 Signoff 的强制检查项，与 CDC 验证同等地位。

## 原理：为什么复位域交叉会出问题

RDC 失效有三类机理。**（1）复位释放窗口采样**：异步复位释放瞬间（deassertion），源域寄存器输出从复位值跳变到功能值；目标域寄存器如果恰好在这段不稳定窗口内采样，可能采到旧值、新值或亚稳态——本质是异步复位释放违反了目标触发器的恢复/移除时间（Recovery / Removal）。**（2）复位期间组合逻辑扇出**：源域寄存器在复位期间输出固定值，但信号路径上存在组合逻辑时，目标域在释放窗口看到的可能是经过门控/混合逻辑的毛刺或不稳定中间值（尤其复位信号被当作数据参与逻辑运算时）。**（3）复位释放顺序失配**：消费域先于源域释放复位，采样到源域复位期间的不稳定输出——这是工程实践中最常见的 RDC 根因，属于系统级复位序列（Reset Sequencing）设计缺陷而非单模块问题。

## 典型场景

1. **异步复位跨时钟域传播**：源域复位信号经组合路径传播到目标域寄存器的复位端，释放时刻未与目标域时钟同步
2. **多复位域并存**：功能复位、调试复位（Debug）、电源管理复位（PMU）、扫描复位（ATPG）在芯片内交叉——扫描模式的复位释放路径往往与功能模式完全不同
3. **复位序列错误**：顶层复位状态机按错误顺序释放各域复位（消费域先于源域）
4. **复位当数据使用**：复位信号与数据信号在同一条组合路径上混合，或复位释放被数据依赖门控
5. **低功耗/UPF 场景**：电源门控域关断/上电与复位释放交叉——关电域的隔离单元、保持寄存器与复位顺序耦合

## 静态检查（RDC Analysis）

RDC 检查由静态分析工具完成（Synopsys SpyGlass RDC / VC Formal RDC、Cadence Conformal RDC、Siemens Questa RDC），核心步骤：

1. **复位域识别**：按复位源/复位信号对设计划分复位域（类似 CDC 的时钟域划分）
2. **跨域路径识别**：找出从复位域 A 的寄存器/端口驱动到复位域 B 寄存器/端口的路径
3. **同步器存在性检查**：复位信号跨域时是否经过复位同步器（异步置位、同步释放）
4. **复位释放顺序检查**：结合 SDC 与 UPF 中的复位时序/电源状态，验证多域释放顺序（reset release order）合法
5. **联合分析**：复位域与时钟域交叉叠加的路径风险最高（跨时钟 + 跨复位域），需要 CDC 与 RDC 联合检查

CDC 工具通常包含部分复位穿越检查（如 SpyGlass CDC 的 reset crossing 检查项），但专用 RDC 工具覆盖更完整——两者在 Signoff 中常同时执行。

## 修复与缓解方法

**（1）复位同步器（Reset Synchronizer）**：异步断言、同步释放——复位置位立即生效（不受时钟约束），释放时经两级触发器同步到本地时钟，消除恢复/移除时间违例。这是 RDC 最基础的修复手段：

```verilog
// 两级复位同步器：异步断言、同步释放（可综合，标准 RTL 写法）
module rst_sync (
    input  wire clk,         // 目标域时钟：两级触发器同步到该时钟域
    input  wire rst_n_async, // 异步复位输入（低有效）：来自上游复位源
    output wire rst_n_sync   // 同步后的本地复位（低有效）：供目标域使用
);
    reg [1:0] sync_ff; // 两级同步触发器：第一级吸收亚稳态，第二级输出稳定值

    // 异步复位、同步释放：rst_n_async=0 时立即置位（不受时钟约束）；
    // 释放时（0→1）需经过 2 个 clk 上升沿才逐级传递为 1，避免恢复/移除时间违例
    always @(posedge clk or negedge rst_n_async) begin
        if (!rst_n_async)
            sync_ff <= 2'b00;              // 异步断言：复位立即生效
        else
            sync_ff <= {sync_ff[0], 1'b1}; // 同步释放：1 逐级移入，2 拍后输出释放
    end

    assign rst_n_sync = sync_ff[1]; // 同步后的复位输出（低有效）
endmodule
```

**（2）复位排序（Reset Sequencing）**：系统级定义多域释放顺序——提供跨域信号的源域必须先于消费域解除复位。常用层级：PLL/OSC 域最先（提供稳定时钟）→ 系统控制器域 → 高速域（CPU/GPU/NoC）→ 低速外设域，由复位状态机统一管理，并在仿真中用断言检查。

**（3）复位隔离（Isolation Clamp）**：源域处于复位期间，用隔离单元把跨域信号钳位到安全逻辑值（全 0 或全 1），切断不稳定输出向目标域的传播。

**（4）跨域握手与保持寄存器**：高可靠性场景中，跨复位域信号采用握手协议（请求/应答）或保持寄存器（Retention Register）在复位前后保存状态，避免释放窗口采样。

**（5）仿真验证**：X 传播检查 + 复位序列断言。示例断言（仅仿真）：

```systemverilog
// Testbench only（仅仿真）：RDC 复位序列检查——消费域释放时源域必须已释放
// @(posedge clk)：每个时钟上升沿采样
// $rose(rst_n_dst)：消费域复位从 0→1（释放）的边沿
// |->：交叠蕴含——同一周期检查后续条件
// rst_n_src：源域复位必须先完成释放（为 1），否则报警
property p_reset_seq;
    @(posedge clk) $rose(rst_n_dst) |-> rst_n_src;
endproperty
assert property (p_reset_seq) else $error("RDC 违例：消费域先于源域释放复位");
```

## 关键要点

1. **RDC 是 CDC 的对偶问题**：CDC 检查时钟域边界的亚稳态，RDC 检查复位域边界在复位释放时刻的采样正确性
2. **核心风险窗口是复位释放**：失效集中在 deassertion 瞬间——恢复/移除时间违例、释放窗口采样、顺序失配
3. **复位排序是最常见根因**：消费域先于源域释放复位是工程实践中最典型的 RDC 缺陷，属于系统级复位状态机设计问题
4. **异步复位必须"异步置位、同步释放"**：两级复位同步器是 RDC 的基础修复手段，且与 CDC 同步器的设计原则同源
5. **RDC 静态检查是 Signoff 强制项**：SpyGlass RDC / VC Formal RDC / Conformal RDC / Questa RDC 识别跨复位域路径、同步器缺失与释放顺序错误——仿真难以系统性覆盖
6. **复位域与时钟域交叉叠加时风险最高**：跨时钟且跨复位域的路径需要 CDC 与 RDC 联合分析

## 与其他概念的关系

- [[cross-domain/concepts/复位策略|复位策略（Reset Methodology）]] — 复位域划分（Reset Domain Partition）与复位排序（Reset Sequencing）定义 RDC 检查的边界；复位同步器是两者共用的基础结构
- [[cross-domain/concepts/跨时钟域设计|跨时钟域设计（CDC）]] — RDC 是 CDC 的特殊子问题（复位域跨越），两者的同步器设计与 MTBF 分析框架对偶；联合检查覆盖跨时钟又跨复位域的路径
- [[verification/功能验证|功能验证（Verification）]] — 复位序列断言、X 传播检查是 RDC 的仿真验证手段；形式验证的 X-Propagation 分析可补充静态检查
- [[cross-domain/concepts/低功耗设计|低功耗设计（Low Power Design）]] — UPF 电源门控域的关断/上电与复位释放顺序耦合，隔离单元与保持寄存器同时服务低功耗与 RDC
- [[rtl-design/RTL设计|RTL 设计（RTL Design）]] — 异步复位同步释放的编码风格是 RDC 防御的 RTL 落地，复位策略在 RTL 中实现

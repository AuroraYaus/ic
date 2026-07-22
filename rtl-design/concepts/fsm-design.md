---
type: concept
aliases:
  - 有限状态机
  - Finite State Machine
  - FSM
  - Moore状态机
  - Mealy状态机
tags:
  - asic
  - rtl
  - fsm
  - state-machine
source_spec: "Wakerly, Digital Design; Cummings, SNUG 2000 FSM Coding Styles; IEEE 1800-2017"
---

# 有限状态机设计（FSM Design）

有限状态机（Finite State Machine, FSM）是数字控制逻辑最核心的建模和实现范式。FSM 将系统的行为抽象为有限个状态（State），每个状态定义特定的输出行为，状态之间的转换（Transition）由输入条件触发。FSM 广泛应用于总线协议控制器（AXI、PCIe）、存储器控制器、中断控制器、流水线控制、网络协议解析和加密引擎等几乎所有数字控制模块。FSM 的设计质量直接影响系统的功能正确性、面积、功耗和时序收敛——一个精心设计的 FSM 时钟频率可以高于 1GHz，而一个粗糙编写的 FSM 可能成为整个芯片的时序瓶颈。现代 RTL 设计中，FSM 的编码已经从手工门级推导发展为标准化模板驱动的过程，关键挑战在状态编码选择、未使用状态的安全处理和 FSM+Datapath 的架构分离。

## 原理

### Moore 与 Mealy 模型

FSM 依据输出函数与当前状态和输入的关系，分为两种基本模型：

**Moore 状态机**：输出**仅**取决于当前状态，与输入无直接关系。输出在状态转换的时钟沿之后改变——输出与状态同步变化。典型用例包括：定时器（状态对应剩余时间）、仲裁器（状态对应当前授权方）、ALU 控制（状态对应操作类型）。Moore 机的输出相对于输入存在天然的过滤效果——输入毛刺仅影响次态，不直接传播到输出，输出毛刺少、时序收敛简单。代价是可能用更多的状态来编码同一行为（因为每种不同输出需要独立的状态）。

**Mealy 状态机**：输出取决于当前状态**和**当前输入。输入改变可以立即反映到输出（组合逻辑路径穿透），不等待时钟沿。典型用例包括：串行协议解析器（需要响应输入字符立即产生控制信号）、流水线握手（valid/ready 与数据同步变化）、高速接口（输出需要在同一周期响应输入）。Mealy 机状态数更少，响应更快（输入到输出的组合延迟更短），但输出可能携带输入毛刺，且输出时序路径更复杂（输出组合逻辑同时依赖状态寄存器和输入端口）。

实际设计中，Moore 和 Mealy 的边界是模糊的——同一个 FSM 可以从 Moore 的角度设计状态，但将某些输出通过组合逻辑提前产生，从而在状态数不增加的前提下实现 Mealy 级响应速度。

### 三进程（Three-Process）编码风格

现代 SystemVerilog FSM 编码推荐使用**三进程（Three-Process Always Block）模板**，将状态寄存器的更新、次态逻辑和输出逻辑严格分离为三个独立的 always 块：

1. **状态寄存器进程（State Register Process）**：`always_ff @(posedge clk or negedge rst_n)`——唯一的时序 always 块，负责在时钟沿将 next_state 赋给 current_state。除复位赋值外，此块中**不出现任何其他逻辑**——任何试图在状态寄存器块中插入条件判断的做法都违反了分离原则，会导致综合困难。

2. **次态逻辑进程（Next-State Logic Process）**：`always_comb`——纯组合逻辑，根据当前状态和所有输入信号计算下一个状态。此块中使用 case 语句枚举所有状态，每个 case 项包含 if-else 或嵌套 case 描述转换弧。**必须包含 default 分支**以避免锁存器推断，且 default 通常指向错误恢复逻辑或安全状态（而不是保持当前状态）。

3. **输出逻辑进程（Output Logic Process）**：`always_comb`——纯组合逻辑，根据当前状态和输入（Mealy 模式下）计算所有输出信号。Moore 模式的输出仅依赖 current_state；Mealy 模式的输出同时依赖 current_state 和输入。输出逻辑块的 case 结构必须与次态逻辑块的状态枚举一一对应，确保一致性。

三进程分离的核心优势：a) 状态寄存器和组合逻辑边界清晰，STA 工具可精确计算每条路径的时序；b) 综合工具对独立的组合块优化效果更好（不会因为混入时序约束而过度保守）；c) 代码审查可以独立验证次态逻辑（功能正确性）和输出逻辑（接口时序）；d) Lint 工具可以在每个 always 块内实施针对性的规则检查（如组合块锁存器推断检查、时序块混合赋值检查）。

### 状态编码策略

状态编码（State Encoding）的选择对 FSM 的面积、速度和功耗有直接且显著的影响。综合工具通常支持自动编码优化，但设计者应理解编码的理论基础：

- **二进制编码（Binary Encoding）**：N 个状态用 log2(N) 比特表示。状态寄存器最少，但次态逻辑需要译码器——每个当前状态的二进制码需要译码为独热再编码为次态——次态逻辑面积与状态数和输入数的乘积成正比。适用于状态数少的小型 FSM（<16 个状态）。

- **格雷码编码（Gray Code Encoding）**：相邻状态的编码仅一位不同。关键在于将 FSM 状态转换图映射到格雷码序列——只有单跳转路径的 FSM（如环形计数器）完美适用；多分支 FSM 通常无法保证所有相邻状态都是格雷相邻，效果有限。格雷码 FSM 的次态逻辑功耗低（状态变化时平均翻转比特少），在低功耗设计中可选。

- **独热编码（One-Hot Encoding）**：N 个状态用 N 个触发器表示，任意时刻仅一个触发器为 1。优点：次态逻辑极其简单——每个状态的次态仅取决于到达该状态的所有弧（前驱状态的独热信号与转换条件的与门聚合），不需要译码器。独热码的面积开销是 N 个触发器（而非 log2(N)），但组合逻辑面积往往比二进制编码更小，且在中等规模 FSM（16-128 状态）中综合结果面积/速度通常优于二进制编码。独热编码是 FPGA 和现代 ASIC 设计中 FSM 的默认选择。

- **自动编码（Auto/Enum Encoding）**：使用 SystemVerilog 的 enum 定义状态，由综合工具的编码约束（`enum enum_encoding`）或综合指令（Synopsys `fsm_encoding`）自动选择最优编码。这是推荐的设计实践——设计者用符号名称定义状态，编码策略由约束文件控制，可在不修改 RTL 的前提下进行编码 A/B 对比优化。

### 未使用状态的处理

N 个状态寄存器可以表示 2^N 种状态，但实际定义的有效状态通常远少于 2^N。未定义的编码构成**非法状态（Illegal States）**。如果电路因单粒子翻转（Single Event Upset, SEU）、电源干扰或复位不完整进入非法状态，FSM 需要确保能够安全恢复到有效状态（或至少进入安全的固定状态，如复位到 IDLE）。

未使用状态的常见处理策略：
- **安全状态恢复**：在次态逻辑 case 的 default 分支中将 next_state 指向 IDLE 或 SAFE 状态，确保任意非法状态在一个时钟周期后恢复。这是最简单的方案，但需要次态逻辑覆盖所有 2^N 种当前状态编码的译码。
- **错误检测**：额外逻辑持续检查 current_state 是否合法，一旦检测到非法状态立即发出中断信号或触发系统级安全复位。
- **综合工具的 safe_fsm 编译指令**：Synopsys 的 `syn_encoding = "safe"` 和 Cadence 的 `fsm_safe_state` 属性指示综合工具自动插入非法状态检测和恢复逻辑。

### FSM + Datapath 架构分离

在大型数字模块中，推荐将控制逻辑（FSM）与数据通路（Datapath）严格分离：
- **FSM（控制器）** 负责决策：输出控制信号（MUX 选择、寄存器使能、ALU 操作码、存储器读写使能）
- **Datapath（数据通路）** 负责计算：包含功能单元（加法器、乘法器、移位器、MUX）、寄存器和数据总线，根据 FSM 的控制信号选择数据流向和执行具体运算
- FSM 接收 Datapath 的状态信号（如比较器输出、计数器归零、FIFO 空满）作为输入条件，形成控制反馈闭环

这一分离将复杂时序收敛问题简化为两个子域：FSM 的控制信号时序（通常较浅的组合逻辑，容易收敛）和 Datapath 的数据路径时序（可能包含深组合逻辑链，需要流水线拆分）。FSM+Datapath 分离也是验证方法论的基础——FSM 可用 SVA 覆盖率驱动验证，Datapath 可用参考模型比对验证。


### 层次化有限状态机

当 FSM 状态数量超过约 30-40 个时，扁平（Flat）FSM 的次态逻辑开始呈现组合爆炸——每个状态的次态取决于大量输入和当前状态编码的交互，次态逻辑的延迟和面积随状态数超线性增长。**层次化有限状态机（Hierarchical FSM, HFSM）** 将一个复杂 FSM 分解为主状态机（Super-State Machine）和若干子状态机（Sub-State Machine）。主状态机仅管理粗粒度的模式切换（如 IDLE、ACTIVE、ERROR），每个主状态下激活对应的子状态机处理细粒度行为。典型的 HFSM 示例：DDR 控制器的主状态机管理 INIT、CONFIG、ACTIVE、POWER_DOWN 等顶层模式，ACTIVE 主状态下的子状态机处理行激活、列读写、预充电等 DRAM 时序协议。层次化分解将 O(S×I×log(S)) 的面积复杂度降低为 O(S_main + sum(S_sub_i)) 级别。在 RTL 实现中，主状态机和每个子状态机独立编码为三进程 FSM，互不干预——主状态机输出"子状态机使能"信号，子状态机在其使能有效时运转。


## 关键要点

- Moore FSM 输出仅依赖状态（输出与时钟同步、无毛刺），Mealy FSM 输出依赖状态+输入（响应快、状态少但可能传播输入毛刺）
- 三进程编码风格严格分离状态寄存器（always_ff）、次态逻辑（always_comb）和输出逻辑（always_comb），时序清晰、综合友好、lint 友好
- 独热编码在中等规模 FSM（16-128 状态）中次态逻辑简单、面积/速度权衡最优，是现代 ASIC 和 FPGA 的默认选择
- SystemVerilog enum 是 FSM 状态的推荐定义方式——类型安全、符号调试友好，综合工具可据此进行最优编码选择
- 次态逻辑的 default 分支必须将非法状态导向 IDLE（而非保持当前状态），确保单粒子翻转后可恢复
- FSM + Datapath 架构分离是控制器/数据通路经典设计模式的核心，将复杂的时序收敛问题分解为控制路径（浅逻辑）和数据路径（可流水线化）两个子域
- 状态机爆炸（State Explosion）是层级化 FSM（Hierarchical FSM）和多级嵌套 FSM 的控制策略驱动力——将复杂 FSM 分解为子状态机（Sub-FSM）的层次化结构
- 状态机的复位初始状态（Initial State）必须在 always_ff 的异步复位分支中显式赋值，综合工具将 IDLE 编码为复位后的触发器状态
- 输出寄存（Output Registering）——将组合输出经过额外的 D-FF 拍出——是消除输出毛刺和改善输出端口时序的常用优化手段
- Verilog/SV 中避免在次态逻辑 case 中嵌套过深的 if-else（三层以上），深嵌套会严重增加次态逻辑延迟而且难以代码审查

- FSM 的综合指令 `fsm_encoding`（Synopsys）和 `enum_encoding`（IEEE 1800）可以在不修改 RTL 的条件下切换编码策略，使设计者在综合后对比不同编码方案的面积、速度和功耗

## 与其他概念的关系

- [[rtl-design/concepts/sequential-logic|时序逻辑]] — FSM 的状态存储在 D 触发器中，always_ff 描述状态寄存器的时钟和复位行为，时序约束决定了 FSM 的最大时钟频率
- [[rtl-design/concepts/coding-style|RTL 编码风格]] — 三进程 FSM 模板、enum 命名约定、次态逻辑 case 结构的规范化要求和 lint 规则
- [[rtl-design/concepts/pipeline-design|流水线设计]] — FSM 控制流水线的 stall/flush 和数据冒险处理，流水线控制器本质是 FSM + Datapath 的典型实例
- [[rtl-design/concepts/systemverilog|SystemVerilog]] — enum 类型的状态定义、always_ff/always_comb 的意图显式编码、unique case 的互斥性声明

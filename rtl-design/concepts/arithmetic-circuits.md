---
type: concept
aliases:
  - Arithmetic Circuits_算术电路
  - Arithmetic Circuits
  - 加法器
  - 乘法器
tags:
  - asic
  - rtl
  - arithmetic
source_spec: "Parhami, Computer Arithmetic: Algorithms and Hardware Designs; Weste & Harris, CMOS VLSI Design; Hennessy & Patterson, Computer Architecture"
---

# 算术电路（Arithmetic Circuits）

算术电路是数字系统中执行加、减、乘、除和移位等基本算术运算的专门硬件单元，位于几乎所有芯片数据通路的性能关键路径上。算术电路的硬件实现选择——从简单的行波进位加法器（Ripple Carry Adder, RCA）到复杂的 Booth-Wallace 乘法器——直接决定了运算单元的延迟、面积和功耗，进而影响整个系统的时钟频率和能效比。现代综合工具可以从 RTL 中的 `+`、`*` 运算符自动推断硬件结构，但了解底层算法和实现结构对于性能优化（如设置综合约束指导工具选择乘法器架构）、定制设计（如 DSP 加速器）和性能瓶颈分析是必要的。算术电路设计不存在"最优方案"——选择取决于面积、速度和功耗的具体约束。

## 原理

### 加法器：从半加器到超前进位

加法器的进化谱系体现了面积-速度的经典权衡。

**半加器（Half Adder, HA）**：两个 1 位输入的加法，输出和（Sum, $S = A \oplus B$）与进位（Carry, $C = AB$）。HA 是构建全加器的基本模块，不能处理输入进位。

**全加器（Full Adder, FA）**：三个 1 位输入（A, B, Cin）的加法，输出 Sum 和 Cout。Sum = $A \oplus B \oplus C_{in}$，Cout = $AB + (A \oplus B)C_{in}$（或等价 $AB + AC_{in} + BC_{in}$）。FA 的延迟约 2-3 个门延迟（取决于实现），面积约 6-8 个门等效。

**行波进位加法器（Ripple Carry Adder, RCA）**：N 个 FA 串联——第 i 级 FA 的 Cout 连接第 i+1 级 FA 的 Cin。关键路径从最低位 Cin 经过所有 N 级进位链到最高位 Cout——延迟 $\propto N \times T_{FA\_carry}$。RCA 面积最小但延迟最长（N 位加法约 N * 2 门延迟），适用于 N <= 8 的低位宽场景。

**超前进位加法器（Carry Lookahead Adder, CLA）**：解决 RCA 进位链瓶颈——通过并行计算进位生成（Generate, $G_i = A_i B_i$）和进位传播（Propagate, $P_i = A_i \oplus B_i$）信号，使用进位前瞻逻辑 $C_{i+1} = G_i + P_i C_i$ 以 $\log N$ 级层次化计算所有进位。CLA 延迟 $\propto \log N$，面积比 RCA 大约 50%-100%。实际设计中 CLA 通常分组（4 位一组）——组内使用 CLA 快速进位，组间可采用 RCA（Ripple between Groups）或第二级 CLA，形成层次化 CLA（如 64 位 CLA 为 4 组 x 16 位）。

**进位选择加法器（Carry Select Adder, CSA）**：并行计算两个可能结果——一个假设进位输入 Cin=0，另一个 Cin=1——当实际 Cin 到达时通过 MUX 选择正确的结果。CSA 将进位链等待时间转化为额外的面积（约 2x 加法器面积）和并行的提前计算。适用于宽位宽（64 位+）和高时钟频率场景。

### 乘法器：Booth 编码与 Wallace 树

乘法器的硬件实现包含三个步骤。**部分积生成**：Booth 基数-4（Radix-4 Booth Encoding）将乘数每 3 位（重叠 1 位）为一组映射到 {-2, -1, 0, +1, +2} x 被乘数，将部分积数量从 N（N 位乘数）减少到 N/2。Booth 编码的关键在于：移位实现 x2、取反加一实现负部分积（二的补码），编码表将 3 位组（$y_{2i+1}, y_{2i}, y_{2i-1}$）映射到操作——如 011 -> +2x, 100 -> -2x。

**部分积压缩**：使用进位保留加法器（Carry Save Adder）阵列将多层部分积压缩为两层（Sum 和 Carry 向量）。**Wallace 树**使用 3:2 压缩器（全加器）以分组方式逐层压缩——每层将 3 个输入压缩为 2 个输出（Sum + Carry），逐层减少层数直到只剩两层。Wallace 树的层数 $\propto \log_{3/2}(N_{partial}) \approx \log_{1.5} N$。**Dadda 树**以最少的全加器和半加器数量达到与 Wallace 树相同的压缩级数——Dadda 树在每一级只压缩到下一级所需的最小位数，延迟与 Wallace 相同、面积更小但结构不规则。综合工具通常选择 Wallace 树（规则性更好），定制设计选择 Dadda 树（面积更优）。

**最终加法**：压缩后的 Sum 和 Carry 向量通过快速加法器（CLA/CSA）求和得到最终乘积。最终加法器的位宽为 2N（双倍位宽乘积），是乘法器延迟的最后一段关键路径。

### 除法器

除法在硬件中比乘法复杂得多——不可流水线化（结果逐位求解，无法并行）。主要算法：**恢复余数除法（Restoring Division）**——尝试减去除数，若结果为负则"恢复"（加回除数）。**非恢复余数除法（Non-Restoring Division）**——余数为负时不恢复，在下一步做加法而非减法——将每步操作从 2 次减加减少到 1 次，速度提升约 2 倍。**SRT 除法**（Sweeney-Robertson-Tocher）每步使用查找表确定商的多位值（基数-2 为 1 位，基数-4 为 2 位）——减少除法步数，但查找表和复杂的状态逻辑增加面积。除法在现代高速设计中通常避免出现在关键路径上——替代方案包括使用倒数近似（$a/b = a \times (1/b)$）配合流水线乘法器，或使用 CORDIC 迭代算法。

**Newton-Raphson 除法**是高性能处理器中的常见选择——将除法转化为倒数近似问题：$Q = A / B = A \times (1/B)$。倒数的计算使用 Newton-Raphson 迭代 $x_{n+1} = x_n(2 - B x_n)$ 逐步逼近 $1/B$。每次迭代需要两次乘法（一次计算 $B x_n$，一次计算 $x_n \times (2 - B x_n)$）。收敛速度是二次的（每次迭代有效位数翻倍），32 位精度通常需要 3-4 次迭代。Newton-Raphson 将昂贵且不可流水线的除法替换为可流水线化的乘法序列，是高性能处理器（Intel、AMD、ARM Cortex-A 系列）整数和浮点除法的标准微架构实现。

### 可综合算术电路的 Verilog 描述

综合工具从简单的 `+` / `*` 运算符推断底层硬件，但在需要精确控制延迟或面积时，手动结构化描述是必要的。以下展示参数化进位选择加法器的可综合描述：

```systemverilog
// 参数化进位选择加法器：并行计算 Cin=0 和 Cin=1 两个结果，通过 MUX 选择
module carry_select_adder #(
    parameter WIDTH = 64,
    parameter BLOCK_SIZE = 16  // 每块位宽，64 位分 4 块
) (
    input  logic [WIDTH-1:0] a, b,
    input  logic             cin,
    output logic [WIDTH-1:0] sum,
    output logic             cout
);
    localparam BLOCKS = WIDTH / BLOCK_SIZE;

    logic [BLOCKS-1:0] block_cout [2];  // [0]=sum0路径, [1]=sum1路径
    logic [WIDTH-1:0]  sum0, sum1;      // 进位=0 和进位=1 的预计算和
    logic [BLOCKS-1:0] carry_sel;        // 实际块进位选择链

    assign carry_sel[0] = cin;

    genvar i;
    generate
        for (i = 0; i < BLOCKS; i++) begin : blk
            localparam HI = (i+1)*BLOCK_SIZE - 1;
            localparam LO = i*BLOCK_SIZE;
            // 块内使用标准加法（由综合工具优化为 CLA 或 RCA）
            assign {block_cout[0][i], sum0[HI:LO]} = a[HI:LO] + b[HI:LO];
            assign {block_cout[1][i], sum1[HI:LO]} = a[HI:LO] + b[HI:LO] + 1'b1;
            if (i < BLOCKS-1)
                assign carry_sel[i+1] = carry_sel[i] ? block_cout[1][i] : block_cout[0][i];
            // MUX 选择
            assign sum[HI:LO] = carry_sel[i] ? sum1[HI:LO] : sum0[HI:LO];
        end
    endgenerate

    assign cout = carry_sel[BLOCKS-1] ? block_cout[1][BLOCKS-1] : block_cout[0][BLOCKS-1];
endmodule
```

### 移位器

**对数移位器（Logarithmic Shifter）**使用多级 2:1 MUX 选择实现——N 位移位器需要 $\log_2 N$ 级 MUX（第 0 级移位 1 位，第 1 级移位 2 位，第 i 级移位 $2^i$ 位）。每个 MUX 根据移位量的对应比特（shift_amount[i]）选择直通或移位后的数据。对数移位器面积 $\propto N \log N$，是所有 N 位移位器中延迟最小的（$\log N$ 级 MUX 延迟）。

**桶形移位器（Barrel Shifter）**使用完全的 N x N 交叉开关将任意输入位连接到任意输出位——面积 $\propto N^2$，但延迟恒定（单级传输门或 MUX），适用于最高速度需求、位宽较小（<=32 位）的应用。**漏斗移位器（Funnel Shifter）**是桶形移位器的优化变体——输入双倍位宽（2N），输出 N 位，通过选择双倍位宽窗口实现移位、旋转和掩码操作，常用于高性能处理器执行单元（如 ARM Barrel Shifter）。

## 关键要点

- RCA（行波进位）面积最小但延迟最长（$\propto N$），CLA（超前进位）延迟最短（$\propto \log N$）但面积最大——选择取决于位宽和对时序的压力
- Booth 基数-4 将部分积数量减半，每个 Booth 编码器将 3 位乘数映射到 {-2,-1,0,+1,+2} x 被乘数的操作
- Wallace 树使用 3:2 压缩器（全加器）逐层压缩部分积——层数 $\propto \log_{1.5} N$，是商用综合工具乘法器的默认选择
- Dadda 树在每级只压缩到必要的最小位数——延迟与 Wallace 相同、全加器数量更少，但结构不规则
- 除法是最复杂的算术运算——SRT 除法（基数-4）每步产生 2 位商，但硬件复杂度显著提升
- Newton-Raphson 除法通过倒数逼近 $x_{n+1} = x_n(2 - B x_n)$ 将除法转化为可流水线的乘法序列，二次收敛（每次迭代有效位数翻倍），是高性能处理器除法的标准微架构实现
- 对数移位器使用 $\log N$ 级 2:1 MUX 选择，是面积-延迟综合最优的移位器结构——综合工具的 `<<` 和 `>>` 运算符产生近似结构
- 现代 HDL 中直接用 `+`、`*` 运算符并由综合工具的 DesignWare 库自动推断和优化算术结构——手动实例化仅用于定制性能需求
- 进位保留加法器（CSA）阵列是乘法器和多操作数加法的核心——将多层部分积压缩为最终 Sum+Carry 两层的中间数据结构
- 进位选择加法器以约 2x 面积换取进位传播延迟的消除——并行计算两个假设进位结果，实际进位到达时通过 MUX 选择，适用于宽位宽（64 位+）高频设计

## 与其他概念的关系

- [[rtl-design/concepts/pipeline-design|流水线设计]] — 高性能算术单元广泛使用流水分割以提升吞吐率——流水线乘法器和加法器是典型应用。Booth 编码 -> Wallace 树压缩 -> 最终加法器的三级流水分割是 16x16/32x32 位乘法器的标准实现模板
- [[rtl-design/concepts/coding-style|RTL 编码风格]] — 算术运算符的综合推断结果受编码风格影响——无符号/有符号声明、位宽指定和括号分组影响综合的优化空间。`$signed()` 的显式使用和位宽扩展规则的正确理解是避免有符号运算 bugs 的关键
- [[rtl-design/concepts/sequential-logic|时序逻辑]] — 算术电路的延迟决定了整个数据通路的时序预算，时序约束驱动加法器和乘法器的架构选择。流水线寄存器的插入位置由算术单元内部的逻辑深度分布决定——CLA 的进位前瞻树和 Wallace 树的不规则延迟是时序收敛的常见瓶颈
- [[architecture/concepts/pipelining|体系结构流水线]] — 处理器执行单元中的 ALU 设计（加法器/移位器/乘法器架构）是跨体系结构和 RTL 设计的接口决策。体系结构级的指令延迟约束（如单周期整数 ALU、多周期乘法器）直接影响 RTL 算术单元的架构选择和流水线级数

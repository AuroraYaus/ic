---
type: concept
aliases:
  - DSP Algorithm IP_DSP算法IP
  - FIR滤波器
  - CORDIC
tags:
  - asic
  - rtl-design
  - dsp
source_spec: "Parhi, VLSI Digital Signal Processing Systems; Volder, The CORDIC Trigonometric Computing Technique (IRE Trans. 1959); Koren, Computer Arithmetic Algorithms"
queries: 1
---
# DSP算法IP

数字信号处理（Digital Signal Processing, DSP）算法 IP 是数字 IC 设计岗的高频领域——滤波、三角函数、除法是算法与硬件交叉的三个经典主题：FIR 滤波器是"乘法累加结构"的范式、CORDIC 是"移位相加替代乘法"的范式、除法器是"迭代逼近"的范式。三者共同训练的能力是：**把数学公式映射为可综合的寄存器传输级结构**——这是算法 IP 工程师与通用 RTL 工程师的分水岭。本文假设读者了解定点数（见 [[concepts/数制|数制]]）与流水线（见 [[rtl-design/concepts/流水线设计|流水线设计]]）。

## 原理

### FIR 滤波器：乘法累加结构

FIR（Finite Impulse Response，有限冲激响应）滤波器的数学定义是卷积和：$y[n] = \sum_{k=0}^{N-1} h[k] \cdot x[n-k]$——输出是最近 $N$ 个输入与系数的乘积累加。硬件实现有三种结构：

**（1）直接型（Direct Form）**：$N$ 个寄存器组成移位链 + $N$ 个乘法器 + 加法树——直观但加法树深度 $O(\log N)$，关键路径长。**（2）转置型（Transposed Form）**：输入广播到全部乘法器，每级"乘加 + 一级寄存器"——关键路径恒为一次乘法 + 一次加法（与阶数无关），是高速实现的标准答案。**（3）系数对称优化**：线性相位 FIR 满足 $h[k] = h[N-1-k]$——先加后乘把乘法器减半（$N$ 个乘法器变 $N/2$），面积直接减半，是设计加分点。

```systemverilog
// 转置型 FIR：N 阶滤波器的单级乘加单元（可综合，逐行说明）
module fir_tap (
    input  logic        clk,     // 时钟：每拍推进一级流水
    input  logic        rst_n,   // 异步复位（低有效）
    input  logic [15:0] x_in,    // 广播输入：所有级共享同一输入样本
    input  logic [15:0] h_coef,  // 本级系数：滤波器抽头权重（定点 Q 格式约定全设计一致）
    input  logic [31:0] acc_in,  // 上级累加和：转置型的横向传递量
    output logic [31:0] acc_out  // 本级输出：x_in*h_coef + acc_in 寄存一拍
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)      acc_out <= '0;                // 复位清零：'0 表示全 0（任意位宽适配）
        else             acc_out <= x_in * h_coef + acc_in; // 乘加 + 一级寄存器：
            // 转置型关键路径 = 1 次乘法 + 1 次加法——与滤波器阶数无关，级联 N 级即可
    end
endmodule
```

**定点与溢出**：系数与数据都用定点 Q 格式（如 Q1.15）——乘法结果位宽翻倍需要截断/饱和；累加过程中间位宽要留足（累加 $N$ 项增加 $\log_2 N$ 位），最后一级才舍入到输出位宽——中间截断引入的噪声会被后级放大。验证参考模型与 RTL 的定点对齐（舍入方式、饱和行为）见 [[verification/concepts/DPI-C接口|DPI-C接口]]。

### CORDIC：移位相加替代乘法

CORDIC（COordinate Rotation DIgital Computer，坐标旋转数字计算机）用**移位加迭代**计算三角函数/向量模——不需要乘法器，适合面积敏感或三角运算密集的设计。核心迭代：把目标角度分解为一系列预设角度 $\arctan(2^{-i})$ 的组合，每步只做移位（乘 $2^{-i}$ 就是右移 $i$ 位）与加减：

$$\begin{bmatrix} x_{i+1} \\ y_{i+1} \end{bmatrix} = \begin{bmatrix} x_i - d_i \cdot y_i \cdot 2^{-i} \\ y_i + d_i \cdot x_i \cdot 2^{-i} \end{bmatrix}, \quad d_i = \pm 1$$

两种模式：**旋转模式**（给定角度算正余弦——驱动 $y$ 趋近 0，$d_i$ 取角度剩余量的符号）与**向量模式**（给定向量算模与相位——驱动 $y$ 趋近 0，$d_i$ 取 $-y_i$ 的符号）。迭代次数等于位宽（16 位精度约 16 次迭代），每次迭代的关键路径只有移位 + 加减——乘法器换迭代次数，面积大幅下降。

```systemverilog
// CORDIC 单级迭代单元：旋转模式（可综合，逐行说明）
module cordic_stage #(
    parameter int STAGE = 0      // 级号：决定移位量 2^-STAGE
) (
    input  logic signed [15:0] x_i,  // 本级输入 x：中间坐标值
    input  logic signed [15:0] y_i,  // 本级输入 y
    input  logic signed [15:0] z_i,  // 本级剩余角度
    output logic signed [15:0] x_o,  // 本级输出 x
    output logic signed [15:0] y_o,
    output logic signed [15:0] z_o
);
    logic signed [15:0] x_shift, y_shift;
    logic d; // 旋转方向：z 的符号——旋转模式驱动 z 趋近 0

    assign d = (z_i >= 0) ? 1'sb1 : -1'sb1;      // 方向判定：剩余角度为正则正转
    assign x_shift = y_i >>> STAGE;              // 算术右移 STAGE 位：等效乘 2^-STAGE（>>> 保留符号）
    assign y_shift = x_i >>> STAGE;
    assign x_o = x_i - d * x_shift;              // 迭代公式：d 为正时 x -= y*2^-i
    assign y_o = y_i + d * y_shift;              //           y += x*2^-i
    assign z_o = z_i - d * $signed(STAGE_ATAN[STAGE]); // 剩余角度减去本步角度
    // STAGE_ATAN：预计算的反正切表（arctan(2^-i) 定点值）——迭代方向与角度的查表驱动

    localparam logic signed [15:0] STAGE_ATAN [0:15] = '{  // 反正切表：索引即级号
        16'sd11520, 16'sd6801, 16'sd3593, 16'sd1824,   // arctan(1), arctan(1/2), arctan(1/4), arctan(1/8)...
        16'sd916, 16'sd458, 16'sd229, 16'sd115,
        16'sd57, 16'sd29, 16'sd14, 16'sd7,
        16'sd4, 16'sd2, 16'sd1, 16'sd0 };              // 高 15 位为小数（Q1.15 定点表示）
endmodule
```

**工程要点**：角度表与移位量都是编译期常量——级联 16 级可流水（每级一拍）也可折叠（复用一级迭代 16 拍，面积换吞吐）；输出有增益因子 $K \approx 1.6467$（所有迭代的公共缩放），旋转模式需乘回 $1/K$ 修正——忘记增益修正是 CORDIC 第一易错点。

### 除法器：迭代逼近

除法是最贵的算术运算——没有像乘法那样的简单组合电路。三种主流实现：

**（1）恢复余数法（Restoring Division）**：逐位试商——余数左移后减除数，够减商 1、不够减商 0 并把余数**恢复**（加回除数）。每位一次比较 + 加减，$N$ 位商需 $N$ 次迭代——最直观，是"手算除法"的硬件化。

**（2）不恢复余数法（Non-Restoring）**：改进——不够减时商 0 且不恢复，下一步改为加除数（利用"负余数继续迭代"的数学性质）。每步只做一次加减（不做恢复加法），速度与面积都比恢复法优，是最常用的定点除法实现。

**（3）SRT 除法（Sweeney-Robertson-Tocher）**：高基数除法——每拍产生多位商（基数 4 每拍 2 位），用冗余数字集（商位允许 -1/0/+1 而非只有 0/1）避免精确比较，靠查表选商。现代 CPU 浮点除法的核心算法——复杂度最高但吞吐最高。浮点场景还有**牛顿-拉夫逊迭代**（除法转乘法：$x \approx 1/b$ 迭代逼近再用乘法器完成 $a \times (1/b)$）——复用已有乘法器，是"以乘代除"的代表。

**选型逻辑**：面积敏感/低频用恢复或不恢复法（串行迭代）；高性能用 SRT 或牛顿迭代（需要乘法器配合）；面试重点是**不恢复余数法的迭代流程**与"为什么恢复法每步要恢复余数"。

## 关键要点

- **FIR 转置型关键路径与阶数无关**：每级"乘加 + 寄存器"，高速实现的标准答案；线性相位系数对称先加后乘省一半乘法器
- **定点协议全链路一致**：Q 格式、舍入、饱和在 RTL 与参考模型间必须逐位对齐——中间截断噪声会被后级放大
- **CORDIC 用移位加替代乘法**：迭代方向由角度剩余量/向量 y 的符号驱动，角度表与移位量编译期常量——增益因子 $K \approx 1.6467$ 必须修正
- **CORDIC 折叠与流水**：16 级可流水可折叠复用——面积与吞吐的经典权衡
- **除法器的演进线**：恢复余数（直观、每步两次加减）→ 不恢复余数（每步一次加减）→ SRT（每拍多位商 + 冗余商位）→ 牛顿迭代（以乘代除、复用乘法器）
- **算法 IP 的核心能力是公式到结构的映射**：FIR=乘累加结构、CORDIC=移位加迭代、除法=迭代逼近——三种范式覆盖多数算法设计

## 与其他概念的关系

- [[rtl-design/concepts/算术电路|算术电路]] — 加法器/乘法器的底层结构：DSP 单元的乘加与移位运算的硬件基础
- [[rtl-design/concepts/流水线设计|流水线设计]] — CORDIC 折叠与 FIR 转置型的流水权衡：面积换吞吐的结构选择
- [[concepts/数制|数制]] — 定点 Q 格式与舍入/饱和：DSP IP 的数制协议基础
- [[verification/concepts/DPI-C接口|DPI-C接口]] — C 参考模型与 RTL 的定点对齐：算法 IP 验证的黄金模型通道

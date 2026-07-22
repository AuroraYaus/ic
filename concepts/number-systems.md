---
type: concept
aliases:
  - 数制
  - Number Representation
  - 二进制
  - 补码
tags:
  - asic
  - basics
  - math
source_spec: "Mano & Ciletti, Digital Design; IEEE 754-2019"
---

# 数字的数制表示（Number Systems in Digital Design）

数字电路处理的是离散的数值表示，理解数制和编码是数字IC设计的第一步。所有的数据、地址、指令，在硬件层面最终都以二进制比特的形式存在和操作。

## 原理

### 二进制与进制转换

数字系统中，所有的信息最终都表示为二进制（Binary）——只有 {0, 1} 两个符号，分别对应电路中的低电平（GND）和高电平（VDD）。将十进制整数转换为二进制采用 "除 2 取余，逆序排列" 法；小数部分采用 "乘 2 取整，顺序排列" 法。反过来，二进制转十进制则按位权（Positional Weight）累加。十六进制（Hexadecimal）和八进制（Octal）是二进制的紧凑表示——每 4 位二进制对应 1 位 Hex，每 3 位对应 1 位 Octal——方便工程师阅读和调试。

### 有符号数的表示

数字系统中表示正负数有三种主要方式：
- **原码（Sign-Magnitude）**：最高位表示符号（0 正 1 负），其余位表示数值。简单直观但存在正零和负零两个零，加减法需要特殊处理。
- **反码（One's Complement）**：负数表示为对应正数按位取反，减法可转化为加法（需处理循环进位），同样有双零问题。
- **二进制补码（Two's Complement）**：现代数字系统的标准。负数的补码等于对应正数按位取反再加 1。补码的核心优势在于将减法统一为加法——同一套加法器硬件可以同时处理有符号和无符号运算，无需额外逻辑区分。

N 位补码的表示范围为 [-2^(N-1), 2^(N-1) - 1]，这个范围的不对称性（最小值比最大值的绝对值大 1）是补码的内在特性。

### 定点数与浮点数

**定点数（Fixed-Point）** 将小数点固定在特定位位置，所有运算本质上是整数运算。在 DSP（数字信号处理，Digital Signal Processing）和嵌入式场景中广泛使用，避免了浮点单元的硬件开销。定点数的动态范围和精度之间存在权衡——Q 格式（Q15、Q31 等）是常见的定点表示约定。

**浮点数（Floating-Point）** 遵循 IEEE 754 标准，由符号位（S）、指数（Exponent, E）和尾数（Mantissa/Significand, M）三部分组成：value = (-1)^S × (1.M) × 2^(E - bias)。浮点加法器需要经过对齐（Alignment）→ 加法 → 规格化（Normalization）→ 舍入（Rounding）四个步骤，硬件复杂度远高于定点加法器。IEEE 754 定义了多种精度：单精度（binary32）、双精度（binary64）、半精度（binary16）以及 bfloat16。

### BCD 与格雷码

**BCD（Binary-Coded Decimal）** 将每个十进制位独立编码为 4 位二进制，常见于金融计算和显示驱动。**格雷码（Gray Code）** 的相邻码字仅有一位变化，在跨时钟域 FIFO 指针编码和状态机状态编码中至关重要——能避免多比特同时翻转导致的采样错误。

## 关键要点

- 二进制是数字电路的唯一操作对象，所有信息最终映射到比特流和寄存器
- 补码将符号位直接参与运算，同一套加法器硬件统一处理 signed 和 unsigned
- 溢出（Overflow）和进位（Carry）是不同的概念：进位用于无符号数，有符号数通过最高两位的进位异或判溢出
- 符号扩展（Sign Extension）保证不同位宽的有符号数正确操作：将符号位复制到高位
- 算术右移（ASR）复制符号位（保持符号），逻辑右移（LSR）补零（视为无符号）
- IEEE 754 浮点数的特殊值：NaN（非数）、Infinity（无穷）、Denormalized（非规格化数）、带符号零
- 定点数在 DSP 和图像处理中广泛使用：面积小、功耗低、延迟可预测
- 格雷码配合 2-FF 同步器可将 CDC 的 MTBF 控制在安全范围

## 与其他概念的关系

- [[rtl-design/concepts/verilog-hdl\|Verilog HDL]] — HDL 中的 `signed`/`unsigned` 声明、`$signed()` 系统函数和位宽扩展规则
- [[rtl-design/concepts/arithmetic-circuits\|算术电路（Arithmetic Circuits）]] — 加法器（RCA, CLA, CSA）和乘法器（Booth, Wallace Tree）的数制基础
- [[architecture/concepts/pipelining\|流水线（Pipelining）]] — 浮点/定点算术单元如何在流水线中拆分以提高吞吐率
- [[concepts/cmos-fundamentals\|CMOS 基础]] — 底层晶体管如何实现逻辑门来存储和运算这些比特

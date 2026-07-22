---
type: concept
aliases:
  - 分支预测
  - Branch Prediction
tags:
  - asic
  - architecture
  - processor
  - branch-prediction
  - microarchitecture
source_spec: "Hennessy & Patterson, Computer Architecture: A Quantitative Approach, 6th Ed; Seznec & Michaud, 'A Case for (Partially) Tagged GEometric History Length Branch Prediction', JILP, 2006"
---

# 分支预测（Branch Prediction）

分支预测是现代高性能处理器前端（Front-End）的核心组成部分。条件分支指令在全程序中占比约 15-20%，平均每 5-7 条指令就遇到一次分支。如果无法在取指阶段正确预测分支方向，流水线和乱序执行引擎将被迫等待分支结果确定——在深流水线处理器中这可能造成 15-20 个周期的停滞。分支预测器通过在取指时推测分支的方向和目标地址，持续为处理器后端提供指令流。

## 原理

### 静态预测与动态预测

静态预测（Static Prediction）不依赖运行时历史：最简单的"永远不跳转"（Always Not Taken）假设分支不改变控制流，编译器辅助的 BTFNT（Backward Taken, Forward Not Taken）策略将向后跳转（通常是循环回边）预测为跳转，向前跳转（通常是 if-else 结构）预测为不跳转。静态预测精度通常在 60-70% 左右。动态预测（Dynamic Prediction）维护运行时分支行为的历史记录，典型预测精度可达 95-97%，远优于静态方案。

### 两位饱和计数器与 BHT

分支历史表（Branch History Table, BHT）是动态预测的基础结构。每个表项包含一个两位饱和计数器（2-bit Saturating Counter），状态编码为：强不跳转（00）、弱不跳转（01）、弱跳转（10）、强跳转（11）。当分支实际跳转时计数器递增（饱和于 11），实际不跳转时递减（饱和于 00）。两位饱和计数器的关键优点是两次连续的方向改变才使预测方向翻转——这对带有规律性抖动的分支（如 TNTNTNTN...）可以提供 100% 的预测精度（一次不预测后仍然保持不预测方向），而对完全随机的分支则限制在 50%。

### 全局历史与 GSHARE

全局历史预测器（Global History Predictor）使用全局历史寄存器（Global History Register, GHR）记录最近 N 个分支的实际方向（跳转为 1，不跳转为 0），将 GHR 与分支 PC 异或（XOR）后索引模式历史表（Pattern History Table, PHT）——这种结构被称为 GSHARE（Gshare）。GHR 捕获了分支之间的相关性（Correlation）：例如，前后两个条件分支可能联合判断同一个高层条件，单独看每个分支的行为是随机的，但组合来看具有可预测的模式。GSHARE 的 PHT 位宽通常为 2K-4K 项，GHR 为 8-16 位。

### 锦标赛预测器与 TAGE

锦标赛预测器（Tournament / Hybrid Predictor）组合多个预测器组件，并通过一个元预测器（Meta-Predictor / Choice Predictor）在它们之间动态选择。经典的 Alpha 21264 锦标赛预测器结合了局部预测器（Local Predictor，按分支 PC 索引局部历史）和全局预测器（Global Predictor，按 GHR 索引），Choice Predictor 使用两位饱和计数器决定当前分支相信哪个预测器。TAGE（TAgged GEometric history length）预测器是现代分支预测的标杆：它使用多个几何长度递增的全局历史（如 2、4、8、16、32、64、128 位），每个历史长度维护一组部分标签（Partial Tag），最长匹配的条目提供预测。TAGE 在 Championship Branch Prediction（CBP）竞赛中验证了超过 99% 的预测精度。

### BTB 与 RAS

分支目标缓冲（Branch Target Buffer, BTB）缓存分支指令的 PC 与目标地址的映射关系，在取指阶段同时提供方向预测（来自 BHT）和目标预测（来自 BTB），实现零周期分支（Zero-Cycle Branch）。返回地址栈（Return Address Stack, RAS）专门用于预测函数返回指令（Return）的目标地址：每次调用指令（Call）执行时将返回地址（Call 的 PC + 指令长度）压入 RAS，每次预测到 Return 指令时从 RAS 栈顶弹出目标地址。RAS 的大小（通常 8-32 项）决定了覆盖的调用深度。

## 关键要点

- 分支预测精度每提高 1%，在 20 级流水线中约降低 0.5% 的 CPI——因为误预测惩罚很大
- 两位饱和计数器需要在 1K-4K 项时才达到 85-93% 的精度，项数太少会导致别名冲突（Aliasing）
- GSHARE 预测器通过 GHR XOR PC 的哈希降低了别名冲突，但仍有破坏性别名（Destructive Aliasing）问题
- TAGE 的核心洞察是不同分支的最优历史长度不同：循环分支适合长历史，if-else 分支只需短历史
- BTB 的访问时间在 L1 指令缓存之后——在高速设计中，BTB 访问可能与 L1 I-Cache 访问并行
- RAS 的 Corruption 修复（异常返回时从 Checkpoint 恢复 RAS 栈顶）是精确异常支持的必要机制
- 间接跳转（Indirect Jump, jump reg）的预测需要与条件分支不同的预测器——ITTAGE 扩展 TAGE 到间接跳转目标预测
- 分支预测对功耗有显著影响：错误预测消耗了所有投机执行的指令的功耗，这部分功耗（约 10-20% 的总功耗）是纯浪费

## 与其他概念的关系

- [[architecture/concepts/pipelining|流水线（Pipelining）]] — 分支预测直接决定了流水线中控制冒险的处理效率，预测精度决定了误预测惩罚频率
- [[architecture/concepts/out-of-order|乱序执行（Out-of-Order Execution）]] — 错误预测导致 ROB 中所有指令被清空和 RAT 回滚，恢复代价极大
- [[concepts/cmos-fundamentals|CMOS 基础]] — BTB 和 BHT 访问的关键路径由 SRAM 读取延迟决定，先进工艺节点的低延迟 SRAM 是缩短分支延迟的物理基础

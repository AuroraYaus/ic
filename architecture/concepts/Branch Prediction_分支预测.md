---
type: concept
aliases:
  - Branch Prediction_分支预测
  - Branch Prediction
  - 分支预测器
tags:
  - asic
  - architecture
  - processor
  - branch-prediction
  - microarchitecture
source_spec: "Hennessy & Patterson, Computer Architecture: A Quantitative Approach, 6th Ed; Seznec & Michaud, 'A Case for (Partially) Tagged GEometric History Length Branch Prediction', JILP, 2006; McFarling, 'Combining Branch Predictors', DEC WRL TN-36, 1993"
---
# Branch Prediction — 分支预测

分支预测是现代高性能处理器前端的核心部件。条件分支指令在全程序中占比约 15-20%，平均每 5-7 条指令就遇到一次分支。如果处理器在取指阶段无法正确预测分支的方向和目标地址，流水线和乱序执行引擎将被迫等待分支结果确定——在深流水线处理器中可能造成 15-20 个周期的停滞。分支预测器的作用是在取指的同时推测分支方向和目标地址，持续为处理器后端提供投机性的指令流。

## 原理

### 静态预测

静态预测不维护任何运行时历史。最简单的策略是"永远不跳转"（Always Not Taken）：默认顺序取指，分支实际跳转时冲刷已取指错误路径指令。编译器辅助的 BTFNT（Backward Taken, Forward Not Taken）策略利用程序行为规律：向后跳转（通常是循环回边）预测为 Taken，向前跳转（通常是 if-else）预测为 Not Taken。配合 Profile-Guided Optimization，编译器可在分支指令中直接嵌入静态预测位。静态预测精度通常在 60-70% 左右，适用于面积极端受限的嵌入式小核心。

### 两位饱和计数器与 BHT

分支历史表（Branch History Table, BHT）是动态预测的基础。每个表项包含一个两位饱和计数器，状态编码为：强不跳转（00, SNT）、弱不跳转（01, WNT）、弱跳转（10, WT）、强跳转（11, ST）。分支实际为 Taken 时计数器递增饱和于 11，Not Taken 时递减饱和于 00。

两位饱和计数器相比一位预测的关键优势：对于 TNTNTNTN... 模式，一位计数器 0% 精度——每次方向改变都误预测。两位计数器需要两次连续方向改变才发生预测翻转：面对 TNTNTNTN 模式，SNT 经一次 T 变 WNT（预测仍为 NT），第二次 T 才能变 WT 使预测翻转。BHT 表现受限于别名冲突——不同分支映射到同一 BHT 表项时互相干扰。

### 全局历史与 GSHARE

全局历史预测器捕获分支之间的相关性。两个前后出现的分支可能联合判断同一个高层条件——单独看每个分支可能随机，但组合来看具有可预测的模式。全局历史寄存器记录最近 N 个分支的实际方向（0=NT, 1=T），将 GHR 与分支 PC 通过 XOR 组合后索引模式历史表（PHT）——这种结构称为 GSHARE。

GHR XOR PC 的哈希关键思想：GHR 捕获了"程序执行路径到达当前分支"的上下文信息——同一 PC 在不同执行上下文（如从不同调用点进入同一函数）可能对应不同分支行为。GSHARE 是中小面积处理器的典型方案。

### 锦标赛预测器

锦标赛预测器组合了局部预测器（按分支 PC 索引局部历史）和全局预测器，通过一个元预测器（Choice Predictor）在两者之间动态选择。元预测器也是两位饱和计数器，但它记录的是"局部预测器正确还是全局预测器正确"的历史。实际测量表明：约 80% 的分支中局部和全局预测器表现一致；在剩余 20% 中，锦标赛预测器比任一单独预测器提高约 5-10% 的绝对精度。Alpha 21264 是锦标赛预测器的经典实现。

### TAGE 预测器

TAGE（TAgged GEometric history length）预测器是现代分支预测的标杆，广泛用于 Intel、AMD 和 ARM 高性能核心。其核心结构是多个预测器表组件，每个使用不同长度的几何历史：2 位、4 位、8 位、16 位、32 位、64 位、128 位、256 位等。每个组件产生一个预测，TAGE 选择最长历史匹配的组件的预测结果——最长历史的组件最"了解"当前执行上下文，信息量最大。TAGE 的标签机制极大减少了别名冲突——两个冲突的分支除非标签也相同否则不互相干扰。TAGE 在 Championship Branch Prediction 比赛中验证了超过 99% 的预测精度。

### BTB 与 RAS

分支目标缓冲（Branch Target Buffer, BTB）缓存分支指令 PC 与目标地址的映射关系，在取指阶段与方向预测并行工作，实现零周期分支。返回地址栈（Return Address Stack, RAS）专门预测函数返回指令的目标地址：每次 CALL 指令执行时将返回地址压入 RAS 栈顶，每次 RET 指令从栈顶弹出目标地址。CALL/RET 在大多数程序中严格配对，RAS 预测精度接近 100%。但 C++ 异常处理或 longjmp 可能破坏配对，需要 RAS 修复机制。

### 分支预测器的性能度量

分支预测器的度量指标包括：预测精度（Prediction Accuracy / Misprediction Rate），直接决定误预测惩罚频率；预测延迟（Prediction Latency），即从取指 PC 输入预测器到输出方向/目标的时间——在高速处理器中必须在一个周期内完成，否则取指流水线需要额外级数；预测器面积（Predictor Area），BTB + BHT + RAS + TAGE 表的总 SRAM 面积在高性能处理器中可达 1-3 mm2（在 5nm 工艺下）。

误预测惩罚公式：Misprediction Penalty = (Branch Resolution Stage - Fetch Stage) × Clock Period。例如，在 16 级流水线（取指第 1 级，分支在第 10 级解决）2GHz 下 = (10-1) × 0.5ns = 4.5ns = 9 个周期。加上乱序恢复开销（ROB 清空 + RAT 回滚 + 发射队列冲刷），总恢复时间可能达到 15-25 个周期。有效 CPI 贡献 = Branch_Frequency × Misprediction_Rate × Misprediction_Penalty。分支频率约 20%，误预测率 3% → CPI_branch = 0.2 × 0.03 × 20 = 0.12，即约增加 12% 的 CPI。

### 智能分支预测研究前沿

现代分支预测研究集中在三个方向：（1）基于感知器的预测器（Perceptron-Based Predictor）——使用神经网络（单层感知器）替代两位饱和计数器进行决策，感知器的权重向量由 GHR 索引，通过在线学习算法（如随机梯度下降）动态调整权重以适应变长的分支模式。感知器预测器在 SimPoint/SPEC 基准上取得了比 TAGE 更高的精度，但硬件开销（乘法器和加法器树）限制了其在工业产品中的应用。（2）BATAGE（Bunched Architecture TAGE）将多个 TAGE 组件打包成束以提高存储效率。（3）结合上下文的分支预测——利用指令的操作码、立即数和地址偏移等更多信息作为预测特征，进一步提高长历史依赖分支的预测精度。

### 分支预测器存储结构与访问时序

分支预测器的物理实现是一组以取指 PC 为索引的 SRAM 阵列。方向预测器（BHT/TAGE 表）和 BTB 必须在取指阶段（IF）的第一个周期内返回结果，否则下一拍的取指地址无法确定——这构成了前端的最关键时序环路（取指 PC → 预测器 → 下一拍 PC → 取指下一指令的预测器）。BTB 的访问延迟通常为 1-2 个周期——在 5GHz 处理器中，1 周期仅 200ps，在此时间内完成 4K+ 项的 BTB 读取（标签比较 + 目标地址选择）需要非常紧凑的 SRAM 布局和电路设计。

BTB 的组织常用多级结构：L1 BTB（小容量，如 256-512 项，1 周期延迟）覆盖热分支的 95%+；L2 BTB（大容量，2K-4K 项，2-3 周期延迟）处理 L1 BTB 缺失。L1 BTB 缺失时，取指流水线必须停顿等待 L2 BTB 的结果——这称为 BTB 惩戒（BTB Penalty），比分支误预测惩戒小得多（仅 1-2 个取指空洞），但频率更高（因为 BTB 容量有限）。BTB 的替换策略通常使用 Not-Most-Recently-Used（NMRU），倾向于保留最近使用的条目。

### 间接跳转预测

间接跳转（Indirect Branch）的目标地址存储在寄存器中，同一 PC 可以跳转到不同目标——例如 C++ 虚函数调用（vtable dispatch）、switch-case 跳表和函数指针调用。直接跳转的 BTB 查找依赖 PC 索引并返回单一目标，而间接跳转需要在同一 PC 下跟踪多个可能的目标。间接跳转预测器（Indirect Branch Predictor, IBP）通过维护目标历史列表来区分不同的目标上下文。

ITTAGE（Indirect-TAGE）是现代体系结构的标杆解决方案。它在 TAGE 框架基础上为每个 TAGE 组件增加一个目标地址字段——当最长历史组件命中时，不仅提供方向预测，还提供目标地址预测。ITTAGE 在 CBP（Championship Branch Prediction）竞赛中实现了超过 99.5% 的间接跳转预测精度。对于无法预测的间接跳转（如随机多态调用），预测器退化为默认策略——通常使用目标地址栈（Target Address Cache, TAC）维护最近观测到的目标，从中选择最频繁者。

间接跳转预测的难点在于：目标多样性随程序复杂度快速增长（C++ 大程序中单个虚函数调用点可能有数十个目标类），且目标地址分布往往服从幂律——少数热点目标占据大多数调用。ITTAGE 的多组件历史策略在此时发挥关键作用：短历史组件快速适应最近的频繁目标切换，长历史组件在稳定调用模式下提供精确预测。预测错误惩罚与直接分支相同——清空 ROB 并回滚 RAT——因此间接跳转预测精度对面向对象语言编写的程序（如浏览器引擎、数据库）的性能至关重要。

## 关键要点

- 两位饱和计数器在 1K 项时可达 85-92% 精度，4K 项时可达 92-97%，项数增加受面积和访问延迟约束
- GSHARE 核心公式：Index = (PC >> 2) XOR GHR，PC 最低 2 位去掉（指令按 4 字节对齐），右移后低位与 GHR 异或
- 锦标赛预测器元预测器在两者预测相同时简单选择任一方，仅在两者预测不同时才需要 Choice Predictor 决定
- TAGE 的多组件几何历史利用计算级别规律：循环分支周期固定（如 16 次迭代）需至少 16 位 GHR，if-else 只需 4-8 位
- TAGE 标签机制极大减少别名冲突，标签不匹配的条目不计入投票
- BTB 容量决定覆盖范围：小 BTB（256-512 项）仅覆盖内层循环分支，大 BTB（4K-8K 项）覆盖全部热点
- RAS Corruption 修复是精确异常的基础，需要在分支检查点中包含 RAS 栈快照
- 间接跳转（虚函数、switch-case 跳表）的目标预测需要 ITTAGE 或专用间接跳转预测器
- 分支预测功耗影响不容忽视：3% 误预测率约浪费 10-15% 的总功耗在无效投机执行上
- 间接跳转（虚函数、switch-case、函数指针）的预测需要 ITTAGE 或专用 IBP，CBP 竞赛中 ITTAGE 精度超过 99.5%
- 间接跳转的目标地址分布遵循幂律——少数热点目标占据绝大多数调用，短历史组件快速捕获目标切换，长历史组件提供稳态精确预测
- BTB 两级结构的命中率级联：L1 BTB（256-512 项）覆盖 95%+ 动态分支，缺失后 L2 BTB（2K-4K 项）需 2-3 周期填充，产生 BTB 惩戒
- 分支预测器的总面积在高性能处理器中可达 1-3 mm²（5nm），其中 BTB 占 60-70%，TAGE 表占 20-30%，RAS 和逻辑占 10%
- 分支预测器别名冲突（Aliasing）的缓解方法：增大表容量、使用标签区分、应用不同的哈希函数组合 PC 和 GHR，TAGE 的标签机制是此方向的典范
- 循环预测器（Loop Predictor）是 TAGE 的常见补充：对固定迭代次数的循环进行精确预测，第一次循环训练计数器，后续循环直接预测迭代次数和退出点，精度接近 100%
- 分支预测器的更新延迟（Update Latency）存在触达问题：分支在 EX 阶段确定结果后需更新预测器，但后续分支已经在预测器中取指——信息延迟导致下一次循环迭代的第一次分支仍使用陈旧信息
- 取指地址的预测环路延迟（Fetch-Predict-Fetch Loop）是前端频率的关键限制：预测器必须在取指 PC 有效的同一个周期（或最多 1 个延迟周期）内生成下一个取指地址
- 分支预测器的训练策略区分"即时更新"（Speculative Update，在分支推测执行后立即更新）和"提交时更新"（Update at Commit）：前者训练速度快但可能用错误路径污染预测表，后者保证训练信息准确但有延迟

## 与其他概念的关系

- [[architecture/concepts/Pipelining_指令流水线|流水线（Pipelining）]] — 分支预测直接决定流水线控制冒险处理效率，预测精度决定误预测惩罚的频率
- [[architecture/concepts/Out-of-Order_乱序执行|乱序执行（Out-of-Order Execution）]] — 误预测导致 ROB 中投机指令全部清空和 RAT 回滚，恢复开销巨大
- [[architecture/concepts/Memory Hierarchy_存储层次|存储层次（Memory Hierarchy）]] — RAS 和 BTB 本质是以 PC 为索引的小型缓存，其替换和访问策略与缓存设计共享原理。BTB 容量不足引发的 BTB 惩戒与缓存容量缺失类似，增加 BTB 项数是缓解路径
- [[concepts/CMOS Fundamentals_CMOS基础|CMOS 基础]] — 分支预测器的 SRAM 阵列访问延迟是前端的时序瓶颈：在 5GHz 下 200ps 内需完成 BHT/TAGE 表 + BTB 的方向和目标生成，要求极紧凑的 SRAM 位单元布局

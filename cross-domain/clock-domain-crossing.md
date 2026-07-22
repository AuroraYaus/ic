---
type: concept
aliases:
  - 跨时钟域设计
  - CDC
  - Clock Domain Crossing
  - 时钟域交叉
tags:
  - asic
  - cross-domain
  - cdc
  - metastability
source_spec: "Cummings, Clock Domain Crossing Design & Verification Techniques (SNUG 2008); Dally & Poulton, Digital Systems Engineering; Synopsys SpyGlass CDC User Guide"
---

# 跨时钟域设计（Clock Domain Crossing, CDC）

跨时钟域设计（Clock Domain Crossing, CDC）处理数据在不同时钟域之间安全、可靠传输的问题。现代 SoC 包含数十至上百个时钟域——CPU、GPU、DDR 控制器、外设接口各自运行在不同频率和相位下——它们之间的数据交换必然穿越时钟边界。CDC 处理不当导致的亚稳态传播、数据一致性和功能故障在流片后呈现概率性、难以复现的失效模式，是数字IC设计中风险最高的隐患之一。

## 原理

### 亚稳态根源与 MTBF

CDC 的物理根源是亚稳态（Metastability）。触发器的双稳态交叉耦合反相器对在采样时刻如果数据处于建立/保持时间窗口内，输出电压可能落入亚稳态平衡点——既不完全是 0 也不完全是 1 的中间电平振荡。振荡在随机解析时间 $t_{res}$ 后衰减至稳定值。MTBF（Mean Time Between Failures）公式量化失败概率：

$$MTBF = \frac{e^{t_{res}/\tau}}{f_{clk} \cdot f_{data} \cdot T_0}$$

其中 $\tau$ 为解析时间常数（先进工艺约 50ps，7nm 典型值），$T_0$ 为采样窗口参数（约 $10^{-9}s$），$t_{res}$ 为允许的解析时间（目标时钟周期减去次级触发器建立时间）。MTBF 对 $t_{res}$ 极其敏感——增加半周期可将 MTBF 从数秒提升至数千年。

### CDC 场景分类与同步器

慢到快（Slow-to-Fast）：目标时钟远快于源时钟，数据在两次变化间被多次采样，2-FF 同步器处理亚稳态即可。快到慢（Fast-to-Slow）：源数据可能在目标域两次采样之间变化多次，除处理亚稳态外还需防止数据丢失——需脉冲展宽器或握手机制。

2-FF 同步器是单比特 CDC 标准方案：源域信号经目标域第一级 FF，其输出可能亚稳态；一个完整目标时钟周期后大概率（取决于 $t_{res}$ 和工艺 $\tau$）已稳定，再由第二级 FF 安全采样。MTBF 公式指导：对照 MTBF 目标（如 1000 年），可决定是否需要第三级 FF。

### 多比特 CDC 策略

对多比特信号使用独立 2-FF 同步器（每比特各一个）是严重错误——不同比特解析时间不同导致接收端可能采集到逻辑不一致的组合。

格雷码异步 FIFO（Gray-Coded Async FIFO）是多比特 CDC 的主力方案。核心：二进制码转格雷码 $g = b \oplus (b \gg 1)$，格雷码相邻值仅 1 bit 变化。写指针在写时钟域格雷编码后经 2-FF 同步到读域判断"空"（rptr_gray_sync == wptr_gray）；读指针在读域格雷编码后经 2-FF 同步到写域判断"满"（wptr_gray_sync 与 rptr_gray 的 MSB\:MSB-1 不同、其余位相同——超前一整圈）。格雷码的单比特变化确保同步后指针最多偏差一个位置——"空"和"满"判断偏保守但绝不溢出/下溢。

握手同步器（Handshake Synchronizer）：源域准备好数据后置 REQ，REQ 经 2-FF 同步到目标域，目标域采样数据后置 ACK，ACK 同步回源域释放。4 相握手（归零协议，REQ 上升$\to$ACK 上升$\to$REQ 下降$\to$ACK 下降）更简单健壮但每次传输 4 次同步穿越；2 相握手（非归零，REQ 翻转即请求）减少同步往返次数、吞吐率更高。

DMUX 同步器（Data MUX with Toggle）：单条控制比特经 2-FF 同步到目标域选通数据总线，数据总线保证在控制信号稳定期间不变——巧妙的面积优化方案，但仅适用于数据变化率远低于目标时钟的场景。

### CDC 故障模式与验证

同步器失效不仅限于亚稳态传播：数据一致性丢失（多比特 CDC 无保护）、毛刺传播（组合逻辑输出直接跨域而不经触发器）、再收敛发散（Reconvergence Divergence——多路信号分别经不同同步器后到达的组合逻辑节点，各路径延迟差异导致错误的中间组合状态）。

CDC 验证方法论：结构检查（同步器存在性——每条跨域路径必须有同步器）；协议检查（握手完整性、格雷码编码正确性、FIFO 满/空逻辑一致性）；再收敛分析（多同步器输出汇聚点的时序安全）。工具（SpyGlass CDC、Questa CDC、JasperGold CDC）在 RTL 层做静态分析——仿真无法发现 CDC 问题，亚稳态是概率性、工艺特定、频率敏感的现象。

## 关键要点

- 亚稳态根本原因是双稳态元件的物理特性：$\tau \approx 50ps$（7nm），MTBF 对允许的解析时间有指数级敏感性
- 2-FF 同步器是单比特 CDC 标准方案：第一级承担亚稳态风险，第二级安全采样；极高频下需三级同步
- 快到慢 CDC 额外需防数据丢失——异步 FIFO 或握手机制，不能仅靠 2-FF 同步器
- 格雷码 FIFO 是多比特 CDC 主力：指针格雷编码确保同步后最多偏差一个位置，"空"/"满"保守但安全
- 对多比特信号使用独立 2-FF 同步器是严重设计错误——各比特解析时间不同导致数据一致性破坏
- 4 相握手简单健壮，2 相握手吞吐更高但控制逻辑复杂；均适合低频控制信号 CDC
- 再收敛发散（多路同步信号重新组合）是常被忽视的 CDC 故障模式——需验证工具专门检测
- CDC 验证工具是唯一可靠保证——仿真无法重现亚稳态的概率性行为

## 与其他概念的关系

- [[concepts/metastability|亚稳态（Metastability）]] — CDC 的根本物理根源：双稳态元件的亚稳态振荡、解析时间 $\tau$ 和 MTBF 公式
- [[cross-domain/reset-methodology|复位策略（Reset Methodology）]] — 异步复位释放的恢复/移除时间与亚稳态机制相同，复位域交叉需独立复位同步器
- [[rtl-design/concepts/verilog-hdl|Verilog HDL 入门]] — CDC 同步器结构和异步 FIFO 的 RTL 编码实现及跨时钟域 always_ff 的注意事项
- [[rtl-design/concepts/pipeline-design|流水线设计（Pipeline Design）]] — 异步 FIFO 内部常嵌入流水线以切断关键路径，是 CDC 与流水线技术的交汇点

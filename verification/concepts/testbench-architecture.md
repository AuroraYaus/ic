---
type: concept
aliases:
  - 验证平台架构
  - Testbench Architecture
  - 分层验证平台
  - Layered Testbench
tags:
  - asic
  - verification
  - testbench
  - architecture
  - uvm
  - agent
  - scoreboard
source_spec: "IEEE 1800.2-2020 UVM LRM; Mentor/Siemens, UVM Cookbook; Synopsys, VIP Development Guide"
---

# 验证平台架构（Testbench Architecture）

验证平台（Testbench）架构是功能验证基础设施的骨架，它定义了验证环境各组件之间的结构关系、通信路径和执行顺序。现代数字IC验证采用**分层验证平台（Layered Testbench）**架构，其核心理念是将不同关注点分离到不同的抽象层次：信号层（Signal Layer）处理引脚级时序，命令层（Command Layer）处理事务级交互，场景层（Scenario Layer）处理测试意图，功能层（Functional Layer）处理正确性判断。同一验证平台可以运行无数个不同的测试用例——测试用例只改变激励和配置参数，不改变验证平台结构。这一分层复用架构是 UVM 方法学的物理基础。

## 原理

### 分层架构的四个抽象层次

| 层次 | 职责 | 典型组件 | 抽象级别 |
|:---|:---|:---|:---|
| **信号层（Signal Layer）** | 引脚级时序、接口协议 | Interface（`interface`/`modport`） | Cycle-Accurate |
| **命令层（Command Layer）** | 事务级驱动与观测 | Driver, Monitor | Transaction-Level |
| **功能层（Functional Layer）** | 正确性判断、数据检查 | Scoreboard, Checker, Coverage Collector | Spec-Level |
| **场景层（Scenario Layer）** | 测试意图、激励编排 | Sequence, Virtual Sequence, Test | Intent-Level |

这种层次分离使得每一层都可以独立演化和复用。例如，当接口协议从 AXI3 升级到 AXI4 时，只有信号层和命令层的部分代码需要修改，功能层的 Scoreboard 和场景层的 Sequence 保持不变。

### Agent：验证平台的基本构建块

Agent 是分层验证平台中的标准验证组件单元，封装了与一个特定接口协议交互所需的所有组件。一个标准 UVM Agent 包含三个子组件：

```systemverilog
class my_agent extends uvm_agent;
    my_sequencer  sqr;    // Sequence仲裁和调度
    my_driver     drv;    // 事务→引脚信号转换
    my_monitor    mon;    // 引脚观测→事务提取

    uvm_analysis_port #(my_item) item_collected_port;  // 向Scoreboard广播

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon = my_monitor::type_id::create("mon", this);
        if (get_is_active() == UVM_ACTIVE) begin
            sqr = my_sequencer::type_id::create("sqr", this);
            drv = my_driver::type_id::create("drv", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        if (get_is_active() == UVM_ACTIVE)
            drv.seq_item_port.connect(sqr.seq_item_export);
        mon.item_collected_port.connect(item_collected_port);
    endfunction
endclass
```

Agent 通过 `is_active`（UVM_ACTIVE 或 UVM_PASSIVE）控制内部结构。Active 模式实例化 Sequencer + Driver + Monitor，用于驱动 DUT 的输入端口；Passive 模式仅实例化 Monitor，用于观测 DUT 的输出端口。Monitor 是 Agent 中唯一的被动组件——不论 Active 还是 Passive 模式都存在。Monitor 的核心职责是观测接口信号并提取事务：

```systemverilog
task my_monitor::run_phase(uvm_phase phase);
    forever begin
        my_item item = my_item::type_id::create("item");
        @(posedge vif.clk);
        if (vif.valid && vif.ready) begin
            item.data   = vif.data;
            item.id     = vif.id;
            item.is_last = vif.last;
            item_collected_port.write(item);  // Broadcast to Scoreboard
        end
    end
endtask
```

### Sequencer-Driver 握手协议

Sequencer 和 Driver 之间的通信通过 TLM（Transaction Level Modeling）的 `seq_item_port`/`seq_item_export` 连接，遵循标准的请求-完成握手：

1. Driver 调用 `seq_item_port.get_next_item(req)` —— 阻塞等待直到 Sequencer 有事务可提供
2. Sequencer 从当前活跃 Sequence 获取下一个事务对象，通过 TLM 传递给 Driver
3. Driver 将事务转换为接口引脚时序驱动（波形驱动），等待驱动完成后调用 `seq_item_port.item_done()`
4. Sequencer 将控制权返回给 Sequence，Sequence 继续生成下一个事务

```systemverilog
task my_driver::run_phase(uvm_phase phase);
    forever begin
        seq_item_port.get_next_item(req);      // Step 1: request item
        drive_transfer(req);                    // Step 3: drive to pins
        seq_item_port.item_done();              // Step 4: signal completion
    end
endtask
```

这一流水线机制确保了事务级抽象（Sequence Item）和信号级实现（Driver）的完全解耦：Sequence 不感知接口协议时序，Driver 不感知测试意图。`try_next_item()` 是 `get_next_item()` 的非阻塞变体，允许 Driver 在不阻塞的情况下检查是否有待处理事务。

### Scoreboard：功能正确性判断

Scoreboard 是验证平台中负责功能检查的核心组件，通常由**参考模型（Reference Model / Predictor）**和**比较器（Comparator）**两个子部件组成。

参考模型以更高抽象级别实现与 DUT 等价的功能——参考模型不要求时钟精确，它可以在收到完整输入事务后立即 "计算" 出期望输出，而不模拟内部的流水线延迟。这一抽象层次差异是关键——如果参考模型与 DUT 一样逐周期精确，则参考模型本身可能包含相同的设计 Bug。

```systemverilog
class my_scoreboard extends uvm_scoreboard;
    uvm_analysis_imp #(my_item, my_scoreboard) input_imp;
    uvm_analysis_imp #(my_item, my_scoreboard) output_imp;

    my_item expected_queue[$];   // Predicted outputs, in order
    my_item actual_queue[$];     // Actual DUT outputs, in order

    function void write_input(my_item t);
        my_item predicted = predict(t);   // Reference model
        expected_queue.push_back(predicted);
        try_compare();                    // Try matching in-order
    endfunction

    function void write_output(my_item t);
        actual_queue.push_back(t);
        try_compare();
    endfunction
endclass
```

比较器的比对策略分为两种：**顺序比对（In-Order）**——输入输出一一对应按序比较，用于简单流水线、单线程控制器；**乱序比对（Out-of-Order）**——使用关联数组 `expected_pool[id]` 按事务 ID 匹配，用于多线程、乱序返回的复杂设计（如 AXI Out-of-Order transactions）。比较维度包括精确匹配（Exact Match）、延迟容忍（Latency Tolerance）、格式容忍（Format Tolerance）和无关掩码（Don't-Care Mask）。

### 虚拟接口与配置数据库

虚拟接口（Virtual Interface）是 SystemVerilog 中将静态模块域的物理接口引用传递给动态类域验证组件的关键桥梁：

```systemverilog
// Top module: instantiate physical interface
module top;
    my_if dif(clk, rst_n);
    dut u_dut(.clk(clk), .rst_n(rst_n), .dif(dif));

    initial begin
        uvm_config_db #(virtual my_if)::set(null, "*", "vif", dif);
        run_test("my_test");
    end
endmodule
```

config_db 采用层次化通配匹配：`set()` 的第二个参数指定配置作用域，`get()` 从当前组件沿层次树向上追溯查找匹配。通配符 `*` 表示对全部组件可见，这是测试层向整个环境广播配置参数的标准方式。

### 环境分层与测试分层

验证环境（`uvm_env`）的嵌套集成实现验证平台的分层组装：子系统级环境包含多个 IP 级 Agent 和 Scoreboard，系统级包含子系统级环境。测试层（`uvm_test`）在环境之上专注三件事：(1) 通过 `config_db::set()` 配置环境参数；(2) 启动特定 Sequence（包括 Virtual Sequence 编排多接口协同）；(3) 通过工厂覆盖（`set_type_override()`）定制组件实现。

### 回归测试基础设施

回归测试（Regression）在计算集群上并行运行大量测试用例。三个关键维度：**测试用例集**（数百至数千个测试）、**随机种子**（每个测试 5-20 seeds）、**配置参数**（不同配置变体的矩阵）。

回归策略分级：(1) **冒烟回归**（Smoke Regression）——核心测试 + 1-2 seeds，分钟到小时级；(2) **夜间回归**（Nightly Regression）——全部测试 + 5-10 seeds，通宵运行；(3) **完整回归**（Full Regression）——全部测试 + 全部配置组合 + 更多 seeds，周末运行，用于 Signoff 前的最终验证。

回归管理工具（vManager、Verdi Regression Manager）负责作业提交、状态监控、日志自动分类（Pass/Fail）、覆盖率合并和仪表盘报告。90% 的回归失败通常来自环境问题而非设计问题——环境稳定性是回归价值的前提。

## 关键要点

- 分层架构的核心原则是关注点分离：Test 负责"测什么"（What），Sequence 负责"按什么顺序"（When），Driver 负责"怎么给信号"（How），Monitor 负责"怎么观测"（Observe），Scoreboard 负责"怎么判断对错"（Judge）
- Agent 的 active/passive 模式使同一个代码库既能驱动输入又能监测输出——这是 VIP（Verification IP）可复用的技术基础，也是验证平台工程效率的关键
- Sequencer-Driver 握手是验证平台的时序心跳——Driver 不应在未完成当前事务时提前获取下一个（流水线除外），否则 Scoreboard 的期望-实际匹配会因事务乱序而失败
- Scoreboard 参考模型必须与 DUT 行为等价但不要求时钟精确——参考模型抽象层次越高开发维护成本越低，但等价性保证越弱，需在效率和准确性间平衡
- 虚拟接口是 class-based 验证环境和 module-based DUT 世界的唯一桥梁——Interface 中不应包含过程时序逻辑（task/function 除外），保持 module/class 边界清晰
- 验证平台本身的验证（Verification of the Verification Environment）是一个经常被忽视但至关重要的问题：伪通过（False Pass，Scoreboard 误判通过）比伪失败（False Fail，环境配置错误导致失败）更危险
- Virtual Sequence 是多接口协同场景编排的标准手段：在 Virtual Sequence 的 `body()` 中通过 `fork-join` + `wait` 语句实现跨接口的并行激励和同步约束
- 回归测试中环境稳定性是首要挑战——基于随机种子的测试失败必须能精准复现（保存 seed + wave dump + log），否则无法调试和修复

## 与其他概念的关系

- [[verification/concepts/uvm-methodology|UVM 验证方法学（UVM）]] — UVM 是分层验证平台架构的工业标准实现框架，提供了 Agent、Scoreboard、config_db、Factory、TLM 等完整的构建块集合——Testbench Architecture 定义“结构应该怎样”，UVM 提供“结构如何实现”
- [[verification/concepts/constrained-random|约束随机验证（CRV）]] — Sequencer-Driver-Sequence 流水线是 CRV 激励注入的执行通道，Sequence Item 的随机化决定了测试空间的覆盖范围
- [[verification/concepts/coverage-model|覆盖率模型（Coverage Model）]] — Monitor 中采集 Covergroup 样本（观测层），Scoreboard 中检查覆盖率数据的正确性（功能层），回归报告汇总覆盖率收敛态势
- [[verification/concepts/systemverilog-assertions|SystemVerilog 断言（SVA）]] — SVA 在 Interface（信号层）和 Checker（功能层）中运行，构成验证平台的协议合规性检查层，与 Scoreboard 的功能正确性检查形成互补
- [[verification/concepts/formal-verification|形式验证（Formal Verification）]] — 形式验证不需要 Testbench 的激励层，但 Assumption 定义（输入约束）通常可以通过分析 Testbench Driver 的合法行为范围来推导提取

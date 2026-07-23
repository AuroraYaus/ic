---
type: concept
aliases:
  - UVM Methodology_UVM方法学
  - Universal Verification Methodology
  - UVM库
tags:
  - asic
  - verification
  - uvm
  - methodology
  - testbench
source_spec: "IEEE 1800.2-2020 Universal Verification Methodology Language Reference Manual; Accellera UVM 1.2 User's Guide"
queries: 10
---
# UVM 方法学

通用验证方法学（Universal Verification Methodology, UVM）是集成电路功能验证领域事实上的工业标准方法学，由 Accellera 标准化并纳入 IEEE 1800.2-2020。UVM 基于 SystemVerilog 构建，提供了一套完整的类库（Class Library）和验证架构框架，覆盖从块级（Block-Level）到芯片级（Chip-Level）乃至系统级（System-Level）的验证需求。其核心设计理念是通过工厂模式（Factory Pattern）和配置机制（Configuration Mechanism）实现验证组件的高度可重用性和可扩展性。

## 原理

### 类库层次与工厂机制

UVM 的类库层次分为两大分支：以 `uvm_object` 为根的数据对象分支（Sequence Item、Sequence、Configuration 等）和以 `uvm_component` 为根的静态结构分支（Driver、Monitor、Scoreboard、Agent、Environment、Test 等）。`uvm_component` 具有父子层次关系和 Phase 执行机制，而 `uvm_object` 则是轻量级的数据容器。工厂机制（Factory）是 UVM 最核心的设计模式之一：通过 `uvm_factory` 单例，用户可以在不修改现有验证环境代码的前提下，将某个类型的所有实例替换为其子类实现。工厂注册使用宏 `` `uvm_object_utils`` 和 `` `uvm_component_utils``，类型覆盖通过 `set_type_override_by_type()` 或 `set_inst_override_by_type()` 实现，配合 `create()` 方法替代 `new()` 构造函数。这一设计使得验证 IP（VIP）的外部定制和项目间复用成为可能。

配置数据库（Configuration Database, config_db）是 UVM 的另一个关键机制，通过 `uvm_config_db #(T)::set()` 和 `get()` 方法实现验证环境中任意节点间的键值对传递。config_db 采用层次化查找策略：`get()` 调用会从当前组件开始，沿层次树向上追溯到 root，检查键名和路径的通配匹配。config_db 解决了传统验证中全局变量或参数传递带来的耦合问题，常用于传递虚拟接口（Virtual Interface）、Agent 配置（active/passive 模式）、覆盖率使能标志等。config_db 的 `set()` 必须在 `build_phase` 之前或之中完成，而 `get()` 通常发生在 `build_phase` 内，这一时序约束是 UVM Phase 机制的核心保障。

### UVM Phase 机制

UVM 将仿真生命周期划分为一组严格有序的 Phase，确保所有验证组件在统一的时间点上执行初始化、连接和运行操作。最关键的三个 Phase 组是：(1) **Build Phases**（`build_phase`、`connect_phase`、`end_of_elaboration_phase`）——自顶向下构建组件树，然后自底向上完成连接；(2) **Run Phases**——`run_phase` 与 12 个细分 Run-Time Phase（`reset_phase`、`configure_phase`、`main_phase`、`shutdown_phase`）并行执行，允许不同组件在不同 Phase 阶段做不同的事；(3) **Cleanup Phases**（`extract_phase`、`check_phase`、`report_phase`）——收集验证结果和输出报告。Phase 的严格同步通过 `uvm_domain` 和 `uvm_phase` 的 `raise_objection`/`drop_objection` 机制实现：`run_phase` 不会结束直到所有 objection 都已被 drop，这保证仿真不会在激励未发送完毕或检查未完成时提前终止。

### TLM 通信与 Sequence 机制

事务级建模（Transaction Level Modeling, TLM）是 UVM 组件间通信的标准方式。TLM 定义了 Port、Export 和 Imp（Implementation）三种端口角色：Port 是发起端（调用方法方），Export 是中间转发端，Imp 是最终的实现端。TLM 接口方法包括 `put()`、`get()`、`transport()`、`write()` 等，以及对应的 `try_*` 和非阻塞 `nb_*` 变体。`uvm_tlm_analysis_fifo` 是 Monitor 到 Scoreboard 的广播通信中最常用的组件，实现了一个无限深度的 TLM FIFO，允许多个 writer 写入，多个 subscriber 通过 `analysis_port` 独立读取。Sequence → Sequencer → Driver 流水线是 UVM 激励生成的标准范式：Sequence 产生 `uvm_sequence_item` 事务对象，通过 `start()` 方法将其发送到 Sequencer；Sequencer 作为仲裁器管理多个 Sequence 的请求队列；Driver 通过 `seq_item_port.get_next_item()` 从 Sequencer 获取下一个事务，将其转换为 DUT 接口上的引脚级信号时序，完成后调用 `item_done()`。这一流水线将事务级抽象与信号级实现完全解耦。

对于多接口协议协同验证场景，Virtual Sequencer 提供了不直接连接 Driver 的虚拟调度层。通过在 Virtual Sequence 中实例化多个子 Sequencer 的句柄，并在 `body()` 任务中协调各子 Sequence 的执行（串行或并行启动、同步等待等），实现跨接口的复杂测试场景编排。典型的 Virtual Sequence 在 `body()` 中通过 `fork...join` 并行启动子 Sequence，并使用 `grab_lock` / `ungrab_lock` 机制确保关键操作（如寄存器配置后启动传输）不被其他 Sequence 的事务插入打断。

### Sequence 分层与仲裁策略

UVM 推荐将 Sequence 按照抽象层级分层组织：底层 API Sequence（`axi_write_seq`、`apb_read_seq`）封装单次总线操作的事务生成逻辑；中间层 Functional Sequence（`dma_config_seq`、`mem_fill_seq`）组合多个 API Sequence 完成一个功能单元；顶层 Scenario Sequence（`dma_full_test_seq`）协调多个 Functional Sequence 实现完整测试场景。这种分层使得低层 Sequence 可在不同测试场景间复用而不需修改。

Sequencer 的仲裁策略通过 `set_arbitration()` 配置，支持 SEQ_ARB_FIFO（先进先出）、SEQ_ARB_WEIGHTED（权重轮询）、SEQ_ARB_RANDOM（随机）、SEQ_ARB_STRICT_FIFO（严格 FIFO，不考虑优先级）、SEQ_ARB_STRICT_RANDOM（严格随机）和 SEQ_ARB_USER（用户自定义）等多种模式。当多个并行 Sequence 同时有事务待发送时，仲裁策略决定 Driver 的调度顺序——这在多通道 DMA 验证中尤为重要，因为不同通道的 Sequence 优先级直接影响 DUT 的行为正确性。

### UVM 通信的高级模式

除了 TLM FIFO 的广播模式外，UVM 还支持点对点的 TLM 连接用于确定性通信。`uvm_tlm_req_rsp_channel` 封装了 `put()` + `get()` 的双向请求-响应通道，允许组件在发送请求后同步等待响应——这对于需要握手确认的验证逻辑（如 Scoreboard 向 Reference Model 查询预期结果）很有用。`uvm_blocking_transport_port` 和 `uvm_non_blocking_transport_port` 则提供更通用的传输接口，支持阻塞和非阻塞两种通信语义。

### 资源数据库（Resource Database）

除 config_db 外，UVM 1.2 引入了资源数据库（`uvm_resource_db`）作为更灵活的配置传递机制。与 config_db 的层次化作用域不同，resource_db 提供全局平面化的键值存储，不受组件层次约束。resource_db 适用于需要在测试环境中全局共享且不涉及特定组件层次的数据——如全局测试参数、随机种子值、DUT 拓扑信息等。config_db 和 resource_db 可以并存使用，`uvm_config_db::set()` 内部实际上同时向 resource_db 写入数据，而 `get()` 先从 config_db 查找再从 resource_db 查找。

### UVM Report 机制

UVM 的报告机制通过 `uvm_report_handler` 和 `uvm_report_server` 两级结构实现。`uvm_info`/`uvm_warning`/`uvm_error`/`uvm_fatal` 四个宏是主要的报告接口，每个宏支持 verbosity 过滤（`UVM_NONE` 到 `UVM_DEBUG` 共 6 级）、ID 标签、消息体和动作控制。`uvm_report_server` 的 `set_max_quit_count()` 方法设置在仿真因错误退出前允许的 `uvm_error` 最大数量——这是控制"fail fast"行为的关键参数，通常设为 5-10 以在回归测试中快速暴露致命问题而不浪费仿真机时。

### Objection 与仿真终止

UVM 的 Objection 机制是控制仿真生命周期终止的核心：`run_phase` 和所有 12 个 Run-Time Phase 在进入时自动启动，但不会自动结束——必须等待该 Phase 中所有 `raise_objection` 和 `drop_objection` 配对完成。`uvm_objection` 对象维护每个 Phase 的挂起 objection 计数；当计数降为零时 Phase 结束。常见的 Objection 管理方式包括：(1) 在 `uvm_sequence_base` 的 `pre_start()` 和 `post_start()` 中通过配置标志自动 raise/drop objection，减少手动操作；(2) 在 Scoreboard 中 raise objection 直到所有期望事务都被检查完成；(3) 使用看门狗定时器（Watchdog Timer）——在 `run_phase` 中启动定时任务，超时后无条件清空所有 objection 并报 `UVM_FATAL`，防止仿真无限制挂起。

### Callback 机制与扩展点

UVM 的 Callback（回调）机制提供了一种非侵入式的扩展方式：通过 `uvm_callback` 基类和 `` `uvm_register_cb`` 宏，用户可以在 UVM 组件的关键执行点（如 Driver 的事务处理前后、Monitor 的事务广播前后）注册回调函数，注入自定义行为而不需修改原始组件代码。例如在 `uvm_driver::put_response()` 前注册一个错误注入回调，在特定条件下将已发送事务的某个字段篡改为错误值以测试 Scoreboard 的检错能力。Callback 的优势在于不与 Factory Override 产生冲突——Factory Override 替换整个组件类型，而 Callback 只是附加行为；两者可以同时使用。

### RAL 前门访问的适配流程

RAL 前门访问的完整流程为：`uvm_reg::write()` → `uvm_reg_map::do_write()` → `reg_adapter::reg2bus()`（将 `uvm_reg_bus_op` 转换为总线 Sequence Item）→ 将 Sequence Item 发送到 Bus Sequencer → Bus Driver 驱动总线协议信号 → 等待总线响应 → `reg_adapter::bus2reg()`（将总线响应 Sequence Item 转换回 `uvm_reg_bus_op`）→ 返回状态码。后门访问则绕过总线直接通过 HDL 路径（`uvm_hdl_read()`/`uvm_hdl_deposit()`）访问寄存器值，仅需 `add_hdl_path()` 和 `add_hdl_path_slice()` 设置 DUT 路径映射。RAL 的 `predict()` 方法允许在仿真中直接更新镜像值而不发起总线访问——适用于已知硬件行为但不想发送冗余总线事务的场景。

### 寄存器抽象层（Register Abstraction Layer, RAL）

UVM RAL 提供了一套面向对象的寄存器建模和访问框架。用户通过 `uvm_reg_field`、`uvm_reg`、`uvm_reg_block` 等类构建与硬件寄存器映射（Register Map）一一对应的镜像模型。RAL 提供 `read()`/`write()` 前门访问（通过 Bus Sequencer 发送总线事务）和后门访问（通过 HDL 路径直接读写）两种方式，并自动维护期望值（Desired Value）和镜像值（Mirror Value），通过 `mirror()` 或 `update()` 方法实现硬件状态与模型的一致性检查和同步。RAL 内建 Coverage（寄存器域覆盖率收集）和 Memory 建模（`uvm_mem`）以支持配置空间验证和存储控制器验证。

### UVM Phase 机制

UVM 将仿真生命周期划分为一组严格有序的 Phase（阶段），确保所有验证组件在统一的时间点上执行初始化、连接和运行操作。Phase 机制的设计目的是解决 OVM 中组件初始化顺序不确定导致的环境构建竞态问题。

**三大 Phase 组及各自 Phase：**

| Phase 组 | Phase 名称 | 执行顺序 | 函数/任务 | 典型用途 |
|:---|:---|:---|:---|:---|
| **Build** | `build_phase` | 自顶向下 | function | 用 `create()` 实例化子组件，`config_db::get()` 获取配置 |
| | `connect_phase` | 自底向上 | function | 连接 TLM port/export/imp，连接 Virtual Interface |
| | `end_of_elaboration_phase` | 自底向上 | function | 最终配置调整，打印环境拓扑，检查连接完整性 |
| **Run** | `start_of_simulation_phase` | 自底向上 | function | 仿真开始前的最后一次初始化（打印 banner、打开日志文件） |
| | `run_phase` | 并行 | **task** | 主要的激励生成和 DUT 交互（消耗仿真时间） |
| | `reset_phase` | 并行 | task | DUT 复位阶段的特定行为 |
| | `configure_phase` | 并行 | task | DUT 配置阶段的特定行为（编程寄存器等） |
| | `main_phase` | 并行 | task | 核心测试场景执行 |
| | `shutdown_phase` | 并行 | task | DUT 关闭/低功耗进入等结束行为 |
| **Cleanup** | `extract_phase` | 自底向上 | function | 从 Scoreboard/Monitor 提取数据（覆盖率、性能计数等） |
| | `check_phase` | 自底向上 | function | 最终正确性检查（Scoreboard Drain 检查、队列清空验证） |
| | `report_phase` | 自底向上 | function | 输出测试报告、Pass/Fail 判定 |
| | `final_phase` | 自顶向下 | function | 仿真终止前的最后清理（关闭文件、释放资源） |

**Phase Objection 机制：**

Objection 是控制 `run_phase` 和各 Run-Time Phase 何时结束的唯一手段。原理：每个 Phase 进入时自动启动，但不会自动结束——必须等待该 Phase 中所有的 `raise_objection` 和 `drop_objection` 配对完成。

```systemverilog
// ===== Phase Objection 控制仿真生命周期 =====
// uvm_test 派生类：具体的测试用例
class my_test extends uvm_test;
    `uvm_component_utils(my_test)          // 工厂注册宏：将类注册到 UVM 工厂

    task run_phase(uvm_phase phase);       // run_phase 任务：消耗仿真时间
        super.run_phase(phase);            // 调用父类的 run_phase（可选，保留默认行为）

        // phase.raise_objection(this):
        //   向当前 phase 的 objection 管理器注册一个 objection
        //   this: 引用当前组件对象——记账"这个组件还有未完成的工作"
        //   效果：phase 的挂起 objection 计数 +1
        phase.raise_objection(this);       // 告诉 UVM："我还有工作要做，别急着结束仿真"

        // seq.start(sequencer):
        //   启动 Sequence 对象，将其事务发送到指定 Sequencer
        //   sequencer 句柄通过 config_db 或层次路径引用获取
        my_sequence seq = my_sequence::type_id::create("seq");
        seq.start(env.virt_seqr);          // 在 Virtual Sequencer 上启动顶层 Sequence

        // phase.drop_objection(this):
        //   解除当前组件对当前 phase 的 objection
        //   效果：phase 的挂起 objection 计数 -1
        //   当所有 objection 都被 drop 后（计数归零），phase 自动结束
        phase.drop_objection(this);        // 告诉 UVM："我的工作做完了，可以结束了"
    endtask
endclass
```

**不 raise objection 会怎样？**
- `run_phase` 进入后**立即退出**（因为挂起 objection 计数为 0）
- 测试在开始任何实际操作之前就"结束"了
- 最常见的症状：仿真瞬间完成，波形为空，所有覆盖率为 0%
- 这是 UVM 新手最容易犯的错误——忘了 raise objection 导致仿真秒退

**`run_phase` 和 12 个细分 Run-Time Phase 的关系：**

两者**并行执行**，但各自有独立的 Objection 控制。`run_phase` 在所有 12 个 sub-phase 启动时同时启动，在 12 个 sub-phase 全部结束后才结束。典型的分工策略：
- `run_phase` 用于不需要精细阶段控制的简单激励（大多数测试用例只用这个）
- Sub-phase（`reset_phase`/`configure_phase`/`main_phase`/`shutdown_phase`）用于需要按阶段精确控制 DUT 行为的复杂场景（如功耗验证需要精确控制何时进入/退出低功耗模式）

**Phase 跳转：**

UVM 支持 Phase 跳转（Phase Jump），通过 `phase.jump()` 方法实现。典型的跳转场景是错误恢复：`main_phase` 中检测到致命错误后跳转回 `reset_phase` 重新初始化 DUT 而非直接终止仿真。

```systemverilog
// ===== Phase 跳转：错误恢复场景 =====
task main_phase(uvm_phase phase);
    // 执行核心测试逻辑
    if (fatal_error_detected) begin
        `uvm_warning("PHASE_JUMP", "Fatal error detected, jumping back to reset_phase")
        // phase.jump(目标phase): 从当前 phase 直接跳转到指定的 phase
        //   跳转后：reset_phase → configure_phase → main_phase 重新执行一次完整的运行周期
        //   适用场景：错误恢复、DUT 状态异常时的自动重试
        phase.jump(uvm_reset_phase::get());  // 跳转回 reset_phase 从头开始
    end
endtask
```

**UVM 相比 OVM 的改进：**

| 方面 | OVM | UVM |
|:---|:---|:---|
| **Phase 名称不一致** | `build`/`connect`/`run` | 统一 `_phase` 后缀，增加 `start_of_simulation_phase` |
| **Objection 作用域** | 仅 `run` 任务 | 所有 12 个 Run-Time Phase 各自独立管理 |
| **Phase 跳转** | 不支持 | 支持 `phase.jump()` 运行时跳转 |
| **资源数据库** | 仅 config-db 层次查找 | 增加 `uvm_resource_db` 全局平面键值存储 |
| **Callback 注册** | 手动，繁琐 | `uvm_callback` 基类 + `` `uvm_register_cb`` 宏，标准化 |
| **标准规范** | Accellera 内部标准 | IEEE 1800.2-2020 国际标准 |
| **工厂宏** | 非标准，各供应商不同 | `` `uvm_component_utils`` / `` `uvm_object_utils`` 统一标准 |

### uvm_component 和 uvm_object 的区别

`uvm_component` 和 `uvm_object` 是 UVM 类库层次的两个根类，它们决定了 UVM 中所有类的本质行为。

**核心区别对比：**

| 维度 | `uvm_component` | `uvm_object` |
|:---|:---|:---|
| **层次关系** | 有父子层次（parent-child），形成组件树 | 无层次关系，独立存在（或临时挂载到某 component 上） |
| **生命周期** | 静态（仿真全程存在），在 `build_phase` 中创建后持续到仿真结束 | 动态（可随时创建和销毁），每个事务用完即可丢弃 |
| **Phase 机制** | 参与 Phase 执行（自动调用 build/connect/run/check 等回调） | 不参与 Phase 机制 |
| **`new()` 参数** | **必须有 parent 参数**：`function new(string name, uvm_component parent)` | **只需 name 参数**：`function new(string name = "")` |
| **工厂创建位置** | 必须在 `build_phase` 中通过 `create()` 创建 | 可在任何位置通过 `create()` 或在 Sequence 的 `body()` 中创建 |
| **配置访问** | 天然支持 `config_db::get()` / `set()` | 可通过 `uvm_resource_db` 或自身 `m_set_full_name()` 后使用 config_db |
| **典型子类** | Driver, Monitor, Sequencer, Scoreboard, Agent, Env, Test | Sequence Item (Transaction), Sequence (非 component), Configuration, RegModel |
| **工厂宏** | `` `uvm_component_utils`` | `` `uvm_object_utils`` |

**为什么 component 在 build_phase 创建？**

`build_phase` 是 UVM Phase 机制中唯一**自顶向下**执行的 Build Phase——父组件先于子组件执行。这样设计的好处：
1. **config_db 的 set/get 时序**：`set()` 通常在父组件的 `build_phase` 中执行，`get()` 在子组件的 `build_phase` 中执行，自顶向下的顺序保证子组件在 `get()` 时父组件已经完成 `set()`
2. **组件树一次性构建**：所有静态组件在仿真时间 0 之前就全部创建完毕，后续的 connect/run phase 操作在已知的完整组件树上进行

```systemverilog
// ===== uvm_component 的 build_phase：自顶向下创建组件树 =====
class my_env extends uvm_env;
    `uvm_component_utils(my_env)          // 工厂注册：uvm_component 专用宏

    my_agent agent_0;                      // 子组件句柄声明（尚未创建实例）

    // function new: uvm_component 构造函数的参数签名
    //   name:   组件实例名（字符串），用于层次路径构造
    //   parent: 父组件引用（uvm_component 类型），用于建立父子层次关系
    //           必须是 uvm_component（不能是 uvm_object），因为只有 component 有层次
    function new(string name, uvm_component parent);
        super.new(name, parent);           // 调用父类（uvm_env）的构造函数
    endfunction

    // build_phase: 在此 phase 中实例化所有子组件
    //   此 phase 执行时 parent 已经完全构建好（config_db set 已生效）
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);          // 先调用父类 build_phase（保留默认行为）

        // type_id::create(name, parent):
        //   工厂方法——替代 new() 来创建组件实例
        //   name: 实例名（字符串，必须与句柄变量名一致以避免命名冲突）
        //   parent: 传入 this（当前 env 实例），建立 "env → agent" 的父子关系
        //   为什么用 create() 而非 new()：
        //     create() 会查询工厂表——如果外部做了 override，
        //     实际创建的可能是 my_agent 的子类（如 my_agent_extended）
        //     而 new() 直接构造指定类型，绕过了工厂机制
        agent_0 = my_agent::type_id::create("agent_0", this);

        // config_db::get(): 在 build_phase 中获取配置参数
        //   此时父组件的 set() 已经完成（自顶向下），get() 能安全获取到值
        if (!uvm_config_db #(virtual my_if)::get(this, "", "vif", agent_0.vif))
            `uvm_fatal("CFG", "Virtual interface not set for agent_0")
    endfunction
endclass
```

**为什么 new 需要 parent 参数？**

父组件参数 `parent` 是 UVM 组件树的构建基础：
1. **层次路径生成**：每个 component 的完整层次路径由 `parent.get_full_name() + "." + name` 自动拼接，例如 `"uvm_test_top.env.agent_0.driver"`——这用于 config_db 的路径匹配、日志标识和调试定位
2. **自动内存管理**：父组件在其析构时自动释放子组件，无需手动管理
3. **config_db 查找锚点**：`get()` 的自动层次查找从当前组件开始沿 parent 链向上追溯

**`uvm_transaction` 和 `uvm_sequence_item` 的关系：**

```text
uvm_object
  └── uvm_transaction           ← 事务基类：定义了记录和比较接口
        └── uvm_sequence_item    ← 序列项：在 transaction 基础上增加了 sequencer 关联
```

- `uvm_transaction`：提供了 `accept_tr()`/`begin_tr()`/`end_tr()` 等事务记录方法（用于波形和日志中的事务可视化追踪）
- `uvm_sequence_item`：继承自 `uvm_transaction`，增加了 `set_sequencer()` / `get_sequencer()` 方法，使 item 能关联到产生它的 sequencer；增加了 `set_item_context()` 用于序列层次上下文传递
- **工程实践**：几乎所有自定义 Transaction 类都继承自 `uvm_sequence_item`（而非 `uvm_transaction`），因为需要与 Sequencer-Driver 流水线集成

**Sequence 是 component 还是 object？**

Sequence 继承自 `uvm_sequence`，而 `uvm_sequence` 继承自 `uvm_sequence_base`，最终根类是 `uvm_object`——所以 **Sequence 是 object，不是 component**。这意味着：
- Sequence 是**动态的**：每次测试可以创建不同的 Sequence 实例，用完即销毁
- Sequence **不参与 Phase 机制**：它在 `body()` 任务中自主运行，与 Component 的 Phase 生命周期独立
- Sequence 可以**在 `body()` 中 `raise_objection` / `drop_objection`**：虽然 Sequence 不是 component，但它可以通过 `starting_phase` 间接控制当前 Phase 的 Objection

**config_db 给 object 传配置：**

虽然 config_db 主要面向 component，但也可以给 object 传递配置：

```systemverilog
// ===== config_db 给 uvm_object 传配置的两种方式 =====
class my_config extends uvm_object;       // 配置对象（继承自 uvm_object）
    rand int timeout;
    `uvm_object_utils(my_config)
endclass

// 方式 1：通过其创建时的 component context 查询
//   在 Sequence 的 body() 中——Sequence 通过 get_sequencer() 获得其所在的 component context
my_config cfg;
if (!uvm_config_db #(my_config)::get(m_sequencer, "", "cfg", cfg))
    `uvm_error("CFG", "config not found for sequence")

// 方式 2：使用 resource_db（推荐——不依赖 component 层次）
//   需要先给 object 设置 full_name（通过挂载到某个 component 或手动设置 context）
uvm_resource_db #(my_config)::set("GLOBAL", "shared_cfg", cfg_obj);
```

### UVM Factory 机制

Factory（工厂）是 UVM 最核心的设计模式之一。它的本质是用一个全局注册表（Registry）替代直接构造函数调用，实现类型的动态替换——这是验证 IP 可配置性和可复用性的技术基础。

**Factory 的核心作用：**

1. **类型覆盖（Type Override）**：在不修改现有验证环境代码的前提下，将某个类型的所有实例或特定实例替换为其子类实现
2. **实例级替换**：可以精确控制替换范围——"替换所有 AXI Master Agent" vs "只替换 DMA 通道的 AXI Master Agent"
3. **测试用例差异化**：同一个验证环境，不同测试通过 Factory Override 实现不同的组件行为——如错误注入 Driver、特殊配置 Monitor 等

```systemverilog
// ===== Factory 机制：注册、创建、覆盖三部曲 =====

// ── 步骤 1：定义一个可被覆盖的基类 ──
// `uvm_component_utils: 工厂注册宏——将类的基本信息注册到全局工厂表中
//   注册的内容包括：类名、类型 ID（`get_type()`）、创建函数指针（`create()`）
class my_driver extends uvm_driver #(my_item);
    `uvm_component_utils(my_driver)      // 工厂注册：使得 create() 方法可用

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        // 标准驱动行为：获取事务 → 驱动信号 → 确认完成
        forever begin
            seq_item_port.get_next_item(req);
            drive_transfer(req);         // 驱动 DUT 信号（标准行为）
            seq_item_port.item_done();
        end
    endtask
endclass

// ── 步骤 2：定义扩展类（带错误注入的子类）──
// extends my_driver: 继承标准 Driver，复用其所有接口和连接
class my_driver_error extends my_driver;
    `uvm_component_utils(my_driver_error) // 子类也需要独立注册到工厂

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(req);
            // 以 5% 的概率注入错误——翻转数据的第 0 位
            if ($urandom_range(0, 99) < 5)    // 0-4 共 5 个数 → 5% 概率
                req.data[0] = ~req.data[0];    // 位翻转：0→1 或 1→0
            drive_transfer(req);
            seq_item_port.item_done();
        end
    endtask
endclass

// ── 步骤 3：在 Testcase 中通过 Factory Override 替换组件 ──
class my_test_with_error_injection extends uvm_test;
    `uvm_component_utils(my_test_with_error_injection)

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // 方法 A：类型覆盖——该类型的所有实例都被替换
        // set_type_override_by_type(原始类型::get_type(), 替换类型::get_type());
        //   效果：环境中所有 my_driver 类型的实例都会被替换为 my_driver_error
        set_type_override_by_type(
            my_driver::get_type(),           // 要被替换的原始类型
            my_driver_error::get_type()      // 替换后的新类型
        );

        // 方法 B：实例覆盖——只替换特定路径下的特定实例
        // set_inst_override_by_type(原始类型, 替换类型, 实例路径);
        //   效果：只有路径匹配 "env.agent_dma.*" 的 my_driver 实例被替换
        set_inst_override_by_type(
            my_driver::get_type(),
            my_driver_error::get_type(),
            "env.agent_dma.*"                // 通配符路径：只覆盖 DMA Agent 内的 driver
        );
    endfunction
endclass
```

**Factory 与 `new()` 的关键区别：**

| 调用方式 | 行为 | 是否可被 Override |
|:---|:---|:---|
| `my_type::type_id::create("name", parent)` | 查工厂表 → 如存在 override 则创建替换类型 | **是** |
| `new("name", parent)` | 直接构造指定类型 | **否** |

这就是为什么 UVM 组件的实例化**必须**使用 `create()` 而非 `new()`——使用 `new()` 等于放弃了 Factory Override 能力，破坏了验证 IP 的可配置性。

### TLM — put/get/transport 接口

TLM（Transaction Level Modeling，事务级建模）是 UVM 组件间通信的标准方式，其核心思想是：**组件之间不通过信号线连接，而是通过传递事务对象（Transaction）来通信**。TLM 将通信从信号级抽象提升到事务级。

**TLM 端口角色：**

| 角色 | SystemVerilog 类 | 职责 |
|:---|:---|:---|
| **Port**（发起端） | `uvm_*_port` | 发起通信的一方（调用方法方），如 Driver 的 `seq_item_port` |
| **Export**（转发端） | `uvm_*_export` | 中间转发——将调用传递给下游的 Imp |
| **Imp**（实现端） | `uvm_*_imp` | 最终实现通信方法的一方（提供方法体），如 Sequencer 的实现 |

**put/get/transport 三种接口对比：**

| 接口 | 方向 | 参数 | 阻塞/非阻塞 | 典型场景 |
|:---|:---|:---|:---|:---|
| **`put(trans)`** | Port → Imp（生产者→消费者） | 发送的事务对象 | `put()`(阻塞), `try_put()`(非阻塞), `can_put()`(询问) | Monitor 向 Scoreboard 发送观测到的事务 |
| **`get(output trans)`** | Port → Imp（消费者→生产者） | 返回的事务对象 | `get()`(阻塞), `try_get()`(非阻塞), `can_get()`(询问) | Driver 从 Sequencer 获取下一个待发送的事务 |
| **`transport(req, output rsp)`** | Port → Imp（双向，请求→响应） | 请求事务 + 响应事务 | `transport()`(阻塞), `nb_transport()`(非阻塞) | Scoreboard 向 Reference Model 查询预期值并等待返回 |

```systemverilog
// ===== TLM 三种接口的完整代码示例 =====

// --- put 接口：Monitor 向 Scoreboard 推送事务 ---
class my_monitor extends uvm_monitor;
    `uvm_component_utils(my_monitor)

    // uvm_analysis_port: 广播端口——可以向多个订阅者同时发送
    //   #(my_item): 参数化的端口类型——此端口传递 my_item 类型的事务
    //   与 put_port 的区别：analysis_port 不阻塞，不等待应答，
    //   支持多对多广播（多个 writer 写入同一 analysis_fifo）
    uvm_analysis_port #(my_item) ap;       // 声明分析端口（广播用）

    function void build_phase(uvm_phase phase);
        ap = new("ap", this);              // 实例化端口（必须使用 new，不是 create）
    endfunction

    task run_phase(uvm_phase phase);
        my_item item;
        forever begin
            // 采样 DUT 接口信号 → 组装事务 → 广播
            collect_transaction(item);     // 从 DUT 信号组装事务对象
            ap.write(item);                // write(): 广播事务给所有订阅者（非阻塞）
        end
    endtask
endclass

// --- get 接口：Driver 从 Sequencer 拉取事务 ---
class my_driver extends uvm_driver #(my_item);
    `uvm_component_utils(my_driver)

    task run_phase(uvm_phase phase);
        forever begin
            // seq_item_port.get_next_item(req):
            //   UVM 内建的 get 接口封装——底层调用 Sequencer 的 get() 方法
            //   阻塞等待：如果 Sequencer 中无待发事务，Driver 在此阻塞
            seq_item_port.get_next_item(req);  // 阻塞拉取下一个事务

            drive_transfer(req);               // 驱动 DUT 信号

            // seq_item_port.item_done():
            //   通知 Sequencer 当前事务已驱动完成，可以发送下一个
            //   底层调用 Sequencer 的 put_response() 方法
            seq_item_port.item_done();         // 确认完成
        end
    endtask
endclass

// --- transport 接口：Scoreboard 通过 Reference Model 查询 ---
// uvm_blocking_transport_port: 阻塞传输端口——发送请求并等待响应
//   对比 uvm_non_blocking_transport_port（非阻塞版本）
uvm_blocking_transport_port #(my_req, my_rsp) transport_port;
//                                   ^        ^
//                                   请求类型  响应类型
//   注意：transport 需要两个类型参数——请求类型和响应类型

task check_transaction(my_item actual_item);
    my_req req = my_req::type_id::create("req");
    my_rsp rsp;                              // 响应对象句柄

    req.addr = actual_item.addr;
    req.data = actual_item.data;

    // transport_port.transport(req, rsp):
    //   发送 req 给 Reference Model，阻塞等待返回 rsp
    //   底层完成：req → 协议转换 → Reference Model 计算 → 协议转换 → rsp 返回
    transport_port.transport(req, rsp);

    // 比对 DUT 的实际输出（actual_item）与 Reference Model 的预期输出（rsp）
    if (actual_item.result != rsp.expected_result)
        `uvm_error("CHK", $sformatf("Mismatch: got %h, expected %h",
                                     actual_item.result, rsp.expected_result))
endtask
```

**接口选择决策树：**
- 单向推送数据（Monitor → Scoreboard）→ `put()` / `write()`（analysis_port 的 write 是最常见的广播形式）
- 单向拉取数据（Driver ← Sequencer）→ `get()` 或 UVM 内建的 `seq_item_port` 封装
- 双向请求-响应（需要同步等待返回值）→ `transport()`
- 非关键路径不想阻塞 → 使用 `try_*` 或 `nb_*` 变体

### connect_phase — TLM 端口的连接时机与机制

`connect_phase` 是 UVM Build Phases 中的第二个阶段，在 `build_phase` 之后执行。它的唯一职责是**连接 TLM 端口**——将 Port 连到 Export，将 Export 连到 Imp，建立组件间的通信通道。

**1. 为什么需要 connect_phase？**

组件在 `build_phase` 中被创建（`create()`），但在 `build_phase` 结束前，子组件的内部端口尚未完全构建好。因此 UVM 设计了第二个阶段——`connect_phase`——专用于建立连接，且执行方向与 `build_phase` 相反：

```text
build_phase (自顶向下)              connect_phase (自底向上)
─────────────────────────          ─────────────────────────
env.build_phase()                   driver.connect_phase()
  ├─ agent.create()                    └─ seq_item_port.connect(sequencer.seq_item_export)
  ├─ agent.build_phase()           monitor.connect_phase()
  │   ├─ driver.create()              └─ ap.connect(agent.ap)
  └─ scoreboard.create()           agent.connect_phase()
                                       └─ (子组件已连好，此层通常为空)
                                   env.connect_phase()
                                       └─ agent.ap.connect(scoreboard.analysis_export)
```

**connect_phase 的关键特性：**

| 特性 | 说明 |
|:---|:---|
| **执行方向** | **自底向上**（Bottom-Up）——叶子组件先完成连接，父组件后完成。与 build_phase 的自顶向下相反 |
| **执行性质** | `function`（非 task，0 仿真时间） |
| **唯一职责** | 连接 TLM 端口（`port.connect(export)` 调用） |
| **不可做的事** | 不可 `create()` 组件；不可 `raise_objection`；不可消耗仿真时间 |

**2. Port/Export/Imp 的连接规则**

TLM 端口连接有严格的类型和方向约束，且必须在 `connect_phase` 中完成：

```
连接链（单向）：
  Port ──connect()──► Export ──connect()──► Imp
  发起端              中间转发              最终实现

约束：
  - Port 可以连接到 Export 或 Imp
  - Export 只能连接到 Imp（不能连回 Port）
  - Imp 是终端——不能再连接到其他端口
  - 连接必须在 connect_phase 中完成（运行时不可改变）
  - 端口类型必须匹配（put_port → put_export/put_imp，不能连到 get 端口）
  - 参数化类型必须一致（#(my_item) 不能连 #(other_item)）
```

**3. connect_phase 的典型代码模式**

```systemverilog
// ===== Agent: 连接 Driver 到 Sequencer =====
class my_agent extends uvm_agent;
    my_driver    driver;         // 在 build_phase 中 create()
    my_sequencer sequencer;      // 在 build_phase 中 create()
    my_monitor   monitor;        // 在 build_phase 中 create()

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // ── seq_item_port (Port) → sequencer.seq_item_export (Export) ──
        // Driver 通过此连接从 Sequencer 阻塞拉取事务
        driver.seq_item_port.connect(sequencer.seq_item_export);

        // ── monitor.ap (Port) → agent 自身 ap (转发 Export) ──
        // Monitor 广播事务到 Agent 的分析端口，供外部 Env 连接
        monitor.ap.connect(this.ap);
    endfunction
endclass

// ===== Env: 跨层次连接 Agent 到 Scoreboard =====
class my_env extends uvm_env;
    my_agent      agent;         // 在 build_phase 中 create()
    my_scoreboard scoreboard;    // 在 build_phase 中 create()

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // ── agent.ap (Port) → scoreboard.analysis_export (Imp) ──
        // Monitor 发出的每个 write() 都到达 Scoreboard 的 FIFO
        agent.ap.connect(scoreboard.analysis_export);
    endfunction
endclass
```

**4. connect_phase 的常见错误**

| 错误 | 现象 | 修复 |
|:---|:---|:---|
| **在 build_phase 中做 connect** | 子组件端口尚未构造 → Null Handle → 仿真崩溃 | 移到 connect_phase |
| **忘记 super.connect_phase()** | 父类连接逻辑丢失——UVM 内建的 seq_item_port 等连接失效 | 确保每层调用 `super.connect_phase(phase)` |
| **在 connect_phase 中 create() 组件** | 违反 Build Phases 的职责分离——行为不可预测 | 移到 build_phase |
| **connect 方向写反** | `export.connect(port)` → 编译错误 | 始终 `port.connect(export)` |
| **类型不匹配** | 编译报错——参数化类型检查失败 | 检查 `#(type)` 是否一致 |

**5. 三个 Build Phase 的职责对比**

| 阶段 | 方向 | 职责 |
|:---|:---|:---|
| `build_phase` | 自顶向下 | `create()` 组件 + `config_db::get()` |
| `connect_phase` | 自底向上 | 连接 TLM 端口（`port.connect()`） |
| `end_of_elaboration_phase` | 自底向上 | 检查连接完整性——确认所有端口都已正确连接，虚拟接口不为 null |

### Sequence、Sequencer 与 Driver 的交互

Sequence 是激励的**生产者**，Sequencer 是激励的**仲裁器和调度器**，Driver 是激励的**消费者和执行者**。三者形成 UVM 激励生成的流水线（Pipeline）。

**各自职责：**

| 组件 | 基类 | 类型 | 职责 |
|:---|:---|:---|:---|
| **Sequence** | `uvm_sequence #(REQ,RSP)` | `uvm_object` | 定义事务的生成规则：随机化、循环、顺序、条件分支 |
| **Sequencer** | `uvm_sequencer #(REQ,RSP)` | `uvm_component` | 管理多个 Sequence 的请求队列，仲裁后将事务传递给 Driver |
| **Driver** | `uvm_driver #(REQ,RSP)` | `uvm_component` | 从 Sequencer 获取事务，将其拆解为引脚级信号时序，驱动 DUT |

**Driver-Sequencer 交互的完整流程：**

```
Sequence.body()                    Sequencer                     Driver
     │                                │                            │
     ├─ start_item(item) ────────────►│ 仲裁：决定哪个 Sequence   │
     │  (请求发送权限)                 │ 的事务可以发送              │
     │                                │                            │
     ├─ item.randomize()              │                            │
     │  (随机化事务字段)               │                            │
     │                                │                            │
     ├─ finish_item(item) ───────────►│ 事务入队 ─────────────────►│ get_next_item(req)
     │  (完成发送，等待Driver取走)     │  (FIFO/优先级队列)          │  (阻塞等待事务)
     │                                │                            │
     │                                │◄───────────────────────────┤ drive_transfer(req)
     │                                │                            │ (驱动DUT信号)
     │                                │                            │
     │                                │◄───────────────────────────┤ item_done(rsp)
     │                                │  (通知事务完成)             │ (确认完成，可带响应)
     │◄── get_response(rsp) ──────────┤                            │
     │  (获取Driver的响应，可选)       │                            │
```

```systemverilog
// ===== Sequence 示例：产生 N 个随机内存读写事务 =====
// `uvm_object_utils: Sequence 是 object（不是 component），用 object 宏注册
class mem_sequence extends uvm_sequence #(mem_item);
    `uvm_object_utils(mem_sequence)

    rand int num_items = 20;               // 随机生成的事务数量（默认可被覆盖）

    // body(): Sequence 的主任务——定义事务生成逻辑
    //   当调用 seq.start(sequencer) 时，body() 自动执行
    task body();
        mem_item item;

        // starting_phase: 指向当前 Sequence 所在 Phase 的 objection 管理器句柄
        //   如果 starting_phase 非空（即 Sequence 是从 run_phase 中启动的），
        //   则 raise objection 防止仿真过早结束
        if (starting_phase != null)
            starting_phase.raise_objection(this);

        // repeat(N): 循环体执行 N 次——产生 num_items 个随机事务
        repeat (num_items) begin
            // type_id::create(): 通过工厂创建事务对象
            item = mem_item::type_id::create("item");

            // start_item(item):
            //   请求 Sequencer 允许发送 item——进入仲裁队列等待
            //   如果更高优先级的 Sequence 正在 grab lock，则阻塞等待
            start_item(item);

            // randomize(): 在 start_item 和 finish_item 之间随机化
            //   此时 item 已经获得了仲裁许可，随机化字段值
            if (!item.randomize())
                `uvm_fatal("RAND_FAIL", "Item randomization failed")

            // finish_item(item):
            //   将随机化后的事务最终发送到 Sequencer 的输出 FIFO 中
            //   然后阻塞等待 Driver 调用 item_done() 确认消费
            finish_item(item);
        end

        if (starting_phase != null)
            starting_phase.drop_objection(this);
    endtask
endclass
```

**Sequence 启动方式：**

```systemverilog
// 方式 1：在 Test 的 run_phase 中通过 start() 启动
//   default_sequence 方式——最常用
task run_phase(uvm_phase phase);
    mem_sequence seq = mem_sequence::type_id::create("seq");
    phase.raise_objection(this);
    seq.start(env.agent.sequencer);        // 在指定 Sequencer 上启动 Sequence
    phase.drop_objection(this);
endtask

// 方式 2：通过 config_db 配置 default_sequence（无需手动 raise objection）
//   在 build_phase 中设置——UVM 自动管理序列的启动和 objection
uvm_config_db #(uvm_object_wrapper)::set(
    this, "env.agent.sequencer.main_phase",
    "default_sequence", mem_sequence::get_type()
);
```

### Monitor 和 Scoreboard 的职责

Monitor（监视器）和 Scoreboard（计分板）是验证平台中两个职责截然不同的组件——Monitor 负责**观测**，Scoreboard 负责**判断**。

**Monitor 的职责：**

Monitor 是被动组件（Passive Component）——**只采样不驱动**。它对 DUT 接口信号进行持续采样，将信号级事件重新组装（Reassemble）为事务级对象，然后通过 `analysis_port` 广播给所有订阅者。

```systemverilog
// ===== Monitor：被动采样 DUT 信号，组装事务，广播 =====
class axi_monitor extends uvm_monitor;
    `uvm_component_utils(axi_monitor)

    virtual axi_if vif;                    // 虚拟接口：连接到 DUT 引脚
    uvm_analysis_port #(axi_item) ap;      // 分析端口：广播事务给 Scoreboard/Coverage

    function void build_phase(uvm_phase phase);
        ap = new("ap", this);
        // 从 config_db 获取虚拟接口句柄
        if (!uvm_config_db #(virtual axi_if)::get(this, "", "vif", vif))
            `uvm_fatal("CFG", "Virtual interface not set for monitor")
    endfunction

    task run_phase(uvm_phase phase);
        axi_item item;
        forever begin
            // 等待一次完整的 AXI 写事务完成（地址握手 + 数据握手 + 响应握手）
            @(posedge vif.clk);
            if (vif.awvalid && vif.awready) begin          // 写地址握手
                item = axi_item::type_id::create("item");
                item.addr = vif.awaddr;                     // 捕获地址
                item.len  = vif.awlen;                      // 捕获突发长度
                // ... 等待数据握手、响应握手，填充 item ...
                ap.write(item);                             // 广播事务给所有订阅者
            end
        end
    endtask
endclass
```

**Scoreboard 的职责：**

Scoreboard 是验证检查器——从多个 Monitor 接收事务，执行端到端数据比对，判断 DUT 行为是否与预期一致。

```systemverilog
// ===== Scoreboard：接收 Monitor 事务并比对 =====
class my_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(my_scoreboard)

    // uvm_analysis_imp: 分析实现端口——接收来自 Monitor 的 write() 调用
    //   每个 Monitor 对应一个独立的 imp（通过 suffix 区分）
    //   _input/_output: 后缀用于在 connect_phase 中区分连接目标
    uvm_analysis_imp #(axi_item, my_scoreboard) input_imp;   // 输入侧（DUT 输入事务）
    uvm_analysis_imp #(axi_item, my_scoreboard) output_imp;  // 输出侧（DUT 输出事务）

    // 期望队列：存储输入事务，等待对应的输出事务到达后比对
    axi_item expected_queue[$];            // $: 无限队列（SystemVerilog queue）

    // write_input(): 当输入 Monitor 发送事务时调用
    function void write_input(axi_item item);
        expected_queue.push_back(item);    // 将输入事务存入期望队列
    endfunction

    // write_output(): 当输出 Monitor 发送事务时调用
    function void write_output(axi_item item);
        axi_item expected;
        bit matched = 1'b0;                // 匹配标志：防止 null 解引用
        // 从期望队列中查找对应的事务（支持乱序——查找而非简单 pop_front）
        foreach (expected_queue[i]) begin
            if (expected_queue[i].id == item.id) begin  // 用事务 ID 匹配
                expected = expected_queue[i];
                expected_queue.delete(i);    // 匹配后从队列中移除
                matched = 1'b1;
                break;
            end
        end
        // 未匹配到期望事务——报错并返回，避免 null 解引用
        if (!matched) begin
            `uvm_error("SB", $sformatf("No matching expected transaction for id=%0d", item.id))
            return;
        end
        // 比对：实际值 vs 期望值
        if (expected.data != item.data)
            `uvm_error("SB", $sformatf("Data mismatch: exp=%h, got=%h",
                                        expected.data, item.data))
    endfunction

    // check_phase: 仿真结束前检查队列是否已清空（Drain 检查）
    function void check_phase(uvm_phase phase);
        if (expected_queue.size() > 0)
            `uvm_error("SB", $sformatf("%0d unmatched expected items remaining",
                                        expected_queue.size()))
    endfunction
endclass
```

**Monitor vs Scoreboard 关键区别：**

| 维度 | Monitor | Scoreboard |
|:---|:---|:---|
| **职责** | 观测（Observation） | 判断（Judgment） |
| **主动/被动** | 被动（仅采样，不驱动） | 主动（执行比对，判定 Pass/Fail） |
| **DUT 交互** | 连接 DUT 引脚，周期级采样 | 不直接连接 DUT，只接收事务 |
| **输出** | 事务对象（通过 analysis_port 广播） | Pass/Fail 判定（通过 `uvm_error` 报告） |
| **实例数** | 每个 Agent 至少一个 | 整个验证环境通常一个（但可分层） |
| **对象基类** | `uvm_monitor` | `uvm_scoreboard` |

### 虚接口（Virtual Interface）

虚接口（Virtual Interface）是 SystemVerilog 中的一个语言特性，用于在类（Class）内部引用接口（Interface）实例。在 UVM 中，它是连接事务级抽象世界（Testbench 类）和信号级物理世界（DUT 引脚）的唯一桥梁。

**为什么需要 Virtual Interface？**

根本原因：SystemVerilog 的**类不能直接访问模块级的信号和接口**。UVM 的 Driver、Monitor 等组件都是类（`uvm_component` 扩展），它们运行在类的世界中，而 DUT 信号存在于模块的世界中。Virtual Interface 提供了一个"指针"——类通过 Virtual Interface 句柄间接访问 DUT 信号的当前值。

```systemverilog
// ===== Virtual Interface 的全生命周期 =====

// ── 步骤 1：定义 Interface（模块级，连接 DUT 引脚）──
interface axi_if (input logic clk);        // 接口定义：clk 作为输入端口传入
    logic        awvalid, awready;         // 写地址通道握手信号
    logic [31:0] awaddr;                   // 写地址
    logic [31:0] wdata;                    // 写数据
    logic        wvalid, wready;           // 写数据通道握手信号

    // clocking block: 定义采样和驱动相对于时钟的时序偏移
    //   cb: clocking block 名称（通常简写为 cb）
    //   @(posedge clk): 时钟边沿基准
    //   input #1step: 采样发生在 Preponed Region（时间步最开始），
    //                 避免与设计信号在当前时间步的更新产生竞争
    //   output #1: 驱动发生在 1 个时间单位后（Reactive Region），
    //              确保当前时间步的所有设计更新已稳定
    clocking cb @(posedge clk);
        input  awvalid, awready, awaddr;   // 采样信号（Monitor 侧使用）
        output wvalid, wready, wdata;       // 驱动信号（Driver 侧使用）
    endclocking
endinterface

// ── 步骤 2：在顶层模块中配置 Virtual Interface ──
module tb_top;
    logic clk;
    axi_if dut_if (.clk(clk));            // 实例化接口（硬件世界）

    my_dut dut (.if(dut_if));              // 连接 DUT

    initial begin
        // uvm_config_db::set() 必须在 build_phase 之前调用
        //   参数说明：
        //   null:   上下文为 null（全局可见，所有组件都能 get 到）
        //   "*.vif": 路径通配——所有以 vif 为键的 get() 调用都能匹配
        //   dut_if: 接口实例句柄（实接口 → 传到类世界后变为虚接口）
        uvm_config_db #(virtual axi_if)::set(null, "*", "vif", dut_if);
        run_test("my_test");               // 启动 UVM 测试
    end
endmodule

// ── 步骤 3：在 UVM Driver 中通过 Virtual Interface 驱动 DUT ──
class axi_driver extends uvm_driver #(axi_item);
    `uvm_component_utils(axi_driver)

    // virtual axi_if: 虚接口句柄声明
    //   virtual 关键字在此处表示"这是一个引用/指针"，
    //   与面向对象的多态（virtual function）含义不同
    virtual axi_if vif;                    // 虚接口：桥梁，连接类世界和模块世界

    function void build_phase(uvm_phase phase);
        // get(): 从 config_db 获取顶层模块中设置的接口句柄
        //   注意类型参数：virtual axi_if——必须与 set 时的类型完全一致
        if (!uvm_config_db #(virtual axi_if)::get(this, "", "vif", vif))
            `uvm_fatal("CFG", "Virtual interface not found")
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(req);
            // 通过 vif.cb（clocking block）驱动信号
            //   cb 保证了驱动时序与时钟的确定性对齐（#1 延迟）
            @(vif.cb);                     // 等待 clocking block 的时钟沿
            vif.cb.awaddr  <= req.addr;    // 非阻塞赋值：驱动地址（通过 cb 的 output skew）
            vif.cb.awvalid <= 1'b1;        // 驱动写地址有效
            // ... 等待握手完成 ...
            seq_item_port.item_done();
        end
    endtask
endclass
```

**使用 Clocking Block 的核心原因：**

| 问题 | 无 Clocking Block | 有 Clocking Block |
|:---|:---|:---|
| **采样竞争** | `@(posedge clk)` 后立即采样可能读到旧值或中间值 | `input #1step` 在 Preponed Region 采样——保证读到稳定值 |
| **驱动竞争** | 直接驱动在 Active Region，可能与 DUT 赋值冲突 | `output #1` 后延迟驱动——DUT 的所有更新完成后才驱动新值 |
| **时序可移植性** | 依赖工具和版本的默认行为 | clocking block 语义由 IEEE 1800 标准精确定义 |

### 寄存器模型（Register Model）

寄存器模型（Register Abstraction Layer, RAL）是 UVM 提供的一套面向对象的寄存器建模和访问框架。它构建了一个与 DUT 硬件寄存器映射一一对应的软件镜像，使得验证环境可以在事务级（而不是信号级）操作 DUT 的寄存器。

**RAL 的核心组件：**

| 类 | 对应硬件 | 说明 |
|:---|:---|:---|
| `uvm_reg_field` | 寄存器中的位域（Bit Field） | 最小的建模单元，描述访问类型（RW/RO/W1C/W0C 等）和位宽 |
| `uvm_reg` | 一个完整的寄存器 | 包含一个或多个 `uvm_reg_field`，定义寄存器的地址偏移 |
| `uvm_reg_block` | 寄存器块（Register Block） | 包含多个寄存器和子 `uvm_reg_block`，对应一个 IP/子系统的地址空间 |
| `uvm_reg_map` | 地址映射 | 定义寄存器地址到总线地址的映射关系和访问路径 |

**RAL 的核心作用：**

1. **高层抽象访问**：通过 `reg_model.ctrl_reg.write(status, data)` 替代手动构造总线时序——一行代码替代几十行序列代码
2. **自动镜像维护**：RAL 自动维护 Desired Value（期望值）和 Mirror Value（镜像值），通过 `mirror()`/`update()` 方法检查并同步硬件状态
3. **内建覆盖率**：每个 `uvm_reg_field` 自动支持功能覆盖率收集（hit coverage），无需手动编写 covergroup
4. **前后门双重访问**：支持前门（通过总线协议）和后门（通过 HDL 层次路径直接读写）两种访问方式
5. **Memory 建模**：`uvm_mem` 支持大容量存储器的建模和访问

```systemverilog
// ===== RAL 寄存器模型示例 =====
class ctrl_reg extends uvm_reg;            // 控制寄存器（继承自 uvm_reg）
    `uvm_object_utils(ctrl_reg)

    rand uvm_reg_field enable;             // enable 位域：RW 类型
    rand uvm_reg_field mode;               // mode 位域：RW 类型，2-bit

    function new(string name = "ctrl_reg");
        super.new(name, 32, UVM_NO_COVERAGE); // 32-bit 寄存器，名称 ctrl_reg
    endfunction

    function void build();
        // configure(this, ...): 将位域绑定到父寄存器
        //   this: 父寄存器引用
        //   1: 位宽（1 bit）
        //   0: LSB 位置（第 0 位）
        //   "RW": 访问类型——Read/Write
        enable = uvm_reg_field::type_id::create("enable");
        enable.configure(this, 1, 0, "RW", 0, 1'h0, 1, 1, 0);
        //                                 ^     ^    ^  ^  ^
        //                                 宽度=1 LSB=0 RW  复位=0  volatile

        mode   = uvm_reg_field::type_id::create("mode");
        mode.configure(this, 2, 1, "RW", 0, 2'h0, 1, 1, 0);
        //                      ^  ^               ^
        //                      2-bit LSB=1         复位值=0
    endfunction
endclass

class my_reg_block extends uvm_reg_block;  // 寄存器块
    `uvm_object_utils(my_reg_block)

    rand ctrl_reg ctrl;                    // 控制寄存器实例

    function new(string name = "my_reg_block");
        super.new(name);
    endfunction

    function void build();
        // default_map: 每个 reg_block 有一个默认的地址映射
        //   create_map(name, base_addr, n_bytes, endian):
        //   "map": 映射名称
        //   0: 基地址（外部总线可能再加偏移）
        //   4: 总线宽度（4 字节 = 32-bit 总线）
        //   UVM_LITTLE_ENDIAN: 字节序（小端）
        default_map = create_map("map", 0, 4, UVM_LITTLE_ENDIAN);

        ctrl = ctrl_reg::type_id::create("ctrl");
        ctrl.build();                      // 必须手动调用位域的 build()

        // default_map.add_reg(reg, addr, rights):
        //   将寄存器添加到地址映射中
        //   ctrl: 寄存器实例
        //   32'h0: 此寄存器在映射中的地址偏移（相对于基地址）
        //   "RW": 访问权限——可读可写
        default_map.add_reg(ctrl, 32'h0, "RW");
    endfunction
endclass

// ===== 在 Sequence 中使用 RAL 访问寄存器 =====
class config_sequence extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(config_sequence)

    task body();
        uvm_status_e status;               // 访问状态：UVM_IS_OK / UVM_HAS_X / UVM_NOT_OK
        uvm_reg_data_t data;               // 寄存器数据（bit 向量）

        // 前门写：通过总线协议写寄存器
        //   reg_model.ctrl.write(status, value, path, map, ...):
        //   UVM_FRONTDOOR: 前门访问——通过 Bus Sequencer 发送总线事务
        reg_model.ctrl.write(status, 32'h0000_0003, UVM_FRONTDOOR);
        //   enable=1, mode=01

        // 前门读：通过总线协议读寄存器
        reg_model.ctrl.read(status, data, UVM_FRONTDOOR);
        `uvm_info("RAL", $sformatf("Read ctrl_reg = %h, status = %s",
                                    data, status.name()), UVM_LOW)

        // mirror(): 检查硬件寄存器值是否与镜像值一致
        //   UVM_CHECK: 比对模式——发现不一致时报 UVM_ERROR
        reg_model.ctrl.mirror(status, UVM_CHECK, UVM_FRONTDOOR);
    endtask
endclass
```

### 后门访问与前门访问

前门访问和后门访问是 UVM RAL 提供的两种寄存器访问路径，分别对应不同的硬件访问机制和验证需求。

| 维度 | 前门访问（Frontdoor） | 后门访问（Backdoor） |
|:---|:---|:---|
| **访问路径** | 通过总线协议（AXI/APB/I2C 等）→ Bus Sequencer → Bus Driver → DUT 引脚 | 通过 HDL 层次路径（`dut.u_core.ctrl_reg`）直接读写 |
| **仿真时间** | 消耗仿真时间（总线协议时序 + wait cycles） | **零仿真时间**（`$peek`/`$poke` 类 PLI 调用） |
| **协议检查** | 通过——验证了总线接口的协议正确性 | **绕过**——不验证总线接口行为 |
| **硬件行为** | 模拟真实硬件访问（芯片上电后的寄存器操作） | 模拟硬件内部的调试/测试访问（如 JTAG 调试器） |
| **适用阶段** | 正常功能验证、协议验证、集成测试 | 快速配置（初始化大量寄存器）、错误注入、调试读写 |
| **性能** | 慢（每笔操作都经历完整的总线时序） | 快（省去了所有总线协议开销） |
| **SystemVerilog 实现** | `reg_model.reg.write(status, data, UVM_FRONTDOOR)` | `reg_model.reg.write(status, data, UVM_BACKDOOR)` |

```systemverilog
// ===== 前门 vs 后门的 RAL 配置与使用 =====

// ── 步骤 1：为寄存器添加 HDL 路径映射（后门访问的前提）──
class ctrl_reg extends uvm_reg;
    `uvm_object_utils(ctrl_reg)

    function void build();
        // ... 位域定义 ...
        // add_hdl_path_slice(name, offset, size, first=0):
        //   "ctrl_reg": HDL 中的信号/寄存器名
        //   -1: 自动计算偏移（等价于 0 偏移）
        //   32: 寄存器宽度是 32-bit
        //   此方法在仿真中通过 PLI/VPI 接口直接读/写此 HDL 信号
        add_hdl_path_slice("ctrl_reg", -1, 32);
        //  等效完整路径（在 reg_block 中设置 hdl_path 前缀后）：
        //  "tb_top.dut.u_core.ctrl_reg"
    endfunction
endclass

// ── 步骤 2：在 reg_block 中设置 HDL 路径根前缀 ──
class my_reg_block extends uvm_reg_block;
    function void build();
        // ... 创建 map 和寄存器 ...
        // configure(this, hdl_root_path):
        //   设置 HDL 访问的层次路径前缀
        //   此后所有 add_hdl_path_slice 的路径自动拼接此前缀
        configure(this, "tb_top.dut.u_core");
    endfunction
endclass

// ── 步骤 3：在 Sequence 中使用前后门访问 ──
class dual_access_sequence extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(dual_access_sequence)

    task body();
        uvm_status_e status;
        uvm_reg_data_t data;

        // --- 后门访问：快速批量配置 ---
        // 典型场景：芯片启动时需要写 500+ 个寄存器，
        // 如果用前门每个寄存器消耗 10+ 个总线周期 → 仿真极慢
        // 后门访问零仿真时间批量写入，然后切换到前门验证总线接口
        reg_model.ctrl.write(status, 32'h0000_0001, UVM_BACKDOOR);
        //  路径："tb_top.dut.u_core.ctrl_reg" → 直接 poke 值

        // --- 前门访问：验证总线协议 ---
        // 后门写完期望值后，用前门读验证总线接口能正确读回
        reg_model.ctrl.read(status, data, UVM_FRONTDOOR);
        if (data != 32'h0000_0001)
            `uvm_error("RAL", "Frontdoor read mismatch after backdoor write")

        // peek(): 后门读——直接读取 HDL 信号值（零仿真时间）
        reg_model.ctrl.peek(status, data);
        // poke(): 后门写——直接驱动 HDL 信号值（零仿真时间）
        reg_model.ctrl.poke(status, 32'hFFFF_FFFF);
    endtask
endclass
```

**工业实践中的典型用法：**

| 场景 | 使用方式 | 原因 |
|:---|:---|:---|
| 芯片上电配置序列 | **后门写** 初始化 + **前门读** 验证 | 后门写快速跳过配置阶段，前门读确保总线接口正确 |
| 错误注入验证 | **后门写** 注入寄存器位错误 → 前门操作验证检测机制 | 不经过总线操作即可模拟硬件故障 |
| 寄存器复位值检查 | **后门读**（peek）检查复位后的初始值 | 不需要启动总线即可验证芯片上电默认状态 |
| 覆盖率驱动测试 | **前门** 为主 | 前门访问计入总线覆盖率，后门访问不产生协议覆盖率 |

### UVM Callback 机制

Callback（回调）机制是 UVM 提供的一种**非侵入式扩展**方式——在不修改原始组件代码的前提下，在组件的关键执行点注入自定义行为。

**Callback 与 Factory Override 的区别：**

| 机制 | 作用方式 | 修改范围 | 使用场景 |
|:---|:---|:---|:---|
| **Factory Override** | **替换**整个组件的类型 | 整个组件——Driver/Monitor/Scoreboard 全部替换 | 需要完全不同的组件行为（如从 UART Driver 切换到 SPI Driver） |
| **Callback** | **附加**行为到组件的关键执行点 | 仅在回调注册点注入——原始组件的其余行为保持不变 | 在标准化行为之上增加额外操作（如加打印、加错误注入、加覆盖率采样） |

**典型使用场景：**
1. **错误注入**：在 Driver 的 `item_done()` 前注册回调，以特定概率翻转事务中的数据位
2. **性能计数**：在 Monitor 的 `write()` 后注册回调，统计特定类型事务的数量或延迟
3. **调试日志**：在不修改环境代码的情况下，在关键执行点插入详细打印
4. **动态配置调整**：根据仿真运行状态动态调整测试参数

```systemverilog
// ===== Callback 机制的完整实现：错误注入示例 =====

// ── 步骤 1：定义 Callback 基类 ──
// `uvm_register_cb: 将回调类注册到 UVM 回调管理系统中
//   my_driver: 此回调关联的目标组件类型
//   my_driver_cb: 回调类名
//   效果：my_driver（或其子类）的实例可以注册此类型的回调
class my_driver_cb extends uvm_callback;
    `uvm_register_cb(my_driver, my_driver_cb)  // 注册回调：绑定到 my_driver 组件

    function new(string name = "my_driver_cb");
        super.new(name);
    endfunction

    // 虚回调函数：在事务发送前调用——子类覆盖此方法注入自定义行为
    //   driver: 触发回调的 Driver 实例引用（允许回调访问 Driver 的成员）
    //   item: 即将被驱动的事务对象（可以通过引用修改其字段）
    virtual function void pre_drive(my_driver driver, my_item item);
        // 默认空实现：子类覆盖时注入具体行为
    endfunction

    // 虚回调函数：在事务驱动后调用
    virtual function void post_drive(my_driver driver, my_item item);
    endfunction
endclass

// ── 步骤 2：在目标组件（Driver）的关键执行点调用回调 ──
class my_driver extends uvm_driver #(my_item);
    `uvm_component_utils(my_driver)
    // `uvm_register_cb 宏在 my_driver_cb 类中自动生成了：
    //   - my_driver_cb::add(my_driver_inst, callback_inst) 静方法：注册回调实例
    //   - my_driver::do_pre_drive(item) → 遍历注册的回调，调用每个 cb.pre_drive()

    task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(req);

            // `uvm_do_callbacks: 宏——遍历该 Driver 上注册的所有回调实例，
            //   对每个实例调用指定的回调函数
            //   my_driver: 目标组件类型
            //   my_driver_cb: 回调类类型
            //   pre_drive(this, req): 调用的回调函数名及参数
            `uvm_do_callbacks(my_driver, my_driver_cb, pre_drive(this, req))

            drive_transfer(req);           // 原始的驱动行为（没有改动）

            `uvm_do_callbacks(my_driver, my_driver_cb, post_drive(this, req))

            seq_item_port.item_done();
        end
    endtask
endclass

// ── 步骤 3：定义具体的回调实现（错误注入）──
class error_injection_cb extends my_driver_cb;
    `uvm_object_utils(error_injection_cb)  // callback 是 object，用 object 宏注册

    function new(string name = "error_injection_cb");
        super.new(name);
    endfunction

    // 覆盖父类的虚回调函数：在事务驱动前以 5% 概率翻转数据最低位
    function void pre_drive(my_driver driver, my_item item);
        if ($urandom_range(0, 99) < 5)    // 5% 概率
            item.data[0] = ~item.data[0];  // 位翻转注入错误
    endfunction
endclass

// ── 步骤 4：在 Testcase 中注册回调 ──
class my_error_test extends uvm_test;
    `uvm_component_utils(my_error_test)

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        error_injection_cb err_cb = error_injection_cb::type_id::create("err_cb");

        // my_driver_cb::add(driver_instance, callback_instance):
        //   将回调实例注册到指定的 Driver 实例上
        //   之后每次 Driver 执行 `uvm_do_callbacks 时，此回调都会被调用
        //   关键：不需要修改 my_driver 的任何一行代码
        my_driver_cb::add(env.agent.driver, err_cb);
    endfunction
endclass
```

**Callback 机制的工程价值：**

在大型 SoC 验证项目中，UVM Agent 通常以 VIP（Verification IP）的形式由第三方提供。Callback 机制使得项目验证工程师可以在**不修改 VIP 源码**的前提下注入定制行为——这对于 IP License 合规和 VIP 升级兼容性至关重要。

## 关键要点

- **OVM 继承与标准化演进**：UVM 继承自 OVM（Open Verification Methodology），吸收了 VMM 和 eRM 的经验教训，于 2011 年由 Accellera 发布 1.0 版本，当前工业界主流为 UVM 1.2
- **工厂机制 `create()` 替代 `new()`**：工厂机制通过类型注册和 `create()` 替代 `new()` 的构造方式，使得在 `build_phase` 中创建的每一个组件都可以被外部 override，这是验证 IP 重用的关键技术
- **config_db 通配符谨慎使用**：config_db 的路径匹配支持正则通配符：`set("*", "key", val)` 可被所有组件的 `get()` 匹配到，但生产代码中应谨慎使用通配以避免隐蔽的耦合
- **Phase objection 是最易误用的特性**：Phase objection 机制是 UVM 最容易被误解和误用的特性：若 Sequencer 或 Driver 中遗漏 `drop_objection`，仿真会永远挂起在 `run_phase`；若过早 drop，仿真可能在 Scoreboard 完成检查前结束
- **TLM FIFO 广播语义实现时序解耦检查**：TLM FIFO 与 analysis port 的广播语义使得 Scoreboard 的"独立于时序的检查"成为可能：Monitor 不需要知道哪些 Scoreboard 在监听，Scoreboard 也不需要关心数据何时到达
- **Register Adapter 是 RAL 前门访问的关键**：Register Adapter（`uvm_reg_adapter`）是 RAL 前门访问的关键，它将 `uvm_reg_bus_op` 抽象操作转换为具体的总线 Sequence Item，是实现 RAL 协议无关性的适配层
- **Factory/config_db 性能开销不可忽视**：UVM 框架的性能开销不可忽视：factory 查找和 config_db 遍历在大型 SoC 验证环境中可能贡献 5-15% 的仿真时间，适度使用直接赋值可优化性能
- **Report 机制分级日志与 verbosity 控制**：UVM 并不规定 Report 机制的具体实现，但 `uvm_info`、`uvm_warning`、`uvm_error`、`uvm_fatal` 宏提供了分级日志，结合 verbosity 控制（`UVM_LOW` 到 `UVM_DEBUG`）实现运行时可调的日志详细度
- **Sequence 三层分层设计复用激励**：Sequence 分层设计（API Layer → Functional Layer → Scenario Layer）是 UVM 推荐的激励复用策略——底层 API Sequence 封装单次总线操作，中层组合成功能单元，顶层定义完整测试场景
- **`grab_lock` 独占 Sequencer 访问权**：`grab_lock` 和 `ungrab_lock` 机制实现对 Sequencer 的独占访问——当某个 Sequence 需要在无干扰的情况下完成一组原子操作（如配置-启动-等待完成）时可调用 `grab()` 阻止其他 Sequence 插入事务
- **`set_max_quit_count()` 控制 fail-fast 行为**：UVM 的 `set_max_quit_count()` 是控制仿真"fail fast"行为的关键——设为 5-10 可在回归测试中发现首个致命错误后快速终止当前测试，节省仿真机时
- **`resource_db` 与 `config_db` 互补**：UVM 1.2 中 `uvm_resource_db` 是对 `uvm_config_db` 的补充——前者提供全局平面化的键值存储（无层次约束），后者提供层次化作用域查找（沿组件树向上追溯），set() 内部同时写入两者
- **初始化顺序决定环境正确性**：UVM 环境的正确初始化顺序至关重要——通常为：`run_test()` → Build Phase（自顶向下 create 组件 + config_db get）→ Connect Phase（自底向上连接 TLM port/export）→ End of Elaboration（最终配置调整）→ Start of Simulation → Run Phase（并行执行 run_phase 和各 sub-phase）→ Cleanup Phase
- **Register Adapter 适配层协议无关转换**：Register Adapter（`uvm_reg_adapter`）是实现 RAL 协议无关性的关键适配层——它将 `uvm_reg_bus_op` 的抽象寄存器操作（读/写、地址、数据）转换/反向转换为具体总线协议的 Sequence Item（如 AXI-Lite、APB、I2C），一个适配器服务于一种总线协议
- **Callback 机制非侵入式扩展组件**：UVM 的 Callback 机制支持非侵入式扩展——用户通过 `` `uvm_register_cb`` 注册回调类，在 Driver/Monitor 的关键执行点注入错误或附加检查而不修改组件代码
- **`uvm_heartbeat` 看门狗检测组件卡死**：`uvm_heartbeat` 组件提供看门狗功能——配置为检查特定 uvm_component 是否在指定时间窗口内被"心跳触发"，超时则报 `UVM_FATAL`，适用于检测 Driver 或 Sequencer 卡死的场景
- **事件回调降低轮询 CPU 开销**：UVM 1.2 引入的 `uvm_event_callback` 允许在事件触发时注册回调——与纯 `uvm_event` 的 `wait_trigger()` 相比，callback 方式不需要轮询等待，降低 CPU 开销
- **Factory Override 支持实例级细粒度替换**：Factory Override 可以细粒度到实例级别——`set_inst_override_by_type()` 允许替换特定路径下的某个组件实例而不是该类型的所有实例，这使得在同一个 Testbench 中可以为不同 Agent 使用不同的子类变体
- **Base Test 注册 + 自动实例化扩展模式**：工厂 Override 的典型 SystemVerilog 模式：先在 Base Test 的 `build_phase()` 中调用 `set_type_override_by_type(base_type::get_type(), ext_type::get_type())`，然后在 `build_phase()` 中所有组件的 `create()` 调用自动实例化扩展类型——用户无需修改 Environment 或 Agent 代码即可替换任意组件的实现

## 与其他概念的关系

- [[verification/concepts/验证平台架构|验证平台架构（Testbench Architecture）]] — UVM 规定了验证平台的层次化结构（Env → Agent → Driver/Monitor/Sequencer），Agent 是 UVM 架构的基本构建单元，封装了 Sequencer+Driver+Monitor 三件套，testbench-architecture 文件详细描述了这一分层设计到实现的完整映射
- [[verification/concepts/约束随机验证|约束随机验证（Constrained-Random Verification）]] — UVM Sequence 的 `rand` 字段和 `constraint` 块是覆盖率驱动验证（CDV）的随机激励生成基础；Sequence 的 `pre_randomize()`/`post_randomize()` 回调允许在随机化前后插入确定性逻辑以处理约束间的依赖关系
- [[verification/concepts/SVA断言|SystemVerilog 断言（SVA）]] — UVM 环境中通常在 Virtual Interface 内嵌入 SVA 属性进行协议合规性检查，同时在 Scoreboard 中使用 SVA 的 `expect` 语句验证特定时序场景的预期行为
- [[verification/concepts/覆盖率模型|覆盖率模型（Coverage Model）]] — UVM 环境通过 Covergroup（在 Monitor/Scoreboard 中采样事务和信号）和 RAL Coverage（寄存器域覆盖率）收集功能覆盖率，覆盖率的采样时机通常在 Monitor 的 `write()` 方法中以确保每笔事务都被计数
- [[verification/concepts/形式验证|形式验证（Formal Verification）]] — UVM 的仿真驱动验证与形式验证在工业实践中互补：UVM 适合数据路径和复杂场景的功能验证，形式验证适合控制路径、死锁检测和接口协议合规性检查，两者共用 SVA 属性描述语言


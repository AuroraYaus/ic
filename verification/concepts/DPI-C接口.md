---
type: concept
aliases:
  - DPI-C Interface_DPI-C接口
  - SystemVerilog DPI
tags:
  - asic
  - verification
  - c
  - dpi
source_spec: "IEEE 1800-2017 SystemVerilog LRM 第 35 章（DPI）；UVM Cookbook（DPI 章节）；VCS/Questa 用户手册编译链接章节"
queries: 1
---
# DPI-C接口

DPI-C（Direct Programming Interface, C 语言直连接口）是 SystemVerilog 标准（IEEE 1800）定义的双向接口——让 SystemVerilog 直接调用 C 函数（import），也让 C 回调 SystemVerilog 的 task/function（export）。它在验证中的核心价值是**模型复用**：算法 IP（编解码器、滤波器、DSP 链路）的黄金模型通常先用 C 开发验证（C 速度快、生态全），经 DPI-C 原样挂进 UVM 验证平台作参考模型，避免用 SystemVerilog 重写一遍引入二次实现偏差——这正是参考模型"独立实现"原则的最佳实践（见 [[verification/concepts/验证平台架构|验证平台架构]]）。SystemVerilog 与 C 的联合仿真分为 DPI-C（直连、同进程）与 PLI/VPI（基于事件回调的旧式接口）——DPI-C 是两者的现代替代，开销更低、语义更清晰。

## 原理

### import 与 export：双向通道

**import**（SystemVerilog 调用 C）：在 SystemVerilog 中声明 `import "DPI-C" function`，告诉仿真器该函数在 C 侧实现——调用时参数按 DPI 类型映射规则转换后传入。**export**（C 回调 SystemVerilog）：在 SystemVerilog 中声明 `export "DPI-C" task`，C 侧经 `svSetScope` 设定作用域后即可调用——用于 C 模型把事件（中断、完成、错误注入）抛回验证平台。

```systemverilog
// 验证平台侧：import 声明 C 参考模型 + export 暴露回调（SystemVerilog，逐行说明）
import "DPI-C" function int c_ref_model(input int data_in); // import：声明 C 函数 c_ref_model
    // "DPI-C" 固定字面量：声明使用 IEEE 1800 标准的 DPI-C 接口（而非旧式 PLI）
    // function 返回 int：按 DPI 映射规则对应 C 侧 int——返回值与参数方向见下文类型表
export "DPI-C" task sv_report_event; // export：把 sv_report_event 任务暴露给 C 侧回调
    // C 侧先 svSetScope 指向本模块实例，再按普通 C 函数调用 sv_report_event

// 参考模型比对逻辑：DUT 输出 vs C 模型输出（仅仿真代码）
task automatic run_check(input int dut_out); // automatic：允许并发调用，task 内局部变量独立
    int ref_out;                             // C 模型返回值暂存
    ref_out = c_ref_model(dut_out);          // 调用 C 函数：参数按 DPI 类型映射传给 C
    if (ref_out !== dut_out)                 // 全等比较：!== 对 X/Z 也敏感——参考比对必须用全等
        $error("DUT 输出 %0d 与 C 模型 %0d 不一致", dut_out, ref_out); // $error 报错不终止仿真
endtask
```

**import 语义细节**：（1）`import "DPI-C" function` 是纯函数声明——C 函数不得有副作用不得阻塞（不允许在 C 里调用耗时的系统调用）；（2）`import "DPI-C" task` 允许 C 侧阻塞与消耗仿真时间——对应 C 侧返回前可以调用 export task；（3）import 的参数按值传递、默认 input 方向——指针参数用 `chandle` 或 `output` 类型传递句柄。

### 数据类型映射：两套类型系统的翻译表

DPI-C 的核心是 SystemVerilog 与 C 数据类型的映射——跨语言调用时参数按此表自动转换：

| SystemVerilog | C（DPI 侧） | 说明 |
|:---|:---|:---|
| `byte` / `int` / `longint` | `char` / `int` / `long long` | 有符号整型直映射 |
| `bit [31:0]` | `unsigned int` | 位向量映射为无符号整型 |
| `real` / `shortreal` | `double` / `float` | 浮点直映射 |
| `chandle` | `void *` | 不透明指针：SV 侧不解释内容，只做句柄传递 |
| `string` | `const char *` | C 侧只读——修改需经 `output string` 或专用 API |
| 多维数组/open array | `svOpenArrayHandle` | 可变长数组需用 DPI 数组查询 API（`svSize` 等） |

两个高频坑：**（1）四态（logic）与二态（bit）**——`logic` 型参数映射到 C 后 X/Z 会丢失（转成 0/1 的具体值），参考模型比对前要确认 DUT 侧的四态语义是否需要单独处理（通常用 `bit` 声明模型参数，X 传播由 SV 侧检查）；**（2）返回值的符号**——`int` 有符号、`bit [31:0]` 无符号，跨语言符号不一致会让负数的比对全部失败（模型算 -1 而 DUT 侧当作 0xFFFFFFFF）。

### 上下文传递：context 属性与作用域

C 函数默认不知道"谁调用了它"——要回调 export task 或访问模块层次，必须先建立上下文：

```systemverilog
// 上下文敏感 import：C 侧可回调本模块的 export task（SystemVerilog，逐行说明）
import "DPI-C" context function int c_bfm_task(input int cmd); // context 属性：
    // 声明 C 函数需要仿真上下文——允许调用 svSetScope/svGetScope 与 export 回调
    // 代价：调用开销比纯函数高（保存/恢复上下文）——不需要上下文的函数不要加 context
```

```c
/* C 侧：设定作用域后回调 SystemVerilog 的 export task（C 代码，逐行说明） */
#include "svdpi.h"                          // DPI 标准头文件：声明 svSetScope 等上下文 API
extern void sv_report_event(int event_id);  // 引用 SV 侧 export 的 task——编译时由仿真器提供符号

void c_bfm_task(int cmd)                    // 与 SV 侧 import 声明同名的 C 函数
{
    svScope scope = svSetScope(svGetScopeFromName("tb_top.u_dut_monitor")); 
    // svGetScopeFromName：按层次路径字符串查作用域句柄——路径必须与 SV 模块实例层次一致
    // svSetScope：把当前线程的 DPI 作用域切换到目标实例——之后 export 回调才找得到对象
    /* …… 模型计算、驱动逻辑 …… */
    sv_report_event(cmd);                   // 回调 SV 侧 export task——事件抛回验证平台
    svSetScope(scope);                      // 恢复原作用域——避免影响其他线程的后续回调
}
```

**context 属性的代价**：加了 `context` 的 import 函数每次调用都要保存/恢复仿真上下文（线程安全相关），纯计算型函数（参考模型主体）不加 `context` 更快——工程惯例：参考模型计算用纯函数、需要回调的部分单独包一层 context 函数。

### 编译与链接：把 C 代码接进仿真器

DPI 的 C 代码以共享库（Shared Object）形式在仿真启动时加载——三种仿真器的主流流程：

```shell
# GCC 编译 C 参考模型为共享库（shell 命令，逐行说明）
gcc -shared -fPIC -I${VCS_HOME}/include ref_model.c -o ref_model.so
# -shared     生成共享库而非可执行文件——供仿真器运行时动态加载
# -fPIC       位置无关代码：共享库被加载到任意地址的前提
# -I${VCS_HOME}/include  包含仿真器安装目录：svdpi.h 头文件在仿真器安装路径下

# VCS 加载共享库（三步：编译时登记 + 运行时可再补）
#   vcs -full64 tb.sv ref_model.c        —— C 源文件可直接参与编译（自动 gcc 编译）
#   vcs ... -LDFLAGS "-Wl,-rpath,."      —— 链接选项：运行时在当前目录搜索 .so
#   ./simv -sv_lib ref_model             —— 运行时加载：-sv_lib 不带扩展名，自动补 .so
# Questa 等价物：vsim -sv_lib ref_model  —— 同样不带扩展名
```

链接失败的常见原因：共享库不在运行时搜索路径（`-rpath` 或 `LD_LIBRARY_PATH`）、头文件版本与仿真器不匹配（svdpi.h 必须来自同一仿真器版本）、C 函数名与 import 声明不一致（C++ 编译需 `extern "C"` 防名字修饰 Name Mangling）。

### 与 UVM 平台的集成模式

DPI-C 在 UVM 验证平台中的典型集成位置是 Scoreboard 的参考模型层：`uvm_scoreboard` 组件内调用 import 的 C 函数做黄金比对（见 [[verification/concepts/UVM方法学|UVM方法学]] 的 Scoreboard 职责）。C 模型需要访问平台配置或回抛事件时，经 context import + export 回调实现——UVM 侧把回调 task 封装在 monitor/scoreboard 中。CRDB/加速验证场景中 C 模型与加速模型的衔接见 [[verification/concepts/仿真加速与CRDB|仿真加速与 CRDB]]。

## 关键要点

- **DPI-C 的价值是模型复用而非性能**：C 黄金模型原样挂入平台，避免 SV 重写引入二次偏差——参考模型独立实现的工程落点
- **import function 必须无副作用无阻塞**：需要回调或耗时操作用 import task / context function——语义边界在声明时定死
- **类型映射表是翻译规则**：`int` 有符号、`bit [31:0]` 无符号、`chandle` 对 `void *`、open array 要 DPI 查询 API
- **四态语义跨语言丢失**：`logic` 的 X/Z 在 C 侧退化为 0/1——X 检查放 SV 侧、C 侧只管二态计算
- **context 属性有开销**：纯计算函数不加 context，需要回调的单独包一层——性能与功能的边界
- **编译三件套**：`-shared -fPIC` 编译 + `-sv_lib` 加载 + 运行时搜索路径（`-rpath`）——链接失败先查这三处
- **C++ 代码必须 `extern "C"`**：防止名字修饰导致仿真器找不到符号
- **export 回调前先 svSetScope**：作用域不设，回调找不到目标实例——线程并发时注意恢复原作用域

## 与其他概念的关系

- [[verification/concepts/UVM方法学|UVM方法学]] — Scoreboard 的黄金比对经 DPI 调用 C 参考模型：UVM 组件内的 import 集成模式
- [[verification/concepts/验证平台架构|验证平台架构]] — 参考模型（Reference Model）独立实现原则的工程手段：C/SV 双实现降低同源错误
- [[tools/concepts/C语言在数字IC中的应用|C语言在数字IC中的应用]] — C 侧的前置知识：位运算、指针、volatile——DPI 函数体的编写基础
- [[verification/concepts/仿真加速与CRDB|仿真加速与 CRDB（Siloti）]] — 加速验证中 C 模型与加速模型的衔接：DPI 是 RTL 转 C 加速的上游桥梁

---
type: concept
aliases: [Makefile 依赖与自动生成, include -include auto-dependency .d]
tags: [tools, makefile, asic]
source_spec: "GNU Make Manual 3.3, 4.14; GCC -M -MM -MF -MT -MP -MD options"
queries: 1
---

# 14 — Makefile依赖与自动生成

## 学习目标

手写头文件依赖是 C/C++ 项目中最易出错的环节——"改了 .h 但忘了重编"是最隐蔽的增量构建 bug。本篇覆盖 include 指令和自动依赖的完整方案。读完本篇，你应能：

1. 理解 include / -include 的完整行为——不仅是嵌入文件
2. 掌握 .d 自动依赖三步法：编译器生成 → Makefile include → 规则重建
3. 区分 -M/-MM/-MF/-MT/-MP/-MD/-MMD 七个选项
4. 理解依赖文件 remake 机制和 MAKE_RESTARTS 变量

## 前置知识

- [[tools/concepts/12-Makefile模式规则|12 — 模式规则]]
- [[tools/concepts/02-Makefile心智模型与历史|02 — 心智模型]]

## include 指令

include 在读阶段嵌入其他 Makefile 内容，等同于复制粘贴。处理顺序：

1. Make 读到 include 行 → 暂停当前文件
2. 尝试读入目标文件
3. 文件不存在 → 检查是否有规则可以生成它
   - 有规则：构建文件 → 重启 make (remake) → 重新读入
   - 无规则且非 -include：报错退出
   - 无规则但是 -include（= sinclude）：忽略继续

```makefile
include config.mk                      # 必须存在，否则报错
-include $(DEPS)                       # 标准自动依赖入口：不存在也无妨
```

## 自动依赖三步法

```
步骤 1：编译器生成 .d 文件——记录 .o 依赖哪些 .c/.h
步骤 2：-include 将所有 .d 嵌入 Makefile
步骤 3：.d 与 .o 一起由模式规则生成
```

```makefile
SRCS := $(wildcard *.c)               # main.c util.c
OBJS := $(SRCS:.c=.o)                 # main.o util.o
DEPS := $(SRCS:.c=.d)                 # main.d util.d

program: $(OBJS)
	$(CC) $^ -o $@

-include $(DEPS)                       # 首次构建 .d 不存在→静默跳过

%.o: %.c
	$(CC) -MM -MF $(@:.o=.d) -MT $@ $(CFLAGS) -c $< -o $@
```

各选项含义：
- `-MM`：仅用户头文件——不含 `<stdio.h>` 等系统头文件
- `-MF <file>`：.d 输出到指定文件
- `-MT <target>`：自定义依赖行中的目标名

**首次构建流程：**

1. make 读 Makefile → `-include $(DEPS)` 静默跳过（.d 不存在）
2. 目标更新阶段 → `%.o: %.c` 执行
3. 编译器同时生成 main.o 和 main.d，后者内容如 `main.o: main.c config.h utils.h`
4. **下一次** make → include 读入所有 .d → 此后改 config.h 触发 main.o 重建

## 编译器依赖选项全解

| 选项 | 含义 | 推荐 |
|:---|:---|:---|
| `-M` | 所有 #include（含系统头文件） | 否——列表过长 |
| `-MM` | 仅用户头文件 | **是** |
| `-MF <f>` | 输出到文件 f | 核心 |
| `-MT <t>` | 自定义目标名 | `-MT $@` |
| `-MP` | 每个头文件生成空规则 | **是**——防删除报错 |
| `-MD` | -M + 自动输出 .d | 否——含系统头 |
| `-MMD` | -MM + 自动输出 .d | **最佳** |

```makefile
# 最推荐的一步写法：
%.o: %.c
	$(CC) -MMD -MP -MF $(@:.o=.d) -MT $@ $(CFLAGS) -c $< -o $@
```

- `-MMD`：-MM 模式 + 自动输出 .d（一步到位）
- `-MP`：为每个头文件生成空规则——头文件被删除后 Make 不会报错（零代价保护）

## 工程场景：多目录项目

```makefile
SRCS := $(wildcard src/*.c)
OBJS := $(patsubst src/%.c,build/obj/%.o,$(SRCS))
DEPS := $(OBJS:.o=.d)

program: $(OBJS)
	$(CC) $^ -o $@

-include $(DEPS)

build/obj/%.o: src/%.c
	@mkdir -p $(@D)
	$(CC) -MMD -MP -MF $(@:.o=.d) -MT $@ $(CFLAGS) -c $< -o $@

.PHONY: clean
clean:
	rm -rf build/
```

## remake 机制

当 include 的 .d 文件本身有规则可以更新它时：Make 先构建 .d → 重启自己 → 重新读入更新的 .d。`$(MAKE_RESTARTS)` 记录重启次数（正常=0，remake>0）。

```makefile
ifneq ($(MAKE_RESTARTS),0)
$(warning Make was restarted $(MAKE_RESTARTS) times)
endif
```

## 关键要点

1. **include 在读阶段处理——所有依赖信息建立后才做目标更新。**
2. **-include 文件缺失不报错——自动依赖的标准入口。**
3. **三步法 = .d 生成 + -include + 模式规则——缺一不可。**
4. **推荐 -MMD -MP 一步生成 .o + .d——最简洁。**
5. **.d 被修改时触发 remake——Make 自动重启刷新依赖图。**
6. **-MP 防止删除头文件后 Make 报错——零代价。**

## 与其他概念的关系

- [[tools/concepts/12-Makefile模式规则|12 — 模式规则]]
- [[tools/concepts/15-Makefile高级依赖|15 — 高级依赖]]
- [[tools/concepts/19-Makefile调试与性能|19 — 调试与性能]]

## 小练习

1. 手写 `main.o: main.c config.h` vs .d 自动方案——对比修改 .h 后的行为
2. `-MM` vs `-M`——对比生成文件大小
3. 有/无 `-MP`——删除头文件后分别测试
4. 删除 .d 后 `make --debug` 观察 remake 过程

---
type: concept
aliases: [Makefile 常见错误50例, error catalog]
tags: [tools, makefile, asic]
source_spec: "GNU Make Manual; decades of collective Makefile debugging experience"
queries: 1
---

# 24 — Makefile常见错误50例

## 第一类：语法/格式错误（10例）

### 1. 配方用空格而非TAB

**错误示例：**
```makefile
hello:
    echo "hello"                       # 4 个空格——不是 TAB！
```

```shell
$ make
Makefile:2: *** missing separator.  Stop.
```

**修复：** 用真正 TAB 开头。`cat -A Makefile` 确认配方行以 `^I` 开头而非空格。

### 2. IDE 自动 TAB→空格

**错误示例：** VS Code / Vim 配置了 `expandtab`，打开 Makefile 编辑后所有 TAB 被替换为空格。

```shell
$ cat -A Makefile
hello:$
    echo "hello"$                      # 显示空格而非 ^I
```

**修复：** 对 `Makefile` 文件禁用 TAB→空格转换。Vim: `set noexpandtab`；VS Code: `"editor.insertSpaces": false`。

### 3. 条件指令缩进

**错误示例：**
```makefile
all:
    ifeq ($(DEBUG),1)                  # 缩进了！Make 把它当配方传给 Shell
    @echo "debug"
    endif
```

```shell
$ make
/bin/sh: line 1: ifeq: command not found
```

**修复：** `ifeq`/`else`/`endif` 必须顶格写，不能有任何前导空格或 TAB。

### 4. 续行符 `\` 后有空格

**错误示例：**
```makefile
all:
	@echo "this is a long" \          # \ 后面有一个不可见的空格字符
		"message"
```

```shell
$ make
/bin/sh: line 1:  \: command not found
```

**修复：** `\` 必须是该行最后一个字符。`cat -A` 确认 `\$` 后直接是换行——没有空格。

### 5. 变量引用漏括号

**错误示例：**
```makefile
CC = gcc
all:
	echo $CC                           # Make 先展开 $C → 空，C → 字面 "C"
#       输出："C"（不是 "gcc"！）
```

```shell
$ make
echo C
C
```

**修复：** 始终用 `$(CC)` 而非 `$CC`——只有单字符自动变量 `$@`、`$<`、`$^` 等可以不带括号。

### 6. 变量名与操作符间有空格

**错误示例：**
```makefile
CC := gcc                              # 正确
CFLAGS := -Wall                        # 正确
LDFLAGS = -lm                          # 正确——= 前后可有空格
VAR = value                            # 正确——这是 VAR = value
VAR := value                           # 正确
VAR ?= value                           # 正确
# 但写成这样就有问题：
CC = gcc                               # OK
 CC = gcc                              # 不确定——Make 会认为变量名是空格开头
```

**修复：** 变量名紧接 `=`/`:=`/`?=`/`!=`/`+=`，不要在变量名和操作符之间插入多余空格。

### 7. define 块内配方 TAB 被编辑器吃掉

**错误示例：**
```makefile
define my_rule
target:                                # 这行正常
	@echo "hello"                      # TAB 被编辑器替换为空格！
endef
```

**修复：** 确保 define/endef 块内部的配方行 TAB 不被编辑器转换。在 `.editorconfig` 中对 Makefile 禁用 `insert_final_newline` 和 `indent_style = tab`。

### 8. 配方间的"空行"其实含不可见 TAB

**错误示例：**
```makefile
target: dep
	@echo "line one"                   # TAB + echo
	                                    # 这行看起来空，但实际有 TAB 字符
	@echo "line two"                   # Make 认为上面是空配方行
```

```shell
$ make
Makefile:3: *** missing separator.  Stop.
```

**修复：** 规则之间可以有空行，但配方行之间的空行必须完全为空（不能在 TAB 后）。

### 9. 文件末尾无换行

**错误示例：** Makefile 最后一行是 `clean:`，但后面没有换行符。

```shell
$ make
Makefile:10: *** missing 'endif'.  Stop.
# 或：最后一行规则被静默忽略
```

**修复：** 确保文件末尾至少有一个空行。大多数编辑器可配置自动添加。

### 10. `#` 注释出现在配方行中间

**错误示例：**
```makefile
all:
	gcc -Wall main.c -o main           # 编译主程序  ← Shell 看到 '# 编译主程序'
```

```shell
$ make
gcc -Wall main.c -o main              # Shell 不报错——# 在 Shell 中也是注释
# 但如果 # 出现在变量展开中：
	echo $(VAR) # comment              # 先由 Make 展开 $(VAR)，再传给 Shell
```

**修复：** 配方中不要用 `#` 注释。放在规则上方或配方行首。或用 Shell 的 `: 'comment'` 无操作方法。

## 第二类：变量展开陷阱（12例）

### 11. `=` 递归展开导致死循环

**错误示例：**
```makefile
FOO = $(BAR)
BAR = $(FOO)
all: ; @echo $(FOO)
```

```shell
$ make
Makefile:3: *** Recursive variable 'FOO' references itself (eventually).  Stop.
```

**修复：** 改用 `:=` 简单展开打破循环，或重新组织变量依赖关系。

### 12. `$(shell ...)` 用 `=` 导致重复执行

**错误示例：**
```makefile
SRCS = $(shell find . -name '*.c')     # 每次 $(SRCS) 都重新 find！
OBJS = $(SRCS:.c=.o)
all: $(OBJS)
# 如果 OBJS 有 20 个文件，find 被调用了 20+ 次
```

```shell
$ time make                           # 极慢——每次引用都扫描整个目录树
real 0m3.847s
```

**修复：**
```makefile
SRCS := $(shell find . -name '*.c')    # 读阶段执行一次，结果缓存
```

### 13. `+=` 在 `=` 变量上追加也延迟展开

**错误示例：**
```makefile
FLAGS  = -Wall
FLAGS += $(shell date +%s)            # date 在每次引用 FLAGS 时都执行！
```

```shell
$ make; sleep 2; make                 # 每次输出不同的时间戳
```

**修复：**
```makefile
FLAGS := -Wall
FLAGS += $(shell date +%s)            # 现在 date 只执行一次
```

### 14. `$@` 在变量定义中为空

**错误示例：**
```makefile
TARGET_NAME = $@                       # 期望：每次引用时展开为目标名
all: ; @echo $(TARGET_NAME)            # 输出：空字符串
```

```shell
$ make
                                       # 什么都没输出——$(TARGET_NAME) 为空
```

**修复：** 自动变量只能在配方中使用。在配方中直接写 `$@`，不要试图存到普通变量中。

### 15. 变量名拼写错误被静默展开为空

**错误示例：**
```makefile
CFLAGS := -Wall -O2
all: ; @echo $(CFLAG)                  # CFLAG ≠ CFLAGS——拼写错误
```

```shell
$ make
                                       # 空输出——Make 将未定义变量展开为空
```

**修复：** 始终使用 `make --warn-undefined-variables`，它会警告：
```shell
$ make --warn-undefined-variables
Makefile:2: warning: undefined variable 'CFLAG'
```

### 16. export 泄露不该传递的变量

**错误示例：**
```makefile
export                                 # 导出所有变量——包括临时/中间变量
TMP_FILE := /tmp/build_$$$$.tmp
# TMP_FILE 被传递到所有子 Make——可能覆盖子 Make 的同名变量
```

**修复：** 仅 export 需要跨子目录共享的关键变量：`export CC CFLAGS LDFLAGS`。

### 17. 命令行 `make VAR=val` 被 override 阻止

**错误示例：**
```makefile
override CC := gcc                     # override 阻止任何命令行覆盖
```

```shell
$ make CC=clang                        # 无效——CC 仍然是 gcc
```

**修复：** 只有确实需要阻止命令行覆盖的变量才用 `override`。大多数情况用 `?=` 即可。

### 18. 条件判断中引用尚未定义的变量

**错误示例：**
```makefile
ifeq ($(BUILD_TYPE),release)            # BUILD_TYPE 尚未定义——展开为空
CFLAGS := -O2
else
CFLAGS := -g                            # 永远走这个分支！
endif
```

```shell
$ make BUILD_TYPE=release              # 仍然用了 -g！
```

**修复：** 条件中涉及的变量必须在条件之前定义。或者用 `$(origin BUILD_TYPE)` 先检测。

### 19. `$(origin ...)` 返回值误读

**错误示例：**
```makefile
$(info origin CC = $(origin CC))        # 输出：origin CC = default
# 用户设了环境变量 CC=clang，期望 $(origin CC) = environment
```

```shell
$ CC=clang make
origin CC = default                     # 不是 environment！
# 因为 Makefile 中显式定义了 CC，所以 origin 是 file
# 只有用 make -e 时环境才会覆盖——此时 origin = environment override
```

### 20. `$(eval ...)` 内 `$$` 层数错误

**错误示例：**
```makefile
define RULE
$(1)_SRCS = $(wildcard $(1)/*.c)       # eval 执行前 $(wildcard ...) 先被展开——当前目录！
endef
$(eval $(call RULE,src))
# $(src_SRCS) 得到的是当前目录的 *.c——不是 src/ 的！
```

**修复：**
```makefile
define RULE
$(1)_SRCS := $$(wildcard $(1)/*.c)      # $$ → eval 读到 $(wildcard src/*.c)
endef
```

### 21. Target-specific 变量意外传播到所有前置条件

**错误示例：**
```makefile
debug.o: CFLAGS := -g -O0
debug.o: debug.c helper.c              # helper.o 构建时也用 -g -O0！
```

**修复：** 如果不需要传播，用 pattern-specific：`%.debug.o: CFLAGS := -g -O0`。

### 22. `$<` 只取第一个前置条件——不是全部

**错误示例：**
```makefile
program: main.o util.o io.o
	gcc $< -o $@                       # 错误：$< = main.o 只链接了第一个！
```

```shell
$ make
gcc main.o -o program                  # util.o 和 io.o 被忽略了——链接失败
```

**修复：**
```makefile
	gcc $^ -o $@                       # $^ = main.o util.o io.o（全部）
```

## 第三类：依赖/目标错误（10例）

### 23. 目标与目录同名

**错误示例：**
```makefile
build:                                 # 期望：make build 执行构建
	gcc main.c -o program
```

```shell
$ mkdir build                          # 目录作为构建产物存放处
$ make build
make: 'build' is up to date.           # 跳过！目录已存在
```

**修复：** 加 `.PHONY: build` 或改目标名（如 `build-program`）。

### 24. clean 目标被同名文件阻挡

**错误示例：**
```makefile
clean:
	rm -f *.o program                   # 忘记 .PHONY: clean
```

```shell
$ touch clean                          # 偶然创建了名为 clean 的文件
$ make clean
make: 'clean' is up to date.           # 不执行清理！
```

**修复：** `.PHONY: clean`——这是所有 Makefile 中最不该忘记的一行。

### 25. Order-Only 写成普通前置条件

**错误示例：**
```makefile
build/%.o: src/%.c build               # build 是普通前置条件
	$(CC) -c $< -o $@
```

```shell
$ mkdir build; make; touch build/other.txt; make
# build/ 目录的 mtime 改变了 → 所有 .o 重新编译！
```

**修复：**
```makefile
build/%.o: src/%.c | build             # build 在 | 右边 → order-only——只检查存在
```

### 26. 模式规则匹配了不该匹配的文件

**错误示例：**
```makefile
%.o: %.c                                # 太宽泛——所有 .o 都匹配
	$(CC) -c $< -o $@
# 问题：test_main.o 应该从 test_main.cpp 编译，不是 test_main.c！
```

**修复：** 用静态模式规则限定目标列表：`$(C_OBJS): %.o: %.c`。

### 27. 隐含规则悄悄编译了文件

**错误示例：**
```makefile
all: program                           # 没有定义 .c → .o 规则
```

```shell
$ make
cc -c main.c                           # GNU Make 内置的 %.o: %.c 悄悄运行了！
# 用了 cc 而非你期望的 gcc——cc 可能不存在或行为不同
```

**修复：** `make -r` 禁用隐含规则，或显式定义自己的 `%.o: %.c`。

### 28. VPATH 找到了错误的同名文件

**错误示例：**
```makefile
VPATH := lib:src
%.o: %.c; $(CC) -c $< -o $@
# 目录中有 lib/main.c 和 src/main.c——Make 按 VPATH 顺序取 lib/main.c
# 但你想编译的是 src/main.c！
```

**修复：** 用 `vpath` 精确控制，或避免依赖 VPATH 的搜索行为——显式指定完整路径。

### 29. 循环依赖

**错误示例：**
```makefile
a: b; @echo "build a"
b: a; @echo "build b"                  # b 依赖 a——形成环！
```

```shell
$ make a
make: Circular a <- b dependency dropped.
make: Circular b <- a dependency dropped.
```

**修复：** 重新设计依赖图。检查自动生成的 `.d` 文件是否包含了意外的循环。

### 30. 头文件不存在导致 Make 报错

**错误示例：**
```makefile
-include $(DEPS)                       # main.d 内容：main.o: config.h
```

```shell
$ rm config.h && make                  # 头文件被删除了
make: *** No rule to make target 'config.h', needed by 'main.o'.  Stop.
```

**修复：** 编译器加 `-MP` 选项——为每个头文件生成空规则，头文件被删除时不报错。

### 31. .d 文件和 .o 在同一个配方中生成——半途失败

**错误示例：**
```makefile
%.o: %.c
	$(CC) -MM -MF $(@:.o=.d) -MT $@ $(CFLAGS) $<   # 生成 .d（成功）
	$(CC) $(CFLAGS) -c $< -o $@                     # 编译 .o（失败！）
# 此时 .d 已生成但 .o 不存在——下次 make 认为 .o 已最新——bug！
```

**修复：** 两步法或用 Grouped Targets：`%.o %.d &: %.c`。

### 32. include 的 .d 文件 remake 后状态不一致

**错误示例：**
```makefile
-include $(DEPS)
%.d: %.c; $(CC) -MM -MF $@ -MT $(@:.d=.o) $<
# 如果 .d 文件缺失——Make 执行 %d 规则生成它 → 重启 → 重新 include
# 但如果 .d 生成过程中有错误——Make 可能进入 remake 循环
```

**修复：** 检查 `$(MAKE_RESTARTS)` 防止无限重启。

## 第四类：并行构建陷阱（8例）

### 33. 两个独立目标竞争写入同一临时文件

**错误示例：**
```makefile
%.o: %.c
	$(CC) -c $< -o /tmp/$$$$.o && mv /tmp/$$$$.o $@
# 并行模式下多个 %.o 同时运行——$$$$ 展开为相同 PID → 竞争 /tmp/同一文件
```

```shell
$ make -j4
mv: cannot stat '/tmp/12345.o': No such file or directory  # 被另一个进程先 mv 走了
```

**修复：** 每个目标用唯一临时文件名：`/tmp/$$$$-$@.o`。

### 34. mkdir -p 竞态条件

**错误示例：**
```makefile
build/%.o: src/%.c
	@mkdir -p build
	$(CC) -c $< -o $@
# 两个 %.o 同时 mkdir -p build → 竞态——通常无害（mkdir -p 对已存在的目录不报错）
# 但某些边缘情况下可能有问题
```

**修复：** 用 order-only 前置条件：`build/%.o: src/%.c | build`，`build:` 作为单独的目录创建目标。

### 35. 静态库并行构建时 ar 索引损坏

**错误示例：**
```makefile
lib.a: a.o b.o c.o
	$(AR) rcs $@ $^
# 但如果多个 ar 进程同时操作同一个 lib.a——索引可能损坏
```

**修复：** 并行时不允许多个目标操作同一个 `.a`。或在并行限制中对 `.a` 目标加 `.NOTPARALLEL`。

### 36. .NOTPARALLEL 错误地全局禁用并行

**错误示例：**
```makefile
.NOTPARALLEL:                          # 全局禁用——make -j 完全失效
```

```shell
$ make -j8                             # 仍然是串行执行！
```

**修复：** 仅对需要串行化的特定目标禁用：`.NOTPARALLEL: slow-target`。

### 37. 配方输出交错乱码

**错误示例：**
```makefile
%.o: %.c
	@printf 'compiling %s\n' $@
	$(CC) -c $< -o $@
	@printf 'done with %s\n' $@
```

```shell
$ make -j4
compiling main.ocompiling util.o
done with utils.o
done with main.o                       # 输出交错——不可读
```

**修复：** `make -j4 --output-sync=target`——每个目标的输出作为一个整体打印。

### 38. clean 与编译并行执行

**错误示例：**
```shell
$ make -j4 all clean                   # 同时构建和清理！
```

```console
$ make -j4 all clean
gcc -c main.c -o main.o
rm -f *.o                              # .o 被删了
gcc main.o -o program                  # 链接失败——main.o 不存在
```

**修复：** 不要同时运行 `all` 和 `clean`。在 CI 中先 `clean` 再 `all`。

### 39. `$(shell ...)` 在并行环境下的执行顺序不确定

**错误示例：**
```makefile
LOG_FILE := $(shell mktemp)            # 读阶段执行——安全
all:
	@echo $(shell date +%s) > $(LOG_FILE)  # 配方中每次 $(shell ...) 可能乱序
```

**修复：** 读阶段用 `:=` 缓存 `$(shell ...)` 结果。配方中用 Shell 命令而非 Make 的 `$(shell ...)`。

### 40. 子 Make 丢失并行度——硬编码 `make` 而非 `$(MAKE)`

**错误示例：**
```makefile
subdir:
	make -C subdir                     # 硬编码 make——丢失 jobserver 连接！
```

```shell
$ make -j8 subdir
make -C subdir                         # 子 Make 是串行的——只有一个 job！
```

**修复：**
```makefile
subdir:
	$(MAKE) -C subdir                  # $(MAKE) 传递 jobserver——子 Make 也能并行
```

## 第五类：跨平台/可移植性错误（5例）

### 41. `sed -i` 在 macOS 和 Linux 上行为不同

**错误示例：**
```makefile
all:
	sed -i 's/old/new/g' config.txt    # Linux OK；macOS 报错
```

```shell
$ make  # macOS
sed: -i may not be followed by other characters
```

**修复：**
```makefile
SED_INPLACE := $(if $(filter Darwin,$(shell uname -s)),sed -i '',sed -i)
all:
	$(SED_INPLACE) 's/old/new/g' config.txt
```

### 42. Windows 路径分隔符 vs Unix

**错误示例：**
```makefile
SRC_DIR := src\lib                     # Windows 风格——在 Linux 上被当普通字符
```

**修复：** 始终用 `/`。GNU Make 在 Windows 上会自动处理路径转换。

### 43. `echo -n` 行为不可移植

**错误示例：**
```makefile
all:
	echo -n "Processing..."            # Linux bash: 不换行；macOS dash: 输出 "-n Processing..."
```

**修复：** 始终用 `printf` 替代 `echo -n`：`printf 'Processing...'`。

### 44. `/bin/sh` 指向不同的 Shell

**错误示例：**
```makefile
# 配方使用了 bash 专有语法，但 /bin/sh 在 Ubuntu 上指向 dash
all:
	[[ -f config.h ]] && echo "found"  # dash 不支持 [[ ]]
```

```shell
$ make
/bin/sh: 1: [[: not found
```

**修复：** 使用 POSIX `[ ]` 替代 `[[ ]]`，或显式设置 `SHELL := /bin/bash`。

### 45. 文件名大小写在 macOS（不敏感）vs Linux（敏感）

**错误示例：**
```makefile
all: Main.c                             # 正确文件名是 main.c
```

```shell
$ make  # macOS——成功（大小写不敏感）
$ make  # Linux——失败——找不到 Main.c
make: *** No rule to make target 'Main.c'.  Stop.
```

**修复：** 统一小写文件名。用 `$(wildcard ...)` 验证实际文件名。

## 第六类：性能反模式（5例）

### 46. `$(shell find ...)` 用 `=` 导致每次引用都扫描

**错误示例：**
```makefile
SRCS = $(shell find . -name '*.c')     # 每次 $(SRCS) 都重新 find！
OBJS = $(SRCS:.c=.o)
# 如果 OBJS 被引用了 20 次，find 跑了 20+ 次
```

```shell
$ time make
real 0m4.231s                          # 极慢
$ time make                            # 第二次还是慢！
real 0m4.198s
```

**修复：**
```makefile
SRCS := $(shell find . -name '*.c')    # 读阶段一次，缓存
```

```shell
$ time make
real 0m0.847s                          # 快 5 倍
```

### 47. `$(eval ...)` 在配方内调用——每次配方执行都重新 eval

**错误示例：**
```makefile
all:
	$(eval TMP := $(shell date +%s))    # 每次 make 都运行 eval！
	@echo $(TMP)
```

**修复：** `$(eval ...)` 放在读阶段（规则外），不要放在配方中。

### 48. `-j` 设置过大导致 I/O 颠簸

**错误示例：**
```shell
$ make -j64                            # 64 核并行——但磁盘是机械硬盘
```

```console
$ iostat -x 1                          # I/O 等待 > 80%
```

**修复：** `make -j$(nproc) -l 6`——`-l` 限制系统负载，防止 I/O 颠簸。

### 49. 不必要的递归 Make 导致序列化瓶颈

**错误示例：**
```makefile
SUBDIRS := lib src test
$(SUBDIRS): ; $(MAKE) -C $@           # lib 先构建完 → 然后 src → 然后 test
# 即使 src 不依赖 lib，也必须等 lib 完成——序列化！
```

**修复：** 如果子目录确实独立，用 include 式构建消除伪依赖。

### 50. `$(wildcard ...)` 每次引用重新扫描

**错误示例：**
```makefile
FILES = $(wildcard src/*.c)            # 每次 $(FILES) 都重新扫描目录
```

**修复：**
```makefile
FILES := $(wildcard src/*.c)           # := 缓存扫描结果
```

## 关键要点

1. **TAB vs 空格** 是 #1 错误——编辑器配置是第一道防线
2. **`:=` vs `=`** 是 #2 错误——`$(shell ...)` 不用 `:=` 是性能灾难的主要来源
3. **`.PHONY` 忘记** 是 #3 错误——所有动作目标都该加
4. **`$$` 转义** 是 #4 错误——"想让 Shell 看到 `$X`→ 写 `$$X`"
5. **`make --warn-undefined-variables --trace -n`** 覆盖 80% 诊断需求
6. **Order-Only 目录**——`| dir/` 而非 `dir/`——并行构建安全的基石
7. **`$(MAKE)` 非 `make`**——递归 Make 的 jobserver 传递不可省略

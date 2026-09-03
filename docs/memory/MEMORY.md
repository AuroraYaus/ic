# ic 项目记忆索引

> **本目录为记忆文件的项目内权威副本**：随项目文件夹拷贝、在项目内演进——新增/修改记忆先改本目录（含本索引），再同步到会话加载镜像 `~/.claude/projects/-home-yys-AGENT-ic/memory/`，保证项目拷到任何位置固化经验不失效。规则见 CLAUDE.md 第 11 条。

- [latex-unicode-math](latex-unicode-math.md) — 数学符号禁用 Unicode，一律 LaTeX 命令（∘ ₂ 界面字体缺字形渲染失败）
- [code-documentation-standards](code-documentation-standards.md) — 代码块逐行中文注释 + DOXYGEN 函数注释
- [no-meta-in-content](no-meta-in-content.md) — 元指令不入正文
- [qa-pipeline](qa-pipeline.md) — Q&A 知识沉淀流程（润色→检索→命中→queries+MOC 排名）
- [self-consistency-check](self-consistency-check.md) — README/MOC 自指性检查
- [synthesizable-only-rtl](synthesizable-only-rtl.md) — RTL 示例必须可综合
- [understand-before-comment](understand-before-comment.md) — 注释须理解后编写，禁批量生成
- [markdown-bold-flanking](markdown-bold-flanking.md) — 加黑定界符与标点相邻 → 渲染裸 **，术语写 **中文**（EN）
- [qa-enumeration-expansion](qa-enumeration-expansion.md) — 回答中的维度枚举必须逐个展开，"列了就得讲"
- [no-interview-branding](no-interview-branding.md) — 仓库公开，禁用"面试/求职"字样，题库一律"复习自测"定位
- [wavedrom-drawing-rules](wavedrom-drawing-rules.md) — Wavedrom 五规则：. 重复/标签只挂 2 3/= 禁用/data 框后显式电平/改 json 必重渲染
- [sync-before-edit](sync-before-edit.md) — 编辑前先同步远程：干净则 pull --rebase，脏则 fetch + 检查领先

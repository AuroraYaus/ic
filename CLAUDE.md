---
type: spec
aliases:
  - CLAUDE_数字IC 项目 CLAUDE 指南
  - ASIC 执行规范
tags:
  - asic
  - claude
  - policy
source_spec: "Local project instructions — inherited from obsidian vault rules"
---
# 数字IC 项目规范

## 硬性规则

### 0. Skill 优先检查（最高优先级）

**每次收到用户请求后，第一步必须检查可用 SKILL 列表，判断是否有匹配的 SKILL。** 匹配即调用——在生成任何其他回复之前，先用 Skill 工具调用匹配的 SKILL。

### 1. 术语规范

- 数字IC术语首现必须标注 "中文（English Full Name, ABBR）"，如 "寄存器传输级（Register Transfer Level, RTL）"
- 此后可用英文缩写或中文简称
- 禁止口语化标题（如 "搞清楚流水线" → 应为 "流水线（Pipelining）原理"）

### 2. 图表规范

- 波形图/时序图 → Wavedrom（`.json` → `.html` → `.svg`）
- 电路图/架构图/模块框图 → ≤50 节点 Mermaid，>50 节点 PlantUML
- Mermaid 必须配置深色/浅色自适应主题：`%%{init: {'theme': 'default'}}%%`
- 所有图表必须输出 SVG 作为主格式，PNG 为可选
- 图表文件放在对应概念的 `assets/` 子目录

### 3. 代码规范

- HDL 代码必须标注语言类型：```verilog 或 ```systemverilog
- 脚本标注：```tcl / ```python / ```shell
- 代码块上方必须有简短注释说明用途

### 4. Wikilink 与节点规范

- 概念间引用使用 Obsidian wikilink：`领域/文件名` — 路径相对于 vault 根目录
- **零空心节点强制规则**：仅对库内真实存在的 `.md` 文件添加 wikilink。未创建的概念不写 wikilink，用 `#标签` 临时标记。杜绝 Obsidian 图谱灰色空心节点。
- 跨领域概念优先链接到 `cross-domain/` 下的对应文件

### 5. 文档格式规范

- **表格**：必须使用 Markdown 标准 `|` 语法，严禁用 ASCII 字符绘制伪表格或架构图
- **LaTeX 公式**：行内用单 `$`，块级用双 `$$` 独立成行，复杂公式加 `\tag{编号}`。每完成一批文件后运行 LaTeX 渲染检查
- **参考来源**：每个概念文件 frontmatter 中的 `source_spec` 必须填写真实参考来源（教材/标准/论文），不能留空或写占位符

### 6. 项目背景

本项目是数字IC全栈知识库，覆盖六大领域：

- `rtl-design/` — RTL 设计与编码（Verilog/SystemVerilog，FSM，CDC，流水线）
- `verification/` — 功能验证（UVM，SVA，覆盖率，形式验证）
- `architecture/` — 计算机体系结构（流水线，乱序执行，缓存，总线，SoC）
- `asic-flow/` — ASIC 实现流程（综合，STA，DFT，布局布线，Signoff）
- `cross-domain/` — 跨领域概念（时序收敛，低功耗，复位策略，CDC）
- `concepts/` — 数字IC基础（CMOS，数制，亚稳态，半导体基础）

### 7. 内容质量标准

- 每个概念文件 100-400 行
- 原理部分至少 2-3 段实质性内容，不能只有一句话
- "关键要点" 至少 5 条
- "与其他概念的关系" 至少 2 个 wikilink
- 禁止空壳文件（仅标题 + 一句话 + 无实质内容的占位符）

### 8. 图谱配置

Obsidian 全局 Graph 视图按 `type` 元数据分组着色：

| type | 用途 | 示例 |
|:---|:---|:---|
| `index` | 入口/MOC 页面 | `数字IC_入口.md`, `rtl-design_MOC.md` |
| `concept` | 核心概念 | 所有 `concepts/` 下的文件 |
| `moc` | 领域内容地图 | 各领域 `_MOC.md` 文件 |
| `spec` | 项目规范/规则 | `CLAUDE.md` |

图谱颜色分组以 `type` + 领域 `tag` 组合查询，配色区分度高、适配 Obsidian 深色主题。

### 9. 问答与知识沉淀机制（Q&A Pipeline）

收到数字IC相关问题后，必须执行以下流程：

#### 9.1 检索（Search First）

先在知识库中搜索是否已有**相同、相似或相关**的问题与解答：
- 按关键词搜索已有概念文件
- 按主题匹配 wikilink 网络中的邻近节点
- 检查 frontmatter 中的 `queries` 字段

#### 9.2 命中策略（Hit Resolution）

| 匹配程度 | 处理方式 |
|:---|:---|
| **完全一致** | 在文件 frontmatter 中累加 `queries` 计数；在文中标记高频查询；若内容过时则更新 |
| **高度相关** | 在相关文件中扩充对应章节；将新问题作为新的 `###` 子节插入到邻近位置 |
| **部分相关** | 在相关文件的"与其他概念的关系"中添加链接；必要时新建概念文件 |
| **无匹配** | 创建新概念文件，详细解答 + 拓展延伸；放入正确的领域目录和 MOC 索引 |

#### 9.3 查询计数与易忘排名

每个概念文件的 frontmatter 中维护 `queries` 字段（整数，默认 1）：

```yaml
queries: 3
```

每次命中累加。每个领域的 MOC 文件底部维护**易忘知识点排名表**：

```markdown
## 高频查询（易忘知识点排名）

| 排名 | 概念 | 查询次数 | 最后查询 |
|:---|:---|:---|:---|
| 1 | 领域/概念文件名 | 5 | 2026-07-22 |
```

排名按 `queries` 降序，帮助识别需要重点复习的薄弱知识点。

#### 9.4 文件内组织原则

- 相似问题和解答放在**同一文件的相邻位置**（邻近的 `###` 子节）
- 不同主题的问题放在不同文件或不同 `##` 大节下
- 每次新增问答后更新对应 MOC 的概念索引
- 新增文件必须写入 frontmatter `tags` 和 wikilink 网络

#### 9.5 输出标准

- 回答必须包含：**原理阐述（2-3 段）+ 关键要点（≥5 条）+ 与其他概念的关系（≥2 个 wikilink）**
- 首次出现的术语标注 "中文（English Full Name, ABBR）"
- 涉及电路的给出 Mermaid 框图或 Wavedrom 时序图
- 涉及代码的给出 ```systemverilog 或 ```verilog 标注的示例
- 解答后必须更新对应 MOC 的易忘排名表

# Audit Fixes — Implementation Plan

> **For agentic workers:** Execute tasks in order. Each task is independently testable.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all issues identified in the 2026-07-22 comprehensive audit of the 数字IC knowledge base.

**Architecture:** Three phases — structural fixes (MOC, directory, frontmatter), content expansion (31 files, +861 lines), and diagrams (Mermaid/Wavedrom for key concepts). Structural fixes must complete first to avoid broken wikilinks during content work.

**Tech Stack:** Markdown + YAML frontmatter, Obsidian wikilinks, Mermaid (.mmd), bash/python verification scripts.

## Global Constraints

- All wikilinks must resolve at every stage — run verification after each phase
- Concept files: 100-400 lines (target 100-120 for expansion)
- Filenames: kebab-case in `concepts/` subdirectory
- frontmatter: `type`, `aliases`, `tags`, `source_spec` on every file
- MOC files exempt from 100-line minimum (CLAUDE.md rule)
- cross-domain must follow same structure as other domains: `_MOC.md` + `concepts/` subdirectory

---

## Phase 1: Structural Fixes

### Task 1: Create cross-domain MOC and restructure directory

**Files:**
- Create: `cross-domain/cross-domain_MOC.md`
- Create: `cross-domain/concepts/` (directory)
- Move: `cross-domain/concepts/timing-closure.md` → `cross-domain/concepts/timing-closure.md`
- Move: `cross-domain/concepts/low-power-design.md` → `cross-domain/concepts/low-power-design.md`
- Move: `cross-domain/concepts/clock-domain-crossing.md` → `cross-domain/concepts/clock-domain-crossing.md`
- Move: `cross-domain/concepts/reset-methodology.md` → `cross-domain/concepts/reset-methodology.md`
- Modify: All files with wikilinks to cross-domain files (~20+ files)

- [ ] Create `cross-domain/concepts/` directory
- [ ] Move 4 files into `cross-domain/concepts/`
- [ ] Create `cross-domain/cross-domain_MOC.md` with frontmatter, domain overview, concept index, learning path
- [ ] Update all wikilinks: `cross-domain/X` → `cross-domain/concepts/X` (use python script)
- [ ] Update `数字IC_入口.md` wikilinks
- [ ] Run wikilink audit verify 0 broken
- [ ] Commit

### Task 2: Add frontmatter to README.md

- [ ] Add frontmatter block at top: `type: spec`, appropriate aliases/tags/source_spec
- [ ] Verify file renders correctly
- [ ] Commit

---

## Phase 2: Content Expansion (31 files, +861 lines)

Each task covers one domain. All concept files must reach ≥100 lines by adding substantive content:
- Additional principle/mechanism explanations (adds to 原理 section)
- HDL code examples where applicable
- Extended key points with quantitative data
- Deeper cross-concept relationship descriptions

### Task 3: Expand concepts/ (4 files, +151 lines)
### Task 4: Expand rtl-design/concepts/ (7 files, +199 lines)
### Task 5: Expand verification/concepts/ (3 files, +95 lines)
### Task 6: Expand architecture/concepts/ (7 files, +152 lines)
### Task 7: Expand asic-flow/concepts/ (8 files, +218 lines)
### Task 8: Expand cross-domain/concepts/ (2 files, +46 lines)

---

## Phase 3: Diagrams

### Task 9: Create Mermaid diagrams (6 diagrams)
### Task 10: Create Wavedrom timing diagrams (2 diagrams)

---

## Phase 4: Final Verification

### Task 11: Full audit re-run

- [ ] Verify all files ≥100 lines (concept files only)
- [ ] Verify 0 broken wikilinks
- [ ] Verify all frontmatter present
- [ ] Verify cross-domain structure matches other domains
- [ ] Verify diagram files present and referenced
- [ ] Update README.md file count if needed

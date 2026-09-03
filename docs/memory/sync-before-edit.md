---
name: sync-before-edit
description: 编辑项目文件前先同步远程仓库（fetch + 检查领先），防止基于陈旧副本的修改与远程新提交冲突
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ef9f9e62-75f2-4e64-99c2-30008c560696
  modified: 2026-09-03T12:49:42.531Z
---

用户要求（2026-09-03）将"编辑前先同步远程仓库"固化为项目规则：每次开始编辑项目文件前先与远程同步，防止本地陈旧副本与远程新提交产生不一致修改。

**Why:** 双推工作流（origin 配置 gitee + github 双 pushurl）下远程可能被其他设备/协作者更新；基于陈旧副本编辑会在推送时产生冲突或覆盖他人提交。实测教训：工作区有未提交修改时 `git pull --rebase` 直接失败（脏工作树）——必须走 fetch + 检查领先的路径。

**How to apply:**
1. 工作区干净 → `git pull --rebase origin master`
2. 工作区脏 → `git fetch origin` + `git log HEAD..origin/master --oneline` 检查领先：无新提交继续编辑；有新提交先提交/stash 再 pull
3. 长时间会话距上次同步较久或推送前重新检查

已登记 ic/CLAUDE.md §10（硬性规则）。关联 [[qa-pipeline]]。

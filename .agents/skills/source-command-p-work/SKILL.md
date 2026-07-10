---
name: "source-command-p-work"
description: "Issue 기반 작업 시작"
---

# source-command-p-work

Use this skill when the user asks to run `p_work`.

## Command Template

Issue 기반 작업을 시작한다.

## 인자가 비어있을 때

- 현재 git 브랜치를 표시한다.
- `git worktree list` 결과를 함께 표시한다.

## 인자가 있을 때

Issue `#$ARGUMENTS` 작업을 시작한다.

1. GitHub 도구로 Issue 내용을 읽는다.
2. `develop` 브랜치를 최신화한다.
3. 브랜치명을 `feature/$ARGUMENTS-short-description` 형식으로 결정한다.
4. repo 바깥 동일 레벨에 worktree를 만든다.

```bash
git worktree add ../ochul-issue-$ARGUMENTS -b feature/$ARGUMENTS-short-description develop
```

5. worktree에 필요한 로컬 전용 파일과 Codex 작업 규칙을 심볼릭 링크로 연결한다.

```bash
ln -sf $(pwd)/.agents ../ochul-issue-$ARGUMENTS/.agents
ln -sf $(pwd)/AGENTS.md ../ochul-issue-$ARGUMENTS/AGENTS.md
```

6. 로컬 전용 설정이 있으면 연결한다.

```bash
mkdir -p ../ochul-issue-$ARGUMENTS/.codex
test -f .codex/config.toml && ln -sf $(pwd)/.codex/config.toml ../ochul-issue-$ARGUMENTS/.codex/config.toml
test -f .mcp.json && ln -sf $(pwd)/.mcp.json ../ochul-issue-$ARGUMENTS/.mcp.json
test -f .env && ln -sf $(pwd)/.env ../ochul-issue-$ARGUMENTS/.env
test -f .env.local && ln -sf $(pwd)/.env.local ../ochul-issue-$ARGUMENTS/.env.local
```

7. GitHub 도구로 Issue에 현재 사용자를 assign한다.
8. 새 worktree에서 Codex를 시작할 경로를 안내한다.

```bash
cd ../ochul-issue-$ARGUMENTS
```

## 완료

작업 완료 후 `p_done` 절차로 테스트, 커밋, 푸시, PR 생성을 진행한다.

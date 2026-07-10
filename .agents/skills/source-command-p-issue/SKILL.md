---
name: "source-command-p-issue"
description: "이슈 픽업"
---

# source-command-p-issue

Use this skill when the user asks to run `p_issue`.

## Command Template

Issue를 픽업해서 작업을 시작한다.

## 인자

- `$ARGUMENTS`: 픽업할 Issue 번호
- 인자가 없으면 `p_issues`로 이슈 목록을 먼저 조회하라고 안내한다.

## 실행 순서

1. GitHub 도구로 Issue `#$ARGUMENTS` 내용을 조회한다.
2. 제목, 상태, 라벨, 담당자, 본문 요약을 확인한다.
3. 이미 다른 담당자가 있으면 계속 픽업할지 사용자에게 확인한다.
4. 현재 GitHub 사용자를 Issue assignee로 지정한다.
5. `p_work $ARGUMENTS` 절차와 동일하게 독립 worktree를 생성한다.
   - 경로: `../ochul-issue-$ARGUMENTS`
   - 브랜치: `feature/$ARGUMENTS-short-description`
   - base: `develop`
6. worktree에 로컬 전용 파일과 Codex 작업 규칙을 연결한다.
   - `.agents`
   - `AGENTS.md`
   - `.codex/config.toml`이 있으면 `.codex/config.toml`
   - `.mcp.json`이 있으면 `.mcp.json`
   - `.env` 또는 `.env.local`은 존재할 때만 연결하고 커밋하지 않는다.
7. 새 worktree 경로를 안내한다.

## 관계

- `p_issue <번호>`는 이슈를 픽업하고 작업 환경까지 준비한다.
- `p_issues`는 열린 이슈 목록만 조회한다.
- `p_work <번호>`는 worktree 생성 중심의 하위 절차다.

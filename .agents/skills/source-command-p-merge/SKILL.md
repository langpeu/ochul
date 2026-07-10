---
name: "source-command-p-merge"
description: "PR 머지"
---

# source-command-p-merge

Use this skill when the user asks to run `p_merge`.

## Command Template

PR `#$ARGUMENTS`를 머지한다.

## 적용 범위

- feature PR을 `develop`으로 squash merge하기 위한 절차다.
- 배포용 `develop` -> `main` 반영에는 사용하지 않는다.
- 배포는 `develop` 브랜치에서 `p_done main`으로 처리한다.

## 순서

1. PR 상태를 확인한다.
2. PR base branch를 확인한다.
   - base가 `main`이면 `develop`으로 변경 가능한지 확인한다.
3. PR body에서 관련 Issue 번호를 추출한다.
4. `develop`으로 squash merge한다.
5. 관련 Issue가 있으면 close 처리한다.
6. worktree 여부를 판별한다.
   - worktree면 remote feature branch 삭제만 처리하고 local branch 삭제는 건너뛴다.
   - 일반 작업 디렉토리면 `develop`으로 전환 후 최신화하고 feature branch를 정리한다.

## 금지

- `develop`에서 `git merge main` 또는 `git pull origin main`을 실행하지 않는다.
- `main` 또는 `develop`에 직접 커밋하지 않는다.

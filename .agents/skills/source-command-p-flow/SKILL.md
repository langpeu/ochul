---
name: "source-command-p-flow"
description: "작업 완료 전체 플로우: p_done, p_merge, p_done main"
---

# source-command-p-flow

Use this skill when the user asks to run `p_flow`, or asks to finish the current work, merge the PR, and reflect it to `main` in one flow.

## 핵심 원칙

- 이 skill은 상위 orchestration 전용이다.
- `p_done`, `p_merge`, `p_done main` 절차를 재구현하지 않는다.
- 각 단계에서는 기존 skill을 읽고 그대로 실행한다.
- feature 브랜치에서 `main` PR을 만들지 않는다.
- 배포용 `main` 반영은 `develop`에서 fast-forward 방식으로만 진행한다.

## 실행 순서

1. 현재 브랜치와 worktree 상태를 확인한다.
   - 변경사항이 없으면 중단하고 사용자에게 알린다.
   - feature 브랜치가 아니면 `p_done` 규칙에 따라 feature 브랜치를 먼저 만든다.
2. `source-command-p-done`을 실행한다.
   - 검증
   - 커밋
   - 푸시
   - feature -> `develop` PR 생성 또는 업데이트
3. 생성 또는 업데이트한 PR 번호를 확인한다.
4. `source-command-p-merge`를 PR 번호로 실행한다.
   - PR을 `develop`에 squash merge한다.
   - 관련 Issue가 있으면 close 처리한다.
   - feature branch와 worktree를 정리한다.
5. 로컬 브랜치를 `develop`으로 전환하고 최신 `origin/develop`으로 fast-forward한다.
6. `source-command-p-done`의 `main` 인자 절차를 실행한다.
   - `main`을 `develop`으로 `--ff-only` merge한다.
   - `origin/main`에 push한다.
   - 작업 후 다시 `develop`으로 돌아온다.

## 실패/중단 조건

- 검증 실패
- PR 생성 또는 PR 번호 확인 실패
- PR base가 `develop`이 아님
- `p_merge` 실패
- `p_done main` fast-forward 실패
- GitHub 인증 실패

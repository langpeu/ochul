---
name: "source-command-p-issues"
description: "이슈 목록 조회"
---

# source-command-p-issues

Use this skill when the user asks to run `p_issues` or asks to see the open issue list.

## Command Template

현재 열려있는 Issue 목록을 보여준다.

## 실행 순서

1. GitHub 도구가 현재 세션에 노출되어 있는지 확인한다.
2. open 상태의 Issue 목록을 조회한다.
3. 번호, 제목, 라벨, 담당자, 최근 업데이트 시간을 표로 요약한다.
4. 사용자가 바로 픽업할 수 있도록 `p_issue <번호>` 형식의 다음 명령을 안내한다.

## 의미 보존

- `p_issues`는 목록 조회 전용이다.
- Issue를 assign하거나 worktree를 만들지 않는다.

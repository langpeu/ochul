---
name: "source-command-p-done"
description: "작업 완료: 테스트, 커밋, 푸시, PR 생성"
---

# source-command-p-done

Use this skill when the user asks to run `p_done`.

## Command Template

작업을 마무리한다.

## 순서

1. 브랜치 확인
   - `main` 또는 `develop`이면 현재 변경사항을 유지한 채 feature 브랜치를 만든다.
   - 기본 작업 브랜치 prefix는 `feature/`를 사용한다.
2. 검증
   - Flutter 앱이 생성되어 있으면 `flutter analyze`와 `flutter test`를 실행한다.
   - Supabase migration 변경이 있으면 SQL 문법과 RLS 의도를 점검한다.
   - CLI가 없으면 실행하지 못한 이유를 최종 답변에 명확히 적는다.
3. 스크린샷 확인
   - UI 변경이 있으면 `screenshots/issue/{번호}/` 또는 `screenshots/pr/{PR번호}/`에 증거를 남긴다.
4. 커밋
   - Conventional Commits 형식과 한글 설명을 사용한다.
   - `.env`, `.env.local`, `.mcp.json`, `.codex/config.toml`, API key, service role key는 절대 커밋하지 않는다.
5. 푸시
   - 현재 브랜치를 origin에 push한다.
6. PR 생성 또는 업데이트
   - 기본 base branch는 `develop`이다.
   - 이미 현재 브랜치에 열린 PR이 있으면 새 PR을 만들지 않고 업데이트한다.
   - `.github/pull_request_template.md`를 읽고 템플릿 구조를 유지한다.
   - 관련 Issue 번호가 있으면 `closes #번호`를 포함한다.

## `p_done main`

- `p_done main`은 현재 브랜치가 `develop`일 때만 진행한다.
- PR을 만들지 않고 `main`을 `develop`으로 fast-forward 한다.

```bash
git checkout main
git merge develop --ff-only
git push origin main
git checkout develop
```

- fast-forward가 실패하면 force push나 reset을 실행하지 않고 사용자에게 설명한다.

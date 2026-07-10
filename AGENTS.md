# AGENTS.md

이 파일은 Codex가 이 저장소에서 작업할 때 따를 규칙입니다.

## 언어 규칙

- 사용자와의 대화는 한국어로 진행한다.
- 코드, 변수명, 커밋 메시지는 필요한 경우 영어를 사용한다.

## Project Overview

Ochul은 방과후/학원 수업 운영자를 위한 Flutter + Supabase 기반 출결/납부/알림 서비스다.

초기 MVP는 패드 1대에서 동작하는 출석체크 화면을 중심으로 한다.

1. 선생님이 Supabase Auth 이메일/Apple/Google 로그인을 한다.
2. 선생님이 공부방을 선택하거나 생성한다.
3. 선생님이 수업과 학생을 관리한다.
4. 수업에 등록된 학생 목록과 출석 상태가 표시된다.
5. 학생이 자기 이름을 선택한다.
6. 학생 비밀번호를 입력한다.
7. 출석 처리 및 학부모 카카오 알림 발송이 진행된다.

안면인식, BLE, 학생폰 앱 설치는 MVP 범위에서 제외한다.
Face ID는 학생 인증이 아니라 iOS/iPadOS 선생님 모드 진입 보호용으로만 사용한다.

## Repository Layout

```text
apps/tablet_app/       # Flutter 패드 앱
supabase/migrations/   # Supabase schema migrations
supabase/functions/    # Edge Functions
docs/                  # 제품/기술 문서
.agents/skills/        # Codex source-command skills
```

## Branch Rules

- `main`, `develop`에 직접 커밋하지 않는다.
- 일반 작업은 `feature/{issue-number}-short-description` 브랜치에서 진행한다.
- 기본 PR 대상은 `develop`이다.
- 배포 반영은 `develop`에서 검증 후 `main`으로 fast-forward 한다.
- force push, hard reset, destructive checkout은 사용자 명시 요청 없이 실행하지 않는다.

## Product Rules

- 선생님 계정은 Supabase Auth의 이메일, Apple, Google provider로 관리한다.
- `teachers.role = 'admin'` 계정은 관리자 계정이다.
- 관리자 계정은 선생님 목록과 선생님별 공부방/학생 목록을 조회할 수 있다.
- 선생님은 공부방을 생성하고, 공부방 안에서 학생/수업/납부/알림 이력을 관리한다.
- 공부방 권한은 선생님 계정과 연결해 제한한다.
- MVP에서 공부방 데이터는 owner 선생님만 볼 수 있다. 다른 선생님에게 공부방 이름, 학생명, 보호자 연락처, 출결, 납부, 알림 이력이 노출되면 안 된다.
- admin 조회 권한은 예외로 허용하되, 일반 선생님 간 데이터 공유와 혼동하지 않는다.
- Supabase 테이블은 RLS 정책으로 선생님별 데이터 격리를 강제한다.
- 학생 출석 비밀번호는 평문 저장 금지. 서버에는 해시만 저장한다.
- 학생 이름, 보호자 연락처, 출결, 납부 정보는 개인정보로 취급한다.
- 학부모 카카오 발송은 실패해도 출석 기록 자체를 롤백하지 않는다. 실패 로그를 남기고 재시도 가능하게 한다.
- 출석 상태는 최소 `present`, `late`, `absent`, `excused`, `left_early`를 지원한다.
- 선생님은 학생이 직접 처리한 출석을 수동 수정할 수 있어야 하며, 수정 이력을 남긴다.
- 수업은 시작일, 종료일, 요일, 시작/종료 시간을 가진다.
- 학생은 여러 기본 수업과 보강 수업에 등록될 수 있다.
- 선생님 보드에서는 학생을 드래그앤드롭으로 수업에 등록할 수 있어야 한다.
- 휴강, 보강, 수업 시간 변경은 별도 변경 이력으로 남기고 보호자에게 카카오 알림을 발송한다.
- 학생 등록/수정/삭제, 수업 등록/수정/삭제, 수업별 학생 등록/제외, 출결 수정, 납부 상태 변경, 카카오 발송 요청/성공/실패는 사용 히스토리로 남긴다.
- 선생님과 admin은 사용 히스토리를 유형, 기간, 선생님, 공부방, 학생, 수업, 발송 상태로 필터링할 수 있어야 한다.
- 사용 히스토리에는 IP, 기기 식별자, user agent를 저장하지 않는다.
- 학생 출석 모드와 선생님 모드는 UI와 권한을 명확히 분리한다.
- 선생님 모드 진입은 iOS/iPadOS에서 Face ID 또는 기기 생체 인증, Android에서 생체 인증/패턴/PIN 또는 앱 관리자 PIN을 사용한다.
- 한 보호자가 여러 학생을 가질 수 있으므로 카카오 발송 이력은 학생별로 구분한다.

## Supabase Rules

- DB 변경은 `supabase/migrations` SQL로 관리한다.
- Supabase는 로컬 스택이 아니라 MCP로 Cloud 프로젝트를 사용한다.
- `supabase start`, `supabase db reset` 같은 로컬 Supabase 스택 명령은 사용자 명시 요청 없이 실행하지 않는다.
- Cloud DB 변경 전에는 Supabase MCP 연결 대상 프로젝트를 확인한다.
- 운영 DB는 임의로 직접 수정하지 않는다. migration review 후 MCP/SQL 적용 절차를 명확히 확인한다.
- Flutter 앱에서는 Supabase table query, RPC, SQL 호출을 직접 작성하지 않는다.
- Flutter 앱의 Supabase 사용은 Auth 세션 처리와 Edge Function 호출로 제한한다.
- 앱의 모든 비즈니스 데이터 읽기/쓰기는 `supabase/functions` Edge Function으로 구현한다.
- DB query, service role 사용, RLS 보조 검증, Kakao API 호출은 Edge Function 내부에서만 처리한다.
- Flutter 코드에 테이블명, 컬럼명, SQL, PostgREST filter가 드러나면 안 된다.
- service role key, Kakao API key 등 비밀값은 커밋하지 않는다.
- Edge Function은 서버 측 권한이 필요한 작업에만 사용한다.

## Codex Source Commands

- 반복 작업 절차는 `.agents/skills/source-command-*`에 기록한다.
- `p_issues`: 열린 GitHub Issue 목록 조회
- `p_issue <번호>`: Issue 픽업 및 작업 worktree 준비
- `p_work <번호>`: Issue 기반 worktree 생성
- `p_done`: 빌드/테스트/커밋/푸시/PR 생성 또는 업데이트
- `p_flow`: `p_done` -> `p_merge` -> `p_done main`

`p_issue`와 `p_issues`의 의미를 바꾸지 않는다.

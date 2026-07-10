# Ochul

방과후/학원 수업용 패드 기반 출결, 수업료 납부, 학부모 카카오 알림 관리 서비스입니다.

## MVP 출석 흐름

1. 선생님이 이메일, Apple, Google 중 하나로 로그인한다.
2. 선생님이 공부방을 선택하거나 생성한다.
3. 패드에서 오늘 수업 또는 수업방을 선택한다.
4. 수업에 등록된 학생 목록과 출석 상태가 표시된다.
5. 학생이 자기 이름을 선택한다.
6. 학생 비밀번호를 입력한다.
7. 출석 처리 후 학부모에게 카카오 알림을 발송한다.

## 공부방/수업 관리

- 선생님은 로그인 후 공부방과 학생을 관리한다.
- 선생님은 자신이 만든 공부방과 그 안의 학생 정보만 볼 수 있다.
- 다른 선생님에게는 내 공부방과 학생 정보가 노출되지 않는다.
- `admin` 계정은 관리자 화면에서 선생님 목록과 선생님별 공부방/학생 목록을 조회할 수 있다.
- 학생 목록에서 수업방으로 드래그앤드롭하여 학생을 등록한다.
- 학생은 여러 기본 수업에 등록될 수 있다.
- 학생은 필요하면 보강 수업에도 등록될 수 있다.
- 같은 학생이 같은 수업에 중복 등록되지 않도록 한다.

## 수업 운영 흐름

- 수업은 시작일, 종료일, 요일, 시작/종료 시간을 가진다.
- 3개월 과정, 단기 특강처럼 기간이 다른 수업을 만들 수 있다.
- 개인 사정이나 공휴일로 휴강을 등록할 수 있다.
- 휴강된 수업은 보강 회차로 연결할 수 있다.
- 휴강, 보강, 시간 변경은 보호자에게 카카오 알림으로 발송한다.

## 화면 모드

- 학생 출석 모드: 수업 선택, 학생 목록, 출석 상태, 비밀번호 입력만 제공한다.
- 선생님 모드: 수업 관리, 출결 수정, 납부 관리, 카카오 발송 이력을 제공한다.
- iPad/iPhone 선생님 모드 진입은 Face ID 또는 기기 인증을 사용한다.
- Android 선생님 모드 진입은 기기 인증, 패턴/PIN 또는 앱 관리자 PIN을 사용한다.
- 한 보호자가 여러 학생을 가질 수 있으므로 알림에는 학생 이름, 수업 이름, 출석 시간이 포함된다.

## 기술 방향

- App: Flutter
- Backend: Supabase Cloud
- Database 작업: Supabase MCP를 통한 Cloud 프로젝트 기준
- Notification: Kakao 알림톡/비즈메시지 연동용 Edge Function
- Repository: GitHub
- Branches: `main`, `develop`, `feature/*`

## Monorepo Layout

```text
apps/
  tablet_app/          # Flutter 패드 앱
supabase/
  migrations/          # DB schema migrations
  functions/           # Edge Functions
docs/
  product-requirements.md
  data-model.md
  kakao-notifications.md
.agents/
  skills/              # Codex 작업 스킬
```

## Local Setup

현재 저장소에는 Flutter 앱과 Supabase migration SQL을 둡니다.
Supabase는 로컬 스택이 아니라 MCP로 Cloud 프로젝트에 연결해 사용합니다.
`supabase start`, `supabase db reset` 같은 로컬 스택 명령은 기본 workflow에서 사용하지 않습니다.

# Data Model

## 핵심 엔티티

### organizations

학원, 센터, 학교 등 운영 단위.

### study_rooms

선생님이 생성하고 관리하는 공부방. MVP에서는 `organizations`와 1:1 운영 단위로 사용하되, 앱 화면과 사용자 언어는 공부방을 기준으로 한다.

### teachers

Supabase Auth 계정과 연결된 선생님 또는 관리자.
`role = 'admin'`인 계정은 관리자 조회 권한을 가진다.

### study_room_members

공부방에 참여한 선생님과 권한. MVP에서는 owner만 사용하고, 추후 공동 관리 기능을 위한 확장 지점으로 둔다.

### students

출석 대상 학생. 학생 출결 비밀번호는 숫자 6자리이며 평문 저장하지 않는다.
선생님은 학생 비밀번호를 조회할 수 없고 리셋만 할 수 있다.
학생 아바타 선택을 위해 성별, 연령대, 아바타 이미지 키를 가진다.

### guardians

학부모/보호자 연락처와 알림 수신 정보.
보호자 전화번호는 개인정보이며, 출결/수업 변경/납부 안내 목적의 동의 기록과 함께 관리한다.

한 보호자가 여러 학생과 연결될 수 있으므로 학생과 보호자는 다대다 관계로 관리한다.

### classes

공부방 안의 수업방. 수업명, 설명, 수업 기간, 요일 선택, 시간, 담당 선생님, 수업 유형을 가진다.
수업 유형은 기본 수업, 보강 수업, 추가 수업으로 구분한다.

### class_schedules

수업방의 정규 요일/시간 규칙. 예: 월/수 15:00~16:00.

### class_students

수업과 학생의 등록 관계.
드래그앤드롭 수강 등록 UI는 이 관계를 생성/비활성화한다.
학생은 여러 기본 수업과 보강 수업에 등록될 수 있다.

### classroom_layouts

수업별 교실 배치도. 책상/의자 배치 캔버스 크기와 버전 정보를 가진다.

### classroom_seats

교실 배치도 안의 좌석/책상 위치. 좌표, 크기, 회전, 라벨을 저장한다.

### student_seat_assignments

학생과 좌석의 사전 배정 관계. 자유 착석 수업에서는 비워둘 수 있다.

### class_sessions

실제 수업 회차. 출석 기록은 수업방이 아니라 수업 회차에 연결된다.

정규 일정에서 생성된 회차일 수도 있고, 보강 수업처럼 별도 생성된 회차일 수도 있다.

### class_session_changes

휴강, 보강, 시간 변경 등 수업 회차 변경 이력.

### attendance_records

학생별 출결 기록.

### payment_periods

월별 또는 기간별 수업료 청구 단위.

### payment_statuses

학생별 납부 상태.

### notification_logs

카카오 알림 발송 요청, 성공, 실패, 재시도 기록.

학생 이름, 수업 이름, 출석 시간, 변경 전/후 일정 등 템플릿에 필요한 값을 payload에 저장한다.
한 보호자가 여러 자녀를 가진 경우에도 `student_id`와 `guardian_id`를 함께 저장해 학생별 이력을 구분한다.
보호자 전화번호 원문은 저장하지 않고 마스킹된 번호만 저장한다.

### audit_logs

앱 사용 히스토리와 중요한 변경 이력.
학생 등록/수정/삭제, 수업 등록/수정/삭제, 수업별 학생 등록/제외, 출결 수정, 납부 상태 변경, 카카오 발송 관련 이벤트를 저장한다.
필터링을 위해 공부방, 선생님, 학생, 수업, 수업 회차, 알림 로그와 연결한다.

## 출석 처리 규칙

- `class_sessions`가 열려 있어야 학생 출석 입력을 받는다.
- 학생은 선택한 수업에 등록되어 있어야 한다.
- 비밀번호 검증은 Edge Function에서 처리한다.
- 출결 비밀번호는 숫자 6자리만 허용한다.
- 비밀번호 분실 시 선생님이 리셋하고 학생이 새 6자리 비밀번호를 설정한다.
- 비밀번호 해시는 앱으로 반환하지 않는다.
- 같은 `class_session_id`와 `student_id` 조합은 하나의 출석 기록만 가진다.
- 선생님 수동 수정은 `attendance_records`를 업데이트하고 `audit_logs`에 기록한다.
- 좌석 배치형 출석은 `classroom_seats`의 빈 좌석에 학생 아바타를 드래그앤드롭한 뒤 비밀번호 검증을 거쳐 처리한다.
- 좌석 출석 기록은 `attendance_records.classroom_seat_id`에 연결한다.
- 이미 출석된 학생 또는 이미 점유된 좌석은 중복 출석 처리하지 않는다.

## 인증/권한 규칙

- 선생님 로그인은 Supabase Auth의 이메일, Apple, Google provider를 사용한다.
- `teachers.auth_user_id`는 `auth.users.id`와 연결한다.
- 공부방 데이터 접근은 Supabase RLS로 제한한다.
- MVP에서는 `study_rooms.owner_teacher_id`가 현재 로그인한 선생님인 경우에만 접근을 허용한다.
- 다른 선생님은 공부방, 학생, 보호자, 수업, 출결, 납부, 알림 이력을 조회할 수 없다.
- `teachers.role = 'admin'`인 계정은 관리자 조회 화면에서 선생님 목록과 선생님별 공부방/학생 목록을 조회할 수 있다.
- admin 조회 권한과 일반 선생님 수정 권한은 RLS 정책에서 분리한다.
- `study_room_members`는 추후 공동 관리 기능을 위한 테이블이며, 기본 정책은 owner만 접근 가능하게 둔다.

## 보호자 개인정보 규칙

- 보호자 전화번호는 `guardians.phone`에 저장하되 접근 권한을 제한한다.
- 보호자 알림 동의 여부, 동의 일시, 동의 방식, 입력 선생님을 기록한다.
- 보호자가 수신 거부하거나 삭제를 요청하면 `kakao_opt_in = false`로 전환하거나 정책에 따라 삭제/비식별 처리한다.
- `notification_logs`와 `audit_logs`에는 보호자 전화번호 원문을 저장하지 않는다.
- 카카오 발송 시 원문 번호는 Edge Function 내부에서만 사용하고, 로그에는 마스킹 번호만 저장한다.

## 사용 히스토리 규칙

- 주요 변경 작업은 `audit_logs`에 기록한다.
- 학생 생성/수정/삭제는 `entity_type = 'student'`로 기록한다.
- 수업 생성/수정/삭제는 `entity_type = 'class'`로 기록한다.
- 교실 배치 생성/수정/삭제는 `entity_type = 'classroom_layout'` 또는 `classroom_seat`로 기록한다.
- 수업별 학생 등록/제외는 `entity_type = 'class_student'`로 기록한다.
- 출결 수동 수정은 `entity_type = 'attendance'`로 기록한다.
- 납부 상태 변경은 `entity_type = 'payment'`로 기록한다.
- 카카오 발송 요청/성공/실패/재발송은 `notification_logs`와 연결해 확인한다.
- 히스토리 화면은 유형, 기간, 선생님, 공부방, 학생, 수업, 발송 상태로 필터링한다.
- 선생님은 자기 공부방의 히스토리만 보고, admin은 전체 선생님/공부방의 히스토리를 조회할 수 있다.
- 감사 로그에는 IP, 기기 식별자, user agent를 저장하지 않는다.

## Supabase 운영 규칙

- Supabase는 로컬 스택이 아니라 Cloud 프로젝트를 사용한다.
- Codex 작업에서는 Supabase MCP로 Cloud 프로젝트 연결 상태와 대상 프로젝트를 확인한다.
- Migration SQL은 `supabase/migrations`에 보관하되, 적용은 MCP/Cloud 기준으로 검토 후 진행한다.
- 로컬 `supabase/config.toml`은 기본적으로 커밋하지 않는다.

## 앱-서버 경계

- Flutter 앱은 Supabase Auth와 Edge Function 호출만 사용한다.
- Flutter 앱에서 Supabase table query, RPC, SQL, PostgREST filter를 직접 사용하지 않는다.
- 모든 비즈니스 데이터 조회/변경은 Edge Function API로 감싼다.
- 테이블명, 컬럼명, 조인 구조, RLS 보조 검증은 Edge Function 내부 구현으로 숨긴다.
- service role key는 앱에 포함하지 않고 Edge Function secret으로만 사용한다.
- Edge Function은 REST 스타일의 명확한 리소스/동작 이름을 사용한다.

## 수업 일정 규칙

- `classes`는 기간과 활성 상태를 가진다.
- `classes.class_kind`는 기본 수업, 보강 수업, 추가 수업을 구분한다.
- `class_schedules`는 요일과 시간을 가진다.
- 실제 출석은 `class_sessions` 단위로 처리한다.
- 휴강은 기존 `class_sessions` 상태를 `cancelled`로 바꾸고 `class_session_changes`에 기록한다.
- 보강은 `class_sessions`에 `makeup` 회차를 추가하고 원래 회차와 연결한다.
- 일정 변경 알림은 대상 수업에 등록된 학생의 보호자에게 학생별로 생성한다.

## 수강 등록 규칙

- 학생은 같은 수업에 한 번만 활성 등록될 수 있다.
- 선생님 보드에서는 미등록 학생 목록과 수업별 등록 학생 목록을 나란히 보여준다.
- 드래그앤드롭으로 학생을 수업에 넣으면 `class_students`가 생성되거나 다시 활성화된다.
- 보강 수업은 특정 기본 수업 또는 특정 수업 회차와 연결될 수 있다.

## 좌석 배치 규칙

- 수업은 0개 또는 1개의 활성 교실 배치도를 가진다.
- 보강 수업은 기본 수업의 배치도를 복사하거나 독립 배치도를 가질 수 있다.
- 좌석 배치 좌표는 패드 화면 비율에 맞게 정규화된 숫자로 저장한다.
- 좌석 배치 변경은 기존 출석 기록을 훼손하지 않는다.
- 학생 아바타는 앱 에셋 키로 관리하고, 실제 학생 사진은 저장하지 않는다.

## 화면 모드 규칙

- 학생 출석 모드는 수업 목록, 학생 이름, 출석 상태, 비밀번호 입력만 제공한다.
- 선생님 모드는 출결 수정, 수업 일정 변경, 납부 관리, 카카오 발송 이력을 제공한다.
- 선생님 모드 진입은 기기 인증 또는 앱 관리자 PIN으로 보호한다.

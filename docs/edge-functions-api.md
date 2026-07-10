# Edge Functions API

## 원칙

Flutter 앱은 Supabase DB를 직접 호출하지 않는다.

앱에서 허용되는 Supabase 사용은 다음으로 제한한다.

- Supabase Auth 로그인/세션 처리
- Supabase Edge Function 호출

앱에서 금지되는 구현은 다음과 같다.

- `from('students')` 같은 table query
- PostgREST filter
- SQL 문자열
- RPC 직접 호출
- service role key 사용
- DB 테이블명/컬럼명을 UI 코드나 repository 코드에 노출

## 이유

- 앱 바이너리에서 DB 구조가 노출되는 것을 막는다.
- 권한 검증과 감사 로그 생성을 서버 경계에서 일관되게 처리한다.
- 카카오 발송, 학생 비밀번호 검증, 관리자 권한 확인을 앱이 아니라 서버에서 수행한다.

## Edge Function 그룹

### auth/profile

- 내 선생님 프로필 조회
- 공부방 목록 조회
- 관리자 여부 조회

### study-rooms

- 공부방 생성/수정
- 공부방 선택
- 공부방 기본 설정 조회

### students

- 학생 목록 조회
- 학생 생성/수정/삭제
- 보호자 연결 관리
- 학생 출석 비밀번호 변경

### classes

- 수업 목록 조회
- 수업 생성/수정/삭제
- 수업 요일/기간/시간 관리
- 보강/휴강/시간 변경 관리

### enrollments

- 수업별 학생 등록
- 드래그앤드롭 순서 저장
- 기본 수업/보강 수업 등록 구분

### attendance

- 오늘 수업 목록 조회
- 수업별 학생 출석 상태 조회
- 학생 비밀번호 출석 체크
- 선생님 수동 출결 수정

### payments

- 납부 기간 조회
- 학생별 납부 상태 조회
- 납부 상태 변경
- 미납 안내 대상 조회

### notifications

- 카카오 발송 요청
- 카카오 발송 이력 조회
- 실패 건 재발송

### audit-logs

- 사용 히스토리 조회
- 유형, 기간, 선생님, 공부방, 학생, 수업, 발송 상태 필터링

### admin

- 선생님 목록 조회
- 선생님별 공부방 조회
- 공부방별 학생 조회
- 선생님별/공부방별 히스토리 조회

## Edge Function 공통 처리

모든 Edge Function은 다음을 처리한다.

- Supabase Auth JWT 검증
- 현재 선생님 프로필 조회
- owner/admin 권한 확인
- 입력값 검증
- DB 작업
- 필요한 경우 `audit_logs` 기록
- 필요한 경우 `notification_logs` 기록
- 앱에 필요한 형태로 응답 변환

## 응답 원칙

- 앱에는 화면에 필요한 필드만 반환한다.
- 내부 테이블명과 컬럼명에 의존하는 응답 형태를 피한다.
- 오류 메시지는 사용자가 이해 가능한 수준으로 변환한다.

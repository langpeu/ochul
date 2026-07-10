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

Flutter 앱은 Supabase Edge Function `edge-api`만 호출한다.

`edge-api` 요청 body는 다음 형태로 고정한다.

```json
{
  "method": "POST",
  "path": "/class-sessions/{classSessionId}/check-in",
  "body": {
    "studentId": "{studentId}",
    "pin": "123456"
  }
}
```

`edge-api` 내부 라우터는 `method + path`를 REST 리소스처럼 해석한다. 실제 DB 테이블명, 컬럼명, RLS 보조 검증, 카카오 발송 로그 생성은 Edge Function 내부 구현에만 둔다.

Edge API 경로는 REST 스타일로 간결하고 명확하게 둔다.

### auth/profile

- `GET /me`: 내 선생님 프로필, 권한, 공부방 목록
- `POST /me/onboard`: 첫 로그인 선생님 프로필과 기본 공부방 생성

### study-rooms

- `GET /study-rooms`: 공부방 목록
- `POST /study-rooms`: 공부방 생성
- `GET /study-rooms/{studyRoomId}`: 공부방 상세
- `PATCH /study-rooms/{studyRoomId}`: 공부방 수정

### students

- `GET /study-rooms/{studyRoomId}/students`: 학생 목록
- `POST /study-rooms/{studyRoomId}/students`: 학생 생성, 6자리 출결 비밀번호 해시 저장
- `GET /students/{studentId}`: 학생 상세
- `PATCH /students/{studentId}`: 학생 수정
- `DELETE /students/{studentId}`: 학생 퇴원 처리와 수업 등록 비활성화
- `POST /students/{studentId}/pin/reset`: 학생 출결 비밀번호 리셋
- `GET /students/{studentId}/guardians`: 학생 보호자 목록
- `PUT /students/{studentId}/guardians`: 보호자 연락처, 관계, 카카오 수신 동의, 대표 연락처 저장

### classes

- `GET /study-rooms/{studyRoomId}/classes`: 수업 목록
- `POST /study-rooms/{studyRoomId}/classes`: 수업 생성, 기간/요일/시간 규칙 저장
- `GET /classes/{classId}`: 수업 상세
- `PATCH /classes/{classId}`: 수업 수정
- `DELETE /classes/{classId}`: 수업 삭제 또는 비활성화
- `POST /classes/{classId}/sessions`: 수업 회차 생성
- `POST /classes/{classId}/sessions/open`: 오늘 출석용 수업 회차 열기
- `PATCH /class-sessions/{classSessionId}`: 수업 회차 수정
- `POST /classes/{classId}/sessions/cancel-today`: 오늘 수업 휴강 처리와 보호자 카카오 안내 요청
- `POST /classes/{classId}/sessions/makeup`: 보강 수업 생성과 보호자 카카오 안내 요청

### classroom-layouts

- `GET /classes/{classId}/classroom-layout`: 수업별 교실 배치 조회
- `PUT /classes/{classId}/classroom-layout`: 책상/의자 배치 저장
- `PUT /classes/{classId}/seat-assignments`: 학생 좌석 사전 배정 저장
- `POST /classes/{classId}/classroom-layout/copy`: 기본 수업 배치도를 보강 수업으로 복사

### enrollments

- `GET /classes/{classId}/students`: 수업 등록 학생 목록
- `PUT /classes/{classId}/students`: 수업 등록 학생 저장, 제외 학생은 비활성화
- `PATCH /classes/{classId}/students/order`: 드래그앤드롭 순서 저장

### attendance

- `GET /attendance/today`: 오늘 수업 목록
- `GET /class-sessions/{classSessionId}/attendance`: 수업별 출석 상태
- `POST /class-sessions/{classSessionId}/check-in`: 학생 6자리 비밀번호 출석 체크
- `POST /class-sessions/{classSessionId}/seat-check-in`: 학생 아바타 좌석 드래그앤드롭 출석 체크
- `PATCH /attendance-records/{attendanceRecordId}`: 선생님 수동 출결 수정

### payments

- `GET /study-rooms/{studyRoomId}/payment-periods`: 납부 기간 목록
- `POST /study-rooms/{studyRoomId}/payment-periods`: 납부 기간 생성
- `GET /payment-periods/{paymentPeriodId}/statuses`: 학생별 납부 상태
- `PATCH /payment-statuses/{paymentStatusId}`: 납부 상태 변경
- `POST /payment-periods/{paymentPeriodId}/unpaid/notify`: 미납 보호자 카카오 안내 요청

### notifications

- `GET /study-rooms/{studyRoomId}/notifications`: 카카오 발송 이력, 상태/학생 필터 지원
- `POST /notifications/{notificationId}/resend`: 기존 발송 로그를 복제해 pending 재발송 요청 생성

### audit-logs

- `GET /study-rooms/{studyRoomId}/audit-logs`: 사용 히스토리
- Body filter: `category` (`all`, `student`, `class`, `kakao`), `limit`
- 응답은 `audit_logs`와 카카오 `notification_logs`를 시간순으로 합쳐 반환한다.

### admin

- `GET /admin/teachers`: 선생님 목록
- `GET /admin/teachers/{teacherId}/study-rooms`: 선생님별 공부방
- `GET /admin/study-rooms/{studyRoomId}/students`: 공부방별 학생
- `GET /admin/study-rooms/{studyRoomId}/audit-logs`: 공부방별 히스토리

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

데이터를 변경하는 요청은 기본적으로 공부방 소유 선생님만 허용한다. MVP의 `admin` role은 관리자 조회 화면을 위한 권한이며, 출석 체크나 수정 요청에는 자동으로 쓰기 권한을 부여하지 않는다.

학생 출결 비밀번호 검증은 Edge Function에서 DB 함수 `verify_student_pin(target_student_id, plain_pin)`을 호출해 처리한다. Flutter 앱에는 비밀번호 해시나 검증 로직을 노출하지 않는다.

## 응답 원칙

- 앱에는 화면에 필요한 필드만 반환한다.
- 내부 테이블명과 컬럼명에 의존하는 응답 형태를 피한다.
- 오류 메시지는 사용자가 이해 가능한 수준으로 변환한다.

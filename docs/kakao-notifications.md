# Kakao Notifications

## 목적

출결 및 수업료 납부 관련 상태를 학부모에게 카카오 알림으로 전달한다.

## 발송 이벤트

- 학생 출석 완료
- 학생 지각/결석/조퇴 처리
- 수업 휴강
- 수업 보강
- 수업 날짜/시간 변경
- 수업료 납부 마감 전 미납 안내
- 수업료 납부 확인

## 설계 원칙

- 앱에서 직접 Kakao API key를 사용하지 않는다.
- 발송은 Supabase Edge Function에서 처리한다.
- 발송 성공/실패와 provider 응답 코드는 `notification_logs`에 저장한다.
- 출석 기록 저장과 알림 발송은 분리한다. 알림 실패가 출석 실패가 되면 안 된다.
- 한 보호자가 여러 학생을 가질 수 있으므로 알림 payload에는 항상 학생 이름과 수업 이름을 포함한다.
- 출석 알림에는 학생 이름, 수업 이름, 출석 상태, 출석 시간을 포함한다.
- 수업 변경 알림에는 학생 이름, 수업 이름, 기존 일정, 변경 일정, 변경 사유를 포함한다.
- 발송 이력은 학생별, 보호자별, 수업별로 조회 가능해야 한다.
- 보호자 전화번호는 발송 목적에 대한 동의가 있는 경우에만 사용한다.
- 발송 로그에는 보호자 전화번호 원문을 저장하지 않고 마스킹된 번호만 저장한다.
- 보호자가 수신 거부한 경우 카카오 알림을 발송하지 않는다.

## MVP 발송 플로우

1. 출석 기록 생성 또는 상태 변경
2. 수업 일정 변경, 납부 마감 안내 등 발송 이벤트 생성
3. `notification_logs`에 `pending` 로그 생성
4. `POST /notifications/process-pending`이 Kakao provider API 호출
5. 결과를 `notification_logs`의 `sent` 또는 `failed` 상태로 저장
6. 실패 건은 선생님 보드의 카카오 탭에서 재발송 요청 가능

## Edge Function 환경변수

서버 비밀값은 Supabase Edge Function secret으로만 설정한다. Flutter 앱이나 공개 repo에는 넣지 않는다.

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `KAKAO_PROVIDER_ENDPOINT`
- `KAKAO_PROVIDER_API_KEY`
- `KAKAO_SENDER_KEY`
- `KAKAO_TEMPLATE_ATTENDANCE_CHECKED_IN`
- `KAKAO_TEMPLATE_PAYMENT_DUE_REMINDER`
- `KAKAO_TEMPLATE_CLASS_CANCELLED`
- `KAKAO_TEMPLATE_CLASS_MAKEUP_ADDED`
- `KAKAO_TEMPLATE_DEFAULT`

`notification_logs`에는 `recipient_phone_masked`만 저장한다. 실제 발송 시 원문 전화번호는 `guardian_id`로 `guardians.phone`을 조회해 provider 호출에만 사용하고 로그 payload에는 저장하지 않는다.

## Provider 요청 형식

`POST /notifications/process-pending`은 provider endpoint로 다음 JSON을 전송한다.

- `senderKey`
- `recipientPhone`
- `eventType`
- `templateCode`
- `templateParams`
- `messageText`
- `payload`

Provider별 필드명이 다르면 `sendKakaoProviderMessage` adapter에서만 매핑한다. Flutter 앱에는 provider key와 템플릿 코드를 넣지 않는다.

## 출석 알림 예시 필드

- 학생 이름
- 수업 이름
- 출석 상태
- 출석 시간
- 보호자 이름

## 일정 변경 알림 예시 필드

- 학생 이름
- 수업 이름
- 변경 유형: 휴강, 보강, 시간 변경
- 기존 일정
- 변경 일정
- 변경 사유

## 필요한 결정

- 사용할 Kakao 발송 방식: 알림톡, 친구톡, 카카오톡 채널 메시지 중 선택
- 발송 대행사 사용 여부
- 템플릿 승인 문구
- 발신 프로필/채널

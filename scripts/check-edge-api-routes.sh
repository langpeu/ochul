#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

EDGE_API="supabase/functions/edge-api/index.ts"

check_route() {
  local label="$1"
  local pattern="$2"
  if ! rg -F "${pattern}" "${EDGE_API}" >/dev/null; then
    echo "Missing Edge API route for ${label}: expected pattern '${pattern}'" >&2
    return 1
  fi
}

check_route "GET /me" 'method === "GET" && path === "/me"'
check_route "POST /me/onboard" 'method === "POST" && path === "/me/onboard"'
check_route "GET/POST /study-rooms" 'path === "/study-rooms"'
check_route "GET/PATCH /study-rooms/{studyRoomId}" 'path.match(/^\/study-rooms\/([^/]+)$/)'
check_route "GET/POST /study-rooms/{studyRoomId}/students" '^\/study-rooms\/([^/]+)\/students$'
check_route "GET/PATCH/DELETE /students/{studentId}" 'path.match(/^\/students\/([^/]+)$/)'
check_route "POST /students/{studentId}/pin/reset" '^\/students\/([^/]+)\/pin\/reset$'
check_route "GET/PUT /students/{studentId}/guardians" 'path.match(/^\/students\/([^/]+)\/guardians$/)'
check_route "GET/POST /study-rooms/{studyRoomId}/classes" '^\/study-rooms\/([^/]+)\/classes$'
check_route "GET/PATCH/DELETE /classes/{classId}" 'path.match(/^\/classes\/([^/]+)$/)'
check_route "POST /classes/{classId}/sessions" 'path.match(/^\/classes\/([^/]+)\/sessions$/)'
check_route "POST /classes/{classId}/sessions/open" '^\/classes\/([^/]+)\/sessions\/open$'
check_route "PATCH /classes/{classId}/sessions/today" '^\/classes\/([^/]+)\/sessions\/today$'
check_route "PATCH /class-sessions/{classSessionId}" 'path.match(/^\/class-sessions\/([^/]+)$/)'
check_route "POST /classes/{classId}/sessions/cancel-today" '^\/classes\/([^/]+)\/sessions\/cancel-today$'
check_route "POST /classes/{classId}/sessions/makeup" '^\/classes\/([^/]+)\/sessions\/makeup$'
check_route "GET/PUT /classes/{classId}/classroom-layout" '^\/classes\/([^/]+)\/classroom-layout$'
check_route "PUT /classes/{classId}/seat-assignments" '^\/classes\/([^/]+)\/seat-assignments$'
check_route "POST /classes/{classId}/classroom-layout/copy" '^\/classes\/([^/]+)\/classroom-layout\/copy$'
check_route "GET/PUT /classes/{classId}/students" 'path.match(/^\/classes\/([^/]+)\/students$/)'
check_route "PATCH /classes/{classId}/students/order" '^\/classes\/([^/]+)\/students\/order$'
check_route "GET /attendance/today" 'method === "GET" && path === "/attendance/today"'
check_route "GET/PATCH /class-sessions/{classSessionId}/attendance" '^\/class-sessions\/([^/]+)\/attendance$'
check_route "POST /class-sessions/{classSessionId}/check-in" '^\/class-sessions\/([^/]+)\/check-in$'
check_route "POST /class-sessions/{classSessionId}/seat-check-in" '^\/class-sessions\/([^/]+)\/seat-check-in$'
check_route "PATCH /attendance-records/{attendanceRecordId}" 'path.match(/^\/attendance-records\/([^/]+)$/)'
check_route "GET/POST /study-rooms/{studyRoomId}/payment-periods" '^\/study-rooms\/([^/]+)\/payment-periods$'
check_route "GET /payment-periods/{paymentPeriodId}/statuses" '^\/payment-periods\/([^/]+)\/statuses$'
check_route "PATCH /payment-statuses/{paymentStatusId}" 'path.match(/^\/payment-statuses\/([^/]+)$/)'
check_route "POST /payment-periods/{paymentPeriodId}/unpaid/notify" '^\/payment-periods\/([^/]+)\/unpaid\/notify$'
check_route "POST /jobs/payments/unpaid/notify-due" 'method === "POST" && path === "/jobs/payments/unpaid/notify-due"'
check_route "GET /study-rooms/{studyRoomId}/notifications" '^\/study-rooms\/([^/]+)\/notifications$'
check_route "POST /notifications/{notificationId}/resend" '^\/notifications\/([^/]+)\/resend$'
check_route "POST /notifications/process-pending" 'method === "POST" && path === "/notifications/process-pending"'
check_route "GET /study-rooms/{studyRoomId}/audit-logs" '^\/study-rooms\/([^/]+)\/audit-logs$'
check_route "GET /admin/teachers" 'method === "GET" && path === "/admin/teachers"'
check_route "GET /admin/teachers/{teacherId}/study-rooms" '^\/admin\/teachers\/([^/]+)\/study-rooms$'
check_route "GET /admin/study-rooms/{studyRoomId}/students" '^\/admin\/study-rooms\/([^/]+)\/students$'
check_route "GET /admin/study-rooms/{studyRoomId}/audit-logs" '^\/admin\/study-rooms\/([^/]+)\/audit-logs$'
check_route "GET /admin/study-rooms/{studyRoomId}/notifications" '^\/admin\/study-rooms\/([^/]+)\/notifications$'

echo "Edge API route coverage check complete."

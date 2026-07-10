import {
  createClient,
  type SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

type EdgeMethod = "GET" | "POST" | "PUT" | "PATCH" | "DELETE";

type EdgeRequest = {
  method?: string;
  path?: string;
  body?: Record<string, unknown>;
};

type TeacherContext = {
  id: string;
  role: "admin" | "teacher" | string;
};

type GuardianContact = {
  id: string;
  phone: string;
  kakao_opt_in: boolean;
  opt_out_at: string | null;
  deleted_at: string | null;
};

type AppContext = {
  db: SupabaseClient;
  teacher: TeacherContext;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const pinPattern = /^\d{6}$/;

serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonError(405, "Edge API는 POST 요청만 허용합니다.");
  }

  try {
    const payload = await readPayload(request);
    const db = createServiceClient();
    const teacher = await requireTeacher(request, db);
    const response = await routeEdgeRequest(payload, { db, teacher });
    return json(response);
  } catch (error) {
    return handleError(error);
  }
});

async function routeEdgeRequest(
  payload: EdgeRequest,
  context: AppContext,
): Promise<Record<string, unknown>> {
  const method = normalizeMethod(payload.method);
  const path = normalizePath(payload.path);
  const body = payload.body ?? {};

  const checkInMatch = path.match(
    /^\/class-sessions\/([^/]+)\/check-in$/,
  );
  if (method === "POST" && checkInMatch) {
    return await checkInStudent(checkInMatch[1], body, context);
  }

  throw new EdgeApiError(404, "지원하지 않는 API 경로입니다.");
}

async function checkInStudent(
  classSessionId: string,
  body: Record<string, unknown>,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const studentId = stringValue(body.studentId);
  const pin = stringValue(body.pin);

  assertUuid(classSessionId, "수업 회차 정보가 올바르지 않습니다.");
  assertUuid(studentId, "학생 정보가 올바르지 않습니다.");
  if (!pinPattern.test(pin)) {
    throw new EdgeApiError(400, "출결 비밀번호는 숫자 6자리여야 합니다.");
  }

  const session = await readClassSession(db, classSessionId);
  await assertStudyRoomAccess(db, teacher, session.study_room_id, {
    allowAdmin: false,
  });

  if (session.status !== "open") {
    throw new EdgeApiError(409, "현재 출석 체크가 열려있는 수업이 아닙니다.");
  }

  const student = await readStudent(db, studentId, session.study_room_id);
  await assertStudentEnrollment(db, session.class_id, studentId);

  const pinMatches = await verifyStudentPin(db, studentId, pin);
  if (!pinMatches) {
    throw new EdgeApiError(401, "출결 비밀번호가 일치하지 않습니다.");
  }

  const existingRecord = await readExistingAttendance(
    db,
    classSessionId,
    studentId,
  );
  if (existingRecord) {
    return {
      ok: true,
      alreadyCheckedIn: true,
      attendance: {
        id: existingRecord.id,
        status: existingRecord.status,
        checkedInAt: existingRecord.checked_in_at,
      },
    };
  }

  const attendance = await createAttendanceRecord(db, {
    organizationId: session.organization_id,
    studyRoomId: session.study_room_id,
    classSessionId,
    studentId,
    teacherId: teacher.id,
  });

  const classInfo = await readClassInfo(db, session.class_id);
  const notifications = await createAttendanceNotificationLogs(db, {
    organizationId: session.organization_id,
    studyRoomId: session.study_room_id,
    classId: session.class_id,
    classSessionId,
    attendanceRecordId: attendance.id,
    studentId,
    studentName: student.name,
    className: classInfo.name,
    checkedInAt: attendance.checked_in_at,
  });

  await createAuditLog(db, {
    organizationId: session.organization_id,
    studyRoomId: session.study_room_id,
    actorTeacherId: teacher.id,
    studentId,
    classId: session.class_id,
    classSessionId,
    entityId: attendance.id,
    title: "학생 출석 체크",
    summary: `${student.name} 학생이 ${classInfo.name} 수업에 출석했습니다.`,
  });

  return {
    ok: true,
    alreadyCheckedIn: false,
    attendance: {
      id: attendance.id,
      status: attendance.status,
      checkedInAt: attendance.checked_in_at,
    },
    notifications: {
      requested: notifications.length,
    },
  };
}

async function readClassSession(db: SupabaseClient, classSessionId: string) {
  const { data, error } = await db
    .from("class_sessions")
    .select("id, organization_id, study_room_id, class_id, status")
    .eq("id", classSessionId)
    .maybeSingle();

  if (error) throw new EdgeApiError(500, "수업 회차 조회에 실패했습니다.");
  if (!data) throw new EdgeApiError(404, "수업 회차를 찾을 수 없습니다.");
  return data;
}

async function assertStudyRoomAccess(
  db: SupabaseClient,
  teacher: TeacherContext,
  studyRoomId: string,
  options: { allowAdmin: boolean },
) {
  if (options.allowAdmin && teacher.role === "admin") return;

  const { data, error } = await db
    .from("study_rooms")
    .select("id")
    .eq("id", studyRoomId)
    .eq("owner_teacher_id", teacher.id)
    .maybeSingle();

  if (error) throw new EdgeApiError(500, "공부방 권한 확인에 실패했습니다.");
  if (!data) throw new EdgeApiError(403, "해당 공부방에 접근할 수 없습니다.");
}

async function readStudent(
  db: SupabaseClient,
  studentId: string,
  studyRoomId: string,
) {
  const { data, error } = await db
    .from("students")
    .select("id, name, status")
    .eq("id", studentId)
    .eq("study_room_id", studyRoomId)
    .eq("status", "active")
    .maybeSingle();

  if (error) throw new EdgeApiError(500, "학생 조회에 실패했습니다.");
  if (!data) {
    throw new EdgeApiError(404, "출석 가능한 학생을 찾을 수 없습니다.");
  }
  return data;
}

async function assertStudentEnrollment(
  db: SupabaseClient,
  classId: string,
  studentId: string,
) {
  const { data, error } = await db
    .from("class_students")
    .select("class_id")
    .eq("class_id", classId)
    .eq("student_id", studentId)
    .eq("active", true)
    .maybeSingle();

  if (error) throw new EdgeApiError(500, "수강 등록 확인에 실패했습니다.");
  if (!data) throw new EdgeApiError(403, "해당 수업에 등록된 학생이 아닙니다.");
}

async function verifyStudentPin(
  db: SupabaseClient,
  studentId: string,
  pin: string,
) {
  const { data, error } = await db.rpc("verify_student_pin", {
    target_student_id: studentId,
    plain_pin: pin,
  });

  if (error) throw new EdgeApiError(500, "출결 비밀번호 확인에 실패했습니다.");
  return data === true;
}

async function readExistingAttendance(
  db: SupabaseClient,
  classSessionId: string,
  studentId: string,
) {
  const { data, error } = await db
    .from("attendance_records")
    .select("id, status, checked_in_at")
    .eq("class_session_id", classSessionId)
    .eq("student_id", studentId)
    .maybeSingle();

  if (error) throw new EdgeApiError(500, "출석 기록 조회에 실패했습니다.");
  return data;
}

async function createAttendanceRecord(
  db: SupabaseClient,
  input: {
    organizationId: string;
    studyRoomId: string;
    classSessionId: string;
    studentId: string;
    teacherId: string;
  },
) {
  const { data, error } = await db
    .from("attendance_records")
    .insert({
      organization_id: input.organizationId,
      study_room_id: input.studyRoomId,
      class_session_id: input.classSessionId,
      student_id: input.studentId,
      status: "present",
      checked_in_at: new Date().toISOString(),
      checked_in_method: "student_pin",
      created_by_teacher_id: input.teacherId,
      updated_by_teacher_id: input.teacherId,
    })
    .select("id, status, checked_in_at")
    .single();

  if (error) throw new EdgeApiError(500, "출석 기록 생성에 실패했습니다.");
  return data;
}

async function readClassInfo(db: SupabaseClient, classId: string) {
  const { data, error } = await db
    .from("classes")
    .select("id, name")
    .eq("id", classId)
    .single();

  if (error) throw new EdgeApiError(500, "수업 정보 조회에 실패했습니다.");
  return data;
}

async function createAttendanceNotificationLogs(
  db: SupabaseClient,
  input: {
    organizationId: string;
    studyRoomId: string;
    classId: string;
    classSessionId: string;
    attendanceRecordId: string;
    studentId: string;
    studentName: string;
    className: string;
    checkedInAt: string;
  },
) {
  const { data: guardians, error } = await db
    .from("student_guardians")
    .select("guardians!inner(id, phone, kakao_opt_in, opt_out_at, deleted_at)")
    .eq("student_id", input.studentId);

  if (error) {
    throw new EdgeApiError(500, "보호자 알림 대상 조회에 실패했습니다.");
  }

  const rows = (guardians ?? [])
    .flatMap((row) => normalizeGuardianContact(row.guardians))
    .filter((guardian) =>
      guardian.kakao_opt_in === true &&
      guardian.opt_out_at === null &&
      guardian.deleted_at === null
    )
    .map((guardian) => ({
      organization_id: input.organizationId,
      study_room_id: input.studyRoomId,
      student_id: input.studentId,
      guardian_id: guardian.id,
      class_id: input.classId,
      class_session_id: input.classSessionId,
      attendance_record_id: input.attendanceRecordId,
      event_type: "attendance_checked_in",
      channel: "kakao",
      recipient_phone_masked: maskPhone(guardian.phone),
      student_name: input.studentName,
      class_name: input.className,
      event_time: input.checkedInAt,
      payload: {
        studentName: input.studentName,
        className: input.className,
        attendanceStatus: "present",
        checkedInAt: input.checkedInAt,
      },
      status: "pending",
    }));

  if (rows.length === 0) return [];

  const { data, error: insertError } = await db
    .from("notification_logs")
    .insert(rows)
    .select("id");

  if (insertError) {
    throw new EdgeApiError(500, "카카오 알림 로그 생성에 실패했습니다.");
  }
  return data ?? [];
}

async function createAuditLog(
  db: SupabaseClient,
  input: {
    organizationId: string;
    studyRoomId: string;
    actorTeacherId: string;
    studentId: string;
    classId: string;
    classSessionId: string;
    entityId: string;
    title: string;
    summary: string;
  },
) {
  const { error } = await db.from("audit_logs").insert({
    organization_id: input.organizationId,
    study_room_id: input.studyRoomId,
    actor_teacher_id: input.actorTeacherId,
    student_id: input.studentId,
    class_id: input.classId,
    class_session_id: input.classSessionId,
    entity_type: "attendance",
    entity_id: input.entityId,
    action: "checked_in",
    title: input.title,
    summary: input.summary,
  });

  if (error) throw new EdgeApiError(500, "사용 히스토리 기록에 실패했습니다.");
}

async function requireTeacher(
  request: Request,
  db: SupabaseClient,
): Promise<TeacherContext> {
  const authHeader = request.headers.get("authorization");
  const jwt = authHeader?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!jwt) throw new EdgeApiError(401, "로그인이 필요합니다.");

  const { data: userData, error: userError } = await db.auth.getUser(jwt);
  if (userError || !userData.user) {
    throw new EdgeApiError(401, "로그인 정보를 확인할 수 없습니다.");
  }

  const { data: teacher, error: teacherError } = await db
    .from("teachers")
    .select("id, role")
    .eq("auth_user_id", userData.user.id)
    .maybeSingle();

  if (teacherError) {
    throw new EdgeApiError(500, "선생님 프로필 조회에 실패했습니다.");
  }
  if (!teacher) throw new EdgeApiError(403, "선생님 프로필이 필요합니다.");

  return { id: teacher.id, role: teacher.role };
}

function createServiceClient() {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    throw new EdgeApiError(
      500,
      "Supabase 서버 환경변수가 설정되지 않았습니다.",
    );
  }
  return createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

async function readPayload(request: Request): Promise<EdgeRequest> {
  const payload = await request.json().catch(() => null);
  if (!payload || typeof payload !== "object") {
    throw new EdgeApiError(400, "요청 형식이 올바르지 않습니다.");
  }
  return payload as EdgeRequest;
}

function normalizeMethod(method: unknown): EdgeMethod {
  if (typeof method !== "string") {
    throw new EdgeApiError(400, "HTTP method가 필요합니다.");
  }
  const normalized = method.toUpperCase();
  if (!["GET", "POST", "PUT", "PATCH", "DELETE"].includes(normalized)) {
    throw new EdgeApiError(400, "지원하지 않는 HTTP method입니다.");
  }
  return normalized as EdgeMethod;
}

function normalizePath(path: unknown): string {
  if (typeof path !== "string" || !path.startsWith("/")) {
    throw new EdgeApiError(400, "API path가 필요합니다.");
  }
  return path.replace(/\/+$/, "") || "/";
}

function stringValue(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function assertUuid(value: string, message: string) {
  if (!uuidPattern.test(value)) throw new EdgeApiError(400, message);
}

function maskPhone(phone: string) {
  const digits = phone.replace(/\D/g, "");
  if (digits.length < 7) return "****";
  return `${digits.slice(0, 3)}****${digits.slice(-4)}`;
}

function normalizeGuardianContact(value: unknown): GuardianContact[] {
  if (Array.isArray(value)) {
    return value.filter(isGuardianContact);
  }
  return isGuardianContact(value) ? [value] : [];
}

function isGuardianContact(value: unknown): value is GuardianContact {
  if (!value || typeof value !== "object") return false;
  const candidate = value as Partial<GuardianContact>;
  return typeof candidate.id === "string" &&
    typeof candidate.phone === "string" &&
    typeof candidate.kakao_opt_in === "boolean";
}

function handleError(error: unknown) {
  if (error instanceof EdgeApiError) {
    return jsonError(error.status, error.message);
  }
  console.error(error);
  return jsonError(500, "서버 처리 중 문제가 발생했습니다.");
}

function json(data: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function jsonError(status: number, message: string) {
  return json({ ok: false, error: { message } }, status);
}

class EdgeApiError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
  }
}

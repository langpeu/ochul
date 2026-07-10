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

type AuthUserContext = {
  id: string;
  email: string | null;
  name: string | null;
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
  authUser: AuthUserContext;
  teacher: TeacherContext | null;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-ochul-job-secret",
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
    if (isInternalJobPath(payload.path)) {
      requireInternalJobSecret(request);
      const response = await routeInternalJobRequest(payload, { db });
      return json(response);
    }
    const authUser = await requireAuthUser(request, db);
    const teacher = await readTeacherByAuthUser(db, authUser.id);
    const response = await routeEdgeRequest(payload, { db, authUser, teacher });
    return json(response);
  } catch (error) {
    return handleError(error);
  }
});

async function routeInternalJobRequest(
  payload: EdgeRequest,
  context: { db: SupabaseClient },
): Promise<Record<string, unknown>> {
  const method = normalizeMethod(payload.method);
  const path = normalizePath(payload.path);
  const body = payload.body ?? {};

  if (method === "POST" && path === "/jobs/payments/unpaid/notify-due") {
    return await notifyDueUnpaidPayments(body, context);
  }

  throw new EdgeApiError(404, "지원하지 않는 내부 작업 경로입니다.");
}

async function routeEdgeRequest(
  payload: EdgeRequest,
  context: AppContext,
): Promise<Record<string, unknown>> {
  const method = normalizeMethod(payload.method);
  const path = normalizePath(payload.path);
  const body = payload.body ?? {};

  if (method === "GET" && path === "/me") {
    return await readMe(context);
  }

  if (method === "POST" && path === "/me/onboard") {
    return await onboardTeacher(body, context);
  }

  if (path === "/study-rooms") {
    if (method === "GET") {
      return await listStudyRooms(context);
    }
    if (method === "POST") {
      return await createStudyRoom(body, context);
    }
  }

  const studyRoomMatch = path.match(/^\/study-rooms\/([^/]+)$/);
  if (studyRoomMatch) {
    if (method === "GET") {
      return await getStudyRoom(studyRoomMatch[1], context);
    }
    if (method === "PATCH") {
      return await updateStudyRoom(studyRoomMatch[1], body, context);
    }
  }

  if (method === "GET" && path === "/admin/teachers") {
    return await listAdminTeachers(context);
  }

  const adminTeacherStudyRoomsMatch = path.match(
    /^\/admin\/teachers\/([^/]+)\/study-rooms$/,
  );
  if (method === "GET" && adminTeacherStudyRoomsMatch) {
    return await listAdminTeacherStudyRooms(
      adminTeacherStudyRoomsMatch[1],
      context,
    );
  }

  const adminStudyRoomStudentsMatch = path.match(
    /^\/admin\/study-rooms\/([^/]+)\/students$/,
  );
  if (method === "GET" && adminStudyRoomStudentsMatch) {
    return await listAdminStudyRoomStudents(
      adminStudyRoomStudentsMatch[1],
      context,
    );
  }

  const adminStudyRoomAuditLogsMatch = path.match(
    /^\/admin\/study-rooms\/([^/]+)\/audit-logs$/,
  );
  if (method === "GET" && adminStudyRoomAuditLogsMatch) {
    return await listAdminStudyRoomAuditLogs(
      adminStudyRoomAuditLogsMatch[1],
      body,
      context,
    );
  }

  const adminStudyRoomNotificationsMatch = path.match(
    /^\/admin\/study-rooms\/([^/]+)\/notifications$/,
  );
  if (method === "GET" && adminStudyRoomNotificationsMatch) {
    return await listAdminStudyRoomNotifications(
      adminStudyRoomNotificationsMatch[1],
      body,
      context,
    );
  }

  const studyRoomStudentsMatch = path.match(
    /^\/study-rooms\/([^/]+)\/students$/,
  );
  if (studyRoomStudentsMatch) {
    if (method === "GET") {
      return await listStudents(studyRoomStudentsMatch[1], context);
    }
    if (method === "POST") {
      return await createStudent(studyRoomStudentsMatch[1], body, context);
    }
  }

  const studentMatch = path.match(/^\/students\/([^/]+)$/);
  if (studentMatch) {
    if (method === "PATCH") {
      return await updateStudent(studentMatch[1], body, context);
    }
    if (method === "DELETE") {
      return await leaveStudent(studentMatch[1], context);
    }
  }

  const resetStudentPinMatch = path.match(/^\/students\/([^/]+)\/pin\/reset$/);
  if (method === "POST" && resetStudentPinMatch) {
    return await resetStudentPin(resetStudentPinMatch[1], body, context);
  }

  const studentGuardiansMatch = path.match(/^\/students\/([^/]+)\/guardians$/);
  if (studentGuardiansMatch) {
    if (method === "GET") {
      return await listStudentGuardians(studentGuardiansMatch[1], context);
    }
    if (method === "PUT") {
      return await saveStudentGuardians(
        studentGuardiansMatch[1],
        body,
        context,
      );
    }
  }

  const studyRoomClassesMatch = path.match(
    /^\/study-rooms\/([^/]+)\/classes$/,
  );
  if (studyRoomClassesMatch) {
    if (method === "GET") {
      return await listClasses(studyRoomClassesMatch[1], context);
    }
    if (method === "POST") {
      return await createClass(studyRoomClassesMatch[1], body, context);
    }
  }

  const classMatch = path.match(/^\/classes\/([^/]+)$/);
  if (classMatch) {
    if (method === "PATCH") {
      return await updateClass(classMatch[1], body, context);
    }
    if (method === "DELETE") {
      return await deleteClass(classMatch[1], context);
    }
  }

  const classLayoutMatch = path.match(
    /^\/classes\/([^/]+)\/classroom-layout$/,
  );
  if (classLayoutMatch) {
    if (method === "GET") {
      return await getClassroomLayout(classLayoutMatch[1], context);
    }
    if (method === "PUT") {
      return await saveClassroomLayout(classLayoutMatch[1], body, context);
    }
  }

  const seatAssignmentsMatch = path.match(
    /^\/classes\/([^/]+)\/seat-assignments$/,
  );
  if (method === "PUT" && seatAssignmentsMatch) {
    return await saveSeatAssignments(seatAssignmentsMatch[1], body, context);
  }

  const copyClassroomLayoutMatch = path.match(
    /^\/classes\/([^/]+)\/classroom-layout\/copy$/,
  );
  if (method === "POST" && copyClassroomLayoutMatch) {
    return await copyClassroomLayout(
      copyClassroomLayoutMatch[1],
      body,
      context,
    );
  }

  const studyRoomAuditLogsMatch = path.match(
    /^\/study-rooms\/([^/]+)\/audit-logs$/,
  );
  if (method === "GET" && studyRoomAuditLogsMatch) {
    return await listAuditLogs(studyRoomAuditLogsMatch[1], body, context);
  }

  const studyRoomNotificationsMatch = path.match(
    /^\/study-rooms\/([^/]+)\/notifications$/,
  );
  if (method === "GET" && studyRoomNotificationsMatch) {
    return await listNotifications(
      studyRoomNotificationsMatch[1],
      body,
      context,
    );
  }

  const resendNotificationMatch = path.match(
    /^\/notifications\/([^/]+)\/resend$/,
  );
  if (method === "POST" && resendNotificationMatch) {
    return await resendNotification(resendNotificationMatch[1], context);
  }

  if (method === "POST" && path === "/notifications/process-pending") {
    return await processPendingNotifications(body, context);
  }

  const paymentPeriodsMatch = path.match(
    /^\/study-rooms\/([^/]+)\/payment-periods$/,
  );
  if (paymentPeriodsMatch) {
    if (method === "GET") {
      return await listPaymentPeriods(paymentPeriodsMatch[1], context);
    }
    if (method === "POST") {
      return await createPaymentPeriod(paymentPeriodsMatch[1], body, context);
    }
  }

  const paymentStatusesMatch = path.match(
    /^\/payment-periods\/([^/]+)\/statuses$/,
  );
  if (method === "GET" && paymentStatusesMatch) {
    return await listPaymentStatuses(paymentStatusesMatch[1], context);
  }

  const paymentUnpaidMatch = path.match(
    /^\/payment-periods\/([^/]+)\/unpaid\/notify$/,
  );
  if (method === "POST" && paymentUnpaidMatch) {
    return await notifyUnpaidPayments(paymentUnpaidMatch[1], context);
  }

  const paymentStatusMatch = path.match(/^\/payment-statuses\/([^/]+)$/);
  if (method === "PATCH" && paymentStatusMatch) {
    return await updatePaymentStatus(paymentStatusMatch[1], body, context);
  }

  const classStudentsMatch = path.match(/^\/classes\/([^/]+)\/students$/);
  if (classStudentsMatch) {
    if (method === "GET") {
      return await listClassStudents(classStudentsMatch[1], context);
    }
    if (method === "PUT") {
      return await saveClassStudents(classStudentsMatch[1], body, context);
    }
  }

  const classStudentOrderMatch = path.match(
    /^\/classes\/([^/]+)\/students\/order$/,
  );
  if (method === "PATCH" && classStudentOrderMatch) {
    return await updateClassStudentOrder(
      classStudentOrderMatch[1],
      body,
      context,
    );
  }

  const openClassSessionMatch = path.match(
    /^\/classes\/([^/]+)\/sessions\/open$/,
  );
  if (method === "POST" && openClassSessionMatch) {
    return await openClassSession(openClassSessionMatch[1], context);
  }

  const cancelClassSessionMatch = path.match(
    /^\/classes\/([^/]+)\/sessions\/cancel-today$/,
  );
  if (method === "POST" && cancelClassSessionMatch) {
    return await cancelTodayClassSession(
      cancelClassSessionMatch[1],
      body,
      context,
    );
  }

  const todayClassSessionMatch = path.match(
    /^\/classes\/([^/]+)\/sessions\/today$/,
  );
  if (method === "PATCH" && todayClassSessionMatch) {
    return await rescheduleTodayClassSession(
      todayClassSessionMatch[1],
      body,
      context,
    );
  }

  const makeupClassSessionMatch = path.match(
    /^\/classes\/([^/]+)\/sessions\/makeup$/,
  );
  if (method === "POST" && makeupClassSessionMatch) {
    return await createMakeupClassSession(
      makeupClassSessionMatch[1],
      body,
      context,
    );
  }

  if (method === "GET" && path === "/attendance/today") {
    return await listTodayAttendance(context);
  }

  const classSessionAttendanceMatch = path.match(
    /^\/class-sessions\/([^/]+)\/attendance$/,
  );
  if (classSessionAttendanceMatch) {
    if (method === "GET") {
      return await listClassSessionAttendance(
        classSessionAttendanceMatch[1],
        context,
      );
    }
    if (method === "PATCH") {
      return await updateClassSessionAttendance(
        classSessionAttendanceMatch[1],
        body,
        context,
      );
    }
  }

  const checkInMatch = path.match(
    /^\/class-sessions\/([^/]+)\/check-in$/,
  );
  if (method === "POST" && checkInMatch) {
    return await checkInStudent(checkInMatch[1], body, context);
  }

  const seatCheckInMatch = path.match(
    /^\/class-sessions\/([^/]+)\/seat-check-in$/,
  );
  if (method === "POST" && seatCheckInMatch) {
    return await seatCheckInStudent(seatCheckInMatch[1], body, context);
  }

  throw new EdgeApiError(404, "지원하지 않는 API 경로입니다.");
}

async function readMe(
  { db, authUser, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  if (!teacher) {
    return {
      ok: true,
      needsOnboarding: true,
      authUser: {
        id: authUser.id,
        email: authUser.email,
        name: authUser.name,
      },
      teacher: null,
      studyRooms: [],
    };
  }

  const { data: teacherProfile, error: teacherError } = await db
    .from("teachers")
    .select("id, name, email, role")
    .eq("id", teacher.id)
    .single();

  if (teacherError) {
    throw new EdgeApiError(500, "선생님 프로필 조회에 실패했습니다.");
  }

  const { data: studyRooms, error: studyRoomsError } = await db
    .from("study_rooms")
    .select("id, name, description, created_at")
    .eq("owner_teacher_id", teacher.id)
    .order("created_at", { ascending: true });

  if (studyRoomsError) {
    throw new EdgeApiError(500, "공부방 목록 조회에 실패했습니다.");
  }

  return {
    ok: true,
    needsOnboarding: false,
    teacher: {
      id: teacherProfile.id,
      name: teacherProfile.name,
      email: teacherProfile.email,
      role: teacherProfile.role,
    },
    studyRooms: (studyRooms ?? []).map((studyRoom) => ({
      id: studyRoom.id,
      name: studyRoom.name,
      description: studyRoom.description,
    })),
  };
}

async function onboardTeacher(
  body: Record<string, unknown>,
  { db, authUser, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  if (teacher) {
    return await readMe({ db, authUser, teacher });
  }

  const teacherName = stringValue(body.teacherName) || authUser.name ||
    authUser.email?.split("@")[0] || "선생님";
  const studyRoomName = stringValue(body.studyRoomName);
  if (teacherName.length < 2) {
    throw new EdgeApiError(400, "선생님 이름은 2자 이상 입력해 주세요.");
  }
  if (studyRoomName.length < 2) {
    throw new EdgeApiError(400, "공부방 이름은 2자 이상 입력해 주세요.");
  }

  const { data: organization, error: organizationError } = await db
    .from("organizations")
    .insert({ name: studyRoomName })
    .select("id")
    .single();

  if (organizationError) {
    throw new EdgeApiError(500, "운영 공간 생성에 실패했습니다.");
  }

  const { data: teacherProfile, error: teacherError } = await db
    .from("teachers")
    .insert({
      organization_id: organization.id,
      auth_user_id: authUser.id,
      name: teacherName,
      email: authUser.email,
      role: "teacher",
    })
    .select("id, name, email, role")
    .single();

  if (teacherError) {
    throw new EdgeApiError(500, "선생님 프로필 생성에 실패했습니다.");
  }

  const { data: studyRoom, error: studyRoomError } = await db
    .from("study_rooms")
    .insert({
      organization_id: organization.id,
      name: studyRoomName,
      owner_teacher_id: teacherProfile.id,
    })
    .select("id, name, description")
    .single();

  if (studyRoomError) {
    throw new EdgeApiError(500, "공부방 생성에 실패했습니다.");
  }

  const { error: memberError } = await db.from("study_room_members").insert({
    study_room_id: studyRoom.id,
    teacher_id: teacherProfile.id,
    role: "owner",
  });

  if (memberError) {
    throw new EdgeApiError(500, "공부방 권한 생성에 실패했습니다.");
  }

  return {
    ok: true,
    needsOnboarding: false,
    teacher: {
      id: teacherProfile.id,
      name: teacherProfile.name,
      email: teacherProfile.email,
      role: teacherProfile.role,
    },
    studyRooms: [{
      id: studyRoom.id,
      name: studyRoom.name,
      description: studyRoom.description,
    }],
  };
}

async function listStudyRooms(
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  const { data: studyRooms, error } = await db
    .from("study_rooms")
    .select("id, name, description, created_at")
    .eq("owner_teacher_id", activeTeacher.id)
    .order("created_at", { ascending: true });

  if (error) throw new EdgeApiError(500, "공부방 목록 조회에 실패했습니다.");

  return {
    ok: true,
    studyRooms: (studyRooms ?? []).map(formatStudyRoomSummary),
  };
}

async function getStudyRoom(
  studyRoomId: string,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(studyRoomId, "공부방 정보가 올바르지 않습니다.");
  const studyRoom = await readAccessibleStudyRoom(
    db,
    studyRoomId,
    activeTeacher,
    { allowAdmin: true },
  );
  return { ok: true, studyRoom: formatStudyRoomSummary(studyRoom) };
}

async function createStudyRoom(
  body: Record<string, unknown>,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  if (activeTeacher.role === "admin") {
    throw new EdgeApiError(403, "관리자는 공부방을 생성할 수 없습니다.");
  }

  const name = stringValue(body.name);
  const description = nullableString(body.description);
  if (name.length < 2) {
    throw new EdgeApiError(400, "공부방 이름은 2자 이상 입력해 주세요.");
  }

  const teacherProfile = await readTeacherProfileForWrite(db, activeTeacher.id);
  const { data: studyRoom, error: studyRoomError } = await db
    .from("study_rooms")
    .insert({
      organization_id: teacherProfile.organization_id,
      name,
      description,
      owner_teacher_id: activeTeacher.id,
    })
    .select("id, name, description, created_at")
    .single();

  if (studyRoomError) {
    throw new EdgeApiError(500, "공부방 생성에 실패했습니다.");
  }

  const { error: memberError } = await db.from("study_room_members").insert({
    study_room_id: studyRoom.id,
    teacher_id: activeTeacher.id,
    role: "owner",
  });

  if (memberError) {
    throw new EdgeApiError(500, "공부방 권한 생성에 실패했습니다.");
  }

  await createStudyRoomAuditLog(db, {
    organizationId: teacherProfile.organization_id,
    studyRoomId: studyRoom.id,
    actorTeacherId: activeTeacher.id,
    action: "created",
    title: "공부방 등록",
    summary: `${studyRoom.name} 공부방을 등록했습니다.`,
  });

  return { ok: true, studyRoom: formatStudyRoomSummary(studyRoom) };
}

async function updateStudyRoom(
  studyRoomId: string,
  body: Record<string, unknown>,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(studyRoomId, "공부방 정보가 올바르지 않습니다.");
  const current = await readAccessibleStudyRoom(
    db,
    studyRoomId,
    activeTeacher,
    { allowAdmin: false },
  );

  const name = stringValue(body.name);
  const description = nullableString(body.description);
  if (name.length < 2) {
    throw new EdgeApiError(400, "공부방 이름은 2자 이상 입력해 주세요.");
  }

  const { data: studyRoom, error } = await db
    .from("study_rooms")
    .update({ name, description })
    .eq("id", studyRoomId)
    .eq("owner_teacher_id", activeTeacher.id)
    .select("id, name, description, created_at")
    .single();

  if (error) throw new EdgeApiError(500, "공부방 수정에 실패했습니다.");

  await createStudyRoomAuditLog(db, {
    organizationId: current.organization_id,
    studyRoomId,
    actorTeacherId: activeTeacher.id,
    action: "updated",
    title: "공부방 수정",
    summary: `${studyRoom.name} 공부방 정보를 수정했습니다.`,
  });

  return { ok: true, studyRoom: formatStudyRoomSummary(studyRoom) };
}

async function listAdminTeachers(
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  requireAdminTeacher(teacher);

  const { data: teachers, error } = await db
    .from("teachers")
    .select("id, name, email, role, created_at")
    .order("created_at", { ascending: false });

  if (error) throw new EdgeApiError(500, "선생님 목록 조회에 실패했습니다.");

  return {
    ok: true,
    teachers: (teachers ?? []).map((item) => ({
      id: item.id,
      name: item.name,
      email: item.email,
      role: item.role,
      createdAt: item.created_at,
    })),
  };
}

async function listAdminTeacherStudyRooms(
  teacherId: string,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  requireAdminTeacher(teacher);
  assertUuid(teacherId, "선생님 정보가 올바르지 않습니다.");

  const { data: studyRooms, error } = await db
    .from("study_rooms")
    .select("id, name, description, created_at")
    .eq("owner_teacher_id", teacherId)
    .order("created_at", { ascending: true });

  if (error) throw new EdgeApiError(500, "공부방 목록 조회에 실패했습니다.");

  return {
    ok: true,
    studyRooms: (studyRooms ?? []).map((studyRoom) => ({
      id: studyRoom.id,
      name: studyRoom.name,
      description: studyRoom.description,
      createdAt: studyRoom.created_at,
    })),
  };
}

async function listAdminStudyRoomStudents(
  studyRoomId: string,
  context: AppContext,
): Promise<Record<string, unknown>> {
  requireAdminTeacher(context.teacher);
  return await listStudents(studyRoomId, context);
}

async function listAdminStudyRoomAuditLogs(
  studyRoomId: string,
  body: Record<string, unknown>,
  context: AppContext,
): Promise<Record<string, unknown>> {
  requireAdminTeacher(context.teacher);
  return await listAuditLogs(studyRoomId, body, context);
}

async function listAdminStudyRoomNotifications(
  studyRoomId: string,
  body: Record<string, unknown>,
  context: AppContext,
): Promise<Record<string, unknown>> {
  requireAdminTeacher(context.teacher);
  return await listNotifications(studyRoomId, body, context);
}

async function listClasses(
  studyRoomId: string,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(studyRoomId, "공부방 정보가 올바르지 않습니다.");
  await assertStudyRoomAccess(db, activeTeacher, studyRoomId, {
    allowAdmin: true,
  });

  const { data: classes, error } = await db
    .from("classes")
    .select(
      "id, name, description, class_kind, start_date, end_date, schedule_text, active, class_schedules(day_of_week, starts_at, ends_at, active)",
    )
    .eq("study_room_id", studyRoomId)
    .eq("active", true)
    .order("created_at", { ascending: false });

  if (error) throw new EdgeApiError(500, "수업 목록 조회에 실패했습니다.");

  return {
    ok: true,
    classes: (classes ?? []).map(formatClassSummary),
  };
}

async function createClass(
  studyRoomId: string,
  body: Record<string, unknown>,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(studyRoomId, "공부방 정보가 올바르지 않습니다.");
  await assertStudyRoomAccess(db, activeTeacher, studyRoomId, {
    allowAdmin: false,
  });

  const name = stringValue(body.name);
  const description = nullableString(body.description);
  const classKind = normalizeClassKind(body.classKind);
  const startDate = stringValue(body.startDate);
  const endDate = stringValue(body.endDate);
  const dayOfWeeks = normalizeDayOfWeeks(body.dayOfWeeks);
  const startsAt = normalizeTime(
    body.startsAt,
    "수업 시작 시간을 입력해 주세요.",
  );
  const endsAt = normalizeTime(body.endsAt, "수업 종료 시간을 입력해 주세요.");

  if (name.length < 2) throw new EdgeApiError(400, "수업명을 입력해 주세요.");
  assertDate(startDate, "수업 시작일이 올바르지 않습니다.");
  assertDate(endDate, "수업 종료일이 올바르지 않습니다.");
  if (endDate < startDate) {
    throw new EdgeApiError(400, "수업 종료일은 시작일 이후여야 합니다.");
  }
  if (startsAt >= endsAt) {
    throw new EdgeApiError(400, "수업 종료 시간은 시작 시간 이후여야 합니다.");
  }

  const { data: studyRoom, error: studyRoomError } = await db
    .from("study_rooms")
    .select("id, organization_id")
    .eq("id", studyRoomId)
    .eq("owner_teacher_id", activeTeacher.id)
    .single();

  if (studyRoomError) {
    throw new EdgeApiError(500, "공부방 조회에 실패했습니다.");
  }

  const scheduleText = formatScheduleText(dayOfWeeks, startsAt, endsAt);
  const { data: classRoom, error: classError } = await db
    .from("classes")
    .insert({
      organization_id: studyRoom.organization_id,
      study_room_id: studyRoomId,
      teacher_id: activeTeacher.id,
      name,
      description,
      class_kind: classKind,
      start_date: startDate,
      end_date: endDate,
      schedule_text: scheduleText,
      active: true,
    })
    .select(
      "id, name, description, class_kind, start_date, end_date, schedule_text, active",
    )
    .single();

  if (classError) throw new EdgeApiError(500, "수업 생성에 실패했습니다.");

  const scheduleRows = dayOfWeeks.map((dayOfWeek) => ({
    class_id: classRoom.id,
    day_of_week: dayOfWeek,
    starts_at: startsAt,
    ends_at: endsAt,
  }));
  const { data: schedules, error: scheduleError } = await db
    .from("class_schedules")
    .insert(scheduleRows)
    .select("day_of_week, starts_at, ends_at");

  if (scheduleError) {
    throw new EdgeApiError(500, "수업 일정 저장에 실패했습니다.");
  }

  await createClassAuditLog(db, {
    organizationId: studyRoom.organization_id,
    studyRoomId,
    actorTeacherId: activeTeacher.id,
    classId: classRoom.id,
    title: "수업 등록",
    summary: `${classRoom.name} 수업을 등록했습니다.`,
  });

  return {
    ok: true,
    class: formatClassSummary({
      ...classRoom,
      class_schedules: schedules ?? [],
    }),
  };
}

async function updateClass(
  classId: string,
  body: Record<string, unknown>,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(classId, "수업 정보가 올바르지 않습니다.");
  const classRoom = await readAccessibleClass(db, classId, activeTeacher, {
    allowAdmin: false,
  });

  const name = stringValue(body.name);
  const description = nullableString(body.description);
  const classKind = normalizeClassKind(body.classKind);
  const startDate = stringValue(body.startDate);
  const endDate = stringValue(body.endDate);
  const dayOfWeeks = normalizeDayOfWeeks(body.dayOfWeeks);
  const startsAt = normalizeTime(
    body.startsAt,
    "수업 시작 시간을 입력해 주세요.",
  );
  const endsAt = normalizeTime(body.endsAt, "수업 종료 시간을 입력해 주세요.");

  if (name.length < 2) throw new EdgeApiError(400, "수업명을 입력해 주세요.");
  assertDate(startDate, "수업 시작일이 올바르지 않습니다.");
  assertDate(endDate, "수업 종료일이 올바르지 않습니다.");
  if (endDate < startDate) {
    throw new EdgeApiError(400, "수업 종료일은 시작일 이후여야 합니다.");
  }
  if (startsAt >= endsAt) {
    throw new EdgeApiError(400, "수업 종료 시간은 시작 시간 이후여야 합니다.");
  }

  const scheduleText = formatScheduleText(dayOfWeeks, startsAt, endsAt);
  const { data: updatedClass, error: classError } = await db
    .from("classes")
    .update({
      name,
      description,
      class_kind: classKind,
      start_date: startDate,
      end_date: endDate,
      schedule_text: scheduleText,
    })
    .eq("id", classId)
    .eq("teacher_id", activeTeacher.id)
    .select(
      "id, name, description, class_kind, start_date, end_date, schedule_text, active",
    )
    .single();

  if (classError) throw new EdgeApiError(500, "수업 수정에 실패했습니다.");

  const { error: inactiveScheduleError } = await db
    .from("class_schedules")
    .update({ active: false })
    .eq("class_id", classId);

  if (inactiveScheduleError) {
    throw new EdgeApiError(500, "기존 수업 일정 정리에 실패했습니다.");
  }

  const scheduleRows = dayOfWeeks.map((dayOfWeek) => ({
    class_id: classId,
    day_of_week: dayOfWeek,
    starts_at: startsAt,
    ends_at: endsAt,
    active: true,
  }));
  const { data: schedules, error: scheduleError } = await db
    .from("class_schedules")
    .insert(scheduleRows)
    .select("day_of_week, starts_at, ends_at");

  if (scheduleError) {
    throw new EdgeApiError(500, "수업 일정 저장에 실패했습니다.");
  }

  await createClassAuditLog(db, {
    organizationId: classRoom.organization_id,
    studyRoomId: classRoom.study_room_id,
    actorTeacherId: activeTeacher.id,
    classId,
    action: "updated",
    title: "수업 수정",
    summary: `${updatedClass.name} 수업 정보를 수정했습니다.`,
  });

  return {
    ok: true,
    class: formatClassSummary({
      ...updatedClass,
      class_schedules: schedules ?? [],
    }),
  };
}

async function deleteClass(
  classId: string,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(classId, "수업 정보가 올바르지 않습니다.");
  const classRoom = await readAccessibleClass(db, classId, activeTeacher, {
    allowAdmin: false,
  });

  const { error: classError } = await db
    .from("classes")
    .update({ active: false })
    .eq("id", classId)
    .eq("teacher_id", activeTeacher.id);

  if (classError) throw new EdgeApiError(500, "수업 삭제에 실패했습니다.");

  const { error: enrollmentError } = await db
    .from("class_students")
    .update({ active: false })
    .eq("class_id", classId);

  if (enrollmentError) {
    throw new EdgeApiError(500, "수업 학생 등록 정리에 실패했습니다.");
  }

  const { error: scheduleError } = await db
    .from("class_schedules")
    .update({ active: false })
    .eq("class_id", classId);

  if (scheduleError) {
    throw new EdgeApiError(500, "수업 일정 정리에 실패했습니다.");
  }

  await createClassAuditLog(db, {
    organizationId: classRoom.organization_id,
    studyRoomId: classRoom.study_room_id,
    actorTeacherId: activeTeacher.id,
    classId,
    action: "deleted",
    title: "수업 삭제",
    summary: `${classRoom.name} 수업을 비활성화했습니다.`,
  });

  return { ok: true };
}

async function getClassroomLayout(
  classId: string,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(classId, "수업 정보가 올바르지 않습니다.");
  const classRoom = await readAccessibleClass(db, classId, activeTeacher, {
    allowAdmin: true,
  });
  const layout = await readActiveClassroomLayout(db, classId);
  if (!layout) {
    return {
      ok: true,
      layout: {
        id: null,
        classId,
        name: "기본 배치",
        canvasWidth: 1000,
        canvasHeight: 700,
        seats: [],
        assignments: [],
      },
    };
  }
  return {
    ok: true,
    layout: await formatClassroomLayout(db, layout, classRoom),
  };
}

async function saveClassroomLayout(
  classId: string,
  body: Record<string, unknown>,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(classId, "수업 정보가 올바르지 않습니다.");
  const classRoom = await readAccessibleClass(db, classId, activeTeacher, {
    allowAdmin: false,
  });

  const name = stringValue(body.name) || "기본 배치";
  const canvasWidth = normalizePositiveNumber(body.canvasWidth, 1000);
  const canvasHeight = normalizePositiveNumber(body.canvasHeight, 700);
  const seats = normalizeClassroomSeats(body.seats);

  const existing = await readActiveClassroomLayout(db, classId);
  const layout = existing
    ? await updateClassroomLayoutRow(db, existing.id, {
      name,
      canvasWidth,
      canvasHeight,
    })
    : await createClassroomLayoutRow(db, classRoom, {
      name,
      canvasWidth,
      canvasHeight,
      teacherId: activeTeacher.id,
    });

  const incomingIds = seats
    .map((seat) => seat.id)
    .filter((id): id is string => id !== null);
  let inactiveSeatQuery = db
    .from("classroom_seats")
    .update({ active: false })
    .eq("classroom_layout_id", layout.id);
  if (incomingIds.length > 0) {
    inactiveSeatQuery = inactiveSeatQuery.not(
      "id",
      "in",
      `(${incomingIds.join(",")})`,
    );
  }
  const { error: inactiveSeatError } = await inactiveSeatQuery;

  if (inactiveSeatError) {
    throw new EdgeApiError(500, "좌석 정리에 실패했습니다.");
  }

  const savedSeats = [];
  for (const seat of seats) {
    if (seat.id) {
      const { data, error } = await db
        .from("classroom_seats")
        .update({
          label: seat.label,
          desk_x: seat.deskX,
          desk_y: seat.deskY,
          seat_x: seat.seatX,
          seat_y: seat.seatY,
          rotation_degrees: seat.rotationDegrees,
          display_order: seat.displayOrder,
          active: true,
        })
        .eq("id", seat.id)
        .eq("classroom_layout_id", layout.id)
        .select(
          "id, label, desk_x, desk_y, seat_x, seat_y, rotation_degrees, display_order",
        )
        .single();
      if (error) throw new EdgeApiError(500, "좌석 수정에 실패했습니다.");
      savedSeats.push(data);
    } else {
      const { data, error } = await db
        .from("classroom_seats")
        .insert({
          organization_id: classRoom.organization_id,
          study_room_id: classRoom.study_room_id,
          classroom_layout_id: layout.id,
          label: seat.label,
          desk_x: seat.deskX,
          desk_y: seat.deskY,
          seat_x: seat.seatX,
          seat_y: seat.seatY,
          rotation_degrees: seat.rotationDegrees,
          display_order: seat.displayOrder,
          active: true,
        })
        .select(
          "id, label, desk_x, desk_y, seat_x, seat_y, rotation_degrees, display_order",
        )
        .single();
      if (error) throw new EdgeApiError(500, "좌석 생성에 실패했습니다.");
      savedSeats.push(data);
    }
  }

  let staleAssignmentQuery = db
    .from("student_seat_assignments")
    .delete()
    .eq("classroom_layout_id", layout.id);
  const savedSeatIds = savedSeats.map((seat) => String(seat.id));
  if (savedSeatIds.length > 0) {
    staleAssignmentQuery = staleAssignmentQuery.not(
      "classroom_seat_id",
      "in",
      `(${savedSeatIds.join(",")})`,
    );
  }
  const { error: staleAssignmentError } = await staleAssignmentQuery;
  if (staleAssignmentError) {
    throw new EdgeApiError(500, "삭제된 좌석의 배정 정리에 실패했습니다.");
  }

  await createClassroomLayoutAuditLog(db, {
    organizationId: classRoom.organization_id,
    studyRoomId: classRoom.study_room_id,
    actorTeacherId: activeTeacher.id,
    classId,
    classroomLayoutId: layout.id,
    action: existing ? "updated" : "created",
    title: existing ? "교실 배치 수정" : "교실 배치 생성",
    summary:
      `${classRoom.name} 수업의 좌석 ${savedSeats.length}개를 저장했습니다.`,
  });

  return {
    ok: true,
    layout: await formatClassroomLayout(db, layout, classRoom),
  };
}

async function saveSeatAssignments(
  classId: string,
  body: Record<string, unknown>,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(classId, "수업 정보가 올바르지 않습니다.");
  const classRoom = await readAccessibleClass(db, classId, activeTeacher, {
    allowAdmin: false,
  });
  const layout = await readActiveClassroomLayout(db, classId);
  if (!layout) throw new EdgeApiError(400, "교실 배치를 먼저 저장해 주세요.");
  const assignments = normalizeSeatAssignments(body.assignments);

  await assertSeatAssignmentScope(db, layout.id, classRoom, assignments);

  const { error: deleteError } = await db
    .from("student_seat_assignments")
    .delete()
    .eq("classroom_layout_id", layout.id);
  if (deleteError) {
    throw new EdgeApiError(500, "기존 좌석 배정 정리에 실패했습니다.");
  }

  if (assignments.length > 0) {
    const { error: insertError } = await db
      .from("student_seat_assignments")
      .insert(
        assignments.map((assignment) => ({
          classroom_layout_id: layout.id,
          classroom_seat_id: assignment.seatId,
          student_id: assignment.studentId,
          assigned_by_teacher_id: activeTeacher.id,
          active: true,
        })),
      );
    if (insertError) {
      throw new EdgeApiError(500, "좌석 배정 저장에 실패했습니다.");
    }
  }

  await createClassroomLayoutAuditLog(db, {
    organizationId: classRoom.organization_id,
    studyRoomId: classRoom.study_room_id,
    actorTeacherId: activeTeacher.id,
    classId,
    classroomLayoutId: layout.id,
    action: "assigned",
    title: "좌석 배정",
    summary:
      `${classRoom.name} 수업의 학생 좌석 ${assignments.length}건을 저장했습니다.`,
  });

  return {
    ok: true,
    layout: await formatClassroomLayout(db, layout, classRoom),
  };
}

async function copyClassroomLayout(
  targetClassId: string,
  body: Record<string, unknown>,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  const sourceClassId = stringValue(body.sourceClassId);
  assertUuid(targetClassId, "대상 수업 정보가 올바르지 않습니다.");
  assertUuid(sourceClassId, "원본 수업 정보가 올바르지 않습니다.");
  if (sourceClassId === targetClassId) {
    throw new EdgeApiError(400, "같은 수업으로는 배치를 복사할 수 없습니다.");
  }

  const targetClass = await readAccessibleClass(
    db,
    targetClassId,
    activeTeacher,
    { allowAdmin: false },
  );
  const sourceClass = await readAccessibleClass(
    db,
    sourceClassId,
    activeTeacher,
    { allowAdmin: false },
  );
  if (sourceClass.study_room_id !== targetClass.study_room_id) {
    throw new EdgeApiError(
      400,
      "같은 공부방 수업끼리만 배치를 복사할 수 있습니다.",
    );
  }

  const sourceLayout = await readActiveClassroomLayout(db, sourceClassId);
  if (!sourceLayout) {
    throw new EdgeApiError(400, "원본 수업에 복사할 교실 배치가 없습니다.");
  }

  await deactivateActiveClassroomLayouts(db, targetClassId);

  const layout = await createClassroomLayoutRow(db, targetClass, {
    name: `${sourceLayout.name} 복사`,
    canvasWidth: Number(sourceLayout.canvas_width ?? 1000),
    canvasHeight: Number(sourceLayout.canvas_height ?? 700),
    teacherId: activeTeacher.id,
  });

  const { data: sourceSeats, error: sourceSeatsError } = await db
    .from("classroom_seats")
    .select(
      "id, label, desk_x, desk_y, seat_x, seat_y, rotation_degrees, display_order",
    )
    .eq("classroom_layout_id", sourceLayout.id)
    .eq("active", true)
    .order("display_order", { ascending: true });
  if (sourceSeatsError) {
    throw new EdgeApiError(500, "원본 좌석 조회에 실패했습니다.");
  }

  const seatIdBySourceId = new Map<string, string>();
  for (const seat of sourceSeats ?? []) {
    const { data: copiedSeat, error: copiedSeatError } = await db
      .from("classroom_seats")
      .insert({
        organization_id: targetClass.organization_id,
        study_room_id: targetClass.study_room_id,
        classroom_layout_id: layout.id,
        label: seat.label,
        desk_x: seat.desk_x,
        desk_y: seat.desk_y,
        seat_x: seat.seat_x,
        seat_y: seat.seat_y,
        rotation_degrees: seat.rotation_degrees,
        display_order: seat.display_order,
        active: true,
      })
      .select("id")
      .single();
    if (copiedSeatError) {
      throw new EdgeApiError(500, "좌석 복사에 실패했습니다.");
    }
    seatIdBySourceId.set(String(seat.id), String(copiedSeat.id));
  }

  const copiedAssignments = await copyEligibleSeatAssignments(db, {
    sourceLayoutId: String(sourceLayout.id),
    targetLayoutId: String(layout.id),
    targetClassId,
    seatIdBySourceId,
    teacherId: activeTeacher.id,
  });

  await createClassroomLayoutAuditLog(db, {
    organizationId: targetClass.organization_id,
    studyRoomId: targetClass.study_room_id,
    actorTeacherId: activeTeacher.id,
    classId: targetClassId,
    classroomLayoutId: layout.id,
    action: "copied",
    title: "교실 배치 복사",
    summary:
      `${sourceClass.name} 수업의 좌석 ${seatIdBySourceId.size}개와 배정 ${copiedAssignments}건을 ${targetClass.name} 수업으로 복사했습니다.`,
  });

  return {
    ok: true,
    layout: await formatClassroomLayout(db, layout, targetClass),
  };
}

async function listClassStudents(
  classId: string,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(classId, "수업 정보가 올바르지 않습니다.");
  await readAccessibleClass(db, classId, activeTeacher, { allowAdmin: true });

  const { data: rows, error } = await db
    .from("class_students")
    .select(
      "student_id, display_order, enrollment_kind, students!inner(id, student_code, name, status)",
    )
    .eq("class_id", classId)
    .eq("active", true)
    .order("display_order", { ascending: true });

  if (error) throw new EdgeApiError(500, "수업 등록 학생 조회에 실패했습니다.");

  return {
    ok: true,
    students: (rows ?? []).map((row) => {
      const student = normalizeJoinedObject(row.students);
      return {
        id: student.id,
        code: student.student_code,
        name: student.name,
        status: student.status,
        displayOrder: row.display_order,
        enrollmentKind: row.enrollment_kind,
      };
    }),
  };
}

async function saveClassStudents(
  classId: string,
  body: Record<string, unknown>,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(classId, "수업 정보가 올바르지 않습니다.");
  const classRoom = await readAccessibleClass(db, classId, activeTeacher, {
    allowAdmin: false,
  });
  const studentIds = normalizeUuidList(
    body.studentIds,
    "학생 목록이 올바르지 않습니다.",
  );

  if (studentIds.length > 0) {
    const { data: students, error: studentError } = await db
      .from("students")
      .select("id")
      .eq("study_room_id", classRoom.study_room_id)
      .in("id", studentIds);

    if (studentError) {
      throw new EdgeApiError(500, "학생 소속 확인에 실패했습니다.");
    }
    if ((students ?? []).length !== studentIds.length) {
      throw new EdgeApiError(
        400,
        "같은 공부방 학생만 수업에 등록할 수 있습니다.",
      );
    }
  }

  let deactivateQuery = db
    .from("class_students")
    .update({ active: false })
    .eq("class_id", classId);
  if (studentIds.length > 0) {
    deactivateQuery = deactivateQuery.not(
      "student_id",
      "in",
      `(${studentIds.join(",")})`,
    );
  }
  const { error: deactivateError } = await deactivateQuery;

  if (deactivateError) {
    throw new EdgeApiError(500, "수업 학생 제외에 실패했습니다.");
  }

  if (studentIds.length > 0) {
    const rows = studentIds.map((studentId, index) => ({
      class_id: classId,
      student_id: studentId,
      enrollment_kind: classRoom.class_kind,
      display_order: index,
      active: true,
    }));

    const { error: upsertError } = await db
      .from("class_students")
      .upsert(rows, { onConflict: "class_id,student_id" });

    if (upsertError) {
      throw new EdgeApiError(500, "수업 학생 등록 저장에 실패했습니다.");
    }
  }

  await createClassStudentAuditLog(db, {
    organizationId: classRoom.organization_id,
    studyRoomId: classRoom.study_room_id,
    actorTeacherId: activeTeacher.id,
    classId,
    title: "수업 학생 등록 변경",
    summary:
      `${classRoom.name} 수업의 등록 학생 ${studentIds.length}명을 저장했습니다.`,
  });

  return await listClassStudents(classId, {
    db,
    authUser: { id: "", email: null, name: null },
    teacher: activeTeacher,
  });
}

async function updateClassStudentOrder(
  classId: string,
  body: Record<string, unknown>,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(classId, "수업 정보가 올바르지 않습니다.");
  const classRoom = await readAccessibleClass(db, classId, activeTeacher, {
    allowAdmin: false,
  });
  const studentIds = normalizeUuidList(
    body.studentIds,
    "학생 순서가 올바르지 않습니다.",
  );
  if (studentIds.length === 0) {
    throw new EdgeApiError(400, "정렬할 학생을 선택해 주세요.");
  }

  const { data: activeEnrollments, error: enrollmentError } = await db
    .from("class_students")
    .select("student_id")
    .eq("class_id", classId)
    .eq("active", true)
    .in("student_id", studentIds);

  if (enrollmentError) {
    throw new EdgeApiError(500, "수업 학생 등록 확인에 실패했습니다.");
  }
  if ((activeEnrollments ?? []).length !== studentIds.length) {
    throw new EdgeApiError(400, "등록된 학생만 순서를 변경할 수 있습니다.");
  }

  const updateResults = await Promise.all(
    studentIds.map((studentId, index) =>
      db
        .from("class_students")
        .update({ display_order: index })
        .eq("class_id", classId)
        .eq("student_id", studentId)
        .eq("active", true)
    ),
  );
  if (updateResults.some((result) => result.error)) {
    throw new EdgeApiError(500, "학생 순서 저장에 실패했습니다.");
  }

  await createClassStudentAuditLog(db, {
    organizationId: classRoom.organization_id,
    studyRoomId: classRoom.study_room_id,
    actorTeacherId: activeTeacher.id,
    classId,
    title: "수업 학생 순서 변경",
    summary: `${classRoom.name} 수업의 학생 표시 순서를 변경했습니다.`,
  });

  return await listClassStudents(classId, {
    db,
    authUser: { id: "", email: null, name: null },
    teacher: activeTeacher,
  });
}

async function openClassSession(
  classId: string,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(classId, "수업 정보가 올바르지 않습니다.");
  const classRoom = await readAccessibleClass(db, classId, activeTeacher, {
    allowAdmin: false,
  });

  const sessionDate = todayDateString();
  const { data: existing, error: existingError } = await db
    .from("class_sessions")
    .select("id, session_date, starts_at, ends_at, status")
    .eq("class_id", classId)
    .eq("session_date", sessionDate)
    .eq("status", "open")
    .maybeSingle();

  if (existingError) {
    throw new EdgeApiError(500, "열린 수업 회차 조회에 실패했습니다.");
  }
  if (existing) {
    return {
      ok: true,
      session: formatClassSession(existing, classRoom),
    };
  }

  const { data: schedule, error: scheduleError } = await db
    .from("class_schedules")
    .select("id, starts_at, ends_at")
    .eq("class_id", classId)
    .eq("active", true)
    .order("day_of_week", { ascending: true })
    .limit(1)
    .maybeSingle();

  if (scheduleError) {
    throw new EdgeApiError(500, "수업 일정 조회에 실패했습니다.");
  }
  if (!schedule) {
    throw new EdgeApiError(400, "수업 일정이 먼저 필요합니다.");
  }

  const { data: session, error: sessionError } = await db
    .from("class_sessions")
    .insert({
      organization_id: classRoom.organization_id,
      study_room_id: classRoom.study_room_id,
      class_id: classId,
      class_schedule_id: schedule.id,
      session_date: sessionDate,
      starts_at: toKstIso(sessionDate, schedule.starts_at),
      ends_at: toKstIso(sessionDate, schedule.ends_at),
      kind: classRoom.class_kind,
      status: "open",
      opened_by_teacher_id: activeTeacher.id,
    })
    .select("id, session_date, starts_at, ends_at, status")
    .single();

  if (sessionError) {
    throw new EdgeApiError(500, "수업 회차 열기에 실패했습니다.");
  }

  await createClassSessionAuditLog(db, {
    organizationId: classRoom.organization_id,
    studyRoomId: classRoom.study_room_id,
    actorTeacherId: activeTeacher.id,
    classId,
    classSessionId: session.id,
    title: "출석 회차 열기",
    summary: `${classRoom.name} 수업의 출석 회차를 열었습니다.`,
  });

  return {
    ok: true,
    session: formatClassSession(session, classRoom),
  };
}

async function cancelTodayClassSession(
  classId: string,
  body: Record<string, unknown>,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(classId, "수업 정보가 올바르지 않습니다.");
  const classRoom = await readAccessibleClass(db, classId, activeTeacher, {
    allowAdmin: false,
  });
  const reason = nullableString(body.reason);
  const sessionDate = stringValue(body.sessionDate) || todayDateString();
  assertDate(sessionDate, "휴강 날짜가 올바르지 않습니다.");
  const session = await ensureClassSessionForDate(db, classRoom, sessionDate, {
    status: "cancelled",
    reason,
    teacherId: activeTeacher.id,
  });

  const { data: updatedSession, error: updateError } = await db
    .from("class_sessions")
    .update({
      status: "cancelled",
      change_reason: reason,
      opened_by_teacher_id: activeTeacher.id,
    })
    .eq("id", session.id)
    .select("id, session_date, starts_at, ends_at, status")
    .single();

  if (updateError) {
    throw new EdgeApiError(500, "휴강 처리에 실패했습니다.");
  }

  await createClassSessionChange(db, {
    organizationId: classRoom.organization_id,
    studyRoomId: classRoom.study_room_id,
    classSessionId: updatedSession.id,
    changeType: "cancelled",
    reason,
    teacherId: activeTeacher.id,
    beforeValue: { status: session.status },
    afterValue: { status: "cancelled", sessionDate },
  });

  const notifications = await createClassChangeNotificationLogs(db, {
    organizationId: classRoom.organization_id,
    studyRoomId: classRoom.study_room_id,
    classId,
    classSessionId: updatedSession.id,
    eventType: "class_cancelled",
    className: String(classRoom.name),
    messageTitle: "휴강 안내",
    sessionDate,
    startsAt: updatedSession.starts_at,
    endsAt: updatedSession.ends_at,
    reason,
  });

  await createClassChangeAuditLog(db, {
    organizationId: classRoom.organization_id,
    studyRoomId: classRoom.study_room_id,
    actorTeacherId: activeTeacher.id,
    classId,
    classSessionId: updatedSession.id,
    action: "status_changed",
    title: "수업 휴강",
    summary: `${classRoom.name} 수업을 ${sessionDate} 휴강 처리했습니다.`,
  });

  return {
    ok: true,
    session: formatClassSession(updatedSession, classRoom),
    notifications: { requested: notifications.length },
  };
}

async function rescheduleTodayClassSession(
  classId: string,
  body: Record<string, unknown>,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(classId, "수업 정보가 올바르지 않습니다.");
  const classRoom = await readAccessibleClass(db, classId, activeTeacher, {
    allowAdmin: false,
  });
  const startsAt = normalizeTime(
    body.startsAt,
    "변경 시작 시간을 입력해 주세요.",
  );
  const endsAt = normalizeTime(body.endsAt, "변경 종료 시간을 입력해 주세요.");
  if (startsAt >= endsAt) {
    throw new EdgeApiError(400, "변경 종료 시간은 시작 시간 이후여야 합니다.");
  }
  const reason = nullableString(body.reason);
  const sessionDate = stringValue(body.sessionDate) || todayDateString();
  assertDate(sessionDate, "변경 날짜가 올바르지 않습니다.");
  const session = await ensureClassSessionForDate(db, classRoom, sessionDate, {
    status: "scheduled",
    reason,
    teacherId: activeTeacher.id,
  });
  if (session.status === "cancelled") {
    throw new EdgeApiError(
      400,
      "휴강 처리된 회차는 시간을 변경할 수 없습니다.",
    );
  }

  const beforeValue = {
    sessionDate: session.session_date,
    startsAt: session.starts_at,
    endsAt: session.ends_at,
    status: session.status,
  };
  const { data: updatedSession, error } = await db
    .from("class_sessions")
    .update({
      starts_at: toKstIso(sessionDate, startsAt),
      ends_at: toKstIso(sessionDate, endsAt),
      change_reason: reason,
      opened_by_teacher_id: activeTeacher.id,
    })
    .eq("id", session.id)
    .select("id, session_date, starts_at, ends_at, status")
    .single();

  if (error) throw new EdgeApiError(500, "수업 시간 변경에 실패했습니다.");

  await createClassSessionChange(db, {
    organizationId: classRoom.organization_id,
    studyRoomId: classRoom.study_room_id,
    classSessionId: updatedSession.id,
    changeType: "time_changed",
    reason,
    teacherId: activeTeacher.id,
    beforeValue,
    afterValue: { sessionDate, startsAt, endsAt },
  });

  const notifications = await createClassChangeNotificationLogs(db, {
    organizationId: classRoom.organization_id,
    studyRoomId: classRoom.study_room_id,
    classId,
    classSessionId: updatedSession.id,
    eventType: "class_time_changed",
    className: String(classRoom.name),
    messageTitle: "수업 시간 변경 안내",
    sessionDate,
    startsAt: updatedSession.starts_at,
    endsAt: updatedSession.ends_at,
    reason,
  });

  await createClassChangeAuditLog(db, {
    organizationId: classRoom.organization_id,
    studyRoomId: classRoom.study_room_id,
    actorTeacherId: activeTeacher.id,
    classId,
    classSessionId: updatedSession.id,
    action: "status_changed",
    title: "수업 시간 변경",
    summary: `${classRoom.name} ${sessionDate} 수업 시간을 변경했습니다.`,
  });

  return {
    ok: true,
    session: formatClassSession(updatedSession, classRoom),
    notifications: { requested: notifications.length },
  };
}

async function createMakeupClassSession(
  classId: string,
  body: Record<string, unknown>,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(classId, "수업 정보가 올바르지 않습니다.");
  const classRoom = await readAccessibleClass(db, classId, activeTeacher, {
    allowAdmin: false,
  });

  const sessionDate = stringValue(body.sessionDate);
  const startsAt = normalizeTime(
    body.startsAt,
    "보강 시작 시간을 입력해 주세요.",
  );
  const endsAt = normalizeTime(body.endsAt, "보강 종료 시간을 입력해 주세요.");
  const reason = nullableString(body.reason);
  const originalSessionDate = nullableString(body.originalSessionDate);
  assertDate(sessionDate, "보강 날짜가 올바르지 않습니다.");
  if (originalSessionDate) {
    assertDate(originalSessionDate, "연결할 휴강 날짜가 올바르지 않습니다.");
  }
  if (startsAt >= endsAt) {
    throw new EdgeApiError(400, "보강 종료 시간은 시작 시간 이후여야 합니다.");
  }
  const originalSession = originalSessionDate
    ? await readClassSessionForDate(db, classId, originalSessionDate)
    : null;
  if (originalSession && originalSession.status !== "cancelled") {
    throw new EdgeApiError(
      400,
      "휴강 처리된 회차만 보강과 연결할 수 있습니다.",
    );
  }

  const { data: session, error } = await db
    .from("class_sessions")
    .insert({
      organization_id: classRoom.organization_id,
      study_room_id: classRoom.study_room_id,
      class_id: classId,
      original_class_session_id: originalSession?.id ?? null,
      session_date: sessionDate,
      starts_at: toKstIso(sessionDate, startsAt),
      ends_at: toKstIso(sessionDate, endsAt),
      kind: "makeup",
      status: "scheduled",
      change_reason: reason,
      opened_by_teacher_id: activeTeacher.id,
    })
    .select("id, session_date, starts_at, ends_at, status")
    .single();

  if (error) throw new EdgeApiError(500, "보강 회차 생성에 실패했습니다.");

  await createClassSessionChange(db, {
    organizationId: classRoom.organization_id,
    studyRoomId: classRoom.study_room_id,
    classSessionId: originalSession?.id ?? session.id,
    relatedClassSessionId: originalSession ? session.id : undefined,
    changeType: "makeup_added",
    reason,
    teacherId: activeTeacher.id,
    beforeValue: originalSession
      ? {
        sessionDate: originalSession.session_date,
        startsAt: originalSession.starts_at,
        endsAt: originalSession.ends_at,
        status: originalSession.status,
      }
      : null,
    afterValue: {
      sessionDate,
      startsAt,
      endsAt,
      originalSessionId: originalSession?.id ?? null,
    },
  });

  const notifications = await createClassChangeNotificationLogs(db, {
    organizationId: classRoom.organization_id,
    studyRoomId: classRoom.study_room_id,
    classId,
    classSessionId: session.id,
    eventType: "class_makeup_added",
    className: String(classRoom.name),
    messageTitle: "보강 안내",
    sessionDate,
    startsAt: session.starts_at,
    endsAt: session.ends_at,
    reason,
  });

  await createClassChangeAuditLog(db, {
    organizationId: classRoom.organization_id,
    studyRoomId: classRoom.study_room_id,
    actorTeacherId: activeTeacher.id,
    classId,
    classSessionId: session.id,
    action: "created",
    title: "보강 수업 생성",
    summary: originalSession
      ? `${classRoom.name} ${originalSessionDate} 휴강의 보강 수업을 생성했습니다.`
      : `${classRoom.name} 보강 수업을 생성했습니다.`,
  });

  return {
    ok: true,
    session: formatClassSession(session, classRoom),
    notifications: { requested: notifications.length },
  };
}

async function listTodayAttendance(
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  const { data: sessions, error } = await db
    .from("class_sessions")
    .select(
      "id, study_room_id, class_id, session_date, starts_at, ends_at, status, classes!inner(id, name, class_kind, schedule_text)",
    )
    .eq("status", "open")
    .eq("session_date", todayDateString())
    .order("starts_at", { ascending: true });

  if (error) throw new EdgeApiError(500, "오늘 출석 수업 조회에 실패했습니다.");

  const accessibleSessions = [];
  for (const session of sessions ?? []) {
    try {
      await assertStudyRoomAccess(db, activeTeacher, session.study_room_id, {
        allowAdmin: false,
      });
      accessibleSessions.push(session);
    } catch (error) {
      if (!(error instanceof EdgeApiError) || error.status !== 403) throw error;
    }
  }

  const formatted = [];
  for (const session of accessibleSessions) {
    const students = await listSessionStudents(
      db,
      session.id,
      session.class_id,
    );
    formatted.push({
      id: session.id,
      classId: session.class_id,
      className: normalizeJoinedObject(session.classes).name,
      classKind: normalizeJoinedObject(session.classes).class_kind,
      scheduleText: normalizeJoinedObject(session.classes).schedule_text,
      startsAt: session.starts_at,
      endsAt: session.ends_at,
      layout: await readAttendanceClassroomLayout(
        db,
        session.class_id,
        session.id,
      ),
      students,
    });
  }

  return { ok: true, sessions: formatted };
}

async function listClassSessionAttendance(
  classSessionId: string,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(classSessionId, "수업 회차 정보가 올바르지 않습니다.");
  const session = await readClassSession(db, classSessionId);
  await assertStudyRoomAccess(db, activeTeacher, session.study_room_id, {
    allowAdmin: true,
  });
  const classInfo = await readClassInfo(db, session.class_id);
  const students = await listSessionStudents(
    db,
    classSessionId,
    session.class_id,
  );

  return {
    ok: true,
    session: {
      id: session.id,
      classId: session.class_id,
      className: classInfo.name,
      status: session.status,
    },
    students,
  };
}

async function updateClassSessionAttendance(
  classSessionId: string,
  body: Record<string, unknown>,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(classSessionId, "수업 회차 정보가 올바르지 않습니다.");
  const studentId = stringValue(body.studentId);
  assertUuid(studentId, "학생 정보가 올바르지 않습니다.");
  const status = normalizeAttendanceStatus(body.status);
  const note = nullableString(body.note);

  const session = await readClassSession(db, classSessionId);
  await assertStudyRoomAccess(db, activeTeacher, session.study_room_id, {
    allowAdmin: false,
  });
  const student = await readStudent(db, studentId, session.study_room_id);
  await assertStudentEnrollment(db, session.class_id, studentId);

  const { data: record, error } = await db
    .from("attendance_records")
    .upsert({
      organization_id: session.organization_id,
      study_room_id: session.study_room_id,
      class_session_id: classSessionId,
      student_id: studentId,
      status,
      checked_in_at: status === "present" || status === "late"
        ? new Date().toISOString()
        : null,
      checked_in_method: "teacher_manual",
      note,
      created_by_teacher_id: activeTeacher.id,
      updated_by_teacher_id: activeTeacher.id,
      updated_at: new Date().toISOString(),
    }, { onConflict: "class_session_id,student_id" })
    .select("id, student_id, status, checked_in_at, note")
    .single();

  if (error) throw new EdgeApiError(500, "출결 상태 저장에 실패했습니다.");

  const classInfo = await readClassInfo(db, session.class_id);
  const notificationTime = record.checked_in_at ?? new Date().toISOString();
  const notifications = await createAttendanceNotificationLogs(db, {
    organizationId: session.organization_id,
    studyRoomId: session.study_room_id,
    classId: session.class_id,
    classSessionId,
    attendanceRecordId: record.id,
    studentId,
    studentName: student.name,
    className: classInfo.name,
    attendanceStatus: status,
    checkedInAt: notificationTime,
  });

  await createAuditLog(db, {
    organizationId: session.organization_id,
    studyRoomId: session.study_room_id,
    actorTeacherId: activeTeacher.id,
    studentId,
    classId: session.class_id,
    classSessionId,
    entityId: record.id,
    action: "status_changed",
    title: "출결 상태 수정",
    summary:
      `${student.name} 학생의 ${classInfo.name} 출결 상태를 ${status}로 수정했습니다.`,
  });

  return {
    ok: true,
    attendance: {
      recordId: record.id,
      studentId: record.student_id,
      status: record.status,
      checkedInAt: record.checked_in_at,
      note: record.note,
    },
    notifications: {
      requested: notifications.length,
    },
  };
}

async function listSessionStudents(
  db: SupabaseClient,
  classSessionId: string,
  classId: string,
) {
  const { data: enrollments, error: enrollmentError } = await db
    .from("class_students")
    .select(
      "student_id, display_order, students!inner(id, student_code, name, avatar_key)",
    )
    .eq("class_id", classId)
    .eq("active", true)
    .order("display_order", { ascending: true });

  if (enrollmentError) {
    throw new EdgeApiError(500, "출석 학생 목록 조회에 실패했습니다.");
  }

  const { data: records, error: recordError } = await db
    .from("attendance_records")
    .select("id, student_id, status, checked_in_at, note")
    .eq("class_session_id", classSessionId);

  if (recordError) {
    throw new EdgeApiError(500, "출석 상태 조회에 실패했습니다.");
  }
  const statusByStudentId = new Map(
    (records ?? []).map((record) => [record.student_id, record]),
  );

  return (enrollments ?? []).map((row) => {
    const student = normalizeJoinedObject(row.students);
    const record = statusByStudentId.get(String(student.id));
    return {
      id: student.id,
      code: student.student_code,
      name: student.name,
      avatarKey: student.avatar_key,
      recordId: record?.id ?? null,
      status: record?.status ?? "waiting",
      checkedInAt: record?.checked_in_at ?? null,
      note: record?.note ?? null,
    };
  });
}

async function listStudents(
  studyRoomId: string,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(studyRoomId, "공부방 정보가 올바르지 않습니다.");
  await assertStudyRoomAccess(db, activeTeacher, studyRoomId, {
    allowAdmin: true,
  });

  const { data: students, error } = await db
    .from("students")
    .select("id, student_code, name, status, gender, age_group, avatar_key")
    .eq("study_room_id", studyRoomId)
    .order("created_at", { ascending: false });

  if (error) throw new EdgeApiError(500, "학생 목록 조회에 실패했습니다.");

  return {
    ok: true,
    students: (students ?? []).map((student) => ({
      id: student.id,
      code: student.student_code,
      name: student.name,
      status: student.status,
      gender: student.gender,
      ageGroup: student.age_group,
      avatarKey: student.avatar_key,
    })),
  };
}

async function listAuditLogs(
  studyRoomId: string,
  body: Record<string, unknown>,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(studyRoomId, "공부방 정보가 올바르지 않습니다.");
  await assertStudyRoomAccess(db, activeTeacher, studyRoomId, {
    allowAdmin: true,
  });

  const category = normalizeAuditCategory(body.category);
  const limit = normalizeLimit(body.limit, 60, 100);
  const studentId = nullableString(body.studentId);
  const classId = nullableString(body.classId);
  const dateFrom = nullableString(body.dateFrom);
  const dateTo = nullableString(body.dateTo);
  if (studentId) assertUuid(studentId, "학생 정보가 올바르지 않습니다.");
  if (classId) assertUuid(classId, "수업 정보가 올바르지 않습니다.");
  if (dateFrom) assertDate(dateFrom, "조회 시작일이 올바르지 않습니다.");
  if (dateTo) assertDate(dateTo, "조회 종료일이 올바르지 않습니다.");
  const records: Record<string, unknown>[] = [];

  if (category !== "kakao") {
    let query = db
      .from("audit_logs")
      .select(
        "id, entity_type, action, title, summary, student_id, class_id, class_session_id, notification_log_id, created_at, teachers(name)",
      )
      .eq("study_room_id", studyRoomId)
      .order("created_at", { ascending: false })
      .limit(limit);

    const entityTypes = auditEntityTypesForCategory(category);
    if (entityTypes.length > 0) {
      query = query.in("entity_type", entityTypes);
    }
    if (studentId) query = query.eq("student_id", studentId);
    if (classId) query = query.eq("class_id", classId);
    if (dateFrom) query = query.gte("created_at", `${dateFrom}T00:00:00+09:00`);
    if (dateTo) query = query.lte("created_at", `${dateTo}T23:59:59.999+09:00`);

    const { data: auditLogs, error: auditError } = await query;
    if (auditError) {
      throw new EdgeApiError(500, "사용 히스토리 조회에 실패했습니다.");
    }

    records.push(
      ...(auditLogs ?? []).map((log) => {
        const teacher = normalizeJoinedObject(log.teachers);
        return {
          id: log.id,
          category: auditCategoryFromEntityType(log.entity_type),
          entityType: log.entity_type,
          action: log.action,
          title: log.title,
          summary: log.summary,
          actor: teacher.name ?? "시스템",
          studentId: log.student_id,
          classId: log.class_id,
          classSessionId: log.class_session_id,
          notificationLogId: log.notification_log_id,
          createdAt: log.created_at,
        };
      }),
    );
  }

  if (category === "all" || category === "kakao") {
    let notificationQuery = db
      .from("notification_logs")
      .select(
        "id, event_type, status, student_id, class_id, class_session_id, student_name, class_name, recipient_phone_masked, created_at, sent_at",
      )
      .eq("study_room_id", studyRoomId)
      .eq("channel", "kakao")
      .order("created_at", { ascending: false })
      .limit(limit);
    if (studentId) {
      notificationQuery = notificationQuery.eq("student_id", studentId);
    }
    if (classId) notificationQuery = notificationQuery.eq("class_id", classId);
    if (dateFrom) {
      notificationQuery = notificationQuery.gte(
        "created_at",
        `${dateFrom}T00:00:00+09:00`,
      );
    }
    if (dateTo) {
      notificationQuery = notificationQuery.lte(
        "created_at",
        `${dateTo}T23:59:59.999+09:00`,
      );
    }

    const { data: notificationLogs, error: notificationError } =
      await notificationQuery;

    if (notificationError) {
      throw new EdgeApiError(500, "카카오 발송 이력 조회에 실패했습니다.");
    }

    records.push(
      ...(notificationLogs ?? []).map((log) => ({
        id: log.id,
        category: "kakao",
        entityType: "notification",
        action: notificationStatusToAction(log.status),
        title: formatNotificationTitle(log.status),
        summary: formatNotificationSummary(log),
        actor: "시스템",
        studentId: log.student_id,
        classId: log.class_id,
        classSessionId: log.class_session_id,
        notificationLogId: log.id,
        createdAt: log.sent_at ?? log.created_at,
      })),
    );
  }

  records.sort((a, b) =>
    String(b.createdAt).localeCompare(String(a.createdAt))
  );

  return {
    ok: true,
    logs: records.slice(0, limit),
  };
}

async function listNotifications(
  studyRoomId: string,
  body: Record<string, unknown>,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(studyRoomId, "공부방 정보가 올바르지 않습니다.");
  await assertStudyRoomAccess(db, activeTeacher, studyRoomId, {
    allowAdmin: true,
  });

  const status = normalizeNotificationStatusFilter(body.status);
  const studentId = nullableString(body.studentId);
  const classId = nullableString(body.classId);
  const dateFrom = nullableString(body.dateFrom);
  const dateTo = nullableString(body.dateTo);
  const limit = normalizeLimit(body.limit, 80, 150);
  if (studentId) assertUuid(studentId, "학생 정보가 올바르지 않습니다.");
  if (classId) assertUuid(classId, "수업 정보가 올바르지 않습니다.");
  if (dateFrom) assertDate(dateFrom, "조회 시작일이 올바르지 않습니다.");
  if (dateTo) assertDate(dateTo, "조회 종료일이 올바르지 않습니다.");

  let query = db
    .from("notification_logs")
    .select(
      "id, event_type, channel, recipient_phone_masked, student_id, student_name, class_name, payload, status, error_message, retry_count, retry_of_notification_id, created_at, sent_at",
    )
    .eq("study_room_id", studyRoomId)
    .eq("channel", "kakao")
    .order("created_at", { ascending: false })
    .limit(limit);

  if (status !== "all") query = query.eq("status", status);
  if (studentId) query = query.eq("student_id", studentId);
  if (classId) query = query.eq("class_id", classId);
  if (dateFrom) query = query.gte("created_at", `${dateFrom}T00:00:00+09:00`);
  if (dateTo) query = query.lte("created_at", `${dateTo}T23:59:59.999+09:00`);

  const { data: notifications, error } = await query;
  if (error) {
    throw new EdgeApiError(500, "카카오 발송 이력 조회에 실패했습니다.");
  }

  return {
    ok: true,
    notifications: (notifications ?? []).map(formatNotificationLog),
  };
}

async function resendNotification(
  notificationId: string,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(notificationId, "알림 정보가 올바르지 않습니다.");

  const { data: current, error: currentError } = await db
    .from("notification_logs")
    .select(
      "id, organization_id, study_room_id, student_id, guardian_id, class_id, class_session_id, attendance_record_id, event_type, channel, recipient_phone_masked, student_name, class_name, event_time, payload, retry_count",
    )
    .eq("id", notificationId)
    .maybeSingle();

  if (currentError) {
    throw new EdgeApiError(500, "카카오 발송 이력 조회에 실패했습니다.");
  }
  if (!current) {
    throw new EdgeApiError(404, "카카오 발송 이력을 찾을 수 없습니다.");
  }
  await assertStudyRoomAccess(db, activeTeacher, current.study_room_id, {
    allowAdmin: false,
  });

  const { data: retry, error: retryError } = await db
    .from("notification_logs")
    .insert({
      organization_id: current.organization_id,
      study_room_id: current.study_room_id,
      student_id: current.student_id,
      guardian_id: current.guardian_id,
      class_id: current.class_id,
      class_session_id: current.class_session_id,
      attendance_record_id: current.attendance_record_id,
      event_type: current.event_type,
      channel: current.channel,
      recipient_phone_masked: current.recipient_phone_masked,
      student_name: current.student_name,
      class_name: current.class_name,
      event_time: new Date().toISOString(),
      payload: current.payload,
      retry_of_notification_id: current.id,
      retry_count: Number(current.retry_count ?? 0) + 1,
      status: "pending",
    })
    .select(
      "id, event_type, channel, recipient_phone_masked, student_id, student_name, class_name, status, error_message, retry_count, retry_of_notification_id, created_at, sent_at",
    )
    .single();

  if (retryError) {
    throw new EdgeApiError(500, "카카오 재발송 요청 생성에 실패했습니다.");
  }

  await createNotificationAuditLog(db, {
    organizationId: current.organization_id,
    studyRoomId: current.study_room_id,
    actorTeacherId: activeTeacher.id,
    studentId: current.student_id,
    notificationLogId: retry.id,
    action: "message_resent",
    title: "카카오 재발송 요청",
    summary: `${current.student_name ?? "학생"} ${
      current.class_name ?? ""
    } 알림 재발송을 요청했습니다.`,
  });

  return {
    ok: true,
    notification: formatNotificationLog(retry),
  };
}

async function processPendingNotifications(
  body: Record<string, unknown>,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  const studyRoomId = stringValue(body.studyRoomId);
  assertUuid(studyRoomId, "공부방 정보가 올바르지 않습니다.");
  await assertStudyRoomAccess(db, activeTeacher, studyRoomId, {
    allowAdmin: false,
  });
  const limit = normalizeLimit(body.limit, 20, 50);

  const { data: notifications, error } = await db
    .from("notification_logs")
    .select(
      "id, organization_id, study_room_id, guardian_id, event_type, payload, recipient_phone_masked, student_name, class_name, retry_count, guardians!inner(phone, kakao_opt_in, opt_out_at, deleted_at)",
    )
    .eq("study_room_id", studyRoomId)
    .eq("channel", "kakao")
    .eq("status", "pending")
    .order("created_at", { ascending: true })
    .limit(limit);

  if (error) {
    throw new EdgeApiError(500, "대기 카카오 알림 조회에 실패했습니다.");
  }

  let sent = 0;
  let failed = 0;
  for (const notification of notifications ?? []) {
    const guardian = normalizeJoinedObject(notification.guardians);
    try {
      if (
        guardian.kakao_opt_in !== true ||
        guardian.opt_out_at !== null ||
        guardian.deleted_at !== null
      ) {
        throw new EdgeApiError(400, "보호자가 카카오 수신 대상이 아닙니다.");
      }
      const providerResult = await sendKakaoProviderMessage({
        recipientPhone: stringValue(guardian.phone),
        eventType: String(notification.event_type),
        payload: normalizeProviderPayload(notification.payload),
      });
      const { error: updateError } = await db
        .from("notification_logs")
        .update({
          status: "sent",
          sent_at: new Date().toISOString(),
          provider_message_id: providerResult.messageId,
          provider_response: providerResult.response,
          error_message: null,
        })
        .eq("id", notification.id);
      if (updateError) {
        throw new EdgeApiError(500, "카카오 발송 성공 기록에 실패했습니다.");
      }
      sent += 1;
    } catch (error) {
      const message = error instanceof Error
        ? error.message
        : "카카오 발송에 실패했습니다.";
      const { error: updateError } = await db
        .from("notification_logs")
        .update({
          status: "failed",
          error_message: message,
          provider_response: { error: message },
        })
        .eq("id", notification.id);
      if (updateError) {
        throw new EdgeApiError(500, "카카오 발송 실패 기록에 실패했습니다.");
      }
      failed += 1;
    }
  }

  const firstNotification = notifications?.[0];
  if (firstNotification) {
    await createNotificationAuditLog(db, {
      organizationId: firstNotification.organization_id,
      studyRoomId,
      actorTeacherId: activeTeacher.id,
      studentId: null,
      notificationLogId: firstNotification.id,
      action: failed > 0 ? "message_failed" : "message_sent",
      title: "카카오 대기 알림 처리",
      summary: `카카오 대기 알림 ${sent}건 성공, ${failed}건 실패`,
    }).catch((error) => {
      console.error("notification audit log failed", error);
    });
  }

  return {
    ok: true,
    processed: (notifications ?? []).length,
    sent,
    failed,
  };
}

async function listPaymentPeriods(
  studyRoomId: string,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(studyRoomId, "공부방 정보가 올바르지 않습니다.");
  await assertStudyRoomAccess(db, activeTeacher, studyRoomId, {
    allowAdmin: true,
  });

  const { data: periods, error } = await db
    .from("payment_periods")
    .select("id, name, due_date, created_at")
    .eq("study_room_id", studyRoomId)
    .order("due_date", { ascending: false });

  if (error) throw new EdgeApiError(500, "납부 기간 조회에 실패했습니다.");

  return {
    ok: true,
    periods: (periods ?? []).map((period) => ({
      id: period.id,
      name: period.name,
      dueDate: period.due_date,
      createdAt: period.created_at,
    })),
  };
}

async function createPaymentPeriod(
  studyRoomId: string,
  body: Record<string, unknown>,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(studyRoomId, "공부방 정보가 올바르지 않습니다.");
  await assertStudyRoomAccess(db, activeTeacher, studyRoomId, {
    allowAdmin: false,
  });

  const name = stringValue(body.name);
  const dueDate = stringValue(body.dueDate);
  const amount = normalizeAmount(body.amount);
  if (name.length < 2) {
    throw new EdgeApiError(400, "납부 기간명을 입력해 주세요.");
  }
  assertDate(dueDate, "납부 마감일이 올바르지 않습니다.");

  const { data: studyRoom, error: studyRoomError } = await db
    .from("study_rooms")
    .select("id, organization_id")
    .eq("id", studyRoomId)
    .eq("owner_teacher_id", activeTeacher.id)
    .single();

  if (studyRoomError) {
    throw new EdgeApiError(500, "공부방 조회에 실패했습니다.");
  }

  const { data: period, error: periodError } = await db
    .from("payment_periods")
    .insert({
      organization_id: studyRoom.organization_id,
      study_room_id: studyRoomId,
      name,
      due_date: dueDate,
    })
    .select("id, name, due_date, created_at")
    .single();

  if (periodError) {
    throw new EdgeApiError(500, "납부 기간 생성에 실패했습니다.");
  }

  const { data: students, error: studentError } = await db
    .from("students")
    .select("id")
    .eq("study_room_id", studyRoomId)
    .eq("status", "active");

  if (studentError) {
    throw new EdgeApiError(500, "납부 대상 학생 조회에 실패했습니다.");
  }

  const statusRows = (students ?? []).map((student) => ({
    organization_id: studyRoom.organization_id,
    study_room_id: studyRoomId,
    payment_period_id: period.id,
    student_id: student.id,
    amount,
    status: "unpaid",
  }));
  if (statusRows.length > 0) {
    const { error: statusError } = await db
      .from("payment_statuses")
      .insert(statusRows);
    if (statusError) {
      throw new EdgeApiError(500, "학생별 납부 상태 생성에 실패했습니다.");
    }
  }

  await createPaymentAuditLog(db, {
    organizationId: studyRoom.organization_id,
    studyRoomId,
    actorTeacherId: activeTeacher.id,
    entityId: period.id,
    action: "created",
    title: "납부 기간 생성",
    summary: `${name} 납부 기간을 생성했습니다.`,
  });

  return {
    ok: true,
    period: {
      id: period.id,
      name: period.name,
      dueDate: period.due_date,
      createdAt: period.created_at,
    },
  };
}

async function listPaymentStatuses(
  paymentPeriodId: string,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(paymentPeriodId, "납부 기간 정보가 올바르지 않습니다.");
  const period = await readAccessiblePaymentPeriod(
    db,
    paymentPeriodId,
    activeTeacher,
    {
      allowAdmin: true,
    },
  );

  const { data: statuses, error } = await db
    .from("payment_statuses")
    .select(
      "id, student_id, amount, status, paid_at, note, students!inner(id, student_code, name, status)",
    )
    .eq("payment_period_id", paymentPeriodId)
    .order("created_at", { ascending: true });

  if (error) throw new EdgeApiError(500, "납부 상태 조회에 실패했습니다.");

  return {
    ok: true,
    period: {
      id: period.id,
      name: period.name,
      dueDate: period.due_date,
    },
    statuses: (statuses ?? []).map(formatPaymentStatus),
  };
}

async function updatePaymentStatus(
  paymentStatusId: string,
  body: Record<string, unknown>,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(paymentStatusId, "납부 상태 정보가 올바르지 않습니다.");
  const status = normalizePaymentStatus(body.status);
  const note = nullableString(body.note);

  const current = await readPaymentStatusForOwnerWrite(
    db,
    paymentStatusId,
    activeTeacher,
  );
  const period = await readAccessiblePaymentPeriod(
    db,
    current.payment_period_id,
    activeTeacher,
    { allowAdmin: false },
  );
  const paidAt = status === "paid" ? new Date().toISOString() : null;

  const { data: updated, error } = await db
    .from("payment_statuses")
    .update({
      status,
      note,
      paid_at: paidAt,
      updated_at: new Date().toISOString(),
    })
    .eq("id", paymentStatusId)
    .select(
      "id, student_id, amount, status, paid_at, note, students!inner(id, student_code, name, status)",
    )
    .single();

  if (error) throw new EdgeApiError(500, "납부 상태 변경에 실패했습니다.");

  const student = normalizeJoinedObject(updated.students);
  await createPaymentAuditLog(db, {
    organizationId: current.organization_id,
    studyRoomId: current.study_room_id,
    actorTeacherId: activeTeacher.id,
    studentId: updated.student_id,
    entityId: paymentStatusId,
    action: "status_changed",
    title: "납부 상태 변경",
    summary: `${student.name ?? "학생"} 납부 상태를 ${status}로 변경했습니다.`,
  });

  let createdCount = 0;
  if (status === "paid" && current.status !== "paid") {
    const notifications = await createPaymentPaidNotificationLogs(db, {
      organizationId: current.organization_id,
      studyRoomId: current.study_room_id,
      paymentPeriodId: current.payment_period_id,
      paymentStatusId,
      studentId: updated.student_id,
      studentName: stringValue(student.name) || "학생",
      periodName: period.name,
      paidAt: updated.paid_at,
      amount: Number(updated.amount ?? 0),
    });
    createdCount = notifications.length;
  }

  return {
    ok: true,
    status: formatPaymentStatus(updated),
    notifications: { requested: createdCount },
  };
}

async function notifyUnpaidPayments(
  paymentPeriodId: string,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(paymentPeriodId, "납부 기간 정보가 올바르지 않습니다.");
  const period = await readAccessiblePaymentPeriod(
    db,
    paymentPeriodId,
    activeTeacher,
    {
      allowAdmin: false,
    },
  );

  const { data: unpaidStatuses, error } = await db
    .from("payment_statuses")
    .select(
      "id, student_id, amount, status, students!inner(id, name)",
    )
    .eq("payment_period_id", paymentPeriodId)
    .in("status", ["unpaid", "partial"]);

  if (error) throw new EdgeApiError(500, "미납 대상 조회에 실패했습니다.");

  const createdCount = await createPaymentReminderLogsForStatuses(
    db,
    period,
    unpaidStatuses ?? [],
  );

  await createPaymentAuditLog(db, {
    organizationId: period.organization_id,
    studyRoomId: period.study_room_id,
    actorTeacherId: activeTeacher.id,
    entityId: paymentPeriodId,
    action: "message_requested",
    title: "미납 안내 요청",
    summary: `${period.name} 미납 안내 ${createdCount}건을 요청했습니다.`,
  });

  return {
    ok: true,
    notifications: { requested: createdCount },
  };
}

async function notifyDueUnpaidPayments(
  body: Record<string, unknown>,
  { db }: { db: SupabaseClient },
): Promise<Record<string, unknown>> {
  const dueInDays = normalizeLimit(body.dueInDays, 3, 30);
  const periodLimit = normalizeLimit(body.periodLimit, 100, 500);
  const today = kstDateString(new Date());
  const dueUntil = kstDateString(addDays(new Date(), dueInDays));

  const { data: periods, error: periodError } = await db
    .from("payment_periods")
    .select("id, organization_id, study_room_id, name, due_date")
    .gte("due_date", today)
    .lte("due_date", dueUntil)
    .order("due_date", { ascending: true })
    .limit(periodLimit);

  if (periodError) {
    throw new EdgeApiError(
      500,
      "자동 미납 안내 대상 기간 조회에 실패했습니다.",
    );
  }

  let requested = 0;
  let statusCount = 0;
  for (const period of periods ?? []) {
    const { data: unpaidStatuses, error } = await db
      .from("payment_statuses")
      .select("id, student_id, amount, status, students!inner(id, name)")
      .eq("payment_period_id", period.id)
      .in("status", ["unpaid", "partial"]);

    if (error) {
      throw new EdgeApiError(
        500,
        "자동 미납 안내 대상 학생 조회에 실패했습니다.",
      );
    }

    statusCount += unpaidStatuses?.length ?? 0;
    requested += await createPaymentReminderLogsForStatuses(
      db,
      period,
      unpaidStatuses ?? [],
    );
  }

  return {
    ok: true,
    dueWindow: { from: today, to: dueUntil, dueInDays },
    periods: { scanned: periods?.length ?? 0 },
    paymentStatuses: { matched: statusCount },
    notifications: { requested },
  };
}

async function createPaymentReminderLogsForStatuses(
  db: SupabaseClient,
  period: {
    id: string;
    organization_id: string;
    study_room_id: string;
    name: string;
    due_date: string;
  },
  unpaidStatuses: Record<string, unknown>[],
) {
  let createdCount = 0;
  for (const paymentStatus of unpaidStatuses) {
    const student = normalizeJoinedObject(paymentStatus.students);
    const notifications = await createPaymentReminderNotificationLogs(db, {
      organizationId: period.organization_id,
      studyRoomId: period.study_room_id,
      paymentPeriodId: period.id,
      paymentStatusId: String(paymentStatus.id),
      studentId: String(paymentStatus.student_id),
      studentName: stringValue(student.name) || "학생",
      periodName: period.name,
      dueDate: period.due_date,
      amount: Number(paymentStatus.amount ?? 0),
    });
    createdCount += notifications.length;
  }
  return createdCount;
}

async function createStudent(
  studyRoomId: string,
  body: Record<string, unknown>,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(studyRoomId, "공부방 정보가 올바르지 않습니다.");
  await assertStudyRoomAccess(db, activeTeacher, studyRoomId, {
    allowAdmin: false,
  });

  const name = stringValue(body.name);
  const code = stringValue(body.code);
  const pin = stringValue(body.pin);
  const gender = normalizeStudentGender(body.gender);
  const ageGroup = normalizeStudentAgeGroup(body.ageGroup);
  const avatarKey = normalizeAvatarKey(body.avatarKey, gender, ageGroup);
  if (name.length < 2) {
    throw new EdgeApiError(400, "학생 이름을 입력해 주세요.");
  }
  if (code.length < 1) throw new EdgeApiError(400, "학생번호를 입력해 주세요.");
  if (!pinPattern.test(pin)) {
    throw new EdgeApiError(400, "출결 비밀번호는 숫자 6자리여야 합니다.");
  }

  const { data: studyRoom, error: studyRoomError } = await db
    .from("study_rooms")
    .select("id, organization_id")
    .eq("id", studyRoomId)
    .eq("owner_teacher_id", activeTeacher.id)
    .single();

  if (studyRoomError) {
    throw new EdgeApiError(500, "공부방 조회에 실패했습니다.");
  }

  const { data: student, error: studentError } = await db
    .from("students")
    .insert({
      organization_id: studyRoom.organization_id,
      study_room_id: studyRoomId,
      student_code: code,
      name,
      pin_hash: await hashStudentPin(db, pin),
      pin_reset_required: false,
      status: "active",
      gender,
      age_group: ageGroup,
      avatar_key: avatarKey,
    })
    .select("id, student_code, name, status, gender, age_group, avatar_key")
    .single();

  if (studentError) {
    if (studentError.code === "23505") {
      throw new EdgeApiError(409, "이미 사용 중인 학생번호입니다.");
    }
    throw new EdgeApiError(500, "학생 등록에 실패했습니다.");
  }

  await createStudentAuditLog(db, {
    organizationId: studyRoom.organization_id,
    studyRoomId,
    actorTeacherId: activeTeacher.id,
    studentId: student.id,
    title: "학생 등록",
    summary: `${student.name} 학생을 등록했습니다.`,
  });

  return {
    ok: true,
    student: {
      id: student.id,
      code: student.student_code,
      name: student.name,
      status: student.status,
      gender: student.gender,
      ageGroup: student.age_group,
      avatarKey: student.avatar_key,
    },
  };
}

async function updateStudent(
  studentId: string,
  body: Record<string, unknown>,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(studentId, "학생 정보가 올바르지 않습니다.");
  const current = await readStudentForOwnerWrite(db, studentId, activeTeacher);

  const name = stringValue(body.name);
  const code = stringValue(body.code);
  const status = normalizeStudentStatus(body.status);
  const gender = normalizeStudentGender(body.gender);
  const ageGroup = normalizeStudentAgeGroup(body.ageGroup);
  const avatarKey = normalizeAvatarKey(body.avatarKey, gender, ageGroup);
  if (name.length < 2) {
    throw new EdgeApiError(400, "학생 이름을 입력해 주세요.");
  }
  if (code.length < 1) throw new EdgeApiError(400, "학생번호를 입력해 주세요.");

  const { data: student, error } = await db
    .from("students")
    .update({
      student_code: code,
      name,
      status,
      gender,
      age_group: ageGroup,
      avatar_key: avatarKey,
      updated_at: new Date().toISOString(),
    })
    .eq("id", studentId)
    .select("id, student_code, name, status, gender, age_group, avatar_key")
    .single();

  if (error) {
    if (error.code === "23505") {
      throw new EdgeApiError(409, "이미 사용 중인 학생번호입니다.");
    }
    throw new EdgeApiError(500, "학생 수정에 실패했습니다.");
  }

  await createStudentAuditLog(db, {
    organizationId: current.organization_id,
    studyRoomId: current.study_room_id,
    actorTeacherId: activeTeacher.id,
    studentId,
    action: "updated",
    title: "학생 정보 수정",
    summary: `${student.name} 학생 정보를 수정했습니다.`,
  });

  return { ok: true, student: formatManagedStudent(student) };
}

async function resetStudentPin(
  studentId: string,
  body: Record<string, unknown>,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(studentId, "학생 정보가 올바르지 않습니다.");
  const current = await readStudentForOwnerWrite(db, studentId, activeTeacher);

  const pin = stringValue(body.pin);
  if (!pinPattern.test(pin)) {
    throw new EdgeApiError(400, "출결 비밀번호는 숫자 6자리여야 합니다.");
  }

  const { data: student, error } = await db
    .from("students")
    .update({
      pin_hash: await hashStudentPin(db, pin),
      pin_reset_required: false,
      updated_at: new Date().toISOString(),
    })
    .eq("id", studentId)
    .select("id, student_code, name, status, gender, age_group, avatar_key")
    .single();

  if (error) throw new EdgeApiError(500, "출결 비밀번호 리셋에 실패했습니다.");

  await createStudentAuditLog(db, {
    organizationId: current.organization_id,
    studyRoomId: current.study_room_id,
    actorTeacherId: activeTeacher.id,
    studentId,
    action: "updated",
    title: "출결 비밀번호 리셋",
    summary: `${student.name} 학생의 출결 비밀번호를 리셋했습니다.`,
  });

  return { ok: true, student: formatManagedStudent(student) };
}

async function leaveStudent(
  studentId: string,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(studentId, "학생 정보가 올바르지 않습니다.");
  const current = await readStudentForOwnerWrite(db, studentId, activeTeacher);

  const { data: student, error } = await db
    .from("students")
    .update({ status: "left", updated_at: new Date().toISOString() })
    .eq("id", studentId)
    .select("id, student_code, name, status, gender, age_group, avatar_key")
    .single();

  if (error) throw new EdgeApiError(500, "학생 삭제 처리에 실패했습니다.");

  const { error: enrollmentError } = await db
    .from("class_students")
    .update({ active: false })
    .eq("student_id", studentId);

  if (enrollmentError) {
    throw new EdgeApiError(500, "학생 수업 등록 해제에 실패했습니다.");
  }

  await createStudentAuditLog(db, {
    organizationId: current.organization_id,
    studyRoomId: current.study_room_id,
    actorTeacherId: activeTeacher.id,
    studentId,
    action: "deleted",
    title: "학생 삭제",
    summary: `${student.name} 학생을 삭제 처리했습니다.`,
  });

  return { ok: true, student: formatManagedStudent(student) };
}

async function listStudentGuardians(
  studentId: string,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(studentId, "학생 정보가 올바르지 않습니다.");

  const { data: student, error: studentError } = await db
    .from("students")
    .select("id, study_room_id")
    .eq("id", studentId)
    .maybeSingle();

  if (studentError) throw new EdgeApiError(500, "학생 조회에 실패했습니다.");
  if (!student) throw new EdgeApiError(404, "학생을 찾을 수 없습니다.");
  await assertStudyRoomAccess(db, activeTeacher, student.study_room_id, {
    allowAdmin: true,
  });

  const { data: rows, error } = await db
    .from("student_guardians")
    .select(
      "relationship, primary_contact, guardians!inner(id, name, phone, kakao_opt_in, consent_confirmed_at, opt_out_at, deleted_at)",
    )
    .eq("student_id", studentId)
    .order("created_at", { ascending: true });

  if (error) throw new EdgeApiError(500, "보호자 목록 조회에 실패했습니다.");

  return {
    ok: true,
    guardians: (rows ?? []).map(formatStudentGuardian),
  };
}

async function saveStudentGuardians(
  studentId: string,
  body: Record<string, unknown>,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  const activeTeacher = requireTeacherProfile(teacher);
  assertUuid(studentId, "학생 정보가 올바르지 않습니다.");
  const student = await readStudentForOwnerWrite(db, studentId, activeTeacher);
  const guardians = normalizeGuardianInputs(body.guardians);

  const keptGuardianIds: string[] = [];
  for (const guardianInput of guardians) {
    let guardianId = guardianInput.id;
    const currentGuardian = guardianId
      ? await readGuardianForStudyRoom(db, guardianId, student.study_room_id)
      : null;
    const deletedAt = guardianInput.deleted ? new Date().toISOString() : null;
    const kakaoOptIn = guardianInput.deleted ? false : guardianInput.kakaoOptIn;
    const primaryContact = guardianInput.deleted
      ? false
      : guardianInput.primaryContact;
    const consentConfirmedAt = kakaoOptIn
      ? currentGuardian?.consent_confirmed_at ?? new Date().toISOString()
      : null;
    const consentConfirmedByTeacherId = kakaoOptIn
      ? currentGuardian?.consent_confirmed_by_teacher_id ?? activeTeacher.id
      : null;
    const guardianValues = {
      name: guardianInput.name || null,
      phone: guardianInput.phone,
      kakao_opt_in: kakaoOptIn,
      consent_confirmed_at: consentConfirmedAt,
      consent_method: kakaoOptIn ? "teacher_confirmed" : null,
      consent_confirmed_by_teacher_id: consentConfirmedByTeacherId,
      opt_out_at: kakaoOptIn ? null : new Date().toISOString(),
      deleted_at: deletedAt,
    };

    if (guardianId) {
      const { error: updateError } = await db
        .from("guardians")
        .update(guardianValues)
        .eq("id", guardianId)
        .eq("study_room_id", student.study_room_id);
      if (updateError) {
        throw new EdgeApiError(500, "보호자 정보 수정에 실패했습니다.");
      }
    } else {
      const { data: guardian, error: insertError } = await db
        .from("guardians")
        .insert({
          organization_id: student.organization_id,
          study_room_id: student.study_room_id,
          ...guardianValues,
        })
        .select("id")
        .single();
      if (insertError) {
        throw new EdgeApiError(500, "보호자 정보 생성에 실패했습니다.");
      }
      guardianId = guardian.id;
    }
    if (!guardianId) {
      throw new EdgeApiError(500, "보호자 정보 저장에 실패했습니다.");
    }

    keptGuardianIds.push(guardianId);
    const { error: linkError } = await db
      .from("student_guardians")
      .upsert({
        student_id: studentId,
        guardian_id: guardianId,
        relationship: guardianInput.relationship || null,
        primary_contact: primaryContact,
      }, { onConflict: "student_id,guardian_id" });
    if (linkError) {
      throw new EdgeApiError(500, "학생 보호자 연결 저장에 실패했습니다.");
    }
  }

  let unlinkQuery = db
    .from("student_guardians")
    .delete()
    .eq("student_id", studentId);
  if (keptGuardianIds.length > 0) {
    unlinkQuery = unlinkQuery.not(
      "guardian_id",
      "in",
      `(${keptGuardianIds.join(",")})`,
    );
  }
  const { error: unlinkError } = await unlinkQuery;
  if (unlinkError) {
    throw new EdgeApiError(500, "학생 보호자 연결 정리에 실패했습니다.");
  }

  await createGuardianAuditLog(db, {
    organizationId: student.organization_id,
    studyRoomId: student.study_room_id,
    actorTeacherId: activeTeacher.id,
    studentId,
    entityId: studentId,
    title: "보호자 정보 저장",
    summary:
      `${student.name} 학생의 보호자 ${guardians.length}명을 저장했습니다.`,
  });

  return await listStudentGuardians(studentId, {
    db,
    authUser: { id: "", email: null, name: null },
    teacher: activeTeacher,
  });
}

async function checkInStudent(
  classSessionId: string,
  body: Record<string, unknown>,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  if (!teacher) throw new EdgeApiError(403, "선생님 프로필이 필요합니다.");

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
    attendanceStatus: "present",
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

async function seatCheckInStudent(
  classSessionId: string,
  body: Record<string, unknown>,
  { db, teacher }: AppContext,
): Promise<Record<string, unknown>> {
  if (!teacher) throw new EdgeApiError(403, "선생님 프로필이 필요합니다.");

  const studentId = stringValue(body.studentId);
  const seatId = stringValue(body.seatId);
  const pin = stringValue(body.pin);

  assertUuid(classSessionId, "수업 회차 정보가 올바르지 않습니다.");
  assertUuid(studentId, "학생 정보가 올바르지 않습니다.");
  assertUuid(seatId, "좌석 정보가 올바르지 않습니다.");
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

  await assertSeatCheckInScope(db, {
    classId: session.class_id,
    classSessionId,
    studentId,
    seatId,
  });

  const attendance = await createAttendanceRecord(db, {
    organizationId: session.organization_id,
    studyRoomId: session.study_room_id,
    classSessionId,
    studentId,
    teacherId: teacher.id,
    classroomSeatId: seatId,
    checkedInMethod: "seat_pin",
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
    attendanceStatus: "present",
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
    title: "학생 좌석 출석 체크",
    summary:
      `${student.name} 학생이 ${classInfo.name} 수업에 좌석 출석했습니다.`,
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

async function readClassSessionForDate(
  db: SupabaseClient,
  classId: string,
  sessionDate: string,
) {
  const { data, error } = await db
    .from("class_sessions")
    .select("id, session_date, starts_at, ends_at, status")
    .eq("class_id", classId)
    .eq("session_date", sessionDate)
    .maybeSingle();

  if (error) throw new EdgeApiError(500, "수업 회차 조회에 실패했습니다.");
  if (!data) {
    throw new EdgeApiError(404, "연결할 휴강 회차를 찾을 수 없습니다.");
  }
  return data;
}

async function ensureClassSessionForDate(
  db: SupabaseClient,
  classRoom: Record<string, unknown>,
  sessionDate: string,
  input: {
    status: "scheduled" | "open" | "completed" | "cancelled";
    reason: string | null;
    teacherId: string;
  },
) {
  const { data: existing, error: existingError } = await db
    .from("class_sessions")
    .select("id, session_date, starts_at, ends_at, status")
    .eq("class_id", classRoom.id)
    .eq("session_date", sessionDate)
    .maybeSingle();

  if (existingError) {
    throw new EdgeApiError(500, "수업 회차 조회에 실패했습니다.");
  }
  if (existing) return existing;

  const { data: schedule, error: scheduleError } = await db
    .from("class_schedules")
    .select("id, starts_at, ends_at")
    .eq("class_id", classRoom.id)
    .eq("active", true)
    .order("day_of_week", { ascending: true })
    .limit(1)
    .maybeSingle();

  if (scheduleError) {
    throw new EdgeApiError(500, "수업 일정 조회에 실패했습니다.");
  }
  if (!schedule) {
    throw new EdgeApiError(400, "수업 일정이 먼저 필요합니다.");
  }

  const { data: session, error } = await db
    .from("class_sessions")
    .insert({
      organization_id: classRoom.organization_id,
      study_room_id: classRoom.study_room_id,
      class_id: classRoom.id,
      class_schedule_id: schedule.id,
      session_date: sessionDate,
      starts_at: toKstIso(sessionDate, schedule.starts_at),
      ends_at: toKstIso(sessionDate, schedule.ends_at),
      kind: classRoom.class_kind,
      status: input.status,
      change_reason: input.reason,
      opened_by_teacher_id: input.teacherId,
    })
    .select("id, session_date, starts_at, ends_at, status")
    .single();

  if (error) throw new EdgeApiError(500, "수업 회차 생성에 실패했습니다.");
  return session;
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

async function readAccessibleStudyRoom(
  db: SupabaseClient,
  studyRoomId: string,
  teacher: TeacherContext,
  options: { allowAdmin: boolean },
) {
  const { data, error } = await db
    .from("study_rooms")
    .select(
      "id, organization_id, name, description, created_at, owner_teacher_id",
    )
    .eq("id", studyRoomId)
    .maybeSingle();

  if (error) throw new EdgeApiError(500, "공부방 조회에 실패했습니다.");
  if (!data) throw new EdgeApiError(404, "공부방을 찾을 수 없습니다.");
  await assertStudyRoomAccess(db, teacher, studyRoomId, options);
  return data;
}

async function readAccessibleClass(
  db: SupabaseClient,
  classId: string,
  teacher: TeacherContext,
  options: { allowAdmin: boolean },
) {
  const { data, error } = await db
    .from("classes")
    .select("id, organization_id, study_room_id, name, class_kind")
    .eq("id", classId)
    .maybeSingle();

  if (error) throw new EdgeApiError(500, "수업 조회에 실패했습니다.");
  if (!data) throw new EdgeApiError(404, "수업을 찾을 수 없습니다.");
  await assertStudyRoomAccess(db, teacher, data.study_room_id, options);
  return data;
}

async function readActiveClassroomLayout(
  db: SupabaseClient,
  classId: string,
) {
  const { data, error } = await db
    .from("classroom_layouts")
    .select(
      "id, organization_id, study_room_id, class_id, name, canvas_width, canvas_height, version",
    )
    .eq("class_id", classId)
    .eq("active", true)
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) throw new EdgeApiError(500, "교실 배치 조회에 실패했습니다.");
  return data;
}

async function deactivateActiveClassroomLayouts(
  db: SupabaseClient,
  classId: string,
) {
  const { error } = await db
    .from("classroom_layouts")
    .update({ active: false })
    .eq("class_id", classId)
    .eq("active", true);
  if (error) throw new EdgeApiError(500, "기존 교실 배치 정리에 실패했습니다.");
}

async function createClassroomLayoutRow(
  db: SupabaseClient,
  classRoom: Record<string, unknown>,
  input: {
    name: string;
    canvasWidth: number;
    canvasHeight: number;
    teacherId: string;
  },
) {
  const { data, error } = await db
    .from("classroom_layouts")
    .insert({
      organization_id: classRoom.organization_id,
      study_room_id: classRoom.study_room_id,
      class_id: classRoom.id,
      name: input.name,
      canvas_width: input.canvasWidth,
      canvas_height: input.canvasHeight,
      created_by_teacher_id: input.teacherId,
      active: true,
    })
    .select(
      "id, organization_id, study_room_id, class_id, name, canvas_width, canvas_height, version",
    )
    .single();
  if (error) throw new EdgeApiError(500, "교실 배치 생성에 실패했습니다.");
  return data;
}

async function updateClassroomLayoutRow(
  db: SupabaseClient,
  layoutId: string,
  input: { name: string; canvasWidth: number; canvasHeight: number },
) {
  const { data, error } = await db
    .from("classroom_layouts")
    .update({
      name: input.name,
      canvas_width: input.canvasWidth,
      canvas_height: input.canvasHeight,
    })
    .eq("id", layoutId)
    .select(
      "id, organization_id, study_room_id, class_id, name, canvas_width, canvas_height, version",
    )
    .single();
  if (error) throw new EdgeApiError(500, "교실 배치 수정에 실패했습니다.");
  return data;
}

async function formatClassroomLayout(
  db: SupabaseClient,
  layout: Record<string, unknown>,
  classRoom: Record<string, unknown>,
) {
  const { data: seats, error: seatsError } = await db
    .from("classroom_seats")
    .select(
      "id, label, desk_x, desk_y, seat_x, seat_y, rotation_degrees, display_order",
    )
    .eq("classroom_layout_id", layout.id)
    .eq("active", true)
    .order("display_order", { ascending: true });
  if (seatsError) throw new EdgeApiError(500, "좌석 조회에 실패했습니다.");

  const { data: assignments, error: assignmentsError } = await db
    .from("student_seat_assignments")
    .select(
      "classroom_seat_id, student_id, students!inner(name, student_code, avatar_key)",
    )
    .eq("classroom_layout_id", layout.id)
    .eq("active", true);
  if (assignmentsError) {
    throw new EdgeApiError(500, "좌석 배정 조회에 실패했습니다.");
  }

  return {
    id: layout.id,
    classId: classRoom.id,
    name: layout.name,
    canvasWidth: Number(layout.canvas_width ?? 1000),
    canvasHeight: Number(layout.canvas_height ?? 700),
    seats: (seats ?? []).map(formatClassroomSeat),
    assignments: (assignments ?? []).map(formatSeatAssignment),
  };
}

async function readAttendanceClassroomLayout(
  db: SupabaseClient,
  classId: string,
  classSessionId: string,
) {
  const layout = await readActiveClassroomLayout(db, classId);
  if (!layout) return null;

  const { data: seats, error: seatsError } = await db
    .from("classroom_seats")
    .select(
      "id, label, desk_x, desk_y, seat_x, seat_y, rotation_degrees, display_order",
    )
    .eq("classroom_layout_id", layout.id)
    .eq("active", true)
    .order("display_order", { ascending: true });
  if (seatsError) throw new EdgeApiError(500, "좌석 조회에 실패했습니다.");

  const { data: assignments, error: assignmentsError } = await db
    .from("student_seat_assignments")
    .select("classroom_seat_id, student_id, students!inner(name, student_code)")
    .eq("classroom_layout_id", layout.id)
    .eq("active", true);
  if (assignmentsError) {
    throw new EdgeApiError(500, "좌석 배정 조회에 실패했습니다.");
  }

  const { data: occupiedSeats, error: occupiedSeatsError } = await db
    .from("attendance_records")
    .select(
      "classroom_seat_id, student_id, status, checked_in_at, students!inner(name, student_code, avatar_key)",
    )
    .eq("class_session_id", classSessionId)
    .not("classroom_seat_id", "is", null);
  if (occupiedSeatsError) {
    throw new EdgeApiError(500, "좌석 출석 상태 조회에 실패했습니다.");
  }

  return {
    id: layout.id,
    name: layout.name,
    canvasWidth: Number(layout.canvas_width ?? 1000),
    canvasHeight: Number(layout.canvas_height ?? 700),
    seats: (seats ?? []).map(formatClassroomSeat),
    assignments: (assignments ?? []).map(formatSeatAssignment),
    occupiedSeats: (occupiedSeats ?? []).map(formatSeatOccupancy),
  };
}

async function assertSeatCheckInScope(
  db: SupabaseClient,
  input: {
    classId: string;
    classSessionId: string;
    studentId: string;
    seatId: string;
  },
) {
  const layout = await readActiveClassroomLayout(db, input.classId);
  if (!layout) throw new EdgeApiError(400, "교실 배치가 없는 수업입니다.");

  const { data: seat, error: seatError } = await db
    .from("classroom_seats")
    .select("id")
    .eq("id", input.seatId)
    .eq("classroom_layout_id", layout.id)
    .eq("active", true)
    .maybeSingle();
  if (seatError) throw new EdgeApiError(500, "좌석 범위 확인에 실패했습니다.");
  if (!seat) throw new EdgeApiError(400, "좌석 정보가 올바르지 않습니다.");

  const { data: assignment, error: assignmentError } = await db
    .from("student_seat_assignments")
    .select("student_id")
    .eq("classroom_layout_id", layout.id)
    .eq("classroom_seat_id", input.seatId)
    .eq("active", true)
    .maybeSingle();
  if (assignmentError) {
    throw new EdgeApiError(500, "좌석 배정 확인에 실패했습니다.");
  }
  if (assignment && assignment.student_id !== input.studentId) {
    throw new EdgeApiError(409, "다른 학생에게 배정된 좌석입니다.");
  }

  const { data: occupiedSeat, error: occupiedSeatError } = await db
    .from("attendance_records")
    .select("id, student_id")
    .eq("class_session_id", input.classSessionId)
    .eq("classroom_seat_id", input.seatId)
    .maybeSingle();
  if (occupiedSeatError) {
    throw new EdgeApiError(500, "좌석 출석 중복 확인에 실패했습니다.");
  }
  if (occupiedSeat && occupiedSeat.student_id !== input.studentId) {
    throw new EdgeApiError(409, "이미 사용 중인 좌석입니다.");
  }
}

async function copyEligibleSeatAssignments(
  db: SupabaseClient,
  input: {
    sourceLayoutId: string;
    targetLayoutId: string;
    targetClassId: string;
    seatIdBySourceId: Map<string, string>;
    teacherId: string;
  },
) {
  const { data: targetStudents, error: targetStudentsError } = await db
    .from("class_students")
    .select("student_id")
    .eq("class_id", input.targetClassId)
    .eq("active", true);
  if (targetStudentsError) {
    throw new EdgeApiError(500, "대상 수업 학생 조회에 실패했습니다.");
  }
  const targetStudentIds = new Set(
    (targetStudents ?? []).map((row) => String(row.student_id)),
  );
  if (targetStudentIds.size === 0) return 0;

  const { data: assignments, error: assignmentsError } = await db
    .from("student_seat_assignments")
    .select("classroom_seat_id, student_id")
    .eq("classroom_layout_id", input.sourceLayoutId)
    .eq("active", true);
  if (assignmentsError) {
    throw new EdgeApiError(500, "원본 좌석 배정 조회에 실패했습니다.");
  }

  const nextAssignments = [];
  for (const assignment of assignments ?? []) {
    const studentId = String(assignment.student_id);
    const sourceSeatId = String(assignment.classroom_seat_id);
    const targetSeatId = input.seatIdBySourceId.get(sourceSeatId);
    if (!targetSeatId || !targetStudentIds.has(studentId)) continue;
    nextAssignments.push({
      classroom_layout_id: input.targetLayoutId,
      classroom_seat_id: targetSeatId,
      student_id: studentId,
      assigned_by_teacher_id: input.teacherId,
      active: true,
    });
  }

  if (nextAssignments.length === 0) return 0;

  const { error: insertError } = await db
    .from("student_seat_assignments")
    .insert(nextAssignments);
  if (insertError) {
    throw new EdgeApiError(500, "좌석 배정 복사에 실패했습니다.");
  }
  return nextAssignments.length;
}

async function assertSeatAssignmentScope(
  db: SupabaseClient,
  layoutId: string,
  classRoom: Record<string, unknown>,
  assignments: Array<{ seatId: string; studentId: string }>,
) {
  if (assignments.length === 0) return;
  const seatIds = [...new Set(assignments.map((item) => item.seatId))];
  const studentIds = [...new Set(assignments.map((item) => item.studentId))];
  if (
    seatIds.length !== assignments.length ||
    studentIds.length !== assignments.length
  ) {
    throw new EdgeApiError(400, "좌석 또는 학생이 중복 배정되었습니다.");
  }

  const { data: seats, error: seatsError } = await db
    .from("classroom_seats")
    .select("id")
    .eq("classroom_layout_id", layoutId)
    .eq("active", true)
    .in("id", seatIds);
  if (seatsError) throw new EdgeApiError(500, "좌석 범위 확인에 실패했습니다.");
  if ((seats ?? []).length !== seatIds.length) {
    throw new EdgeApiError(400, "좌석 정보가 올바르지 않습니다.");
  }

  const { data: classStudents, error: studentsError } = await db
    .from("class_students")
    .select("student_id")
    .eq("class_id", classRoom.id)
    .eq("active", true)
    .in("student_id", studentIds);
  if (studentsError) {
    throw new EdgeApiError(500, "수강 학생 범위 확인에 실패했습니다.");
  }
  if ((classStudents ?? []).length !== studentIds.length) {
    throw new EdgeApiError(
      400,
      "수업에 등록된 학생만 좌석에 배정할 수 있습니다.",
    );
  }
}

async function readAccessiblePaymentPeriod(
  db: SupabaseClient,
  paymentPeriodId: string,
  teacher: TeacherContext,
  options: { allowAdmin: boolean },
) {
  const { data, error } = await db
    .from("payment_periods")
    .select("id, organization_id, study_room_id, name, due_date")
    .eq("id", paymentPeriodId)
    .maybeSingle();

  if (error) throw new EdgeApiError(500, "납부 기간 조회에 실패했습니다.");
  if (!data) throw new EdgeApiError(404, "납부 기간을 찾을 수 없습니다.");
  await assertStudyRoomAccess(db, teacher, data.study_room_id, options);
  return data;
}

async function readPaymentStatusForOwnerWrite(
  db: SupabaseClient,
  paymentStatusId: string,
  teacher: TeacherContext,
) {
  const { data, error } = await db
    .from("payment_statuses")
    .select(
      "id, organization_id, study_room_id, payment_period_id, student_id, status, study_rooms!inner(owner_teacher_id)",
    )
    .eq("id", paymentStatusId)
    .maybeSingle();

  if (error) throw new EdgeApiError(500, "납부 상태 조회에 실패했습니다.");
  if (!data) throw new EdgeApiError(404, "납부 상태를 찾을 수 없습니다.");
  const studyRoom = normalizeJoinedObject(data.study_rooms);
  if (studyRoom.owner_teacher_id !== teacher.id) {
    throw new EdgeApiError(403, "해당 납부 상태를 수정할 수 없습니다.");
  }
  return data;
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

async function readStudentForOwnerWrite(
  db: SupabaseClient,
  studentId: string,
  teacher: TeacherContext,
) {
  const { data, error } = await db
    .from("students")
    .select(
      "id, organization_id, study_room_id, name, study_rooms!inner(owner_teacher_id)",
    )
    .eq("id", studentId)
    .maybeSingle();

  if (error) throw new EdgeApiError(500, "학생 조회에 실패했습니다.");
  if (!data) throw new EdgeApiError(404, "학생을 찾을 수 없습니다.");
  const studyRoom = normalizeJoinedObject(data.study_rooms);
  if (studyRoom.owner_teacher_id !== teacher.id) {
    throw new EdgeApiError(403, "해당 학생을 수정할 수 없습니다.");
  }
  return data;
}

async function readGuardianForStudyRoom(
  db: SupabaseClient,
  guardianId: string,
  studyRoomId: string,
) {
  const { data, error } = await db
    .from("guardians")
    .select("id, consent_confirmed_at, consent_confirmed_by_teacher_id")
    .eq("id", guardianId)
    .eq("study_room_id", studyRoomId)
    .maybeSingle();

  if (error) throw new EdgeApiError(500, "보호자 정보 조회에 실패했습니다.");
  if (!data) throw new EdgeApiError(404, "보호자 정보를 찾을 수 없습니다.");
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
    classroomSeatId?: string;
    checkedInMethod?: string;
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
      checked_in_method: input.checkedInMethod ?? "student_pin",
      classroom_seat_id: input.classroomSeatId ?? null,
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
    attendanceStatus: string;
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
    .map((guardian) => {
      const eventType = input.attendanceStatus === "present"
        ? "attendance_checked_in"
        : "attendance_status_changed";
      return {
        organization_id: input.organizationId,
        study_room_id: input.studyRoomId,
        student_id: input.studentId,
        guardian_id: guardian.id,
        class_id: input.classId,
        class_session_id: input.classSessionId,
        attendance_record_id: input.attendanceRecordId,
        event_type: eventType,
        channel: "kakao",
        recipient_phone_masked: maskPhone(guardian.phone),
        student_name: input.studentName,
        class_name: input.className,
        event_time: input.checkedInAt,
        payload: buildKakaoTemplatePayload(eventType, {
          studentName: input.studentName,
          className: input.className,
          attendanceStatus: input.attendanceStatus,
          checkedInAt: input.checkedInAt,
        }),
        status: "pending",
      };
    });

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

async function createPaymentReminderNotificationLogs(
  db: SupabaseClient,
  input: {
    organizationId: string;
    studyRoomId: string;
    paymentPeriodId: string;
    paymentStatusId: string;
    studentId: string;
    studentName: string;
    periodName: string;
    dueDate: string;
    amount: number;
  },
) {
  if (
    await hasPaymentNotificationLog(db, {
      eventType: "payment_due_reminder",
      paymentStatusId: input.paymentStatusId,
    })
  ) {
    return [];
  }

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
      payment_period_id: input.paymentPeriodId,
      payment_status_id: input.paymentStatusId,
      event_type: "payment_due_reminder",
      channel: "kakao",
      recipient_phone_masked: maskPhone(guardian.phone),
      student_name: input.studentName,
      class_name: input.periodName,
      event_time: new Date().toISOString(),
      payload: buildKakaoTemplatePayload("payment_due_reminder", {
        studentName: input.studentName,
        paymentPeriodName: input.periodName,
        dueDate: input.dueDate,
        amount: input.amount,
        paymentPeriodId: input.paymentPeriodId,
        paymentStatusId: input.paymentStatusId,
      }),
      status: "pending",
    }));

  if (rows.length === 0) return [];

  const { data, error: insertError } = await db
    .from("notification_logs")
    .insert(rows)
    .select("id");

  if (insertError) {
    throw new EdgeApiError(500, "카카오 미납 안내 로그 생성에 실패했습니다.");
  }
  return data ?? [];
}

async function createPaymentPaidNotificationLogs(
  db: SupabaseClient,
  input: {
    organizationId: string;
    studyRoomId: string;
    paymentPeriodId: string;
    paymentStatusId: string;
    studentId: string;
    studentName: string;
    periodName: string;
    paidAt: string | null;
    amount: number;
  },
) {
  if (
    await hasPaymentNotificationLog(db, {
      eventType: "payment_paid_confirmed",
      paymentStatusId: input.paymentStatusId,
    })
  ) {
    return [];
  }

  const { data: guardians, error } = await db
    .from("student_guardians")
    .select("guardians!inner(id, phone, kakao_opt_in, opt_out_at, deleted_at)")
    .eq("student_id", input.studentId);

  if (error) {
    throw new EdgeApiError(500, "보호자 알림 대상 조회에 실패했습니다.");
  }

  const eventTime = input.paidAt ?? new Date().toISOString();
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
      payment_period_id: input.paymentPeriodId,
      payment_status_id: input.paymentStatusId,
      event_type: "payment_paid_confirmed",
      channel: "kakao",
      recipient_phone_masked: maskPhone(guardian.phone),
      student_name: input.studentName,
      class_name: input.periodName,
      event_time: eventTime,
      payload: buildKakaoTemplatePayload("payment_paid_confirmed", {
        studentName: input.studentName,
        paymentPeriodName: input.periodName,
        paidAt: eventTime,
        amount: input.amount,
        paymentPeriodId: input.paymentPeriodId,
        paymentStatusId: input.paymentStatusId,
      }),
      status: "pending",
    }));

  if (rows.length === 0) return [];

  const { data, error: insertError } = await db
    .from("notification_logs")
    .insert(rows)
    .select("id");

  if (insertError) {
    throw new EdgeApiError(500, "카카오 납부 확인 로그 생성에 실패했습니다.");
  }
  return data ?? [];
}

async function hasPaymentNotificationLog(
  db: SupabaseClient,
  input: {
    eventType: "payment_due_reminder" | "payment_paid_confirmed";
    paymentStatusId: string;
  },
) {
  const { data, error } = await db
    .from("notification_logs")
    .select("id")
    .eq("event_type", input.eventType)
    .eq("payment_status_id", input.paymentStatusId)
    .neq("status", "cancelled")
    .limit(1);

  if (error) {
    throw new EdgeApiError(500, "카카오 납부 알림 중복 확인에 실패했습니다.");
  }
  return (data ?? []).length > 0;
}

async function createClassChangeNotificationLogs(
  db: SupabaseClient,
  input: {
    organizationId: string;
    studyRoomId: string;
    classId: string;
    classSessionId: string;
    eventType: "class_cancelled" | "class_makeup_added" | "class_time_changed";
    className: string;
    messageTitle: string;
    sessionDate: string;
    startsAt: string;
    endsAt: string;
    reason: string | null;
  },
) {
  const { data: enrollments, error } = await db
    .from("class_students")
    .select(
      "student_id, students!inner(id, name, student_guardians(guardians!inner(id, phone, kakao_opt_in, opt_out_at, deleted_at)))",
    )
    .eq("class_id", input.classId)
    .eq("active", true);

  if (error) {
    throw new EdgeApiError(500, "수업 보호자 알림 대상 조회에 실패했습니다.");
  }

  const rows = [];
  for (const enrollment of enrollments ?? []) {
    const student = normalizeJoinedObject(enrollment.students);
    const guardianLinks = Array.isArray(student.student_guardians)
      ? student.student_guardians
      : [];
    for (const link of guardianLinks) {
      const guardians = normalizeGuardianContact(
        (link as Record<string, unknown>).guardians,
      );
      for (const guardian of guardians) {
        if (
          guardian.kakao_opt_in !== true ||
          guardian.opt_out_at !== null ||
          guardian.deleted_at !== null
        ) {
          continue;
        }
        rows.push({
          organization_id: input.organizationId,
          study_room_id: input.studyRoomId,
          student_id: enrollment.student_id,
          guardian_id: guardian.id,
          class_id: input.classId,
          class_session_id: input.classSessionId,
          event_type: input.eventType,
          channel: "kakao",
          recipient_phone_masked: maskPhone(guardian.phone),
          student_name: student.name,
          class_name: input.className,
          event_time: new Date().toISOString(),
          payload: buildKakaoTemplatePayload(input.eventType, {
            title: input.messageTitle,
            studentName: student.name,
            className: input.className,
            sessionDate: input.sessionDate,
            startsAt: input.startsAt,
            endsAt: input.endsAt,
            reason: input.reason,
          }),
          status: "pending",
        });
      }
    }
  }

  if (rows.length === 0) return [];

  const { data, error: insertError } = await db
    .from("notification_logs")
    .insert(rows)
    .select("id");

  if (insertError) {
    throw new EdgeApiError(
      500,
      "카카오 수업 변경 알림 로그 생성에 실패했습니다.",
    );
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
    action?: "checked_in" | "status_changed";
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
    action: input.action ?? "checked_in",
    title: input.title,
    summary: input.summary,
  });

  if (error) throw new EdgeApiError(500, "사용 히스토리 기록에 실패했습니다.");
}

async function createClassSessionChange(
  db: SupabaseClient,
  input: {
    organizationId: string;
    studyRoomId: string;
    classSessionId: string;
    relatedClassSessionId?: string;
    changeType: "cancelled" | "makeup_added" | "rescheduled" | "time_changed";
    beforeValue: Record<string, unknown> | null;
    afterValue: Record<string, unknown> | null;
    reason: string | null;
    teacherId: string;
  },
) {
  const { error } = await db.from("class_session_changes").insert({
    organization_id: input.organizationId,
    study_room_id: input.studyRoomId,
    class_session_id: input.classSessionId,
    related_class_session_id: input.relatedClassSessionId,
    change_type: input.changeType,
    before_value: input.beforeValue,
    after_value: input.afterValue,
    reason: input.reason,
    notify_guardians: true,
    changed_by_teacher_id: input.teacherId,
  });

  if (error) throw new EdgeApiError(500, "수업 변경 이력 기록에 실패했습니다.");
}

async function createClassChangeAuditLog(
  db: SupabaseClient,
  input: {
    organizationId: string;
    studyRoomId: string;
    actorTeacherId: string;
    classId: string;
    classSessionId: string;
    action: "created" | "status_changed";
    title: string;
    summary: string;
  },
) {
  const { error } = await db.from("audit_logs").insert({
    organization_id: input.organizationId,
    study_room_id: input.studyRoomId,
    actor_teacher_id: input.actorTeacherId,
    class_id: input.classId,
    class_session_id: input.classSessionId,
    entity_type: "class_session",
    entity_id: input.classSessionId,
    action: input.action,
    title: input.title,
    summary: input.summary,
  });

  if (error) throw new EdgeApiError(500, "사용 히스토리 기록에 실패했습니다.");
}

async function createPaymentAuditLog(
  db: SupabaseClient,
  input: {
    organizationId: string;
    studyRoomId: string;
    actorTeacherId: string;
    studentId?: string;
    entityId: string;
    action: "created" | "status_changed" | "message_requested";
    title: string;
    summary: string;
  },
) {
  const { error } = await db.from("audit_logs").insert({
    organization_id: input.organizationId,
    study_room_id: input.studyRoomId,
    actor_teacher_id: input.actorTeacherId,
    student_id: input.studentId,
    entity_type: "payment",
    entity_id: input.entityId,
    action: input.action,
    title: input.title,
    summary: input.summary,
  });

  if (error) throw new EdgeApiError(500, "사용 히스토리 기록에 실패했습니다.");
}

async function createStudentAuditLog(
  db: SupabaseClient,
  input: {
    organizationId: string;
    studyRoomId: string;
    actorTeacherId: string;
    studentId: string;
    action?: "created" | "updated" | "deleted";
    title: string;
    summary: string;
  },
) {
  const { error } = await db.from("audit_logs").insert({
    organization_id: input.organizationId,
    study_room_id: input.studyRoomId,
    actor_teacher_id: input.actorTeacherId,
    student_id: input.studentId,
    entity_type: "student",
    entity_id: input.studentId,
    action: input.action ?? "created",
    title: input.title,
    summary: input.summary,
  });

  if (error) throw new EdgeApiError(500, "사용 히스토리 기록에 실패했습니다.");
}

async function createGuardianAuditLog(
  db: SupabaseClient,
  input: {
    organizationId: string;
    studyRoomId: string;
    actorTeacherId: string;
    studentId: string;
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
    entity_type: "guardian",
    entity_id: input.entityId,
    action: "updated",
    title: input.title,
    summary: input.summary,
  });

  if (error) throw new EdgeApiError(500, "사용 히스토리 기록에 실패했습니다.");
}

async function createNotificationAuditLog(
  db: SupabaseClient,
  input: {
    organizationId: string;
    studyRoomId: string;
    actorTeacherId: string;
    studentId: string | null;
    notificationLogId: string;
    action:
      | "message_requested"
      | "message_sent"
      | "message_failed"
      | "message_resent";
    title: string;
    summary: string;
  },
) {
  const { error } = await db.from("audit_logs").insert({
    organization_id: input.organizationId,
    study_room_id: input.studyRoomId,
    actor_teacher_id: input.actorTeacherId,
    student_id: input.studentId,
    notification_log_id: input.notificationLogId,
    entity_type: "notification",
    entity_id: input.notificationLogId,
    action: input.action,
    title: input.title,
    summary: input.summary,
  });

  if (error) throw new EdgeApiError(500, "사용 히스토리 기록에 실패했습니다.");
}

async function createClassAuditLog(
  db: SupabaseClient,
  input: {
    organizationId: string;
    studyRoomId: string;
    actorTeacherId: string;
    classId: string;
    action?: "created" | "updated" | "deleted";
    title: string;
    summary: string;
  },
) {
  const { error } = await db.from("audit_logs").insert({
    organization_id: input.organizationId,
    study_room_id: input.studyRoomId,
    actor_teacher_id: input.actorTeacherId,
    class_id: input.classId,
    entity_type: "class",
    entity_id: input.classId,
    action: input.action ?? "created",
    title: input.title,
    summary: input.summary,
  });

  if (error) throw new EdgeApiError(500, "사용 히스토리 기록에 실패했습니다.");
}

async function createStudyRoomAuditLog(
  db: SupabaseClient,
  input: {
    organizationId: string;
    studyRoomId: string;
    actorTeacherId: string;
    action: "created" | "updated" | "deleted";
    title: string;
    summary: string;
  },
) {
  const { error } = await db.from("audit_logs").insert({
    organization_id: input.organizationId,
    study_room_id: input.studyRoomId,
    actor_teacher_id: input.actorTeacherId,
    entity_type: "study_room",
    entity_id: input.studyRoomId,
    action: input.action,
    title: input.title,
    summary: input.summary,
  });

  if (error) throw new EdgeApiError(500, "사용 히스토리 기록에 실패했습니다.");
}

async function createClassroomLayoutAuditLog(
  db: SupabaseClient,
  input: {
    organizationId: string;
    studyRoomId: string;
    actorTeacherId: string;
    classId: string;
    classroomLayoutId: string;
    action: "created" | "updated" | "assigned" | "copied";
    title: string;
    summary: string;
  },
) {
  const { error } = await db.from("audit_logs").insert({
    organization_id: input.organizationId,
    study_room_id: input.studyRoomId,
    actor_teacher_id: input.actorTeacherId,
    class_id: input.classId,
    classroom_layout_id: input.classroomLayoutId,
    entity_type: "classroom_layout",
    entity_id: input.classroomLayoutId,
    action: input.action,
    title: input.title,
    summary: input.summary,
  });

  if (error) throw new EdgeApiError(500, "사용 히스토리 기록에 실패했습니다.");
}

async function createClassStudentAuditLog(
  db: SupabaseClient,
  input: {
    organizationId: string;
    studyRoomId: string;
    actorTeacherId: string;
    classId: string;
    title: string;
    summary: string;
  },
) {
  const { error } = await db.from("audit_logs").insert({
    organization_id: input.organizationId,
    study_room_id: input.studyRoomId,
    actor_teacher_id: input.actorTeacherId,
    class_id: input.classId,
    entity_type: "class_student",
    entity_id: input.classId,
    action: "assigned",
    title: input.title,
    summary: input.summary,
  });

  if (error) throw new EdgeApiError(500, "사용 히스토리 기록에 실패했습니다.");
}

async function createClassSessionAuditLog(
  db: SupabaseClient,
  input: {
    organizationId: string;
    studyRoomId: string;
    actorTeacherId: string;
    classId: string;
    classSessionId: string;
    title: string;
    summary: string;
  },
) {
  const { error } = await db.from("audit_logs").insert({
    organization_id: input.organizationId,
    study_room_id: input.studyRoomId,
    actor_teacher_id: input.actorTeacherId,
    class_id: input.classId,
    class_session_id: input.classSessionId,
    entity_type: "class_session",
    entity_id: input.classSessionId,
    action: "created",
    title: input.title,
    summary: input.summary,
  });

  if (error) throw new EdgeApiError(500, "사용 히스토리 기록에 실패했습니다.");
}

async function hashStudentPin(db: SupabaseClient, pin: string) {
  const { data, error } = await db.rpc("hash_student_pin", {
    plain_pin: pin,
  });

  if (error || typeof data !== "string") {
    throw new EdgeApiError(500, "출결 비밀번호 저장에 실패했습니다.");
  }
  return data;
}

async function requireAuthUser(
  request: Request,
  db: SupabaseClient,
): Promise<AuthUserContext> {
  const authHeader = request.headers.get("authorization");
  const jwt = authHeader?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!jwt) throw new EdgeApiError(401, "로그인이 필요합니다.");

  const { data: userData, error: userError } = await db.auth.getUser(jwt);
  if (userError || !userData.user) {
    throw new EdgeApiError(401, "로그인 정보를 확인할 수 없습니다.");
  }

  const metadata = userData.user.user_metadata;
  const metadataName = typeof metadata?.name === "string"
    ? metadata.name
    : typeof metadata?.full_name === "string"
    ? metadata.full_name
    : null;

  return {
    id: userData.user.id,
    email: userData.user.email ?? null,
    name: metadataName,
  };
}

async function readTeacherByAuthUser(
  db: SupabaseClient,
  authUserId: string,
): Promise<TeacherContext | null> {
  const { data: teacher, error: teacherError } = await db
    .from("teachers")
    .select("id, role")
    .eq("auth_user_id", authUserId)
    .maybeSingle();

  if (teacherError) {
    throw new EdgeApiError(500, "선생님 프로필 조회에 실패했습니다.");
  }
  if (!teacher) return null;
  return { id: teacher.id, role: teacher.role };
}

async function readTeacherProfileForWrite(
  db: SupabaseClient,
  teacherId: string,
) {
  const { data: teacher, error } = await db
    .from("teachers")
    .select("id, organization_id, role")
    .eq("id", teacherId)
    .single();

  if (error) throw new EdgeApiError(500, "선생님 프로필 조회에 실패했습니다.");
  return teacher;
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

function nullableString(value: unknown): string | null {
  const text = stringValue(value);
  return text.length === 0 ? null : text;
}

function assertUuid(value: string, message: string) {
  if (!uuidPattern.test(value)) throw new EdgeApiError(400, message);
}

function assertDate(value: string, message: string) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw new EdgeApiError(400, message);
  }
}

function normalizeClassKind(value: unknown) {
  const kind = stringValue(value) || "regular";
  if (!["regular", "makeup", "extra"].includes(kind)) {
    throw new EdgeApiError(400, "수업 유형이 올바르지 않습니다.");
  }
  return kind;
}

function normalizeDayOfWeeks(value: unknown) {
  if (!Array.isArray(value)) {
    throw new EdgeApiError(400, "수업 요일을 선택해 주세요.");
  }
  const days = [...new Set(value.map((day) => Number(day)))].sort();
  if (
    days.length === 0 ||
    days.some((day) => !Number.isInteger(day) || day < 0 || day > 6)
  ) {
    throw new EdgeApiError(400, "수업 요일이 올바르지 않습니다.");
  }
  return days;
}

function normalizeUuidList(value: unknown, message: string) {
  if (!Array.isArray(value)) throw new EdgeApiError(400, message);
  const ids = [...new Set(value.map((item) => stringValue(item)))];
  if (ids.some((id) => !uuidPattern.test(id))) {
    throw new EdgeApiError(400, message);
  }
  return ids;
}

function normalizeAuditCategory(value: unknown) {
  const category = stringValue(value) || "all";
  if (!["all", "student", "class", "kakao"].includes(category)) {
    throw new EdgeApiError(400, "히스토리 필터가 올바르지 않습니다.");
  }
  return category;
}

function normalizeNotificationStatusFilter(value: unknown) {
  const status = stringValue(value) || "all";
  if (!["all", "pending", "sent", "failed", "cancelled"].includes(status)) {
    throw new EdgeApiError(400, "알림 상태 필터가 올바르지 않습니다.");
  }
  return status;
}

function normalizeAttendanceStatus(value: unknown) {
  const status = stringValue(value);
  if (
    !["present", "late", "absent", "excused", "left_early"].includes(status)
  ) {
    throw new EdgeApiError(400, "출결 상태가 올바르지 않습니다.");
  }
  return status;
}

function normalizeLimit(value: unknown, fallback: number, maximum: number) {
  const limit = Number(value ?? fallback);
  if (!Number.isInteger(limit) || limit < 1) return fallback;
  return Math.min(limit, maximum);
}

function addDays(date: Date, days: number) {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
}

function kstDateString(date: Date) {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Seoul",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  return formatter.format(date);
}

function normalizeStudentStatus(value: unknown) {
  const status = stringValue(value) || "active";
  if (!["active", "paused", "left"].includes(status)) {
    throw new EdgeApiError(400, "학생 상태가 올바르지 않습니다.");
  }
  return status;
}

function normalizeStudentGender(value: unknown) {
  const gender = stringValue(value) || "unspecified";
  if (!["male", "female", "unspecified"].includes(gender)) {
    throw new EdgeApiError(400, "학생 아바타 성별이 올바르지 않습니다.");
  }
  return gender;
}

function normalizeStudentAgeGroup(value: unknown) {
  const ageGroup = stringValue(value) || "elementary";
  if (!["elementary", "middle", "high"].includes(ageGroup)) {
    throw new EdgeApiError(400, "학생 아바타 연령대가 올바르지 않습니다.");
  }
  return ageGroup;
}

function normalizeAvatarKey(
  value: unknown,
  gender: string,
  ageGroup: string,
) {
  const avatarKey = stringValue(value) || `${ageGroup}_${gender}_01`;
  if (!/^[a-z0-9_-]{3,64}$/.test(avatarKey)) {
    throw new EdgeApiError(400, "학생 아바타 키가 올바르지 않습니다.");
  }
  return avatarKey;
}

function normalizeGuardianInputs(value: unknown) {
  if (!Array.isArray(value)) {
    throw new EdgeApiError(400, "보호자 목록이 올바르지 않습니다.");
  }
  return value.map((item) => {
    if (!item || typeof item !== "object") {
      throw new EdgeApiError(400, "보호자 정보가 올바르지 않습니다.");
    }
    const input = item as Record<string, unknown>;
    const id = stringValue(input.id);
    const name = stringValue(input.name);
    const phone = stringValue(input.phone);
    const relationship = stringValue(input.relationship);
    if (id && !uuidPattern.test(id)) {
      throw new EdgeApiError(400, "보호자 정보가 올바르지 않습니다.");
    }
    if (phone.length < 7) {
      throw new EdgeApiError(400, "보호자 전화번호를 입력해 주세요.");
    }
    const kakaoOptIn = input.kakaoOptIn === true;
    const consentConfirmed = input.consentConfirmed === true;
    const deleted = input.deleted === true;
    if (!id && deleted) {
      throw new EdgeApiError(
        400,
        "저장된 보호자만 정보 삭제 요청할 수 있습니다.",
      );
    }
    if (kakaoOptIn && !consentConfirmed && !deleted) {
      throw new EdgeApiError(400, "보호자 카카오 수신 동의 확인이 필요합니다.");
    }
    return {
      id: id || null,
      name,
      phone,
      relationship,
      kakaoOptIn: deleted ? false : kakaoOptIn,
      consentConfirmed: deleted ? false : consentConfirmed,
      primaryContact: deleted ? false : input.primaryContact === true,
      deleted,
    };
  });
}

function normalizePaymentStatus(value: unknown) {
  const status = stringValue(value) || "unpaid";
  if (!["unpaid", "paid", "partial", "exempt", "refunded"].includes(status)) {
    throw new EdgeApiError(400, "납부 상태가 올바르지 않습니다.");
  }
  return status;
}

function normalizeAmount(value: unknown) {
  const amount = Number(value ?? 0);
  if (!Number.isInteger(amount) || amount < 0) {
    throw new EdgeApiError(400, "납부 금액이 올바르지 않습니다.");
  }
  return amount;
}

function normalizePositiveNumber(value: unknown, fallback: number) {
  const amount = Number(value ?? fallback);
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new EdgeApiError(400, "크기 값이 올바르지 않습니다.");
  }
  return amount;
}

function normalizeCoordinate(value: unknown, message: string) {
  const amount = Number(value);
  if (!Number.isFinite(amount) || amount < 0 || amount > 1) {
    throw new EdgeApiError(400, message);
  }
  return amount;
}

function normalizeClassroomSeats(value: unknown) {
  if (!Array.isArray(value)) {
    throw new EdgeApiError(400, "좌석 정보가 필요합니다.");
  }
  return value.map((item, index) => {
    if (!item || typeof item !== "object") {
      throw new EdgeApiError(400, "좌석 정보가 올바르지 않습니다.");
    }
    const input = item as Record<string, unknown>;
    const id = nullableString(input.id);
    if (id && !uuidPattern.test(id)) {
      throw new EdgeApiError(400, "좌석 정보가 올바르지 않습니다.");
    }
    const displayOrder = Number(input.displayOrder ?? index);
    if (!Number.isInteger(displayOrder) || displayOrder < 0) {
      throw new EdgeApiError(400, "좌석 순서가 올바르지 않습니다.");
    }
    const rotationDegrees = Number(input.rotationDegrees ?? 0);
    if (!Number.isFinite(rotationDegrees)) {
      throw new EdgeApiError(400, "좌석 회전 값이 올바르지 않습니다.");
    }
    return {
      id,
      label: nullableString(input.label) ?? `${index + 1}`,
      deskX: normalizeCoordinate(
        input.deskX,
        "책상 X 좌표가 올바르지 않습니다.",
      ),
      deskY: normalizeCoordinate(
        input.deskY,
        "책상 Y 좌표가 올바르지 않습니다.",
      ),
      seatX: normalizeCoordinate(
        input.seatX,
        "의자 X 좌표가 올바르지 않습니다.",
      ),
      seatY: normalizeCoordinate(
        input.seatY,
        "의자 Y 좌표가 올바르지 않습니다.",
      ),
      rotationDegrees,
      displayOrder,
    };
  });
}

function normalizeSeatAssignments(value: unknown) {
  if (!Array.isArray(value)) {
    throw new EdgeApiError(400, "좌석 배정 정보가 필요합니다.");
  }
  return value.map((item) => {
    if (!item || typeof item !== "object") {
      throw new EdgeApiError(400, "좌석 배정 정보가 올바르지 않습니다.");
    }
    const input = item as Record<string, unknown>;
    const seatId = stringValue(input.seatId);
    const studentId = stringValue(input.studentId);
    if (!uuidPattern.test(seatId) || !uuidPattern.test(studentId)) {
      throw new EdgeApiError(400, "좌석 배정 정보가 올바르지 않습니다.");
    }
    return { seatId, studentId };
  });
}

function normalizeTime(value: unknown, message: string) {
  const time = stringValue(value);
  if (!/^\d{2}:\d{2}$/.test(time)) throw new EdgeApiError(400, message);
  return time;
}

function formatClassSummary(classRoom: Record<string, unknown>) {
  const schedules = Array.isArray(classRoom.class_schedules)
    ? classRoom.class_schedules.filter((schedule) =>
      (schedule as Record<string, unknown>).active !== false
    )
    : [];
  return {
    id: classRoom.id,
    name: classRoom.name,
    description: classRoom.description,
    classKind: classRoom.class_kind,
    startDate: classRoom.start_date,
    endDate: classRoom.end_date,
    scheduleText: classRoom.schedule_text ??
      formatScheduleTextFromSchedules(schedules),
    active: classRoom.active,
    schedules: schedules.map((schedule) => ({
      dayOfWeek: (schedule as Record<string, unknown>).day_of_week,
      startsAt: trimSeconds((schedule as Record<string, unknown>).starts_at),
      endsAt: trimSeconds((schedule as Record<string, unknown>).ends_at),
    })),
  };
}

function formatStudyRoomSummary(studyRoom: Record<string, unknown>) {
  return {
    id: studyRoom.id,
    name: studyRoom.name,
    description: studyRoom.description,
    createdAt: studyRoom.created_at,
  };
}

function formatClassroomSeat(seat: Record<string, unknown>) {
  return {
    id: seat.id,
    label: seat.label,
    deskX: Number(seat.desk_x ?? 0),
    deskY: Number(seat.desk_y ?? 0),
    seatX: Number(seat.seat_x ?? 0),
    seatY: Number(seat.seat_y ?? 0),
    rotationDegrees: Number(seat.rotation_degrees ?? 0),
    displayOrder: seat.display_order,
  };
}

function formatSeatAssignment(row: Record<string, unknown>) {
  const student = normalizeJoinedObject(row.students);
  return {
    seatId: row.classroom_seat_id,
    studentId: row.student_id,
    studentName: student.name,
    studentCode: student.student_code,
    avatarKey: student.avatar_key,
  };
}

function formatSeatOccupancy(row: Record<string, unknown>) {
  const student = normalizeJoinedObject(row.students);
  return {
    seatId: row.classroom_seat_id,
    studentId: row.student_id,
    studentName: student.name,
    studentCode: student.student_code,
    avatarKey: student.avatar_key,
    status: row.status,
    checkedInAt: row.checked_in_at,
  };
}

function formatManagedStudent(student: Record<string, unknown>) {
  return {
    id: student.id,
    code: student.student_code,
    name: student.name,
    status: student.status,
    gender: student.gender,
    ageGroup: student.age_group,
    avatarKey: student.avatar_key,
  };
}

function formatPaymentStatus(row: Record<string, unknown>) {
  const student = normalizeJoinedObject(row.students);
  return {
    id: row.id,
    studentId: row.student_id,
    studentName: student.name,
    studentCode: student.student_code,
    studentStatus: student.status,
    amount: row.amount,
    status: row.status,
    paidAt: row.paid_at,
    note: row.note,
  };
}

function formatStudentGuardian(row: Record<string, unknown>) {
  const guardian = normalizeJoinedObject(row.guardians);
  return {
    id: guardian.id,
    name: guardian.name,
    phone: guardian.phone,
    relationship: row.relationship,
    kakaoOptIn: guardian.kakao_opt_in === true && guardian.opt_out_at === null,
    consentConfirmed: guardian.consent_confirmed_at !== null,
    primaryContact: row.primary_contact,
    deleted: guardian.deleted_at !== null,
  };
}

function formatNotificationLog(row: Record<string, unknown>) {
  const payload = normalizeProviderPayload(row.payload);
  return {
    id: row.id,
    eventType: row.event_type,
    channel: row.channel,
    recipientPhoneMasked: row.recipient_phone_masked,
    studentId: row.student_id,
    studentName: row.student_name,
    className: row.class_name,
    status: row.status,
    errorMessage: row.error_message,
    retryCount: row.retry_count,
    retryOfNotificationId: row.retry_of_notification_id,
    templateCode: stringValue(payload.templateCode),
    messagePreview: stringValue(payload.messageText),
    createdAt: row.created_at,
    sentAt: row.sent_at,
  };
}

function formatScheduleTextFromSchedules(schedules: unknown[]) {
  if (schedules.length === 0) return "";
  const typed = schedules
    .map((schedule) => schedule as Record<string, unknown>)
    .sort((a, b) => Number(a.day_of_week) - Number(b.day_of_week));
  return formatScheduleText(
    typed.map((schedule) => Number(schedule.day_of_week)),
    trimSeconds(typed[0].starts_at),
    trimSeconds(typed[0].ends_at),
  );
}

function formatScheduleText(
  dayOfWeeks: number[],
  startsAt: string,
  endsAt: string,
) {
  const dayLabels = ["일", "월", "화", "수", "목", "금", "토"];
  return `${
    dayOfWeeks.map((day) => dayLabels[day]).join("/")
  } ${startsAt}-${endsAt}`;
}

function trimSeconds(value: unknown) {
  const text = stringValue(value);
  return text.length >= 5 ? text.slice(0, 5) : text;
}

function normalizeStringRecord(value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  const normalized: Record<string, string> = {};
  for (const [key, rawValue] of Object.entries(value)) {
    const text = stringValue(rawValue);
    if (text.length > 0) normalized[key] = text;
  }
  return normalized;
}

function formatKakaoDateTime(value: unknown) {
  const text = stringValue(value);
  if (!text) return "";
  const date = new Date(text);
  if (Number.isNaN(date.getTime())) return text;
  return new Intl.DateTimeFormat("ko-KR", {
    timeZone: "Asia/Seoul",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(date);
}

function formatKakaoTime(value: unknown) {
  const text = trimSeconds(value);
  if (!text) return "";
  const date = new Date(text);
  if (Number.isNaN(date.getTime())) return text;
  return new Intl.DateTimeFormat("ko-KR", {
    timeZone: "Asia/Seoul",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(date);
}

function formatWon(value: unknown) {
  const amount = Number(value ?? 0);
  if (!Number.isFinite(amount)) return "";
  return `${Math.trunc(amount).toLocaleString("ko-KR")}원`;
}

function formatAttendanceStatusLabel(value: unknown) {
  switch (stringValue(value)) {
    case "present":
      return "출석";
    case "late":
      return "지각";
    case "absent":
      return "결석";
    case "excused":
      return "인정결석";
    case "left_early":
      return "조퇴";
    default:
      return stringValue(value) || "출결 변경";
  }
}

function todayDateString() {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Seoul",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
}

function toKstIso(date: string, time: unknown) {
  return `${date}T${trimSeconds(time)}:00+09:00`;
}

function formatClassSession(
  session: Record<string, unknown>,
  classRoom: Record<string, unknown>,
) {
  return {
    id: session.id,
    classId: classRoom.id,
    className: classRoom.name,
    classKind: classRoom.class_kind,
    sessionDate: session.session_date,
    startsAt: session.starts_at,
    endsAt: session.ends_at,
    status: session.status,
  };
}

function auditEntityTypesForCategory(category: string) {
  if (category === "student") return ["student", "guardian"];
  if (category === "class") {
    return [
      "class",
      "class_schedule",
      "class_student",
      "class_session",
      "attendance",
    ];
  }
  return [];
}

function auditCategoryFromEntityType(value: unknown) {
  const entityType = String(value);
  if (["student", "guardian"].includes(entityType)) return "student";
  if (entityType === "notification") return "kakao";
  return "class";
}

function notificationStatusToAction(value: unknown) {
  const status = String(value);
  if (status === "sent") return "message_sent";
  if (status === "failed") return "message_failed";
  if (status === "resent") return "message_resent";
  return "message_requested";
}

function formatNotificationTitle(status: unknown) {
  const label = switchNotificationStatus(status);
  return `카카오 알림 ${label}`;
}

function formatNotificationSummary(log: Record<string, unknown>) {
  const studentName = stringValue(log.student_name) || "학생";
  const className = stringValue(log.class_name) || "수업";
  const recipient = stringValue(log.recipient_phone_masked) || "보호자";
  return `${studentName} · ${className} · ${recipient}`;
}

function normalizeProviderPayload(value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  return value as Record<string, unknown>;
}

function buildKakaoTemplatePayload(
  eventType: string,
  params: Record<string, unknown>,
) {
  const templateCode = kakaoTemplateCode(eventType);
  const templateParams = normalizeKakaoTemplateParams(eventType, params);
  return {
    templateCode,
    templateParams,
    messageText: buildKakaoMessageText(eventType, templateParams),
  };
}

function kakaoTemplateCode(eventType: string) {
  switch (eventType) {
    case "attendance_checked_in":
      return Deno.env.get("KAKAO_TEMPLATE_ATTENDANCE_CHECKED_IN") ??
        "ATTENDANCE_CHECKED_IN";
    case "attendance_status_changed":
      return Deno.env.get("KAKAO_TEMPLATE_ATTENDANCE_STATUS_CHANGED") ??
        "ATTENDANCE_STATUS_CHANGED";
    case "payment_due_reminder":
      return Deno.env.get("KAKAO_TEMPLATE_PAYMENT_DUE_REMINDER") ??
        "PAYMENT_DUE_REMINDER";
    case "payment_paid_confirmed":
      return Deno.env.get("KAKAO_TEMPLATE_PAYMENT_PAID_CONFIRMED") ??
        "PAYMENT_PAID_CONFIRMED";
    case "class_cancelled":
      return Deno.env.get("KAKAO_TEMPLATE_CLASS_CANCELLED") ??
        "CLASS_CANCELLED";
    case "class_makeup_added":
      return Deno.env.get("KAKAO_TEMPLATE_CLASS_MAKEUP_ADDED") ??
        "CLASS_MAKEUP_ADDED";
    case "class_time_changed":
      return Deno.env.get("KAKAO_TEMPLATE_CLASS_TIME_CHANGED") ??
        "CLASS_TIME_CHANGED";
    default:
      return Deno.env.get("KAKAO_TEMPLATE_DEFAULT") ?? "DEFAULT_NOTICE";
  }
}

function normalizeKakaoTemplateParams(
  eventType: string,
  params: Record<string, unknown>,
) {
  const normalized: Record<string, string> = {};
  const put = (key: string, value: unknown) => {
    const text = stringValue(value);
    if (text.length > 0) normalized[key] = text;
  };

  put("studentName", params.studentName);
  put("className", params.className);

  if (eventType === "attendance_checked_in") {
    put(
      "attendanceStatus",
      formatAttendanceStatusLabel(params.attendanceStatus),
    );
    put("checkedInAt", formatKakaoDateTime(params.checkedInAt));
  } else if (eventType === "attendance_status_changed") {
    put(
      "attendanceStatus",
      formatAttendanceStatusLabel(params.attendanceStatus),
    );
    put("checkedInAt", formatKakaoDateTime(params.checkedInAt));
  } else if (eventType === "payment_due_reminder") {
    put("paymentPeriodName", params.paymentPeriodName);
    put("dueDate", params.dueDate);
    put("amount", formatWon(params.amount));
  } else if (eventType === "payment_paid_confirmed") {
    put("paymentPeriodName", params.paymentPeriodName);
    put("paidAt", formatKakaoDateTime(params.paidAt));
    put("amount", formatWon(params.amount));
  } else if (
    eventType === "class_cancelled" ||
    eventType === "class_makeup_added" ||
    eventType === "class_time_changed"
  ) {
    put("title", params.title);
    put("sessionDate", params.sessionDate);
    put("startsAt", formatKakaoTime(params.startsAt));
    put("endsAt", formatKakaoTime(params.endsAt));
    put("reason", params.reason ?? "사유 미입력");
  }

  return normalized;
}

function buildKakaoMessageText(
  eventType: string,
  params: Record<string, string>,
) {
  switch (eventType) {
    case "attendance_checked_in":
      return `${params.studentName ?? "학생"} 학생이 ${
        params.className ?? "수업"
      }에 ${params.attendanceStatus ?? "출석"}했습니다. 시간: ${
        params.checkedInAt ?? ""
      }`;
    case "attendance_status_changed":
      return `${params.studentName ?? "학생"} 학생의 ${
        params.className ?? "수업"
      } 출결 상태가 ${
        params.attendanceStatus ?? "변경"
      } 처리되었습니다. 시간: ${params.checkedInAt ?? ""}`;
    case "payment_due_reminder":
      return `${params.studentName ?? "학생"} 학생의 ${
        params.paymentPeriodName ?? "수업료"
      } 납부 마감일은 ${params.dueDate ?? ""}입니다. 금액: ${
        params.amount ?? ""
      }`;
    case "payment_paid_confirmed":
      return `${params.studentName ?? "학생"} 학생의 ${
        params.paymentPeriodName ?? "수업료"
      } 납부가 확인되었습니다. 시간: ${params.paidAt ?? ""}, 금액: ${
        params.amount ?? ""
      }`;
    case "class_cancelled":
      return `${params.studentName ?? "학생"} 학생의 ${
        params.className ?? "수업"
      } 휴강 안내입니다. 일정: ${params.sessionDate ?? ""} ${
        params.startsAt ?? ""
      }-${params.endsAt ?? ""}, 사유: ${params.reason ?? ""}`;
    case "class_makeup_added":
      return `${params.studentName ?? "학생"} 학생의 ${
        params.className ?? "수업"
      } 보강 안내입니다. 일정: ${params.sessionDate ?? ""} ${
        params.startsAt ?? ""
      }-${params.endsAt ?? ""}, 사유: ${params.reason ?? ""}`;
    case "class_time_changed":
      return `${params.studentName ?? "학생"} 학생의 ${
        params.className ?? "수업"
      } 시간 변경 안내입니다. 일정: ${params.sessionDate ?? ""} ${
        params.startsAt ?? ""
      }-${params.endsAt ?? ""}, 사유: ${params.reason ?? ""}`;
    default:
      return `${params.studentName ?? "학생"} · ${params.className ?? "알림"}`;
  }
}

async function sendKakaoProviderMessage(input: {
  recipientPhone: string;
  eventType: string;
  payload: Record<string, unknown>;
}) {
  const endpoint = Deno.env.get("KAKAO_PROVIDER_ENDPOINT");
  const apiKey = Deno.env.get("KAKAO_PROVIDER_API_KEY");
  const senderKey = Deno.env.get("KAKAO_SENDER_KEY");
  if (!endpoint || !apiKey || !senderKey) {
    throw new EdgeApiError(
      500,
      "카카오 발송 서버 환경변수가 설정되지 않았습니다.",
    );
  }

  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      senderKey,
      recipientPhone: input.recipientPhone,
      eventType: input.eventType,
      templateCode: stringValue(input.payload.templateCode),
      templateParams: normalizeStringRecord(input.payload.templateParams),
      messageText: stringValue(input.payload.messageText),
      payload: input.payload,
    }),
  });
  const responseBody = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new EdgeApiError(
      response.status,
      `카카오 provider 발송 실패: ${response.status}`,
    );
  }

  const body = responseBody as Record<string, unknown>;
  return {
    messageId: typeof body.messageId === "string" ? body.messageId : null,
    response: body,
  };
}

function switchNotificationStatus(status: unknown) {
  switch (String(status)) {
    case "sent":
      return "발송 성공";
    case "failed":
      return "발송 실패";
    case "cancelled":
      return "취소";
    default:
      return "발송 대기";
  }
}

function requireTeacherProfile(teacher: TeacherContext | null) {
  if (!teacher) throw new EdgeApiError(403, "선생님 프로필이 필요합니다.");
  return teacher;
}

function requireAdminTeacher(teacher: TeacherContext | null) {
  const activeTeacher = requireTeacherProfile(teacher);
  if (activeTeacher.role !== "admin") {
    throw new EdgeApiError(403, "관리자 권한이 필요합니다.");
  }
  return activeTeacher;
}

function isInternalJobPath(path: unknown) {
  return typeof path === "string" && normalizePath(path).startsWith("/jobs/");
}

function requireInternalJobSecret(request: Request) {
  const configuredSecret = Deno.env.get("OCHUL_INTERNAL_JOB_SECRET");
  if (!configuredSecret) {
    throw new EdgeApiError(500, "내부 작업 secret이 설정되지 않았습니다.");
  }
  const requestSecret = request.headers.get("x-ochul-job-secret");
  if (requestSecret !== configuredSecret) {
    throw new EdgeApiError(401, "내부 작업 인증에 실패했습니다.");
  }
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

function normalizeJoinedObject(value: unknown) {
  if (Array.isArray(value)) {
    return (value[0] ?? {}) as Record<string, unknown>;
  }
  return (value ?? {}) as Record<string, unknown>;
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

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
    const authUser = await requireAuthUser(request, db);
    const teacher = await readTeacherByAuthUser(db, authUser.id);
    const response = await routeEdgeRequest(payload, { db, authUser, teacher });
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

  if (method === "GET" && path === "/me") {
    return await readMe(context);
  }

  if (method === "POST" && path === "/me/onboard") {
    return await onboardTeacher(body, context);
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

  const checkInMatch = path.match(
    /^\/class-sessions\/([^/]+)\/check-in$/,
  );
  if (method === "POST" && checkInMatch) {
    return await checkInStudent(checkInMatch[1], body, context);
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
      "id, name, description, class_kind, start_date, end_date, schedule_text, active, class_schedules(day_of_week, starts_at, ends_at)",
    )
    .eq("study_room_id", studyRoomId)
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
  const sessionDate = todayDateString();
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
    summary: `${classRoom.name} 수업을 휴강 처리했습니다.`,
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
  assertDate(sessionDate, "보강 날짜가 올바르지 않습니다.");
  if (startsAt >= endsAt) {
    throw new EdgeApiError(400, "보강 종료 시간은 시작 시간 이후여야 합니다.");
  }

  const { data: session, error } = await db
    .from("class_sessions")
    .insert({
      organization_id: classRoom.organization_id,
      study_room_id: classRoom.study_room_id,
      class_id: classId,
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
    classSessionId: session.id,
    changeType: "makeup_added",
    reason,
    teacherId: activeTeacher.id,
    beforeValue: null,
    afterValue: { sessionDate, startsAt, endsAt },
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
    summary: `${classRoom.name} 보강 수업을 생성했습니다.`,
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
      students,
    });
  }

  return { ok: true, sessions: formatted };
}

async function listSessionStudents(
  db: SupabaseClient,
  classSessionId: string,
  classId: string,
) {
  const { data: enrollments, error: enrollmentError } = await db
    .from("class_students")
    .select("student_id, display_order, students!inner(id, student_code, name)")
    .eq("class_id", classId)
    .eq("active", true)
    .order("display_order", { ascending: true });

  if (enrollmentError) {
    throw new EdgeApiError(500, "출석 학생 목록 조회에 실패했습니다.");
  }

  const { data: records, error: recordError } = await db
    .from("attendance_records")
    .select("student_id, status")
    .eq("class_session_id", classSessionId);

  if (recordError) {
    throw new EdgeApiError(500, "출석 상태 조회에 실패했습니다.");
  }
  const statusByStudentId = new Map(
    (records ?? []).map((record) => [record.student_id, record.status]),
  );

  return (enrollments ?? []).map((row) => {
    const student = normalizeJoinedObject(row.students);
    return {
      id: student.id,
      code: student.student_code,
      name: student.name,
      status: statusByStudentId.get(String(student.id)) ?? "waiting",
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
    const { data: notificationLogs, error: notificationError } = await db
      .from("notification_logs")
      .select(
        "id, event_type, status, student_id, class_id, class_session_id, student_name, class_name, recipient_phone_masked, created_at, sent_at",
      )
      .eq("study_room_id", studyRoomId)
      .eq("channel", "kakao")
      .order("created_at", { ascending: false })
      .limit(limit);

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
  const limit = normalizeLimit(body.limit, 80, 150);
  if (studentId) assertUuid(studentId, "학생 정보가 올바르지 않습니다.");

  let query = db
    .from("notification_logs")
    .select(
      "id, event_type, channel, recipient_phone_masked, student_id, student_name, class_name, status, error_message, retry_count, retry_of_notification_id, created_at, sent_at",
    )
    .eq("study_room_id", studyRoomId)
    .eq("channel", "kakao")
    .order("created_at", { ascending: false })
    .limit(limit);

  if (status !== "all") query = query.eq("status", status);
  if (studentId) query = query.eq("student_id", studentId);

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

  return { ok: true, status: formatPaymentStatus(updated) };
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

  let createdCount = 0;
  for (const paymentStatus of unpaidStatuses ?? []) {
    const student = normalizeJoinedObject(paymentStatus.students);
    const notifications = await createPaymentReminderNotificationLogs(db, {
      organizationId: period.organization_id,
      studyRoomId: period.study_room_id,
      paymentPeriodId,
      paymentStatusId: paymentStatus.id,
      studentId: paymentStatus.student_id,
      studentName: stringValue(student.name) || "학생",
      periodName: period.name,
      dueDate: period.due_date,
      amount: Number(paymentStatus.amount ?? 0),
    });
    createdCount += notifications.length;
  }

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
      "relationship, primary_contact, guardians!inner(id, name, phone, kakao_opt_in, opt_out_at)",
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
    const guardianValues = {
      name: guardianInput.name || null,
      phone: guardianInput.phone,
      kakao_opt_in: guardianInput.kakaoOptIn,
      consent_confirmed_at: guardianInput.kakaoOptIn
        ? new Date().toISOString()
        : null,
      consent_method: guardianInput.kakaoOptIn ? "teacher_confirmed" : null,
      consent_confirmed_by_teacher_id: guardianInput.kakaoOptIn
        ? activeTeacher.id
        : null,
      opt_out_at: guardianInput.kakaoOptIn ? null : new Date().toISOString(),
      deleted_at: null,
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
        primary_contact: guardianInput.primaryContact,
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
      "id, organization_id, study_room_id, payment_period_id, student_id, study_rooms!inner(owner_teacher_id)",
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
      event_type: "payment_due_reminder",
      channel: "kakao",
      recipient_phone_masked: maskPhone(guardian.phone),
      student_name: input.studentName,
      class_name: input.periodName,
      event_time: new Date().toISOString(),
      payload: {
        studentName: input.studentName,
        paymentPeriodName: input.periodName,
        dueDate: input.dueDate,
        amount: input.amount,
        paymentPeriodId: input.paymentPeriodId,
        paymentStatusId: input.paymentStatusId,
      },
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

async function createClassChangeNotificationLogs(
  db: SupabaseClient,
  input: {
    organizationId: string;
    studyRoomId: string;
    classId: string;
    classSessionId: string;
    eventType: "class_cancelled" | "class_makeup_added";
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
          payload: {
            title: input.messageTitle,
            studentName: student.name,
            className: input.className,
            sessionDate: input.sessionDate,
            startsAt: input.startsAt,
            endsAt: input.endsAt,
            reason: input.reason,
          },
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
    action: "created",
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

function normalizeLimit(value: unknown, fallback: number, maximum: number) {
  const limit = Number(value ?? fallback);
  if (!Number.isInteger(limit) || limit < 1) return fallback;
  return Math.min(limit, maximum);
}

function normalizeStudentStatus(value: unknown) {
  const status = stringValue(value) || "active";
  if (!["active", "paused", "left"].includes(status)) {
    throw new EdgeApiError(400, "학생 상태가 올바르지 않습니다.");
  }
  return status;
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
    return {
      id: id || null,
      name,
      phone,
      relationship,
      kakaoOptIn: input.kakaoOptIn !== false,
      primaryContact: input.primaryContact === true,
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

function normalizeTime(value: unknown, message: string) {
  const time = stringValue(value);
  if (!/^\d{2}:\d{2}$/.test(time)) throw new EdgeApiError(400, message);
  return time;
}

function formatClassSummary(classRoom: Record<string, unknown>) {
  const schedules = Array.isArray(classRoom.class_schedules)
    ? classRoom.class_schedules
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
    primaryContact: row.primary_contact,
  };
}

function formatNotificationLog(row: Record<string, unknown>) {
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

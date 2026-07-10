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

  const classStudentsMatch = path.match(/^\/classes\/([^/]+)\/students$/);
  if (classStudentsMatch) {
    if (method === "GET") {
      return await listClassStudents(classStudentsMatch[1], context);
    }
    if (method === "PUT") {
      return await saveClassStudents(classStudentsMatch[1], body, context);
    }
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

async function createStudentAuditLog(
  db: SupabaseClient,
  input: {
    organizationId: string;
    studyRoomId: string;
    actorTeacherId: string;
    studentId: string;
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
    action: "created",
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

function requireTeacherProfile(teacher: TeacherContext | null) {
  if (!teacher) throw new EdgeApiError(403, "선생님 프로필이 필요합니다.");
  return teacher;
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

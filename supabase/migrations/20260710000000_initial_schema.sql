create extension if not exists pgcrypto;

create type attendance_status as enum (
  'present',
  'late',
  'absent',
  'excused',
  'left_early'
);

create type student_status as enum (
  'active',
  'paused',
  'left'
);

create type payment_status as enum (
  'unpaid',
  'paid',
  'partial',
  'exempt',
  'refunded'
);

create type notification_status as enum (
  'pending',
  'sent',
  'failed',
  'cancelled'
);

create type class_session_status as enum (
  'scheduled',
  'open',
  'completed',
  'cancelled'
);

create type class_session_kind as enum (
  'regular',
  'makeup',
  'extra'
);

create type class_change_type as enum (
  'cancelled',
  'makeup_added',
  'rescheduled',
  'time_changed'
);

create type study_room_member_role as enum (
  'owner',
  'admin',
  'teacher'
);

create type class_kind as enum (
  'regular',
  'makeup',
  'extra'
);

create type audit_entity_type as enum (
  'student',
  'guardian',
  'class',
  'class_schedule',
  'class_student',
  'class_session',
  'attendance',
  'payment',
  'notification',
  'study_room',
  'teacher'
);

create type audit_action_type as enum (
  'created',
  'updated',
  'deleted',
  'restored',
  'assigned',
  'unassigned',
  'checked_in',
  'status_changed',
  'message_requested',
  'message_sent',
  'message_failed',
  'message_resent'
);

create table organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table study_rooms (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  name text not null,
  description text,
  owner_teacher_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table teachers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  auth_user_id uuid references auth.users(id) on delete set null,
  name text not null,
  email text,
  role text not null default 'teacher',
  created_at timestamptz not null default now(),
  unique (auth_user_id)
);

alter table study_rooms
  add constraint study_rooms_owner_teacher_fk
  foreign key (owner_teacher_id) references teachers(id) on delete set null;

create table study_room_members (
  study_room_id uuid not null references study_rooms(id) on delete cascade,
  teacher_id uuid not null references teachers(id) on delete cascade,
  role study_room_member_role not null default 'teacher',
  created_at timestamptz not null default now(),
  primary key (study_room_id, teacher_id)
);

create table students (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  study_room_id uuid not null references study_rooms(id) on delete cascade,
  student_code text not null,
  name text not null,
  pin_hash text not null,
  status student_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (study_room_id, student_code)
);

create table guardians (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  study_room_id uuid not null references study_rooms(id) on delete cascade,
  name text,
  phone text not null,
  kakao_opt_in boolean not null default true,
  created_at timestamptz not null default now()
);

create table student_guardians (
  student_id uuid not null references students(id) on delete cascade,
  guardian_id uuid not null references guardians(id) on delete cascade,
  relationship text,
  primary_contact boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (student_id, guardian_id)
);

create table classes (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  study_room_id uuid not null references study_rooms(id) on delete cascade,
  teacher_id uuid references teachers(id) on delete set null,
  parent_class_id uuid references classes(id) on delete set null,
  name text not null,
  description text,
  class_kind class_kind not null default 'regular',
  start_date date not null,
  end_date date not null,
  schedule_text text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint classes_date_range_check check (end_date >= start_date)
);

create table class_schedules (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references classes(id) on delete cascade,
  day_of_week integer not null,
  starts_at time not null,
  ends_at time not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint class_schedules_day_check check (day_of_week between 0 and 6),
  constraint class_schedules_time_check check (ends_at > starts_at)
);

create table class_students (
  class_id uuid not null references classes(id) on delete cascade,
  student_id uuid not null references students(id) on delete cascade,
  enrollment_kind class_kind not null default 'regular',
  display_order integer not null default 0,
  enrolled_at timestamptz not null default now(),
  active boolean not null default true,
  primary key (class_id, student_id)
);

create table class_sessions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  study_room_id uuid not null references study_rooms(id) on delete cascade,
  class_id uuid not null references classes(id) on delete cascade,
  class_schedule_id uuid references class_schedules(id) on delete set null,
  original_class_session_id uuid references class_sessions(id) on delete set null,
  session_date date not null default current_date,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  kind class_session_kind not null default 'regular',
  status class_session_status not null default 'scheduled',
  change_reason text,
  opened_by_teacher_id uuid references teachers(id) on delete set null,
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint class_sessions_time_check check (ends_at > starts_at)
);

alter table classes
  add column parent_class_session_id uuid references class_sessions(id) on delete set null;

create table class_session_changes (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  study_room_id uuid not null references study_rooms(id) on delete cascade,
  class_session_id uuid references class_sessions(id) on delete set null,
  related_class_session_id uuid references class_sessions(id) on delete set null,
  change_type class_change_type not null,
  before_value jsonb,
  after_value jsonb,
  reason text,
  notify_guardians boolean not null default true,
  changed_by_teacher_id uuid references teachers(id) on delete set null,
  created_at timestamptz not null default now()
);

create table attendance_records (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  study_room_id uuid not null references study_rooms(id) on delete cascade,
  class_session_id uuid not null references class_sessions(id) on delete cascade,
  student_id uuid not null references students(id) on delete cascade,
  status attendance_status not null,
  checked_in_at timestamptz,
  checked_in_method text not null default 'student_pin',
  note text,
  created_by_teacher_id uuid references teachers(id) on delete set null,
  updated_by_teacher_id uuid references teachers(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (class_session_id, student_id)
);

create table payment_periods (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  study_room_id uuid not null references study_rooms(id) on delete cascade,
  name text not null,
  due_date date not null,
  created_at timestamptz not null default now()
);

create table payment_statuses (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  study_room_id uuid not null references study_rooms(id) on delete cascade,
  payment_period_id uuid not null references payment_periods(id) on delete cascade,
  student_id uuid not null references students(id) on delete cascade,
  amount integer not null default 0,
  status payment_status not null default 'unpaid',
  paid_at timestamptz,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (payment_period_id, student_id)
);

create table notification_logs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  study_room_id uuid not null references study_rooms(id) on delete cascade,
  student_id uuid references students(id) on delete set null,
  guardian_id uuid references guardians(id) on delete set null,
  class_id uuid references classes(id) on delete set null,
  class_session_id uuid references class_sessions(id) on delete set null,
  attendance_record_id uuid references attendance_records(id) on delete set null,
  event_type text not null,
  channel text not null default 'kakao',
  recipient_phone text not null,
  student_name text,
  class_name text,
  event_time timestamptz,
  payload jsonb not null default '{}'::jsonb,
  provider_message_id text,
  retry_of_notification_id uuid references notification_logs(id) on delete set null,
  retry_count integer not null default 0,
  provider_response jsonb,
  status notification_status not null default 'pending',
  error_message text,
  created_at timestamptz not null default now(),
  sent_at timestamptz
);

create table audit_logs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  study_room_id uuid not null references study_rooms(id) on delete cascade,
  actor_teacher_id uuid references teachers(id) on delete set null,
  student_id uuid references students(id) on delete set null,
  class_id uuid references classes(id) on delete set null,
  class_session_id uuid references class_sessions(id) on delete set null,
  notification_log_id uuid references notification_logs(id) on delete set null,
  entity_type audit_entity_type not null,
  entity_id uuid not null,
  action audit_action_type not null,
  title text not null,
  summary text,
  before_value jsonb,
  after_value jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index idx_students_organization on students(organization_id);
create index idx_students_study_room on students(study_room_id);
create index idx_guardians_organization on guardians(organization_id);
create index idx_guardians_study_room on guardians(study_room_id);
create index idx_student_guardians_guardian on student_guardians(guardian_id);
create index idx_classes_organization on classes(organization_id);
create index idx_classes_study_room on classes(study_room_id);
create index idx_class_schedules_class on class_schedules(class_id);
create index idx_class_sessions_class_date on class_sessions(class_id, session_date);
create index idx_class_sessions_study_room on class_sessions(study_room_id, session_date);
create index idx_class_sessions_status on class_sessions(status, starts_at);
create index idx_class_session_changes_session on class_session_changes(class_session_id);
create index idx_class_session_changes_study_room on class_session_changes(study_room_id, created_at desc);
create index idx_attendance_session on attendance_records(class_session_id);
create index idx_attendance_study_room on attendance_records(study_room_id, created_at desc);
create index idx_payment_period_student on payment_statuses(payment_period_id, student_id);
create index idx_payment_periods_study_room on payment_periods(study_room_id, due_date);
create index idx_payment_statuses_study_room on payment_statuses(study_room_id, created_at desc);
create index idx_notification_status on notification_logs(status, created_at);
create index idx_notification_student on notification_logs(student_id, created_at desc);
create index idx_notification_guardian on notification_logs(guardian_id, created_at desc);
create index idx_notification_class on notification_logs(class_id, created_at desc);
create index idx_notification_study_room on notification_logs(study_room_id, created_at desc);
create index idx_notification_retry_of on notification_logs(retry_of_notification_id);
create index idx_audit_logs_study_room on audit_logs(study_room_id, created_at desc);
create index idx_audit_logs_actor on audit_logs(actor_teacher_id, created_at desc);
create index idx_audit_logs_entity on audit_logs(entity_type, action, created_at desc);
create index idx_audit_logs_student on audit_logs(student_id, created_at desc);
create index idx_audit_logs_class on audit_logs(class_id, created_at desc);
create index idx_audit_logs_notification on audit_logs(notification_log_id, created_at desc);

alter table organizations enable row level security;
alter table teachers enable row level security;
alter table students enable row level security;
alter table guardians enable row level security;
alter table student_guardians enable row level security;
alter table classes enable row level security;
alter table class_schedules enable row level security;
alter table class_students enable row level security;
alter table class_sessions enable row level security;
alter table class_session_changes enable row level security;
alter table attendance_records enable row level security;
alter table payment_periods enable row level security;
alter table payment_statuses enable row level security;
alter table notification_logs enable row level security;
alter table audit_logs enable row level security;

create or replace function public.current_teacher_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select t.id
  from public.teachers t
  where t.auth_user_id = auth.uid()
  limit 1
$$;

create or replace function public.owns_study_room(target_study_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.study_rooms sr
    join public.teachers t on t.id = sr.owner_teacher_id
    where sr.id = target_study_room_id
      and t.auth_user_id = auth.uid()
  )
$$;

create or replace function public.is_admin_teacher()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.teachers t
    where t.auth_user_id = auth.uid()
      and t.role = 'admin'
  )
$$;

create policy "teachers can read own profile"
on teachers for select
using (auth_user_id = auth.uid());

create policy "admins can read all teacher profiles"
on teachers for select
using (is_admin_teacher());

create policy "teachers can insert own profile"
on teachers for insert
with check (auth_user_id = auth.uid());

create policy "teachers can update own profile"
on teachers for update
using (auth_user_id = auth.uid())
with check (auth_user_id = auth.uid());

create policy "teachers can read own organizations"
on organizations for select
using (
  exists (
    select 1
    from teachers t
    where t.organization_id = organizations.id
      and t.auth_user_id = auth.uid()
  )
);

create policy "admins can read organizations"
on organizations for select
using (is_admin_teacher());

create policy "owner can access own study rooms"
on study_rooms for all
using (owns_study_room(id))
with check (
  owner_teacher_id = current_teacher_id()
  and organization_id in (
    select t.organization_id
    from teachers t
    where t.id = current_teacher_id()
  )
);

create policy "admins can read study rooms"
on study_rooms for select
using (is_admin_teacher());

create policy "owner can access own study room members"
on study_room_members for all
using (owns_study_room(study_room_id))
with check (owns_study_room(study_room_id));

create policy "admins can read study room members"
on study_room_members for select
using (is_admin_teacher());

create policy "owner can access own students"
on students for all
using (owns_study_room(study_room_id))
with check (owns_study_room(study_room_id));

create policy "admins can read students"
on students for select
using (is_admin_teacher());

create policy "owner can access own guardians"
on guardians for all
using (owns_study_room(study_room_id))
with check (owns_study_room(study_room_id));

create policy "admins can read guardians"
on guardians for select
using (is_admin_teacher());

create policy "owner can access own student guardians"
on student_guardians for all
using (
  exists (
    select 1
    from students s
    where s.id = student_guardians.student_id
      and owns_study_room(s.study_room_id)
  )
)
with check (
  exists (
    select 1
    from students s
    where s.id = student_guardians.student_id
      and owns_study_room(s.study_room_id)
  )
);

create policy "admins can read student guardians"
on student_guardians for select
using (is_admin_teacher());

create policy "owner can access own classes"
on classes for all
using (owns_study_room(study_room_id))
with check (owns_study_room(study_room_id));

create policy "admins can read classes"
on classes for select
using (is_admin_teacher());

create policy "owner can access own class schedules"
on class_schedules for all
using (
  exists (
    select 1
    from classes c
    where c.id = class_schedules.class_id
      and owns_study_room(c.study_room_id)
  )
)
with check (
  exists (
    select 1
    from classes c
    where c.id = class_schedules.class_id
      and owns_study_room(c.study_room_id)
  )
);

create policy "admins can read class schedules"
on class_schedules for select
using (is_admin_teacher());

create policy "owner can access own class students"
on class_students for all
using (
  exists (
    select 1
    from classes c
    where c.id = class_students.class_id
      and owns_study_room(c.study_room_id)
  )
)
with check (
  exists (
    select 1
    from classes c
    join students s on s.id = class_students.student_id
    where c.id = class_students.class_id
      and owns_study_room(c.study_room_id)
      and s.study_room_id = c.study_room_id
  )
);

create policy "admins can read class students"
on class_students for select
using (is_admin_teacher());

create policy "owner can access own class sessions"
on class_sessions for all
using (owns_study_room(study_room_id))
with check (owns_study_room(study_room_id));

create policy "admins can read class sessions"
on class_sessions for select
using (is_admin_teacher());

create policy "owner can access own class session changes"
on class_session_changes for all
using (owns_study_room(study_room_id))
with check (owns_study_room(study_room_id));

create policy "admins can read class session changes"
on class_session_changes for select
using (is_admin_teacher());

create policy "owner can access own attendance records"
on attendance_records for all
using (owns_study_room(study_room_id))
with check (owns_study_room(study_room_id));

create policy "admins can read attendance records"
on attendance_records for select
using (is_admin_teacher());

create policy "owner can access own payment periods"
on payment_periods for all
using (owns_study_room(study_room_id))
with check (owns_study_room(study_room_id));

create policy "admins can read payment periods"
on payment_periods for select
using (is_admin_teacher());

create policy "owner can access own payment statuses"
on payment_statuses for all
using (owns_study_room(study_room_id))
with check (owns_study_room(study_room_id));

create policy "admins can read payment statuses"
on payment_statuses for select
using (is_admin_teacher());

create policy "owner can access own notification logs"
on notification_logs for all
using (owns_study_room(study_room_id))
with check (owns_study_room(study_room_id));

create policy "admins can read notification logs"
on notification_logs for select
using (is_admin_teacher());

create policy "owner can access own audit logs"
on audit_logs for all
using (owns_study_room(study_room_id))
with check (owns_study_room(study_room_id));

create policy "admins can read audit logs"
on audit_logs for select
using (is_admin_teacher());

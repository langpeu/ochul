alter table notification_logs
  add column if not exists payment_period_id uuid references payment_periods(id) on delete set null,
  add column if not exists payment_status_id uuid references payment_statuses(id) on delete set null;

create index if not exists idx_notification_payment_status
on notification_logs(payment_status_id, event_type)
where payment_status_id is not null;

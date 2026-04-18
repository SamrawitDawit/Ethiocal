-- =============================================
-- EthioCal — Notifications Migration
-- =============================================

-- 1. Notification preferences per user
create table if not exists public.notification_preferences (
    id              uuid primary key default gen_random_uuid(),
    user_id         uuid not null references public.profiles(id) on delete cascade unique,
    meal_reminders  boolean default true,
    health_alerts   boolean default true,
    reminder_times  jsonb default '["08:00","12:30","18:30"]'::jsonb,
    created_at      timestamptz default now(),
    updated_at      timestamptz default now()
);

alter table public.notification_preferences enable row level security;

create policy "Users can view own notification preferences"
    on public.notification_preferences for select
    using (auth.uid() = user_id);

create policy "Users can insert own notification preferences"
    on public.notification_preferences for insert
    with check (auth.uid() = user_id);

create policy "Users can update own notification preferences"
    on public.notification_preferences for update
    using (auth.uid() = user_id);

-- 2. Notification log
create table if not exists public.notifications (
    id              uuid primary key default gen_random_uuid(),
    user_id         uuid not null references public.profiles(id) on delete cascade,
    type            text not null check (type in ('meal_reminder', 'health_alert')),
    title           text not null,
    body            text not null,
    is_read         boolean default false,
    created_at      timestamptz default now()
);

create index idx_notifications_user_id on public.notifications(user_id);
create index idx_notifications_created_at on public.notifications(created_at);

alter table public.notifications enable row level security;

create policy "Users can view own notifications"
    on public.notifications for select
    using (auth.uid() = user_id);

create policy "Users can update own notifications"
    on public.notifications for update
    using (auth.uid() = user_id);

create policy "System can insert notifications"
    on public.notifications for insert
    to authenticated
    with check (true);

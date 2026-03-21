-- =============================================
-- EthioCal — Supabase Database Schema
-- =============================================
-- Run this SQL in the Supabase SQL Editor
-- (Dashboard → SQL Editor → New Query) to
-- create all tables and RLS policies.
-- =============================================


-- =============================================
-- 1. Profiles table
-- =============================================
-- Extends the built-in auth.users table with
-- app-specific fields (health info, calorie goal).
-- The id column references auth.users.id so every
-- Supabase Auth user gets a matching profile.
-- =============================================

create table if not exists public.profiles (
    id          uuid primary key references auth.users(id) on delete cascade,
    email       text not null,
    full_name   text not null,

    -- Health conditions
    has_diabetes       boolean default false,
    has_hypertension   boolean default false,
    has_heart_disease  boolean default false,

    -- Calorie tracking
    daily_calorie_goal float default 2000.0,

    is_active   boolean default true,
    created_at  timestamptz default now(),
    updated_at  timestamptz default now()
);

-- Auto-update the updated_at column on every row change
create or replace function public.handle_updated_at()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
    before update on public.profiles
    for each row execute function public.handle_updated_at();

-- RLS: users can only read/update their own profile
alter table public.profiles enable row level security;

drop policy if exists "Users can view own profile" on public.profiles;
create policy "Users can view own profile"
    on public.profiles for select
    using (auth.uid() = id);

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
    on public.profiles for update
    using (auth.uid() = id);

drop policy if exists "Users can insert own profile" on public.profiles;
create policy "Users can insert own profile"
    on public.profiles for insert
    with check (auth.uid() = id);


-- =============================================
-- 2. Auto-create a profile on signup
-- =============================================
-- This trigger fires after a new row is added
-- to auth.users (i.e. after Supabase sign-up)
-- and inserts a matching profiles row.
-- =============================================

create or replace function public.handle_new_user()
returns trigger as $$
begin
    insert into public.profiles (id, email, full_name)
    values (
        new.id,
        new.email,
        coalesce(new.raw_user_meta_data->>'full_name', '')
    );
    return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();


-- =============================================
-- 3. Food items table
-- =============================================
-- Pre-populated lookup table of Ethiopian foods
-- with nutritional data per standard serving.
-- =============================================

create table if not exists public.food_items (
    id              uuid primary key default gen_random_uuid(),
    name            text not null,
    name_amharic    text,
    description     text,
    category        text,           -- e.g. "wot", "injera", "kitfo"

    -- Nutritional info per serving
    calories        float not null,
    protein_g       float default 0.0,
    carbs_g         float default 0.0,
    fat_g           float default 0.0,
    fiber_g         float default 0.0,
    serving_size_g  float default 100.0,

    -- Label the AI model maps to this food
    ai_label        text unique,

    created_at      timestamptz default now()
);

-- Anyone logged in can read food items (reference data)
alter table public.food_items enable row level security;

drop policy if exists "Authenticated users can read food items" on public.food_items;
create policy "Authenticated users can read food items"
    on public.food_items for select
    to authenticated
    using (true);


-- =============================================
-- 4. Meals table
-- =============================================
-- A meal event (breakfast, lunch, dinner, snack)
-- belonging to a user on a specific date.
-- =============================================

create table if not exists public.meals (
    id          uuid primary key default gen_random_uuid(),
    user_id     uuid not null references public.profiles(id) on delete cascade,
    meal_type   text not null,      -- "breakfast" | "lunch" | "dinner" | "snack"
    image_url   text,               -- Supabase Storage URL of uploaded photo
    created_at  timestamptz default now()
);

create index if not exists idx_meals_user_id on public.meals(user_id);

alter table public.meals enable row level security;

drop policy if exists "Users can view own meals" on public.meals;
create policy "Users can view own meals"
    on public.meals for select
    using (auth.uid() = user_id);

drop policy if exists "Users can insert own meals" on public.meals;
create policy "Users can insert own meals"
    on public.meals for insert
    with check (auth.uid() = user_id);


-- =============================================
-- 5. Meal logs table
-- =============================================
-- Junction table linking a meal to the food
-- items consumed, with quantity and calorie
-- snapshot.
-- =============================================

create table if not exists public.meal_logs (
    id              uuid primary key default gen_random_uuid(),
    user_id         uuid not null references public.profiles(id) on delete cascade,
    meal_id         uuid not null references public.meals(id) on delete cascade,
    food_item_id    uuid not null references public.food_items(id) on delete restrict,
    quantity        float default 1.0,
    total_calories  float not null,
    created_at      timestamptz default now()
);

create index if not exists idx_meal_logs_user_id on public.meal_logs(user_id);
create index if not exists idx_meal_logs_meal_id on public.meal_logs(meal_id);

alter table public.meal_logs enable row level security;

drop policy if exists "Users can view own meal logs" on public.meal_logs;
create policy "Users can view own meal logs"
    on public.meal_logs for select
    using (auth.uid() = user_id);

drop policy if exists "Users can insert own meal logs" on public.meal_logs;
create policy "Users can insert own meal logs"
    on public.meal_logs for insert
    with check (auth.uid() = user_id);


-- =============================================
-- 6. Supabase Storage bucket for food images
-- =============================================
-- Run this separately or create the bucket via
-- the Supabase Dashboard → Storage.
-- =============================================

insert into storage.buckets (id, name, public)
values ('food-images', 'food-images', true)
on conflict (id) do nothing;

-- Allow authenticated users to upload to their own folder
drop policy if exists "Users can upload food images" on storage.objects;
create policy "Users can upload food images"
    on storage.objects for insert
    to authenticated
    with check (bucket_id = 'food-images');

-- Allow public read access to food images
drop policy if exists "Public read access for food images" on storage.objects;
create policy "Public read access for food images"
    on storage.objects for select
    to public
    using (bucket_id = 'food-images');


-- =============================================
-- 7. Sample Ethiopian food data (seed)
-- =============================================

insert into public.food_items (name, name_amharic, category, calories, protein_g, carbs_g, fat_g, fiber_g, serving_size_g, ai_label) values
    ('Doro Wot',        'ዶሮ ወጥ',       'wot',    350, 28.0, 15.0, 18.0, 3.0, 250.0, 'doro_wot'),
    ('Injera',          'እንጀራ',        'bread',  125,  4.0, 24.0,  1.0, 2.5, 100.0, 'injera'),
    ('Shiro Wot',       'ሽሮ ወጥ',       'wot',    280, 16.0, 32.0,  8.0, 8.0, 200.0, 'shiro_wot'),
    ('Kitfo',           'ክትፎ',         'meat',   400, 22.0,  2.0, 34.0, 0.5, 150.0, 'kitfo'),
    ('Tibs',            'ጥብስ',         'meat',   320, 30.0,  5.0, 20.0, 1.0, 200.0, 'tibs'),
    ('Misir Wot',       'ምስር ወጥ',      'wot',    230, 14.0, 30.0,  5.0, 9.0, 200.0, 'misir_wot'),
    ('Gomen',           'ጎመን',         'vegetable', 90,  4.0, 10.0,  4.0, 5.0, 150.0, 'gomen'),
    ('Ayib',            'አይብ',         'dairy',  120,  8.0,  3.0,  9.0, 0.0, 100.0, 'ayib'),
    ('Firfir',          'ፍርፍር',        'bread',  200,  6.0, 28.0,  7.0, 3.0, 150.0, 'firfir'),
    ('Chechebsa',       'ጨጨብሳ',       'bread',  350,  6.0, 40.0, 18.0, 2.0, 180.0, 'chechebsa')
on conflict (ai_label) do nothing;

-- =============================================
-- 8. User Profile Table
-- =============================================
create table if not exists public.user_profile (
    id          uuid primary key default gen_random_uuid(), -- profileId
    user_id     uuid references auth.users(id) on delete cascade not null unique, -- userId

    -- Health conditions
    has_diabetes       boolean default false,
    has_hypertension   boolean default false,
    has_heart_disease  boolean default false,

    -- Physical Metrics (New)
    age                int check (age > 0),
    gender             text check (gender in ('Male', 'Female')),
    height             float check (height > 0),
    height_unit        text check (height_unit in ('cm', 'ft')),
    weight             float check (weight > 0),
    weight_unit        text check (weight_unit in ('kg', 'lbs')),
    activity_level     text check (activity_level in ('Sedentary', 'Light Active', 'Moderately Active', 'Very Active')),
    -- make sure to add height and weight units so we can standardize to metric for calorie calculations
    -- make sure to add height and weight units so we can standardize to metric for calorie calculations

    -- Calorie tracking
    daily_calorie_goal float,
    created_at  timestamptz default now(),
    updated_at  timestamptz default now()
);

alter table public.user_profile enable row level security;

drop policy if exists "Users can view own profile" on public.user_profile;
create policy "Users can view own profile"
    on public.user_profile for select
    using (auth.uid() = user_id);

drop policy if exists "Users can update own profile" on public.user_profile;
create policy "Users can update own profile"
    on public.user_profile for update
    using (auth.uid() = user_id);

drop policy if exists "Users can insert own profile" on public.user_profile;
create policy "Users can insert own profile"
    on public.user_profile for insert
    with check (auth.uid() = user_id);

-- =============================================
-- 9. Health Condition Table
-- =============================================

create table if not exists public.health_conditions (
    id                   uuid primary key default gen_random_uuid(),
    condition_name       text not null unique,
    restricted_nutrients text check (restricted_nutrients in ('Sugar', 'Sodium', 'Fat', 'Cholesterol')),
    threshold_amount     float check (threshold_amount > 0),
    threshold_unit       text check (threshold_unit in ('mg', 'g', 'kcal')),
    created_at           timestamptz default now()
);

alter table public.health_conditions enable row level security;
drop policy if exists "Allow all authenticated users to read conditions" on public.health_conditions;
create policy "Allow all authenticated users to read conditions" on public.health_conditions for select to authenticated using (true);
drop policy if exists "Admin only insert" on public.health_conditions;
create policy "Admin only insert" on public.health_conditions for insert with check (true); -- TODO: This should be restricted to admin roles

-- =============================================
-- 9.1 User Profile - Health Conditions Junction
-- =============================================

-- Drop the table to ensure it's created with the correct foreign key.
-- This is a destructive action but guarantees the schema matches the file.
DROP TABLE IF EXISTS public.profile_health_conditions CASCADE;

create table if not exists public.profile_health_conditions (
    profile_id   uuid references public.user_profile(id) on delete cascade,
    condition_id uuid references public.health_conditions(id) on delete cascade,
    primary key (profile_id, condition_id)
);

alter table public.profile_health_conditions enable row level security;

drop policy if exists "Users can view own relations" on public.profile_health_conditions;
create policy "Users can view own relations" on public.profile_health_conditions
    for select using (
        auth.uid() = (select user_id from public.user_profile where id = profile_id)
    );

drop policy if exists "Users can modify own relations" on public.profile_health_conditions;
create policy "Users can modify own relations" on public.profile_health_conditions
    for insert with check (
        auth.uid() = (select user_id from public.user_profile where id = profile_id)
    );

drop policy if exists "Users can delete own relations" on public.profile_health_conditions;
create policy "Users can delete own relations" on public.profile_health_conditions
    for delete using (
        auth.uid() = (select user_id from public.user_profile where id = profile_id)
    );
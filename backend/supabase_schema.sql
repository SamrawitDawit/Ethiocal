-- =============================================
-- EthioCal — Supabase Database Schema
-- =============================================
-- Run this SQL in the Supabase SQL Editor
-- (Dashboard → SQL Editor → New Query) to
-- create all tables and RLS policies.
-- =============================================


-- =============================================
-- 1. Profiles table (User)
-- =============================================
-- Extends the built-in auth.users table with
-- app-specific fields including health data.
-- =============================================

create table if not exists public.profiles (
    id                  uuid primary key references auth.users(id) on delete cascade,
    email               text not null,
    full_name           text not null,
    role                text default 'user' check (role in ('user', 'admin')),
    language_preference text default 'English' check (language_preference in ('English', 'Amharic')),
    is_active           boolean default true,

    age                 integer check (age > 0 or age is null),
    gender              text check (gender in ('Male', 'Female') or gender is null),
    height              float check (height > 0 or height is null),
    weight              float check (weight > 0 or weight is null),
    activity_level      text check (activity_level in ('Sedentary', 'Lightly Active', 'Moderately Active', 'Very Active') or activity_level is null),
    daily_calorie_goal  float default 2000.0,
    created_at          timestamptz default now(),
    updated_at          timestamptz default now()
);

-- Auto-update the updated_at column on every row change
create or replace function public.handle_updated_at()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

create trigger set_profiles_updated_at
    before update on public.profiles
    for each row execute function public.handle_updated_at();

-- RLS: users can only read/update their own profile
alter table public.profiles enable row level security;

create policy "Users can view own profile"
    on public.profiles for select
    using (auth.uid() = id);

create policy "Users can update own profile"
    on public.profiles for update
    using (auth.uid() = id);

create policy "Users can insert own profile"
    on public.profiles for insert
    with check (auth.uid() = id);


-- =============================================
-- 2. Health Conditions table
-- =============================================
-- Reference table of health conditions with
-- nutrient restrictions.
-- =============================================

create table if not exists public.health_conditions (
    id                  uuid primary key default gen_random_uuid(),
    condition_name      text not null unique,
    restricted_nutrient text not null check (restricted_nutrient in ('Sugar', 'Sodium', 'Fat', 'Cholesterol')),
    threshold_amount    float not null check (threshold_amount > 0),
    threshold_unit      text not null check (threshold_unit in ('mg', 'g', 'kcal')),
    created_at          timestamptz default now()
);

alter table public.health_conditions enable row level security;

create policy "Authenticated users can read health conditions"
    on public.health_conditions for select
    to authenticated
    using (true);

create policy "Admins can manage health conditions"
    on public.health_conditions for all
    using (
        exists (
            select 1 from public.profiles
            where id = auth.uid() and role = 'admin'
        )
    );

-- Seed health conditions
insert into public.health_conditions (condition_name, restricted_nutrient, threshold_amount, threshold_unit) values
    ('Diabetes', 'Sugar', 25, 'g'),
    ('Hypertension', 'Sodium', 1500, 'mg'),
    ('Heart Disease', 'Cholesterol', 200, 'mg'),
    ('Obesity', 'Fat', 65, 'g')
on conflict (condition_name) do nothing;


-- =============================================
-- 3. User-Health Conditions junction table
-- =============================================

create table if not exists public.user_health_conditions (
    id                  uuid primary key default gen_random_uuid(),
    user_id             uuid not null references public.profiles(id) on delete cascade,
    health_condition_id uuid not null references public.health_conditions(id) on delete cascade,
    created_at          timestamptz default now(),
    unique(user_id, health_condition_id)
);

alter table public.user_health_conditions enable row level security;

create policy "Users can view own health conditions"
    on public.user_health_conditions for select
    using (auth.uid() = user_id);

create policy "Users can manage own health conditions"
    on public.user_health_conditions for all
    using (auth.uid() = user_id);


-- =============================================
-- 4. Food Nutrition table (food_items)
-- =============================================
-- Pre-populated lookup table of Ethiopian foods
-- with nutritional data per standard serving.
-- =============================================

create table if not exists public.food_items (
    id                      uuid primary key default gen_random_uuid(),
    name                    text not null,
    name_amharic            text,
    description             text,
    category                text,
    standard_serving_size   float default 100.0,
    calories_per_serving    float not null,
    carbohydrates           float default 0.0,
    protein                 float default 0.0,
    fat                     float default 0.0,
    fiber                   float default 0.0,
    sodium_mg               float default 0.0,
    sugar                   float default 0.0,
    cholesterol_mg          float default 0.0,
    source                  text default 'manual',
    ai_label                text unique,
    created_at              timestamptz default now()
);

alter table public.food_items enable row level security;

create policy "Authenticated users can read food items"
    on public.food_items for select
    to authenticated
    using (true);

create policy "Admins can manage food items"
    on public.food_items for all
    using (
        exists (
            select 1 from public.profiles
            where id = auth.uid() and role = 'admin'
        )
    );


-- =============================================
-- 5. Ingredients table
-- =============================================
-- Cooking ingredients (oil, onion, spices, etc.)
-- that can be added to meals.
-- =============================================

create table if not exists public.ingredients (
    id                      uuid primary key default gen_random_uuid(),
    name                    text not null,
    name_amharic            text,
    category                text,
    standard_serving_size   float default 10.0,
    calories_per_serving    float not null,
    carbohydrates           float default 0.0,
    protein                 float default 0.0,
    fat                     float default 0.0,
    created_at              timestamptz default now()
);

alter table public.ingredients enable row level security;

create policy "Authenticated users can read ingredients"
    on public.ingredients for select
    to authenticated
    using (true);

-- Seed common Ethiopian cooking ingredients
insert into public.ingredients (name, name_amharic, category, standard_serving_size, calories_per_serving, carbohydrates, protein, fat) values
    ('Vegetable Oil', 'የአትክልት ዘይት', 'oil', 15.0, 120, 0, 0, 14),
    ('Niter Kibbeh', 'ንጥር ቅቤ', 'oil', 15.0, 130, 0, 0, 15),
    ('Onion', 'ሽንኩርት', 'vegetable', 50.0, 20, 5, 0.5, 0),
    ('Garlic', 'ነጭ ሽንኩርት', 'vegetable', 5.0, 7, 1.5, 0.3, 0),
    ('Ginger', 'ዝንጅብል', 'spice', 5.0, 4, 0.9, 0.1, 0),
    ('Berbere', 'በርበሬ', 'spice', 5.0, 15, 3, 0.7, 0.5),
    ('Mitmita', 'ሚጥሚጣ', 'spice', 2.0, 6, 1, 0.2, 0.2),
    ('Tomato', 'ቲማቲም', 'vegetable', 100.0, 18, 4, 0.9, 0.2),
    ('Green Pepper', 'ቃሪያ', 'vegetable', 50.0, 10, 2, 0.4, 0.1),
    ('Salt', 'ጨው', 'seasoning', 1.0, 0, 0, 0, 0)
on conflict do nothing;


-- =============================================
-- 6. Food Item Standard Ingredients
-- =============================================
-- Links food items to their standard ingredients
-- with the standard quantity used in preparation.
-- =============================================

create table if not exists public.food_item_ingredients (
    id              uuid primary key default gen_random_uuid(),
    food_item_id    uuid not null references public.food_items(id) on delete cascade,
    ingredient_id   uuid not null references public.ingredients(id) on delete cascade,
    standard_quantity float not null default 1.0,
    created_at      timestamptz default now(),
    unique(food_item_id, ingredient_id)
);

create index idx_food_item_ingredients_food_id on public.food_item_ingredients(food_item_id);

alter table public.food_item_ingredients enable row level security;

create policy "Authenticated users can read food item ingredients"
    on public.food_item_ingredients for select
    to authenticated
    using (true);

create policy "Admins can manage food item ingredients"
    on public.food_item_ingredients for all
    using (
        exists (
            select 1 from public.profiles
            where id = auth.uid() and role = 'admin'
        )
    );


-- =============================================
-- 7. Logged Meals table
-- =============================================
-- A meal event belonging to a user.
-- =============================================

create table if not exists public.meals (
    id              uuid primary key default gen_random_uuid(),
    user_id         uuid not null references public.profiles(id) on delete cascade,
    meal_type       text not null check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack')),
    portion_size    float default 1.0,
    total_calories  float default 0.0,
    image_url       text,
    created_at      timestamptz default now()
);

create index idx_meals_user_id on public.meals(user_id);
create index idx_meals_created_at on public.meals(created_at);

alter table public.meals enable row level security;

create policy "Users can view own meals"
    on public.meals for select
    using (auth.uid() = user_id);

create policy "Users can insert own meals"
    on public.meals for insert
    with check (auth.uid() = user_id);

create policy "Users can update own meals"
    on public.meals for update
    using (auth.uid() = user_id);

create policy "Users can delete own meals"
    on public.meals for delete
    using (auth.uid() = user_id);


-- =============================================
-- 8. Meal Food Items table
-- =============================================
-- Links meals to food items with quantity.
-- =============================================

create table if not exists public.meal_food_items (
    id              uuid primary key default gen_random_uuid(),
    meal_id         uuid not null references public.meals(id) on delete cascade,
    food_item_id    uuid not null references public.food_items(id) on delete restrict,
    quantity        float default 1.0,
    total_calories  float not null,
    created_at      timestamptz default now()
);

create index idx_meal_food_items_meal_id on public.meal_food_items(meal_id);

alter table public.meal_food_items enable row level security;

create policy "Users can view own meal foods"
    on public.meal_food_items for select
    using (
        exists (
            select 1 from public.meals
            where meals.id = meal_food_items.meal_id
            and meals.user_id = auth.uid()
        )
    );

create policy "Users can insert own meal foods"
    on public.meal_food_items for insert
    with check (
        exists (
            select 1 from public.meals
            where meals.id = meal_food_items.meal_id
            and meals.user_id = auth.uid()
        )
    );


-- =============================================
-- 9. Meal Ingredients table
-- =============================================
-- Optional ingredients added to meals.
-- =============================================

create table if not exists public.meal_ingredients (
    id              uuid primary key default gen_random_uuid(),
    meal_id         uuid not null references public.meals(id) on delete cascade,
    ingredient_id   uuid not null references public.ingredients(id) on delete restrict,
    quantity        float default 1.0,
    total_calories  float not null,
    created_at      timestamptz default now()
);

create index idx_meal_ingredients_meal_id on public.meal_ingredients(meal_id);

alter table public.meal_ingredients enable row level security;

create policy "Users can view own meal ingredients"
    on public.meal_ingredients for select
    using (
        exists (
            select 1 from public.meals
            where meals.id = meal_ingredients.meal_id
            and meals.user_id = auth.uid()
        )
    );

create policy "Users can insert own meal ingredients"
    on public.meal_ingredients for insert
    with check (
        exists (
            select 1 from public.meals
            where meals.id = meal_ingredients.meal_id
            and meals.user_id = auth.uid()
        )
    );


-- =============================================
-- 10. Auto-create profile on signup
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

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();


-- =============================================
-- 11. Supabase Storage bucket
-- =============================================

insert into storage.buckets (id, name, public)
values ('food-images', 'food-images', true)
on conflict (id) do nothing;

create policy "Users can upload food images"
    on storage.objects for insert
    to authenticated
    with check (bucket_id = 'food-images');

create policy "Public read access for food images"
    on storage.objects for select
    to public
    using (bucket_id = 'food-images');


-- =============================================
-- 12. Sample Ethiopian food data (seed)
-- =============================================

insert into public.food_items (name, name_amharic, category, calories_per_serving, protein, carbohydrates, fat, fiber, standard_serving_size, ai_label, source) values
    ('Doro Wot', 'ዶሮ ወጥ', 'wot', 350, 28.0, 15.0, 18.0, 3.0, 250.0, 'doro_wot', 'manual'),
    ('Injera', 'እንጀራ', 'bread', 125, 4.0, 24.0, 1.0, 2.5, 100.0, 'injera', 'manual'),
    ('Shiro Wot', 'ሽሮ ወጥ', 'wot', 280, 16.0, 32.0, 8.0, 8.0, 200.0, 'shiro_wot', 'manual'),
    ('Kitfo', 'ክትፎ', 'meat', 400, 22.0, 2.0, 34.0, 0.5, 150.0, 'kitfo', 'manual'),
    ('Tibs', 'ጥብስ', 'meat', 320, 30.0, 5.0, 20.0, 1.0, 200.0, 'tibs', 'manual'),
    ('Misir Wot', 'ምስር ወጥ', 'wot', 230, 14.0, 30.0, 5.0, 9.0, 200.0, 'misir_wot', 'manual'),
    ('Gomen', 'ጎመን', 'vegetable', 90, 4.0, 10.0, 4.0, 5.0, 150.0, 'gomen', 'manual'),
    ('Ayib', 'አይብ', 'dairy', 120, 8.0, 3.0, 9.0, 0.0, 100.0, 'ayib', 'manual'),
    ('Firfir', 'ፍርፍር', 'bread', 200, 6.0, 28.0, 7.0, 3.0, 150.0, 'firfir', 'manual'),
    ('Chechebsa', 'ጨጨብሳ', 'bread', 350, 6.0, 40.0, 18.0, 2.0, 180.0, 'chechebsa', 'manual'),
    ('Yebeg Tibs', 'የበግ ጥብስ', 'meat', 380, 26.0, 4.0, 28.0, 1.0, 200.0, 'yebeg_tibs', 'manual'),
    ('Key Wot', 'ቀይ ወጥ', 'wot', 310, 24.0, 12.0, 18.0, 2.0, 200.0, 'key_wot', 'manual'),
    ('Alicha Wot', 'አልጫ ወጥ', 'wot', 180, 12.0, 18.0, 6.0, 4.0, 200.0, 'alicha_wot', 'manual'),
    ('Ful', 'ፉል', 'legume', 220, 13.0, 28.0, 6.0, 8.0, 200.0, 'ful', 'manual'),
    ('Genfo', 'ገንፎ', 'porridge', 280, 8.0, 48.0, 6.0, 3.0, 200.0, 'genfo', 'manual')
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

create table if not exists public.health_condition (
    id                   uuid primary key default gen_random_uuid(),
    condition_name       text not null unique,
    restricted_nutrients text check (restricted_nutrients in ('Sugar', 'Sodium', 'Fat', 'Cholesterol')),
    threshold_amount     float check (threshold_amount > 0),
    threshold_unit       text check (threshold_unit in ('mg', 'g', 'kcal')),
    created_at           timestamptz default now()
);

alter table public.health_condition enable row level security;
drop policy if exists "Allow all authenticated users to read conditions" on public.health_condition;
create policy "Allow all authenticated users to read conditions" on public.health_condition for select to authenticated using (true);
drop policy if exists "Admin only insert" on public.health_condition;
create policy "Admin only insert" on public.health_condition for insert with check (true); -- TODO: This should be restricted to admin roles

-- =============================================
-- 9.1 User Profile - Health Conditions Junction
-- =============================================

-- Drop the table to ensure it's created with the correct foreign key.
-- This is a destructive action but guarantees the schema matches the file.
DROP TABLE IF EXISTS public.profile_health_conditions CASCADE;

create table if not exists public.profile_health_conditions (
    profile_id   uuid references public.user_profile(id) on delete cascade,
    condition_id uuid references public.health_condition(id) on delete cascade,
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

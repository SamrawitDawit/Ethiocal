-- =============================================
-- Migration 007: Per-food-item ingredient tracking
-- =============================================
-- This allows ingredient adjustments to be tracked
-- per food item in a meal, so that if Doro Wot
-- has standard 2 oil and Shiro has standard 1 oil,
-- adjusting oil affects only the relevant food item.
-- =============================================

-- Create new table for per-food-item ingredient tracking
create table if not exists public.meal_food_item_ingredients (
    id                  uuid primary key default gen_random_uuid(),
    meal_id             uuid not null references public.meals(id) on delete cascade,
    meal_food_item_id   uuid not null references public.meal_food_items(id) on delete cascade,
    ingredient_id       uuid not null references public.ingredients(id) on delete restrict,
    quantity            float not null default 1.0,
    standard_quantity   float not null default 1.0,  -- The standard quantity for this ingredient in this food item
    quantity_diff       float not null default 0.0,  -- Difference from standard (user_qty - standard_qty)
    total_calories      float not null default 0.0,  -- Calories from the difference
    created_at          timestamptz default now(),
    unique(meal_food_item_id, ingredient_id)
);

create index idx_meal_food_item_ingredients_meal_id on public.meal_food_item_ingredients(meal_id);
create index idx_meal_food_item_ingredients_food_item_id on public.meal_food_item_ingredients(meal_food_item_id);

alter table public.meal_food_item_ingredients enable row level security;

create policy "Users can view own meal food item ingredients"
    on public.meal_food_item_ingredients for select
    using (
        exists (
            select 1 from public.meals
            where meals.id = meal_food_item_ingredients.meal_id
            and meals.user_id = auth.uid()
        )
    );

create policy "Users can insert own meal food item ingredients"
    on public.meal_food_item_ingredients for insert
    with check (
        exists (
            select 1 from public.meals
            where meals.id = meal_food_item_ingredients.meal_id
            and meals.user_id = auth.uid()
        )
    );

create policy "Users can update own meal food item ingredients"
    on public.meal_food_item_ingredients for update
    using (
        exists (
            select 1 from public.meals
            where meals.id = meal_food_item_ingredients.meal_id
            and meals.user_id = auth.uid()
        )
    );

create policy "Users can delete own meal food item ingredients"
    on public.meal_food_item_ingredients for delete
    using (
        exists (
            select 1 from public.meals
            where meals.id = meal_food_item_ingredients.meal_id
            and meals.user_id = auth.uid()
        )
    );

-- Add comments for documentation
comment on table public.meal_food_item_ingredients is 'Tracks ingredient adjustments per food item in a meal';
comment on column public.meal_food_item_ingredients.meal_food_item_id is 'Reference to the specific food item in the meal';
comment on column public.meal_food_item_ingredients.standard_quantity is 'The standard quantity from food_item_ingredients table';
comment on column public.meal_food_item_ingredients.quantity_diff is 'Difference: user_quantity - standard_quantity. Positive = more used, Negative = less used';

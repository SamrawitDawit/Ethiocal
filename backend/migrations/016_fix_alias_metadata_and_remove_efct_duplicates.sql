do $$
declare
    ambiguous_meal_sources text;
    remaining_duplicate_sources text;
begin
    create temporary table tmp_food_item_alias_cleanup (
        alias_ai_label text primary key,
        source_ai_label text not null
    ) on commit drop;

    insert into tmp_food_item_alias_cleanup (alias_ai_label, source_ai_label) values
        ('abeba_gomen', 'efct_040005'),
        ('alicha_difin_misir', 'difin_misir_alicha'),
        ('alicha_dinich', 'dinich_wot'),
        ('alicha_kik', 'kik_alicha'),
        ('alicha_shiro', 'shiro_wot'),
        ('ambasha', 'dabo'),
        ('arusto', 'efct_070157'),
        ('asa', 'efct_090025'),
        ('asa_lebleb', 'efct_160005'),
        ('atint', 'dorowot'),
        ('avocado', 'efct_050003'),
        ('ayibe_gomen', 'efct_170001'),
        ('beso', 'efct_010194'),
        ('bombolino', 'dabo'),
        ('bozena', 'shiro_wot'),
        ('brocolli', 'efct_040033'),
        ('chiko', 'efct_010210'),
        ('chips', 'efct_020028'),
        ('chornake_pasti', 'efct_170004'),
        ('dfo_dabo', 'dabo'),
        ('difin_misir', 'difin_misir_alicha'),
        ('duba_wot', 'tikil_gomen'),
        ('dulet', 'efct_070151'),
        ('fetira', 'efct_010190'),
        ('goden', 'efct_070147'),
        ('gomen_besega', 'efct_040093'),
        ('gored_gored', 'efct_070003'),
        ('gulban', 'efct_170002'),
        ('indomie', 'pasta'),
        ('karya_sng', 'efct_040084'),
        ('key_difin_misir', 'misir_wot'),
        ('key_injera', 'injera'),
        ('key_karya', 'karya'),
        ('kik_wot', 'kik_alicha'),
        ('kinche', 'efct_010193'),
        ('kita', 'efct_010190'),
        ('kolo', 'efct_010210'),
        ('lebleb_kitfo', 'efct_070153'),
        ('lomi', 'efct_050004'),
        ('macaroni', 'pasta'),
        ('mar', 'efct_130004'),
        ('meatball', 'efct_070153'),
        ('mulmul', 'dabo'),
        ('nefro', 'efct_170002'),
        ('pasta_furno', 'efct_170004'),
        ('selata', 'salata'),
        ('seljo', 'efct_030103'),
        ('senafch', 'efct_060010'),
        ('shawarma', 'tibs'),
        ('shekla_tibs', 'tibs'),
        ('shenbera_asa', 'efct_030106'),
        ('siga_wot', 'efct_070159'),
        ('slice_dabo', 'dabo'),
        ('suf_fitfit', 'efct_010206'),
        ('telba_fitfit', 'efct_010206'),
        ('tihilo', 'tihilo_ball'),
        ('tihilo_stew', 'tihilo_ball'),
        ('tire_siga', 'efct_070003'),
        ('tripa', 'efct_070155'),
        ('yedoro_atint', 'dorowot'),
        ('yetetebese_enkulal', 'yetekekele_enkulal');

    -- Fix the alias rows created by migration 015 so their description/source metadata
    -- exactly matches the source food item they were copied from.
    update public.food_items as alias_item
    set description_english = source_item.description_english,
        description_amharic = source_item.description_amharic,
        description = source_item.description,
        source = source_item.source
    from tmp_food_item_alias_cleanup as cleanup
    join public.food_items as source_item
        on source_item.ai_label = cleanup.source_ai_label
    where alias_item.ai_label = cleanup.alias_ai_label;

    -- Preserve standard ingredient links before deleting duplicate EFCT rows.
    insert into public.food_item_ingredients (
        food_item_id,
        ingredient_id,
        quantity_grams
    )
    select
        alias_item.id,
        source_ingredients.ingredient_id,
        source_ingredients.quantity_grams
    from tmp_food_item_alias_cleanup as cleanup
    join public.food_items as source_item
        on source_item.ai_label = cleanup.source_ai_label
    join public.food_items as alias_item
        on alias_item.ai_label = cleanup.alias_ai_label
    join public.food_item_ingredients as source_ingredients
        on source_ingredients.food_item_id = source_item.id
    where cleanup.source_ai_label like 'efct\_%' escape '\'
    on conflict (food_item_id, ingredient_id) do update
    set quantity_grams = excluded.quantity_grams;

    -- If a duplicate EFCT row is already referenced by meal history and maps to more than one
    -- alias label, do not guess which alias should replace it.
    select string_agg(ambiguous.source_ai_label, ', ' order by ambiguous.source_ai_label)
    into ambiguous_meal_sources
    from (
        select cleanup.source_ai_label
        from tmp_food_item_alias_cleanup as cleanup
        join public.food_items as source_item
            on source_item.ai_label = cleanup.source_ai_label
        join public.meal_food_items as meal_item
            on meal_item.food_item_id = source_item.id
        where cleanup.source_ai_label like 'efct\_%' escape '\'
        group by cleanup.source_ai_label
        having count(distinct cleanup.alias_ai_label) > 1
    ) as ambiguous;

    if ambiguous_meal_sources is not null then
        raise exception 'Cannot remove EFCT duplicate rows referenced by meal history without an explicit canonical alias: %', ambiguous_meal_sources;
    end if;

    -- Repoint any meal history that references a duplicate EFCT row when there is exactly one alias.
    with unique_cleanup as (
        select
            cleanup.source_ai_label,
            min(cleanup.alias_ai_label) as alias_ai_label
        from tmp_food_item_alias_cleanup as cleanup
        where cleanup.source_ai_label like 'efct\_%' escape '\'
        group by cleanup.source_ai_label
        having count(*) = 1
    )
    update public.meal_food_items as meal_item
    set food_item_id = alias_item.id
    from unique_cleanup
    join public.food_items as source_item
        on source_item.ai_label = unique_cleanup.source_ai_label
    join public.food_items as alias_item
        on alias_item.ai_label = unique_cleanup.alias_ai_label
    where meal_item.food_item_id = source_item.id
      and meal_item.food_item_id <> alias_item.id;

    delete from public.food_items as source_item
    using (
        select distinct cleanup.source_ai_label
        from tmp_food_item_alias_cleanup as cleanup
        join public.food_items as alias_item
            on alias_item.ai_label = cleanup.alias_ai_label
        where cleanup.source_ai_label like 'efct\_%' escape '\'
    ) as duplicates_to_delete
    where source_item.ai_label = duplicates_to_delete.source_ai_label
      and not exists (
          select 1
          from public.meal_food_items as meal_item
          where meal_item.food_item_id = source_item.id
      );

    select string_agg(remaining.source_ai_label, ', ' order by remaining.source_ai_label)
    into remaining_duplicate_sources
    from (
        select distinct cleanup.source_ai_label
        from tmp_food_item_alias_cleanup as cleanup
        join public.food_items as source_item
            on source_item.ai_label = cleanup.source_ai_label
        join public.food_items as alias_item
            on alias_item.ai_label = cleanup.alias_ai_label
        where cleanup.source_ai_label like 'efct\_%' escape '\'
    ) as remaining;

    if remaining_duplicate_sources is not null then
        raise exception 'Failed to remove duplicate EFCT source rows: %', remaining_duplicate_sources;
    end if;
end $$;
do $$
declare
    missing_source_labels text;
    missing_aliases text;
begin
    -- Add the remaining food-recognition labels as food_items aliases.
    -- Keep the non-food detector label `paper` intentionally unmatched.

    drop table if exists tmp_food_item_alias_seed;

    create temporary table tmp_food_item_alias_seed (
        alias_ai_label text primary key,
        source_ai_label text not null,
        name_english text not null,
        name_amharic text not null
    ) on commit drop;

    insert into tmp_food_item_alias_seed (
        alias_ai_label,
        source_ai_label,
        name_english,
        name_amharic
    ) values
        ('abeba_gomen', 'efct_040005', 'Abeba Gomen', 'አበባ ጎመን'),
        ('alicha_difin_misir', 'difin_misir_alicha', 'Alicha Difin Misir', 'አልጫ ድፍን ምስር'),
        ('alicha_dinich', 'dinich_wot', 'Alicha Dinich', 'አልጫ ድንች'),
        ('alicha_kik', 'kik_alicha', 'Alicha Kik', 'አልጫ ክክ'),
        ('alicha_shiro', 'shiro_wot', 'Alicha Shiro', 'አልጫ ሽሮ'),
        ('ambasha', 'dabo', 'Ambasha', 'አምባሻ'),
        ('arusto', 'efct_070157', 'Arusto', 'አሩስቶ'),
        ('asa', 'efct_090025', 'Asa', 'አሳ'),
        ('asa_lebleb', 'efct_160005', 'Asa Lebleb', 'አሳ ለብለብ'),
        ('atint', 'dorowot', 'Atint', 'አጥንት'),
        ('avocado', 'efct_050003', 'Avocado', 'አቮካዶ'),
        ('ayibe_gomen', 'efct_170001', 'Ayibe Gomen', 'አይብ በጎመን'),
        ('beso', 'efct_010194', 'Beso', 'በሶ'),
        ('bombolino', 'dabo', 'Bombolino', 'ቦምቦሊኖ'),
        ('bozena', 'shiro_wot', 'Bozena', 'ቦዘና'),
        ('brocolli', 'efct_040033', 'Brocolli', 'ብሮኮሊ'),
        ('chiko', 'efct_010210', 'Chiko', 'ጭኮ'),
        ('chips', 'efct_020028', 'Chips', 'ቺፕስ'),
        ('chornake_pasti', 'efct_170004', 'Chornake Pasti', 'ቾርናኬ ፓስቲ'),
        ('dfo_dabo', 'dabo', 'Dfo Dabo', 'ድፎ ዳቦ'),
        ('difin_misir', 'difin_misir_alicha', 'Difin Misir', 'ድፍን ምስር'),
        ('duba_wot', 'tikil_gomen', 'Duba Wot', 'ዱባ ወጥ'),
        ('dulet', 'efct_070151', 'Dulet', 'ዱለት'),
        ('fetira', 'efct_010190', 'Fetira', 'ፈጢራ'),
        ('goden', 'efct_070147', 'Goden', 'ጎደን'),
        ('gomen_besega', 'efct_040093', 'Gomen Besega', 'ጎመን በስጋ'),
        ('gored_gored', 'efct_070003', 'Gored Gored', 'ጎረድ ጎረድ'),
        ('gulban', 'efct_170002', 'Gulban', 'ጉልባን'),
        ('indomie', 'pasta', 'Indomie', 'ኢንዶሚ'),
        ('karya_sng', 'efct_040084', 'Karya Sng', 'ቃርያ ሰንግ'),
        ('key_difin_misir', 'misir_wot', 'Key Difin Misir', 'ቀይ ድፍን ምስር'),
        ('key_injera', 'injera', 'Key Injera', 'ቀይ እንጀራ'),
        ('key_karya', 'karya', 'Key Karya', 'ቀይ ቃርያ'),
        ('kik_wot', 'kik_alicha', 'Kik Wot', 'ክክ ወጥ'),
        ('kinche', 'efct_010193', 'Kinche', 'ቅንጬ'),
        ('kita', 'efct_010190', 'Kita', 'ቂጣ'),
        ('kolo', 'efct_010210', 'Kolo', 'ቆሎ'),
        ('lebleb_kitfo', 'efct_070153', 'Lebleb Kitfo', 'ለብለብ ክትፎ'),
        ('lomi', 'efct_050004', 'Lomi', 'ሎሚ'),
        ('macaroni', 'pasta', 'Macaroni', 'ማካሮኒ'),
        ('mar', 'efct_130004', 'Mar', 'ማር'),
        ('meatball', 'efct_070153', 'Meatball', 'ስጋ ኳስ'),
        ('mulmul', 'dabo', 'Mulmul', 'ሙልሙል'),
        ('nefro', 'efct_170002', 'Nefro', 'ንፍሮ'),
        ('pasta_furno', 'efct_170004', 'Pasta Furno', 'ፓስታ ፉርኖ'),
        ('selata', 'salata', 'Selata', 'ሰላጣ'),
        ('seljo', 'efct_030103', 'Seljo', 'ስልጆ'),
        ('senafch', 'efct_060010', 'Senafch', 'ሰናፍጭ'),
        ('shawarma', 'tibs', 'Shawarma', 'ሻዋርማ'),
        ('shekla_tibs', 'tibs', 'Shekla Tibs', 'ሸክላ ጥብስ'),
        ('shenbera_asa', 'efct_030106', 'Shenbera Asa', 'ሽንብራ አሳ'),
        ('siga_wot', 'efct_070159', 'Siga Wot', 'ስጋ ወጥ'),
        ('slice_dabo', 'dabo', 'Slice Dabo', 'ስላይስ ዳቦ'),
        ('suf_fitfit', 'efct_010206', 'Suf Fitfit', 'ሱፍ ፍትፍት'),
        ('telba_fitfit', 'efct_010206', 'Telba Fitfit', 'ተልባ ፍትፍት'),
        ('tihilo', 'tihilo_ball', 'Tihilo', 'ቲህሎ'),
        ('tihilo_stew', 'tihilo_ball', 'Tihilo Stew', 'ቲህሎ ወጥ'),
        ('tire_siga', 'efct_070003', 'Tire Siga', 'ጥሬ ስጋ'),
        ('tripa', 'efct_070155', 'Tripa', 'ትሪፓ'),
        ('yedoro_atint', 'dorowot', 'Yedoro Atint', 'የዶሮ አጥንት'),
        ('yetetebese_enkulal', 'yetekekele_enkulal', 'Yetetebese Enkulal', 'የተጠበሰ እንቁላል');

    select string_agg(seed.source_ai_label, ', ' order by seed.source_ai_label)
    into missing_source_labels
    from (
        select distinct source_ai_label
        from tmp_food_item_alias_seed
    ) seed
    left join public.food_items source_item
        on source_item.ai_label = seed.source_ai_label
    where source_item.id is null;

    if missing_source_labels is not null then
        raise exception 'Missing source food_items rows for recognition alias seed: %', missing_source_labels;
    end if;
    insert into public.food_items (
        name_english,
        name_amharic,
        description_english,
        description_amharic,
        description,
        category,
        standard_serving_size,
        calories_per_100g,
        carbohydrates,
        protein,
        fat,
        saturated_fat_g,
        fiber,
        sodium_mg,
        sugar,
        cholesterol_mg,
        source,
        ai_label
    )
    select
        seed.name_english,
        seed.name_amharic,
        source_item.description_english,
        source_item.description_amharic,
        source_item.description,
        coalesce(source_item.category, 'uncategorized') as category,
        coalesce(source_item.standard_serving_size, 100.0) as standard_serving_size,
        source_item.calories_per_100g,
        coalesce(source_item.carbohydrates, 0.0) as carbohydrates,
        coalesce(source_item.protein, 0.0) as protein,
        coalesce(source_item.fat, 0.0) as fat,
        coalesce(source_item.saturated_fat_g, 0.0) as saturated_fat_g,
        coalesce(source_item.fiber, 0.0) as fiber,
        coalesce(source_item.sodium_mg, 0.0) as sodium_mg,
        coalesce(source_item.sugar, 0.0) as sugar,
        coalesce(source_item.cholesterol_mg, 0.0) as cholesterol_mg,
        source_item.source,
        seed.alias_ai_label
    from tmp_food_item_alias_seed seed
    join public.food_items source_item
        on source_item.ai_label = seed.source_ai_label
    where not exists (
        select 1
        from public.food_items existing
        where existing.ai_label = seed.alias_ai_label
    )
    on conflict (ai_label) do nothing;

    select string_agg(seed.alias_ai_label, ', ' order by seed.alias_ai_label)
    into missing_aliases
    from tmp_food_item_alias_seed seed
    left join public.food_items food_item
        on food_item.ai_label = seed.alias_ai_label
    where food_item.id is null;

    if missing_aliases is not null then
        raise exception 'Failed to seed recognition aliases for: %', missing_aliases;
    end if;
end $$;

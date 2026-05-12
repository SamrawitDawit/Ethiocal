begin;

do $$
begin
    if exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'food_items'
          and column_name = 'name'
    ) and not exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'food_items'
          and column_name = 'description_english'
    ) then
        alter table public.food_items rename column name to description_english;
    end if;
end $$;

alter table public.food_items
    add column if not exists name_english text,
    add column if not exists description_english text,
    add column if not exists description_amharic text;

alter table public.food_items
    alter column description_english drop not null;

create or replace function public._split_food_item_text(full_name text)
returns text[]
language plpgsql
as $$
declare
    normalized text;
    comma_parts text[];
    word_parts text[];
    title text;
    remainder text;
    descriptor_terms constant text[] := array[
        'black',
        'boiled',
        'brown',
        'dried',
        'drained',
        'dry',
        'flour',
        'fresh',
        'hulled',
        'pearled',
        'peeled',
        'polished',
        'raw',
        'red',
        'refined',
        'salted',
        'split',
        'sweet',
        'unenriched',
        'unfermented',
        'white',
        'whole',
        'whole grain',
        'yellow'
    ];
begin
    normalized := btrim(regexp_replace(coalesce(full_name, ''), '\s+', ' ', 'g'), ' ,;');
    if normalized = '' then
        return array[null, null];
    end if;

    if position(' with ' in lower(normalized)) > 0 then
        title := btrim(left(normalized, position(' with ' in lower(normalized)) - 1), ' ,;');
        remainder := btrim(substring(normalized from position(' with ' in lower(normalized))), ' ,;');
        return array[nullif(title, ''), nullif(remainder, '')];
    end if;

    comma_parts := regexp_split_to_array(normalized, '\s*,\s*');
    if coalesce(array_length(comma_parts, 1), 0) >= 3 then
        if lower(comma_parts[2]) = any(descriptor_terms) then
            title := comma_parts[1];
            remainder := array_to_string(comma_parts[2:array_length(comma_parts, 1)], ', ');
        else
            title := concat_ws(', ', comma_parts[1], comma_parts[2]);
            remainder := array_to_string(comma_parts[3:array_length(comma_parts, 1)], ', ');
        end if;

        return array[
            nullif(btrim(title, ' ,;'), ''),
            nullif(btrim(coalesce(remainder, ''), ' ,;'), '')
        ];
    end if;

    word_parts := regexp_split_to_array(normalized, '\s+');
    if coalesce(array_length(word_parts, 1), 0) > 4 then
        title := array_to_string(word_parts[1:4], ' ');
        remainder := array_to_string(word_parts[5:array_length(word_parts, 1)], ' ');
        return array[nullif(title, ''), nullif(remainder, '')];
    end if;

    return array[normalized, null];
end;
$$;

create or replace function public._translate_food_description_to_amharic(description_text text)
returns text
language plpgsql
as $$
declare
    translated text;
    started_with boolean := false;
    started_from boolean := false;
    english_terms text[] := array[
        'as part of a recipe',
        'seed coat removed',
        'whole grain',
        'red pepper spice blend',
        'green pepper paste',
        'green pepper',
        'beef meat sauce',
        'vegetable sauce',
        'tomato sauce',
        'beef meat',
        'white wheat',
        'brown teff',
        'white teff',
        'white maize',
        'refined flour',
        'without salt',
        'without fat',
        'drained',
        'boiled',
        'roasted',
        'fermented',
        'unfermented',
        'refined',
        'polished',
        'hulled',
        'peeled',
        'fresh',
        'dry',
        'raw',
        'white',
        'black',
        'brown',
        'yellow',
        'red',
        'whole',
        'split',
        'sweet',
        'salted',
        'spiced',
        'seed',
        'flour',
        'tuber',
        'grain',
        'sauce',
        'spices',
        'condiments',
        'tomato',
        'onion',
        'garlic',
        'butter',
        'oil',
        'water',
        'milk',
        'yoghurt',
        'berbere',
        'egg',
        'salt',
        'and'
    ];
    amharic_terms text[] := array[
        'የአሰራር አካል',
        'ቅርፊቱ የተወገደ',
        'ሙሉ እህል',
        'በርበሬ',
        'ኮችኮቻ',
        'አረንጓዴ ቃሪያ',
        'የበሬ ስጋ ሶስ',
        'የአትክልት ሶስ',
        'የቲማቲም ሶስ',
        'የበሬ ስጋ',
        'ነጭ ስንዴ',
        'ቡናማ ጤፍ',
        'ነጭ ጤፍ',
        'ነጭ በቆሎ',
        'የተጣራ ዱቄት',
        'ያለ ጨው',
        'ያለ ስብ',
        'ውሃው የተወገደ',
        'የተቀቀለ',
        'የተጠበሰ',
        'የቦካ',
        'ያልቦካ',
        'የተጣራ',
        'የተፈተገ',
        'ቅርፊቱ የተወገደ',
        'የተላጠ',
        'ትኩስ',
        'ደረቅ',
        'ጥሬ',
        'ነጭ',
        'ጥቁር',
        'ቡናማ',
        'ቢጫ',
        'ቀይ',
        'ሙሉ',
        'የተከፈለ',
        'ጣፋጭ',
        'ጨው ያለበት',
        'በቅመም የተዘጋጀ',
        'ዘር',
        'ዱቄት',
        'ሥር',
        'እህል',
        'ሶስ',
        'ቅመሞች',
        'ቅመሞች',
        'ቲማቲም',
        'ሽንኩርት',
        'ነጭ ሽንኩርት',
        'ቅቤ',
        'ዘይት',
        'ውሃ',
        'ወተት',
        'እርጎ',
        'በርበሬ',
        'እንቁላል',
        'ጨው',
        'እና'
    ];
    i integer;
begin
    translated := btrim(coalesce(description_text, ''), ' .;');
    if translated = '' then
        return null;
    end if;

    if translated ~* '^EFCT 2025 code [0-9]+; edible portion [0-9.]+\.?$' then
        translated := regexp_replace(
            translated,
            '^EFCT 2025 code ([0-9]+); edible portion ([0-9.]+)\.?$',
            'የEFCT 2025 ኮድ \1፤ የሚበላው ክፍል \2 ነው',
            'i'
        );
        return translated || '።';
    end if;

    started_with := lower(translated) like 'with %';
    started_from := lower(translated) like 'from %';

    if started_with then
        translated := substring(translated from 6);
    elsif started_from then
        translated := substring(translated from 6);
    end if;

    translated := lower(translated);

    for i in 1..array_length(english_terms, 1) loop
        translated := replace(translated, english_terms[i], amharic_terms[i]);
    end loop;

    translated := replace(translated, ', ', '፣ ');
    translated := replace(translated, '; ', '፤ ');
    translated := replace(translated, '(', '（');
    translated := replace(translated, ')', '）');
    translated := regexp_replace(translated, '\s+', ' ', 'g');
    translated := btrim(translated, ' ,;');

    if translated = '' then
        return null;
    end if;

    if started_with then
        translated := 'ከ' || translated || ' ጋር';
    elsif started_from then
        translated := 'ከ' || translated || ' የተሰራ';
    end if;

    if right(translated, 1) not in ('።', '፣', '፤') then
        translated := translated || '።';
    end if;

    return translated;
end;
$$;

with parsed as (
    select
        id,
        public._split_food_item_text(description_english) as split_text
    from public.food_items
    where name_english is null or btrim(name_english) = ''
)
update public.food_items as fi
set name_english = coalesce(nullif((parsed.split_text)[1], ''), fi.name_english),
    description_english = nullif((parsed.split_text)[2], '')
from parsed
where fi.id = parsed.id;

update public.food_items
set name_english = initcap(replace(ai_label, '_', ' '))
where (name_english is null or btrim(name_english) = '')
  and ai_label is not null
  and ai_label not like 'efct_%';

update public.food_items
set description_amharic = public._translate_food_description_to_amharic(description_english)
where description_amharic is null or btrim(description_amharic) = '';

drop function public._split_food_item_text(text);
drop function public._translate_food_description_to_amharic(text);

commit;
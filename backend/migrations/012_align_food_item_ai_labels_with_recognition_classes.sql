begin;

-- Align clear food-recognition model classes with seeded food_items rows.
-- Ambiguous classes and non-food negatives such as fork/paper are intentionally left unmapped.
with label_map(current_ai_label, new_ai_label) as (
    values
        ('efct_140049', 'awaze'),
        ('efct_100003', 'ayib'),
        ('efct_020041', 'bula'),
        ('efct_040004', 'carrot'),
        ('efct_010189', 'chechebsa'),
        ('efct_010133', 'dabo'),
        ('efct_030100', 'difin_misir_alicha'),
        ('efct_020026', 'dinich'),
        ('efct_020052', 'dinich_wot'),
        ('efct_070152', 'dorowot'),
        ('efct_080013', 'enkulal_firfir'),
        ('efct_100019', 'ergo'),
        ('efct_010224', 'firfir'),
        ('efct_040090', 'fosoliya'),
        ('efct_010192', 'genfo'),
        ('efct_040092', 'gomen'),
        ('efct_040094', 'gomen_kitfo'),
        ('efct_010109', 'injera'),
        ('efct_140013', 'karya'),
        ('efct_040018', 'key_shinkurt'),
        ('efct_040002', 'keysir'),
        ('efct_030094', 'kik_alicha'),
        ('efct_160004', 'kikil'),
        ('efct_020043', 'kocho'),
        ('efct_040076', 'kosta'),
        ('efct_030093', 'misir_wot'),
        ('efct_140052', 'mitmita'),
        ('efct_010218', 'pasta'),
        ('efct_010167', 'ruz'),
        ('efct_040080', 'salata'),
        ('efct_010223', 'sambusa'),
        ('efct_030085', 'shiro_wot'),
        ('efct_060018', 'suf'),
        ('efct_070156', 'tibs'),
        ('efct_010216', 'tihilo_ball'),
        ('efct_040085', 'tikil_gomen'),
        ('efct_040083', 'timatim_kurt'),
        ('efct_040082', 'timatim_lebleb'),
        ('efct_080007', 'yetekekele_enkulal')
),
updatable as (
    select
        fi.id,
        lm.new_ai_label
    from public.food_items as fi
    join label_map as lm
        on fi.ai_label = lm.current_ai_label
    where not exists (
        select 1
        from public.food_items as existing
        where existing.ai_label = lm.new_ai_label
          and existing.id <> fi.id
    )
)
update public.food_items as fi
set ai_label = updatable.new_ai_label
from updatable
where fi.id = updatable.id;

commit;
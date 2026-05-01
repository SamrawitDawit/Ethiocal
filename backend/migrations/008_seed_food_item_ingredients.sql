-- =============================================
-- Migration 008: Seed standard ingredients for Ethiopian dishes
-- =============================================
-- This seeds the food_item_ingredients table with
-- standard cooking ingredients for popular Ethiopian dishes.
-- 
-- Standard quantities are approximate values used in
-- typical Ethiopian home cooking.
-- =============================================

-- First, get the food item IDs
DO $$
DECLARE
    -- Food items
    doro_wot_id UUID;
    shiro_wot_id UUID;
    misir_wot_id UUID;
    kitfo_id UUID;
    tibs_id UUID;
    yebeg_tibs_id UUID;
    key_wot_id UUID;
    alicha_wot_id UUID;
    firfir_id UUID;
    
    -- Ingredients
    veg_oil_id UUID;
    niter_kibbeh_id UUID;
    onion_id UUID;
    garlic_id UUID;
    ginger_id UUID;
    berbere_id UUID;
    mitmita_id UUID;
    tomato_id UUID;
    green_pepper_id UUID;
    salt_id UUID;
BEGIN
    -- Get food item IDs
    SELECT id INTO doro_wot_id FROM food_items WHERE ai_label = 'doro_wot' LIMIT 1;
    SELECT id INTO shiro_wot_id FROM food_items WHERE ai_label = 'shiro_wot' LIMIT 1;
    SELECT id INTO misir_wot_id FROM food_items WHERE ai_label = 'misir_wot' LIMIT 1;
    SELECT id INTO kitfo_id FROM food_items WHERE ai_label = 'kitfo' LIMIT 1;
    SELECT id INTO tibs_id FROM food_items WHERE ai_label = 'tibs' LIMIT 1;
    SELECT id INTO yebeg_tibs_id FROM food_items WHERE ai_label = 'yebeg_tibs' LIMIT 1;
    SELECT id INTO key_wot_id FROM food_items WHERE ai_label = 'key_wot' LIMIT 1;
    SELECT id INTO alicha_wot_id FROM food_items WHERE ai_label = 'alicha_wot' LIMIT 1;
    SELECT id INTO firfir_id FROM food_items WHERE ai_label = 'firfir' LIMIT 1;
    
    -- Get ingredient IDs
    SELECT id INTO veg_oil_id FROM ingredients WHERE name = 'Vegetable Oil' LIMIT 1;
    SELECT id INTO niter_kibbeh_id FROM ingredients WHERE name = 'Niter Kibbeh' LIMIT 1;
    SELECT id INTO onion_id FROM ingredients WHERE name = 'Onion' LIMIT 1;
    SELECT id INTO garlic_id FROM ingredients WHERE name = 'Garlic' LIMIT 1;
    SELECT id INTO ginger_id FROM ingredients WHERE name = 'Ginger' LIMIT 1;
    SELECT id INTO berbere_id FROM ingredients WHERE name = 'Berbere' LIMIT 1;
    SELECT id INTO mitmita_id FROM ingredients WHERE name = 'Mitmita' LIMIT 1;
    SELECT id INTO tomato_id FROM ingredients WHERE name = 'Tomato' LIMIT 1;
    SELECT id INTO green_pepper_id FROM ingredients WHERE name = 'Green Pepper' LIMIT 1;
    SELECT id INTO salt_id FROM ingredients WHERE name = 'Salt' LIMIT 1;
    
    -- Doro Wot (Chicken Stew) - uses niter kibbeh, berbere, onion, garlic, ginger, tomato
    IF doro_wot_id IS NOT NULL AND veg_oil_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (doro_wot_id, veg_oil_id, 2.0)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF doro_wot_id IS NOT NULL AND niter_kibbeh_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (doro_wot_id, niter_kibbeh_id, 3.0)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF doro_wot_id IS NOT NULL AND onion_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (doro_wot_id, onion_id, 2.0)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF doro_wot_id IS NOT NULL AND garlic_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (doro_wot_id, garlic_id, 1.0)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF doro_wot_id IS NOT NULL AND berbere_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (doro_wot_id, berbere_id, 2.0)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF doro_wot_id IS NOT NULL AND tomato_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (doro_wot_id, tomato_id, 1.5)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    
    -- Shiro Wot (Chickpea Stew) - uses oil, onion, garlic, berbere
    IF shiro_wot_id IS NOT NULL AND veg_oil_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (shiro_wot_id, veg_oil_id, 1.5)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF shiro_wot_id IS NOT NULL AND niter_kibbeh_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (shiro_wot_id, niter_kibbeh_id, 2.0)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF shiro_wot_id IS NOT NULL AND onion_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (shiro_wot_id, onion_id, 1.5)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF shiro_wot_id IS NOT NULL AND garlic_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (shiro_wot_id, garlic_id, 1.0)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF shiro_wot_id IS NOT NULL AND berbere_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (shiro_wot_id, berbere_id, 1.5)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    
    -- Misir Wot (Red Lentil Stew) - uses oil, onion, garlic, berbere
    IF misir_wot_id IS NOT NULL AND veg_oil_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (misir_wot_id, veg_oil_id, 1.0)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF misir_wot_id IS NOT NULL AND niter_kibbeh_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (misir_wot_id, niter_kibbeh_id, 2.0)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF misir_wot_id IS NOT NULL AND onion_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (misir_wot_id, onion_id, 2.0)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF misir_wot_id IS NOT NULL AND garlic_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (misir_wot_id, garlic_id, 1.0)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF misir_wot_id IS NOT NULL AND berbere_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (misir_wot_id, berbere_id, 1.5)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    
    -- Key Wot (Red Beef Stew) - uses niter kibbeh, berbere, onion, garlic
    IF key_wot_id IS NOT NULL AND niter_kibbeh_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (key_wot_id, niter_kibbeh_id, 3.0)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF key_wot_id IS NOT NULL AND onion_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (key_wot_id, onion_id, 2.0)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF key_wot_id IS NOT NULL AND garlic_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (key_wot_id, garlic_id, 1.0)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF key_wot_id IS NOT NULL AND berbere_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (key_wot_id, berbere_id, 2.5)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    
    -- Alicha Wot (Mild Stew) - uses less berbere, more onion and tomato
    IF alicha_wot_id IS NOT NULL AND veg_oil_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (alicha_wot_id, veg_oil_id, 2.0)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF alicha_wot_id IS NOT NULL AND onion_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (alicha_wot_id, onion_id, 3.0)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF alicha_wot_id IS NOT NULL AND garlic_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (alicha_wot_id, garlic_id, 1.0)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF alicha_wot_id IS NOT NULL AND berbere_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (alicha_wot_id, berbere_id, 1.0)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF alicha_wot_id IS NOT NULL AND tomato_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (alicha_wot_id, tomato_id, 2.0)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    
    -- Kitfo - uses niter kibbeh, mitmita, onion
    IF kitfo_id IS NOT NULL AND niter_kibbeh_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (kitfo_id, niter_kibbeh_id, 2.0)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF kitfo_id IS NOT NULL AND mitmita_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (kitfo_id, mitmita_id, 1.0)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF kitfo_id IS NOT NULL AND onion_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (kitfo_id, onion_id, 1.0)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    
    -- Tibs (Sautéed Meat) - uses niter kibbeh, onion, green pepper, tomato
    IF tibs_id IS NOT NULL AND niter_kibbeh_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (tibs_id, niter_kibbeh_id, 2.0)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF tibs_id IS NOT NULL AND onion_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (tibs_id, onion_id, 2.0)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF tibs_id IS NOT NULL AND green_pepper_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (tibs_id, green_pepper_id, 1.5)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF tibs_id IS NOT NULL AND tomato_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (tibs_id, tomato_id, 1.0)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    
    -- Yebeg Tibs (Lamb Tibs) - similar to regular tibs
    IF yebeg_tibs_id IS NOT NULL AND niter_kibbeh_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (yebeg_tibs_id, niter_kibbeh_id, 2.5)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF yebeg_tibs_id IS NOT NULL AND onion_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (yebeg_tibs_id, onion_id, 2.0)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF yebeg_tibs_id IS NOT NULL AND green_pepper_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (yebeg_tibs_id, green_pepper_id, 1.5)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF yebeg_tibs_id IS NOT NULL AND tomato_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (yebeg_tibs_id, tomato_id, 1.0)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF yebeg_tibs_id IS NOT NULL AND mitmita_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (yebeg_tibs_id, mitmita_id, 0.5)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    
    -- Firfir - uses niter kibbeh, berbere, onion, tomato
    IF firfir_id IS NOT NULL AND niter_kibbeh_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (firfir_id, niter_kibbeh_id, 1.5)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF firfir_id IS NOT NULL AND berbere_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (firfir_id, berbere_id, 1.0)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF firfir_id IS NOT NULL AND onion_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (firfir_id, onion_id, 1.0)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    IF firfir_id IS NOT NULL AND tomato_id IS NOT NULL THEN
        INSERT INTO food_item_ingredients (food_item_id, ingredient_id, quantity_grams)
        VALUES (firfir_id, tomato_id, 1.0)
        ON CONFLICT (food_item_id, ingredient_id) DO NOTHING;
    END IF;
    
END $$;

-- Verify the seed data
SELECT 
    fi.name as food_item,
    i.name as ingredient,
    fii.quantity_grams as standard_quantity
FROM food_item_ingredients fii
JOIN food_items fi ON fii.food_item_id = fi.id
JOIN ingredients i ON fii.ingredient_id = i.id
ORDER BY fi.name, i.category, i.name;

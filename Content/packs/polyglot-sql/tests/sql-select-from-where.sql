SELECT id, name, category_id, price, stock FROM product WHERE price >= 10000 AND category_id = 1
UNION ALL
SELECT id, name, category_id, price, stock FROM product WHERE price >= 10000 AND category_id = 3
ORDER BY id;

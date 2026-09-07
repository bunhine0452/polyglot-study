INSERT INTO product (id, name, category_id, price, stock)
VALUES (1, '무엇이든 노트', 1, 999, 999)
ON CONFLICT (id) DO NOTHING
RETURNING id, price, stock;

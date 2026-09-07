INSERT INTO product (id, name, category_id, price, stock)
VALUES (1, '무엇이든 노트', 1, 2000, 30),
       (11, '미니 스테이플러', NULL, 3500, 10)
ON CONFLICT (id) DO UPDATE SET
  price = excluded.price,
  stock = excluded.stock
RETURNING id, price, stock;

INSERT INTO product (id, name, category_id, price, stock)
VALUES
  (101, '모조지 노트', 1, 1200, 50),
  (102, '색종이', 1, 500, 200)
RETURNING id, name, price;

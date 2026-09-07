INSERT INTO customer (id, name, city, joined_on)
VALUES (7, '차돌박', '대구', '2024-07-01')
RETURNING id, name;

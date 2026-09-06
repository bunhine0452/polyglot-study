-- SQL 트랙이 공유하는 시드. 팩의 assets/*.sql 이 경로 사전순으로 한 데이터베이스에
-- 적용되고, 실행마다 그 사본이 클론된다 — 변경 레슨이 다른 레슨을 오염시키지 않는다.
--
-- 트랙이 요구하는 것을 의도적으로 심어 뒀다:
--   · LEFT JOIN 이 의미를 갖도록 주문이 하나도 없는 고객(5, 6)
--   · NULL 처리를 가르치도록 city·shipped_at·category_id 에 NULL
--   · GROUP BY / HAVING 이 갈리도록 고객별 주문 수를 다르게
--   · 창 함수가 재미있도록 카테고리마다 여러 상품과 가격 순위

CREATE TABLE category (
    id   INTEGER PRIMARY KEY,
    name TEXT    NOT NULL UNIQUE
);

CREATE TABLE customer (
    id        INTEGER PRIMARY KEY,
    name      TEXT    NOT NULL,
    city      TEXT,              -- NULL 가능: 도시를 안 밝힌 고객이 있다
    joined_on TEXT    NOT NULL   -- 'YYYY-MM-DD'
);

CREATE TABLE product (
    id          INTEGER PRIMARY KEY,
    name        TEXT    NOT NULL,
    category_id INTEGER,         -- NULL 가능: 분류가 안 된 상품이 있다
    price       INTEGER NOT NULL,
    stock       INTEGER NOT NULL,
    FOREIGN KEY (category_id) REFERENCES category(id)
);

CREATE TABLE "order" (
    id          INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    ordered_at  TEXT    NOT NULL,
    shipped_at  TEXT,             -- NULL 가능: 아직 배송 전인 주문
    FOREIGN KEY (customer_id) REFERENCES customer(id)
);

CREATE TABLE order_item (
    order_id   INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity   INTEGER NOT NULL,
    PRIMARY KEY (order_id, product_id),
    FOREIGN KEY (order_id)   REFERENCES "order"(id),
    FOREIGN KEY (product_id) REFERENCES product(id)
);

INSERT INTO category (id, name) VALUES
    (1, '문구'), (2, '도서'), (3, '음료');

INSERT INTO customer (id, name, city, joined_on) VALUES
    (1, '김하늘', '서울',   '2024-03-11'),
    (2, '이바다', '부산',   '2024-07-02'),
    (3, '박구름', '서울',   '2025-01-20'),
    (4, '최나무', NULL,     '2025-02-14'),
    (5, '정바람', '대전',   '2025-06-30'),
    (6, '한별빛', NULL,     '2026-01-05');

INSERT INTO product (id, name, category_id, price, stock) VALUES
    (1, '공책',       1,    3500,  40),
    (2, '스케치북',   1,    9800,  12),
    (3, '연필',       1,     800, 250),
    (4, '만년필',     1,   42000,   6),
    (5, '지우개',     1,     500, 180),
    (6, 'SQL 입문서', 2,   28000,  25),
    (7, '알고리즘',   2,   35000,   9),
    (8, '아메리카노', 3,    4100, 999),
    (9, '카페라떼',   3,    4600, 999),
    (10, '한정 굿즈', NULL, 15000,   3);

INSERT INTO "order" (id, customer_id, ordered_at, shipped_at) VALUES
    (101, 1, '2025-08-01', '2025-08-03'),
    (102, 1, '2025-09-14', '2025-09-15'),
    (103, 2, '2025-09-20', NULL),
    (104, 3, '2025-10-02', '2025-10-05'),
    (105, 1, '2025-11-11', '2025-11-13'),
    (106, 4, '2026-01-08', NULL),
    (107, 2, '2026-02-19', '2026-02-21');

INSERT INTO order_item (order_id, product_id, quantity) VALUES
    (101, 1, 2), (101, 3, 10),
    (102, 6, 1),
    (103, 8, 3), (103, 9, 2),
    (104, 4, 1), (104, 2, 1),
    (105, 7, 1), (105, 6, 1), (105, 5, 4),
    (106, 8, 1),
    (107, 10, 1), (107, 3, 5);

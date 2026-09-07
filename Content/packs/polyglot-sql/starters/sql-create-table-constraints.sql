-- 아래 CREATE TABLE 의 각 열에 제약을 붙여 완성하세요.
CREATE TABLE cafe_menu (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  kind TEXT NOT NULL,
  price INTEGER NOT NULL
);
INSERT INTO cafe_menu VALUES (1, '아메리카노', 'coffee', 4000);
INSERT INTO cafe_menu VALUES (2, '녹차라떼', 'tea', 4500);
INSERT OR IGNORE INTO cafe_menu VALUES (3, '아메리카노', 'coffee', 4000);
INSERT OR IGNORE INTO cafe_menu VALUES (4, '레몬에이드', 'ade', 0);
INSERT OR IGNORE INTO cafe_menu VALUES (5, '초코쿠키', 'snack', 2000);
SELECT id, name, kind, price FROM cafe_menu ORDER BY id;

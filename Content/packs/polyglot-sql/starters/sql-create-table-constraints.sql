-- 1) delivery 표를 만드세요.
--     id:   INTEGER PRIMARY KEY
--     city: TEXT NOT NULL
--     fee:  INTEGER NOT NULL, 0 미만인 fee 를 CHECK 로 거부
CREATE TABLE delivery (
  id INTEGER PRIMARY KEY,
  city TEXT NOT NULL,
  fee INTEGER NOT NULL
);

-- 2) 다섯 행을 순서대로 INSERT OR IGNORE 로 넣으세요.
INSERT OR IGNORE INTO delivery VALUES (1, '서울', 3000);
INSERT OR IGNORE INTO delivery VALUES (2, '부산', 2500);
-- (1, '중복', 1000)  <- 이 행을 넣는 INSERT OR IGNORE 문을 작성하세요
-- (3, '제주', -500)  <- 이 행을 넣는 INSERT OR IGNORE 문을 작성하세요
-- (3, '제주', 4900)  <- 이 행을 넣는 INSERT OR IGNORE 문을 작성하세요

-- 3) 모든 행을 id 오름차순으로 조회하세요.

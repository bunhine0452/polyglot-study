CREATE TABLE item (
    id    INTEGER PRIMARY KEY,
    kind  TEXT    NOT NULL,
    price INTEGER NOT NULL
);

INSERT INTO item (id, kind, price) VALUES
    (1, 'a', 100),
    (2, 'a', 300),
    (3, 'b', 200);

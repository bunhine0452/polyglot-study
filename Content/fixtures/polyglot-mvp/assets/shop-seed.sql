CREATE TABLE product (
    id       INTEGER PRIMARY KEY,
    name     TEXT    NOT NULL,
    category TEXT    NOT NULL,
    price    INTEGER NOT NULL,
    quantity INTEGER NOT NULL
);

INSERT INTO product (id, name, category, price, quantity) VALUES
    (1, 'notebook',   'paper',  3500,  40),
    (2, 'sketchbook', 'paper',  9800,  12),
    (3, 'pencil',     'pen',     800, 250),
    (4, 'fountain',   'pen',   42000,   6),
    (5, 'eraser',     'pen',     500, 180);

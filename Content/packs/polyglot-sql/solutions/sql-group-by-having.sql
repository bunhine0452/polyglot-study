WITH item(category, price) AS (
  VALUES
    ('book', 12000),
    ('book', 8000),
    ('book', 8000),
    ('toy', 3500),
    ('toy', 9900),
    ('pen', 1200)
)
SELECT category,
       COUNT(*) AS n,
       AVG(price) AS avg_price
FROM item
GROUP BY category
HAVING COUNT(*) >= 2
ORDER BY category;

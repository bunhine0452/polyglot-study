SELECT p.category, p.name, p.price
FROM product AS p
JOIN (
    SELECT category, MAX(price) AS top_price
    FROM product
    GROUP BY category
) AS m
  ON m.category = p.category AND m.top_price = p.price
ORDER BY p.category;

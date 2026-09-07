SELECT COUNT(*) AS product_count,
       SUM(stock) AS total_stock,
       AVG(price) AS avg_price,
       MIN(price) AS min_price,
       MAX(price) AS max_price
FROM product;

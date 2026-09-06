SELECT kind, MAX(price) AS price
FROM item
GROUP BY kind
ORDER BY kind;

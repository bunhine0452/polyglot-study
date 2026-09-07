SELECT c1.name AS name_a, c2.name AS name_b, c1.city AS city
FROM customer c1
JOIN customer c2
WHERE c1.city = c2.city
ORDER BY city, name_a, name_b

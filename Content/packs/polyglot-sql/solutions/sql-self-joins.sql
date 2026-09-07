SELECT c1.name AS name_a, c2.name AS name_b, c1.city AS city
FROM customer AS c1
JOIN customer AS c2 ON c1.city = c2.city AND c1.id < c2.id
ORDER BY city, name_a, name_b

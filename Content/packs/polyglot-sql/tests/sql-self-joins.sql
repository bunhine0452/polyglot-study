SELECT c1.name AS name_a, c2.name AS name_b, c1.city AS city
FROM customer AS c1
INNER JOIN customer AS c2 ON c1.city = c2.city AND c1.id < c2.id
WHERE c1.city IS NOT NULL
ORDER BY c1.city, c1.name, c2.name

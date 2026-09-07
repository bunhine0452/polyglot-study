SELECT id,
       UPPER(name) AS name_up,
       SUBSTR(joined_on, 1, 7) AS joined_ym,
       COALESCE(LOWER(city), '미지정') AS city_label
FROM customer
ORDER BY id;

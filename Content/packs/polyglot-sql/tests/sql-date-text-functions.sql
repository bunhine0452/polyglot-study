SELECT id,
       CAST(julianday(shipped_at) - julianday(ordered_at) AS INTEGER) AS days,
       date(ordered_at, '+7 days') AS due_date,
       CASE WHEN shipped_at > date(ordered_at, '+7 days') THEN 1 ELSE 0 END AS late
FROM "order"
WHERE shipped_at IS NOT NULL
ORDER BY id;

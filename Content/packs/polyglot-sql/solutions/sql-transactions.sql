BEGIN;
UPDATE product SET stock = stock * 2;
DELETE FROM "order" WHERE shipped_at IS NOT NULL;
UPDATE customer SET city = '알수없음' WHERE city IS NULL;
ROLLBACK;
SELECT (SELECT COUNT(*) FROM "order") AS total_orders,
       (SELECT COUNT(*) FROM "order" WHERE shipped_at IS NOT NULL) AS shipped_orders,
       (SELECT COUNT(*) FROM customer WHERE city IS NULL) AS missing_city;

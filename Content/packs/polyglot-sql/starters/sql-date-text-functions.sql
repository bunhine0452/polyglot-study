-- 배송이 완료된 주문만 대상으로 한다 (shipped_at 이 NULL 이 아니다)
-- 각 주문에 대해 다음 네 열을 계산한다:
--   days     : julianday(shipped_at) - julianday(ordered_at) 를 정수로 CAST
--   due_date : date(ordered_at, '+7 days')
--   late     : shipped_at 이 due_date 보다 늦으면 1, 아니면 0 (CASE 식)
-- id 오름차순으로 정렬한다
SELECT id,
       NULL AS days,
       NULL AS due_date,
       NULL AS late
FROM "order"
WHERE shipped_at IS NOT NULL
ORDER BY id;

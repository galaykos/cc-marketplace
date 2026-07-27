SELECT o.id, SUM(i.total) FROM orders o
JOIN items i ON i.order_id = o.id
WHERE o.created_at > NOW() - INTERVAL 30 DAY
GROUP BY o.id;

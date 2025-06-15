-- 1. What is the average percentage of people who add an item to their cart but do not pay for their order in 2023?
-- - There is no 'Add to cart' status, thus I suppose the measures could be: status of the order = cancelled and the overall number of orders in the respective year. The result: 15 %

SELECT COUNT(*) as orders_2023, 
  COUNTIF(status = 'Cancelled') as cancelled_orders,
  ROUND(COUNTIF(status = 'Cancelled') / COUNT(*), 2) AS cancelled_percentage
FROM bigquery-public-data.thelook_ecommerce.order_items
WHERE EXTRACT(YEAR FROM created_at) = 2023; 

-- 3. Which month did the e-shop have the highest ratio of canceled orders to the total number of orders created in that month?
-- - The answer is March

SELECT
  EXTRACT(MONTH FROM created_at) AS month,
  COUNTIF(status = 'Cancelled') AS cancelled,
  COUNT(DISTINCT order_id) AS total_orders, 
  ROUND(COUNTIF(status = 'Cancelled') / COUNT(DISTINCT order_id), 2) AS cancel_ratio
FROM bigquery-public-data.thelook_ecommerce.order_items
GROUP BY month
ORDER BY cancel_ratio DESC
LIMIT 1;

-- 4. Which distribution center historically delivers goods in the slowest manner?
-- - Port Authority of New York with the average delivery of 2.04 days

SELECT 
  dc.name as distribution_center_name,
  ROUND(AVG(DATE_DIFF(o.delivered_at, o.shipped_at, DAY)), 2) AS average_delivery_time_days
FROM bigquery-public-data.thelook_ecommerce.orders AS o
JOIN bigquery-public-data.thelook_ecommerce.order_items AS oi
  ON o.order_id = oi.order_id
JOIN bigquery-public-data.thelook_ecommerce.products AS p 
  ON oi.product_id = p.id
JOIN bigquery-public-data.thelook_ecommerce.distribution_centers AS dc
  ON p.distribution_center_id = dc.id
GROUP BY dc.name
ORDER BY average_delivery_time_days DESC
LIMIT 1;


-- 5. Which distribution center has the highest percentage of complaints?
-- - Memphis, 10 %

SELECT 
  dc.name as distribution_center_name,
  ROUND(SUM(CASE WHEN oi.status = 'Returned' THEN 1 ELSE 0 END) / COUNT(*), 2) AS complaint_percentage
FROM bigquery-public-data.thelook_ecommerce.orders AS o
JOIN bigquery-public-data.thelook_ecommerce.order_items AS oi
  ON o.order_id = oi.order_id
JOIN bigquery-public-data.thelook_ecommerce.products AS p 
  ON oi.product_id = p.id
JOIN bigquery-public-data.thelook_ecommerce.distribution_centers AS dc
  ON p.distribution_center_id = dc.id
GROUP BY dc.name
ORDER BY complaint_percentage DESC
LIMIT 1;

-- 10. Which category of goods and which product was the best seller in March 2020?
-- - NEW Aluminum Credit Card Wallet - RFID Blocking Case - Pink (New Products)

SELECT 
  p.name AS product_name,
  COUNT(*) AS total_sold
FROM bigquery-public-data.thelook_ecommerce.order_items AS oi
JOIN bigquery-public-data.thelook_ecommerce.products AS p 
  ON oi.product_id = p.id
WHERE DATE(oi.created_at) BETWEEN '2020-03-01' AND '2020-03-31'
  AND oi.status = 'Complete'
GROUP BY product_name
ORDER BY total_sold DESC
LIMIT 1;

-- 12. Your superior wants to start calculating the churn rate of customers, suggest a suitable calculation and calculate its development over time?
-- - assumption: a customer is considered churned if they made at least one purchase in one month but made no purchase in the following three months
-- - the number of churned customers is rising

WITH customer_monthly_orders AS (
  SELECT
    user_id,
    FORMAT_DATE('%Y-%m', created_at) AS month,
    COUNT(DISTINCT order_id) AS orders
  FROM bigquery-public-data.thelook_ecommerce.order_items
  WHERE status = 'Complete'
  GROUP BY user_id, month
),

churn_candidates AS (
  SELECT
    a.user_id,
    a.month AS active_month,
    MIN(b.month) AS next_purchase_month
  FROM customer_monthly_orders a
  LEFT JOIN customer_monthly_orders b 
    ON a.user_id = b.user_id
    AND PARSE_DATE('%Y-%m', b.month) > PARSE_DATE('%Y-%m', a.month)
    AND DATE_DIFF(PARSE_DATE('%Y-%m', b.month), PARSE_DATE('%Y-%m', a.month), MONTH) <= 3
  GROUP BY a.user_id, a.month
),

monthly_churn AS (
  SELECT
    active_month,
    COUNT(*) AS total_customers,
    COUNTIF(next_purchase_month IS NULL) AS churned_customers,
    ROUND(COUNTIF(next_purchase_month IS NULL) / COUNT(*), 2) AS churn_rate
  FROM churn_candidates
  GROUP BY active_month
  ORDER BY active_month
)

SELECT * 
FROM monthly_churn;

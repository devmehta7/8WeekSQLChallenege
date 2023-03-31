SET search_path = pizza_runner;

-- SELECTING TABLES
SELECT * 
FROM customer_orders;

SELECT * 
FROM pizza_names;

SELECT * 
FROM pizza_recipes;

SELECT * 
FROM pizza_toppings;

SELECT * 
FROM runner_orders;

SELECT * 
FROM runners;

-- CLEANING TABLE - customer_orders:
CREATE TEMP TABLE customer_orders_cleaned
AS SELECT * FROM customer_orders;

SELECT * FROM customer_orders_cleaned;

UPDATE customer_orders_cleaned SET extras = null 
WHERE extras IN ('null', '');

UPDATE customer_orders_cleaned SET exclusions = null 
WHERE exclusions IN ('null', '');

ALTER TABLE customer_orders_cleaned
ALTER COLUMN order_time TYPE timestamp
USING order_time :: timestamp

-- CLEANING TABLE - runner_orders:

CREATE TEMP TABLE runner_orders_cleaned
AS SELECT * FROM runner_orders;

SELECT * FROM runner_orders_cleaned;

UPDATE runner_orders_cleaned SET cancellation = null 
WHERE cancellation IN ('null', '') OR cancellation is null; 

UPDATE runner_orders_cleaned SET duration= null
WHERE duration = 'null';

UPDATE runner_orders_cleaned SET duration= LEFT(duration,2);

UPDATE runner_orders_cleaned SET distance = null
WHERE distance = 'null';

UPDATE runner_orders_cleaned SET distance = REPLACE(distance, 'km', '');

UPDATE runner_orders_cleaned SET pickup_time = null
WHERE pickup_time = 'null'; 

ALTER TABLE runner_orders_cleaned
ALTER COLUMN pickup_time TYPE timestamp
USING pickup_time :: timestamp


-- A. Pizza Metrics

-- 1. How many pizzas were ordered?
-- NOTE: customer_orders table with 1 row for each individual pizza that is part of the order

SELECT COUNT(pizza_id)
FROM customer_orders;

-- 2. How many unique customer orders were made?
SELECT COUNT(*) AS "unique customer orders"
FROM(
	SELECT order_id, customer_id
	FROM customer_orders
	GROUP BY order_id, customer_id
	) t;

-- 3. How many successful orders were delivered by each runner?

SELECT *
FROM runner_orders_cleaned
WHERE cancellation is null;

-- 4. How many of each type of pizza was delivered?
-- select count of pizza delived group by pizza id

SELECT pizza_id, COUNT(pizza_id) as "pizza delivered"
FROM runner_orders_cleaned
JOIN customer_orders USING(order_id)
GROUP BY pizza_id;

-- 5. How many Vegetarian and Meatlovers were ordered by each customer?

SELECT customer_id, pizza_name, COUNT(*) as "pizza delivered"
FROM runner_orders_cleaned
JOIN customer_orders USING(order_id)
JOIN pizza_names USING(pizza_id)
GROUP BY customer_id, pizza_name
ORDER BY customer_id;

-- 6. What was the maximum number of pizzas delivered in a single order?

SELECT order_id, COUNT(*)
FROM customer_orders
GROUP BY order_id
ORDER BY COUNT(*) DESC
FETCH FIRST 1 ROW ONLY;

-- 7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?

SELECT 
	customer_id, 
	SUM
	(
		CASE
		WHEN exclusions IS NOT NULL OR extras IS NOT NULL THEN
			1
		ELSE
			0
		END
	) AS changes_count,
	SUM
	(
		CASE
		WHEN exclusions IS NULL AND extras IS NULL THEN
			1
		ELSE
			0
		END
	) AS no_changes	
FROM customer_orders_cleaned c
JOIN runner_orders_cleaned r ON r.order_id = c.order_id AND r.cancellation IS NULL
GROUP BY customer_id;

-- 8. How many pizzas were delivered that had both exclusions and extras?

SELECT COUNT(*)
FROM customer_orders_cleaned
JOIN runner_orders_cleaned USING(order_id)
WHERE cancellation IS NULL AND exclusions IS NOT NULL AND extras IS NOT NULL

-- 9. What was the total volume of pizzas ordered for each hour of the day?

SELECT EXTRACT(HOUR FROM order_time) AS hour_of_day, COUNT(*) AS volume
FROM runner_orders_cleaned
JOIN customer_orders_cleaned USING(order_id)
GROUP BY EXTRACT(HOUR FROM order_time)
ORDER BY EXTRACT(HOUR FROM order_time);

-- 10. What was the volume of orders for each day of the week?
-- Day of week based on ISO 8601 Monday (1) to Sunday (7)

SELECT EXTRACT(ISODOW FROM order_time) AS day_of_week, COUNT(*) AS volume
FROM runner_orders_cleaned
JOIN customer_orders_cleaned USING(order_id)
GROUP BY EXTRACT(ISODOW FROM order_time)
ORDER BY EXTRACT(ISODOW FROM order_time);


-- B. Runner and Customer Experience

-- 1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)

SELECT DATE_PART('WEEK', registration_date), COUNT(*)
FROM runners
GROUP BY DATE_PART('WEEK', registration_date);

-- 2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?

SELECT runner_id, AVG(EXTRACT(EPOCH FROM (pickup_time - order_time))/60) AS minutes 
FROM customer_orders_cleaned
JOIN runner_orders_cleaned USING(order_id)
GROUP BY runner_id;

-- 3. Is there any relationship between the number of pizzas and how long the order takes to prepare?

SELECT c.order_id, EXTRACT(EPOCH FROM (pickup_time - order_time))/60 AS minutes, COUNT(pizza_id) OVER(PARTITION BY c.order_id) AS no_of_pizza
FROM customer_orders_cleaned c
JOIN runner_orders_cleaned r ON c.order_id=r.order_id AND cancellation IS NULL
ORDER BY minutes DESC

-- 4. What was the average distance travelled for each customer?

SELECT customer_id, avg(distance :: numeric)
FROM runner_orders_cleaned
JOIN customer_orders_cleaned USING(order_id)
GROUP BY customer_id

-- 5. What was the difference between the longest and shortest delivery times for all orders?

SELECT  MAX(EXTRACT(EPOCH FROM (pickup_time - order_time))/60) - MIN(EXTRACT(EPOCH FROM (pickup_time - order_time))/60) AS difference
FROM customer_orders_cleaned
JOIN runner_orders_cleaned USING(order_id);

-- 6. What was the average speed for each runner for each delivery and do you notice any trend for these values?


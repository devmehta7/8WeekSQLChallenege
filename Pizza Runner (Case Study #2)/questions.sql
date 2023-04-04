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

-- pizza_recipes cleaning
DROP TABLE IF EXISTS pizza_recipes_mapped;
CREATE TEMP TABLE pizza_recipes_mapped AS
select pr.pizza_id, pizza_name, toppings, topping_name from
(select pizza_id, unnest(string_to_array(toppings,','))::numeric as toppings 
from pizza_recipes) pr
JOIN pizza_toppings pt ON pt.topping_id = pr.toppings
JOIN pizza_names pn ON pn.pizza_id = pr.pizza_id
ORDER BY pizza_id, topping_name;

SELECT * FROM pizza_recipes_mapped;
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
USING order_time :: timestamp;


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
USING pickup_time :: timestamp;

ALTER TABLE runner_orders_cleaned
ALTER COLUMN distance TYPE numeric
USING distance :: numeric;

ALTER TABLE runner_orders_cleaned
ALTER COLUMN duration TYPE int
USING duration :: int;

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

SELECT distinct c.order_id, EXTRACT(EPOCH FROM (pickup_time - order_time))/60 AS minutes, COUNT(pizza_id) OVER(PARTITION BY c.order_id) AS no_of_pizza
FROM customer_orders_cleaned c
JOIN runner_orders_cleaned r ON c.order_id=r.order_id AND cancellation IS NULL
ORDER BY minutes DESC;

-- 4. What was the average distance travelled for each customer?

SELECT customer_id, avg(distance :: numeric)
FROM runner_orders_cleaned
JOIN customer_orders_cleaned USING(order_id)
GROUP BY customer_id;

-- 5. What was the difference between the longest and shortest delivery times for all orders?

SELECT  MAX(EXTRACT(EPOCH FROM (pickup_time - order_time))/60) - MIN(EXTRACT(EPOCH FROM (pickup_time - order_time))/60) AS difference
FROM customer_orders_cleaned
JOIN runner_orders_cleaned USING(order_id);

-- 6. What was the average speed for each runner for each delivery and do you notice any trend for these values?

SELECT 
		order_id, 
		round((distance/(duration::numeric/60)),2) as order_speed, 
		AVG(ROUND(distance/(duration::numeric/60),2)) OVER(PARTITION BY runner_id) AS runner_average,
		EXTRACT(HOUR FROM order_time) AS hour_of_day
FROM runner_orders_cleaned
JOIN customer_orders_cleaned USING(order_id); 

-- 7. What is the successful delivery percentage for each runner?

SELECT runner_id, (count(order_id)-count(cancellation))/count(order_id)::numeric * 100 as success_del_perc
FROM runner_orders_cleaned
GROUP BY runner_id;

SELECT *
from runner_orders_cleaned;

-- C. Ingredient Optimisation

-- 1. What are the standard ingredients for each pizza?

SELECT pizza_name, STRING_AGG(topping_name, ', ')
FROM pizza_recipes_mapped pr
JOIN pizza_toppings pt ON pr.toppings = pt.topping_id
JOIN pizza_names pn ON pn.pizza_id = pr.pizza_id
GROUP BY pizza_name;


-- 2. What was the most commonly added extra?

SELECT topping_name, count(*)
FROM
	(select UNNEST(STRING_TO_ARRAY(extras,',')) :: numeric AS extra
	from customer_orders_cleaned) co
JOIN pizza_toppings pz ON co.extra = pz.topping_id
GROUP BY topping_name
ORDER BY count DESC
LIMIT 1;

-- 3. What was the most common exclusion?

SELECT topping_name, count(*)
FROM
	(select UNNEST(STRING_TO_ARRAY(exclusions,',')) :: numeric AS exclusion
	from customer_orders_cleaned) co
JOIN pizza_toppings pz ON co.exclusion = pz.topping_id
GROUP BY topping_name
ORDER BY count DESC
LIMIT 1;

-- 4. Generate an order item for each record in the customers_orders table in the format of one of the following:
-- Meat Lovers
-- Meat Lovers - Exclude Beef
-- Meat Lovers - Extra Bacon
-- Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers

WITH cte
AS
(SELECT order_id, pizza_name, UNNEST(STRING_TO_ARRAY(exclusions,',')) :: numeric AS exclusion, UNNEST(STRING_TO_ARRAY(extras,',')) :: numeric AS extra  
	FROM customer_orders_cleaned co
	JOIN pizza_names pn ON pn.pizza_id = co.pizza_id),
cte_2 AS
(SELECT 
	order_id,
	pizza_name,
	string_agg(pt1.topping_name, ', ') AS exclusion,
	string_agg(pt2.topping_name, ', ') AS extra
FROM cte 
left JOIN pizza_toppings pt1 ON pt1.topping_id = cte.exclusion
left join  pizza_toppings pt2 ON pt2.topping_id = cte.extra
GROUP BY cte.order_id, pizza_name),
cte_3 AS
(
	select order_id, pizza_name, exclusion, extra from cte_2
	UNION
	SELECT order_id, pizza_name, exclusions, extras 
	FROM customer_orders_cleaned co
	JOIN pizza_names pn ON pn.pizza_id = co.pizza_id
	WHERE exclusions IS NULL AND extras IS NULL
)
select 
	order_id,
	CASE
		WHEN exclusion IS NOT NULL AND extra IS NOT NULL THEN
			CONCAT(pizza_name, ' - ','Exclude ', exclusion, ' - ', 'Extra ', extra)
		WHEN exclusion IS NULL AND extra IS NOT NULL THEN
			CONCAT(pizza_name, ' - ','Extra ', extra)
		WHEN exclusion IS NOT NULL AND extra IS NULL THEN
			CONCAT(pizza_name, ' - ','Exclude ', exclusion)
		ELSE
			CONCAT(pizza_name)
	END	AS "order item"
from cte_3;


-- 5. Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients
-- For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"
DROP TABLE customer_orders_ingredients_array;
CREATE TEMP TABLE customer_orders_ingredients_array
AS
WITH cte
AS
	(SELECT ROW_NUMBER() OVER(ORDER BY co.pizza_id) AS id, 
	 	order_id,
	 	co.pizza_id,
	 	pizza_name, 
 		UNNEST(STRING_TO_ARRAY(exclusions,',')) :: numeric AS exclusion, 
	 	UNNEST(STRING_TO_ARRAY(extras,',')) :: numeric AS extra  
		FROM customer_orders_cleaned co
		JOIN pizza_names pn ON pn.pizza_id = co.pizza_id),
cte_2 AS
(SELECT 
	order_id,
 	pizza_id,
	pizza_name,
	string_agg(pt1.topping_name, ', ') AS exclusion,
	string_agg(pt2.topping_name, ', ') AS extra
FROM cte 
left JOIN pizza_toppings pt1 ON pt1.topping_id = cte.exclusion
left join  pizza_toppings pt2 ON pt2.topping_id = cte.extra
GROUP BY id,order_id,pizza_id,pizza_name),
cte_3
AS
(select order_id, pizza_id, pizza_name, STRING_TO_ARRAY(exclusion, ', ') exclusions , STRING_TO_ARRAY(extra, ', ') extras from cte_2
UNION
SELECT order_id, co.pizza_id, pizza_name, STRING_TO_ARRAY(exclusions,', '), STRING_TO_ARRAY(extras,', ') 
FROM customer_orders_cleaned co
JOIN pizza_names pn ON pn.pizza_id = co.pizza_id
WHERE exclusions IS NULL AND extras IS NULL)
	SELECT *
	FROM cte_3;

	
SELECT 
	pizza_id,
	STRING_TO_ARRAY(STRING_AGG(topping_name, ', '),', ') AS recipes
from
	pizza_recipes_mapped
GROUP BY pizza_id;
	
SELECT order_id, co.pizza_id, pizza_name, pr1.topping_name as exclusions, pr2.topping_name as extras
FROM
	(SELECT order_id, pizza_id, UNNEST(STRING_TO_ARRAY(exclusions,',')) :: numeric AS exclusion, UNNEST(STRING_TO_ARRAY(extras,',')) :: numeric AS extra  
		FROM customer_orders_cleaned) co
LEFT JOIN pizza_recipes_mapped pr1 ON pr1.toppings = exclusion
LEFT JOIN pizza_recipes_mapped pr2 ON pr2.toppings = extra
JOIN pizza_names pn ON pn.pizza_id = co.pizza_id


		
SELECT * FROM customer_orders_cleaned;
SELECT * FROM customer_orders_ingredients_array;
SELECT * FROM pizza_recipes_mapped;


-- 6. What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?

SELECT pizza_id
FROM customer_orders_cleaned co
JOIN runner_orders_cleaned ro ON ro.order_id = co.order_id 
WHERE cancellation IS NULL;

SELECT * FROM pizza_recipes_mapped


-- D. Pricing and Ratings

-- 1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes 
-- - how much money has Pizza Runner made so far if there are no delivery fees?
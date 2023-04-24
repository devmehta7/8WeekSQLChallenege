----------------------
-- 2. Digital Analysis
----------------------


--1. How many users are there?

SELECT DISTINCT user_id FROM users ORDER BY user_id;

-- 2. How many cookies does each user have on average?

WITH cte
AS
(
	SELECT
		user_id,
		COUNT(cookie_id) AS total_cookies
	FROM	
		users
	GROUP BY 
		user_id
)
SELECT 
	AVG(total_cookies) AS average_cookie_per_user
FROM
	cte

--3. What is the unique number of visits by all users per month?

SELECT TOP 10* FROM events;
GO

SELECT
	
	DATEPART(MONTH, event_time) AS month,
	COUNT(DISTINCT visit_id) AS visit_count
FROM
	users
JOIN
	events 
	ON users.cookie_id = events.cookie_id
GROUP BY 
	DATEPART(MONTH, event_time)
ORDER BY 
	month;

-- 4. What is the number of events for each event type?

SELECT TOP 50 * FROM events;

SELECT 
	event_name,
	COUNT(*) AS no_of_events
FROM
	events e
JOIN 
	event_identifier ei ON ei.event_type = e.event_type
GROUP BY event_name;
GO

-- 5. What is the percentage of visits which have a purchase event?

SELECT TOP 50 * FROM events;

WITH cte
AS
(
	SELECT
		DISTINCT visit_id
	FROM
		events e
	JOIN
		event_identifier ei ON ei.event_type = e.event_type
	WHERE 
		event_name = 'Purchase'
)
SELECT 
	ROUND(100.0 * COUNT(visit_id)/(SELECT COUNT(DISTINCT visit_id) FROM events),2) AS purchase_visit_perc
FROM
	cte;
GO

-- 6. What is the percentage of visits which view the checkout page but do not have a purchase event?

SELECT TOP 50 * FROM events;
SELECT TOP 50 * FROM page_hierarchy;

WITH cte
AS
(
-- CTE QUERY WILL SHOW RESULT THAT VISITS WHICH ARE VISITED CHECKOUT PAGE AND DOEESNOT HAVE PURCHASE EVENT.
	SELECT 
		DISTINCT visit_id,
		page_name,
		event_name
	FROM
		events e
	JOIN
		page_hierarchy ph ON ph.page_id = e.page_id
	JOIN
		event_identifier ei ON ei.event_type = e.event_type
	WHERE 
		page_name = 'Checkout' AND visit_id NOT IN (SELECT DISTINCT visit_id FROM events WHERE event_type = 3)
)
SELECT 
	ROUND(100.0 * COUNT(visit_id)/(SELECT COUNT(DISTINCT visit_id) FROM events WHERE page_id = 12),2) AS purchase_visit_perc
FROM
	cte;
GO

-- 7. What are the top 3 pages by number of views?

SELECT TOP 50 * FROM page_hierarchy;
SELECT TOP 50 * FROM events;
SELECT TOP 50 * FROM event_identifier;

SELECT 
	page_name,
	COUNT(*) AS no_of_page_view
FROM
	events e
JOIN 
	page_hierarchy ph ON e.page_id = ph.page_id
WHERE
	event_type=1
GROUP BY 
	page_name
ORDER BY 
	no_of_page_view DESC
OFFSET 0 ROWS
FETCH FIRST 3 ROWS ONLY;

-- 8. What is the number of views and cart adds for each product category?

SELECT TOP 50 * FROM page_hierarchy;
SELECT TOP 50 * FROM events;
SELECT TOP 50 * FROM event_identifier;

--WITH cte
--AS
--(
--	SELECT 
--		product_category,
--		COUNT(*) AS total_add_to_cart
--	FROM	
--		events e
--	JOIN 
--		event_identifier ei ON ei.event_type = e.event_type
--	JOIN 
--		page_hierarchy ph ON ph.page_id = E.page_id
--	WHERE 
--		event_name = 'Add to Cart' AND product_category IS NOT NULL
--	GROUP BY 
--		product_category
--),
--cte_2
--AS
--(
--	SELECT 
--		product_category,
--		COUNT(*) AS total_views
--	FROM	
--		events e
--	JOIN 
--		event_identifier ei ON ei.event_type = e.event_type
--	JOIN 
--		page_hierarchy ph ON ph.page_id = E.page_id
--	WHERE 
--		event_name = 'Page View' AND product_category IS NOT NULL
--	GROUP BY 
--		product_category
--)
--SELECT 
--	cte.product_category,
--	total_views,
--	total_add_to_cart
--FROM
--	cte 
--JOIN
--	cte_2 ON cte.product_category = cte_2.product_category


-- My approach was not efficient instead below query just traverse once 
SELECT
	product_category,
  SUM(
    CASE
      WHEN event_name = 'Page View' THEN 1
      ELSE 0
    END
  ) AS number_of_page_views,
  SUM(
    CASE
      WHEN event_name = 'Add to Cart' THEN 1
      ELSE 0
    END
  ) AS number_of_add_to_cart_events
FROM
  events AS e
  JOIN page_hierarchy AS pe ON e.page_id = pe.page_id
  JOIN event_identifier AS ei ON e.event_type = ei.event_type
WHERE
	product_category IS NOT NULL
GROUP BY
	product_category
ORDER BY
	product_category

-- 9. What are the top 3 products by purchases?

SELECT TOP 50 * FROM page_hierarchy;
SELECT TOP 50 * FROM events;
SELECT TOP 50 * FROM event_identifier; 

--WITH cte
--AS
--(
--	SELECT
--		DISTINCT visit_id
--	FROM
--		events
--	WHERE
--		event_type = 3
--)
--select
--	page_name,
--	COUNT(DISTINCT e.visit_id) AS top_products_by_purchases
--from cte c
--join events e on c.visit_id=e.visit_id
--join page_hierarchy ph on ph.page_id = e.page_id AND product_category IS NOT NULL	
--GROUP BY 
--	page_name
--ORDER BY 
--	top_products_by_purchases DESC

-- the question was not clear. below is the query with suitable assumptions.

WITH cte
AS
(
SELECT
    page_name,
    event_name,
    COUNT(event_name) AS number_of_purchases
FROM
    events AS e
    JOIN page_hierarchy AS pe ON e.page_id = pe.page_id
    JOIN event_identifier AS ei ON e.event_type = ei.event_type
WHERE
    visit_id in (
    SELECT
        distinct visit_id
    FROM
        events AS ee
    WHERE
        event_type = 3
    )
    AND product_id > 0
    AND event_name = 'Add to Cart'
GROUP BY
    page_name,
    event_name
)
SELECT 
	page_name,
	number_of_purchases
FROM
	cte
ORDER BY
	number_of_purchases DESC
OFFSET 0 ROWS
FETCH FIRST 3 ROWS ONLY;

-----------------------------
-- 3. Product Funnel Analysis
-----------------------------
--Using a single SQL query - create a new output table which has the following details:

--How many times was each product viewed?
--How many times was each product added to cart?
--How many times was each product added to a cart but not purchased (abandoned)?
--How many times was each product purchased?


SELECT TOP 50 * FROM page_hierarchy;
SELECT TOP 50 * FROM events;
SELECT TOP 50 * FROM event_identifier; 

WITH cte
AS
(
	SELECT
		visit_id,
		page_name,
		product_category,
		event_name
	FROM
		events AS e
		JOIN page_hierarchy AS pe ON e.page_id = pe.page_id
		JOIN event_identifier AS ei ON e.event_type = ei.event_type
	GROUP BY
		visit_id,
		page_name,
		product_category,
		event_name
),
view_and_cart
AS
(
SELECT 
	page_name,
	SUM(CASE WHEN event_name = 'Page View' THEN 1 ELSE 0 END) AS product_views,
	SUM(CASE WHEN event_name = 'Add to Cart' THEN 1 ELSE 0 END) AS product_added_to_cart
FROM
	cte
WHERE 
	product_category IS NOT NULL
GROUP BY 
	page_name
),
purchases
AS
(
	SELECT
		 page_name,
		 COUNT(*) AS total_purchases  
	FROM 
		cte
	WHERE
		visit_id in (
		SELECT
			distinct visit_id
		FROM
			events AS ee
		WHERE
			event_type = 3
		) AND
		event_name = 'Add to Cart'
	GROUP BY 
		page_name
)
SELECT
		 c.page_name,
		 product_views,
		 product_added_to_cart,
		 COUNT(*) AS total_abandoned_carts,
		 total_purchases
	INTO product_stats
	FROM 
		cte c
	JOIN
		purchases p ON p.page_name = c.page_name
	JOIN
		view_and_cart vc ON vc.page_name = c.page_name
	WHERE
		visit_id NOT IN (
		SELECT
			distinct visit_id
		FROM
			events AS ee
		WHERE
			event_type = 3
		) AND
		event_name = 'Add to Cart'
	GROUP BY 
		c.page_name,
		product_views,
		product_added_to_cart,
		total_purchases
	ORDER BY 
		C.page_name;

 --Additionally, create another table which further aggregates the data for the above points but this time for each product category instead of individual products.
 
SELECT 
	product_category,
	SUM(product_views) AS product_views,
	SUM(product_added_to_cart) AS product_added_to_cart,
	SUM(total_abandoned_carts) AS total_abandoned_carts,
	SUM(total_purchases) AS total_purchases
INTO product_category_stats
FROM
	product_stats ps
JOIN page_hierarchy pe ON ps.page_name = pe.page_name
GROUP BY
  product_category
ORDER BY
	product_category;

SELECT * FROM product_category_stats;
SELECT * FROM product_stats;

-- 1. Which product had the most views, cart adds and purchases?

WITH cte
AS
(
	SELECT 
		*,
		ROW_NUMBER() OVER(ORDER BY product_views DESC) AS views,
		ROW_NUMBER() OVER(ORDER BY product_added_to_cart DESC) AS add_to_cart,
		ROW_NUMBER() OVER(ORDER BY total_purchases DESC) AS purchases
	FROM
		product_stats
)
SELECT 
	page_name AS product,
	product_views,
	product_added_to_cart,
	total_purchases
FROM
	cte
WHERE
	views = 1 OR add_to_cart = 1 OR purchases = 1;

-- 2. Which product was most likely to be abandoned?

SELECT
	TOP 1
	page_name AS product,
	total_abandoned_carts
FROM
	product_stats
ORDER BY 
	total_abandoned_carts DESC;

-- 3. Which product had the highest view to purchase percentage?

SELECT * FROM product_stats;

SELECT 
	TOP 1
	page_name AS product,
	(total_purchases * 100.0 /product_views) AS view_to_purchase_perc
FROM	
	product_stats
ORDER BY 
	view_to_purchase_perc DESC;

-- 4. What is the average conversion rate from view to cart add?

SELECT 
	AVG((product_added_to_cart * 100.0 /product_views)) AS view_to_cart_add_perc
FROM	
	product_stats;

-- 5. What is the average conversion rate from cart add to purchase?


SELECT 
	AVG((total_purchases * 100.0 /product_added_to_cart)) AS view_to_cart_add_perc
FROM	
	product_stats;

-----------------------
--3. Campaigns Analysis
-----------------------	
select * from events;
select * from event_identifier;

WITH cte
AS
(
	SELECT
		DISTINCT
		user_id,
		e.cookie_id,
		visit_id,
		--event_type,
		FIRST_VALUE(event_time) OVER(PARTITION BY visit_id ORDER BY event_time) AS visit_start_time
	FROM
		events e
	JOIN
		users u ON e.cookie_id = u.cookie_id
),
event_agg
AS
(
	SELECT 
		visit_id,
		SUM
			(CASE 
				WHEN event_name = 'Page View' THEN 1 ELSE 0
			END) AS page_views,
		SUM
			(CASE 
				WHEN event_name = 'Add to Cart' THEN 1 ELSE 0
			END) AS cart_adds,
		SUM
			(CASE 
				WHEN event_name = 'Ad Impression' THEN 1 ELSE 0
			END) AS impression,
		SUM
			(CASE 
				WHEN event_name = 'Ad Click' THEN 1 ELSE 0
			END) AS click
	FROM
		events e
	JOIN
		event_identifier ei ON ei.event_type = e.event_type
	GROUP BY
		visit_id
),
purchase
AS
(
	SELECT 
		DISTINCT visit_id,
		1 AS purchase
	FROM
		events
	WHERE
		visit_id IN (
			SELECT 
				visit_id
			FROM
				events
			WHERE
				event_type = 3
		)
)
select
	user_id,
	cte.visit_id,
	visit_start_time,
	page_views,
	cart_adds,
	COALESCE(purchase, 0) AS purchase,
	campaign_name,
	impression,
	click
FROM
	cte
JOIN
	event_agg eg ON eg.visit_id = cte.visit_id
LEFT JOIN
	purchase p ON p.visit_id = cte.visit_id
LEFT JOIN 
	campaign_identifier ci ON cte.visit_start_time BETWEEN ci.start_date AND ci.end_date
ORDER BY 
	user_id, visit_start_time;


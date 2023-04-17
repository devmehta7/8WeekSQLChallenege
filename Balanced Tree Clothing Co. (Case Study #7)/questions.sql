---------------------------
--High Level Sales Analysis
---------------------------

-- 1. What was the total quantity sold for all products?

SELECT SUM(qty) AS total_qty 
FROM sales;

-- 2. What is the total generated revenue for all products before discounts?

SELECT * FROM product_prices;
SELECT * FROM product_details;
SELECT * FROM sales;

SELECT SUM(price*qty) AS total_revenue
FROM sales;

-- 3. What was the total discount amount for all products?

SELECT 
	SUM((qty*price*0.01*discount)) AS discount_amt
FROM
	sales;

-----------------------
-- Transaction Analysis
-----------------------

-- 1. How many unique transactions were there?

SELECT COUNT(DISTINCT txn_id) AS unique_transactions FROM sales;

-- 2. What is the average unique products purchased in each transaction?

SELECT * FROM sales;

WITH cte 
AS
(
	SELECT 
		txn_id,
		COUNT(prod_id) AS uniq_prod
	FROM
		sales
	GROUP BY 
		txn_id
)
SELECT 
	AVG(uniq_prod) avg_unique_product_per_transction
FROM 
	cte;

-- 3. What are the 25th, 50th and 75th percentile values for the revenue per transaction?

WITH cte
AS
(
	select
		txn_id,
		sum(qty*price*0.01*(100-discount)) as revenue_per_transaction
	FROM
		sales
	GROUP BY 
		txn_id
)
SELECT
	DISTINCT
	PERCENTILE_CONT(0.25) WITHIN GROUP(ORDER BY revenue_per_transaction) OVER() AS percentile_25,
	PERCENTILE_CONT(0.50) WITHIN GROUP(ORDER BY revenue_per_transaction) OVER() AS percentile_50,
	PERCENTILE_CONT(0.75) WITHIN GROUP(ORDER BY revenue_per_transaction) OVER() AS percentile_75
FROM
	cte;

-- 4. What is the average discount value per transaction?

SELECT * FROM sales;

WITH cte
AS
(
	SELECT 
		txn_id,
		SUM(discount*0.01*price*qty) AS discount_per_transaction
	FROM
		sales
	GROUP BY
		txn_id
)
SELECT 
	AVG(discount_per_transaction) avg_discount_per_transaction
FROM
	cte;

-- 5. What is the percentage split of all transactions for members vs non-members?

SELECT * FROM sales;


SELECT
	SUM(CASE 
			WHEN member = 't' THEN 1 ELSE 0 END)*100.0/
			count(*) AS member_percentage,
	SUM(CASE
		WHEN member = 'F' THEN 1 ELSE 0 END)*100.0/
				count(*) AS non_member_percentage 
		
FROM
	(SELECT
		txn_id,
		member
	FROM	
		sales
	GROUP BY 
		txn_id,
		member) t;

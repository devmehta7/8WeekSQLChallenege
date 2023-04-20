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

-- I thought below query will be more efficient compare to query above but both got same cost in relative batch
--WITH cte
--AS
--(
--	SELECT
--		SUM(CASE 
--				WHEN member = 't' THEN 1 ELSE 0 END) AS member,
--		count(*) AS total_customer,
--		SUM(CASE
--			WHEN member = 'F' THEN 1 ELSE 0 END) AS non_member
--	FROM
--		(SELECT
--			txn_id,
--			member
--		FROM	
--			sales
--		GROUP BY 
--			txn_id,
--			member) t
--)
--SELECT 
--	member * 100.0/total_customer AS member_percentage,
--	non_member * 100.0/total_customer AS non_member_percentage 
--FROM
--	cte;

-- 6. What is the average revenue for member transactions and non-member transactions?

WITH cte
AS
(
	SELECT 
		txn_id,
		CASE 
			WHEN member = 't' THEN 'member' ELSE 'non_member' END AS customer,
		SUM(qty*price) AS revenue
	FROM sales
	GROUP BY 
		txn_id,
		member
)
SELECT 
	customer,
	AVG(revenue) AS average_revenue
FROM
	cte
GROUP BY
	customer;

-------------------
-- Product Analysis
-------------------

-- 1. What are the top 3 products by total revenue before discount?

SELECT
	product_name,
	amount
FROM
	product_details
JOIN
(SELECT
	TOP 3
	prod_id,
	SUM(qty * price) AS amount
FROM
	sales
GROUP BY 
	prod_id
ORDER BY
	amount DESC) t ON t.prod_id =product_details.product_id
ORDER BY 
	amount DESC;

-- 2. What is the total quantity, revenue and discount for each segment?

SELECT * FROM sales;
SELECT * FROM product_details;

SELECT 
	segment_name,
	SUM(qty) AS total_quantity,
	SUM(qty * s.price) AS revenue,
	SUM(qty * discount *0.01 * s.price) AS total_discount
FROM
	sales s
JOIN 
	product_details pd ON s.prod_id = pd.product_id
GROUP BY
	segment_name;

-- 3. What is the top selling product for each segment?

WITH cte
AS
(
	SELECT
		segment_name,
		product_name,
		SUM(qty) as qty_sold,
		DENSE_RANK() OVER(PARTITION BY segment_name ORDER BY SUM(qty) DESC) AS rnk
	FROM
		sales s
	JOIN 
		product_details pd ON s.prod_id = pd.product_id
	GROUP BY 
		segment_name, product_name
)
SELECT
	segment_name,
	product_name,
	qty_sold,
	rnk
FROM
	cte
WHERE
	rnk = 1;

-- 4. What is the total quantity, revenue and discount for each category?

SELECT * FROM sales;
SELECT * FROM product_details;

SELECT 
	category_name,
	SUM(qty) AS total_quantity,
	SUM(qty * s.price) AS revenue,
	SUM(qty * discount *0.01 * s.price) AS total_discount
FROM
	sales s
JOIN 
	product_details pd ON s.prod_id = pd.product_id
GROUP BY
	category_name;

-- 5. What is the top selling product for each category?

WITH cte
AS
(
	SELECT
		category_name,
		product_name,
		SUM(qty) as qty_sold,
		ROW_NUMBER() OVER(PARTITION BY category_name ORDER BY COUNT(qty) DESC) AS rnk
	FROM
		sales s
	JOIN 
		product_details pd ON s.prod_id = pd.product_id
	GROUP BY 
		category_name, product_name
)
SELECT
	category_name,
	product_name,
	qty_sold
FROM
	cte
WHERE
	rnk = 1;

-- 6. What is the percentage split of revenue by product for each segment?

WITH cte
AS
(
	SELECT
		segment_name,
		product_name,
		SUM(qty * s.price) AS revenue
	FROM
		sales s
	JOIN 
		product_details pd ON s.prod_id = pd.product_id
	GROUP BY 
		ROLLUP(segment_name, product_name)
)
SELECT 
	c1.segment_name,
	c1.product_name,
	CAST(c1.revenue*100.0/c2.revenue AS NUMERIC(5,2)) AS segment_perc
FROM 
	cte	c1
JOIN
	cte c2 ON c1.segment_name = c2.segment_name AND c2.product_name IS NULL
WHERE 
	c1.product_name IS NOT NULL
ORDER BY
	segment_name,
	segment_perc DESC;

-- 7. What is the percentage split of revenue by segment for each category?

SELECT * FROM product_details;
	
WITH cte
AS
(
	SELECT
		category_name,
		segment_name,
		SUM(qty * s.price) AS revenue
	FROM
		sales s
	JOIN 
		product_details pd ON s.prod_id = pd.product_id
	GROUP BY 
		ROLLUP(category_name, segment_name)
)
SELECT 
	c1.category_name,
	c1.segment_name,
	CAST(c1.revenue*100.0/c2.revenue AS NUMERIC(5,2)) AS category_perc
FROM 
	cte	c1
JOIN
	cte c2 ON c1.category_name = c2.category_name AND c2.segment_name IS NULL
WHERE 
	c1.segment_name IS NOT NULL
ORDER BY
	category_name,
	category_perc DESC;

-- 8. What is the percentage split of total revenue by category?

WITH cte
AS
(
	SELECT
		category_name,
		SUM(qty*s.price) AS revenue
	FROM
		sales s
	JOIN 
		product_details pd ON s.prod_id = pd.product_id
	GROUP BY 
		ROLLUP(category_name)
)
SELECT 
	c1.category_name,
	CAST(ROUND(c1.revenue * 100.0 / c2.revenue, 2) AS NUMERIC(5,2)) AS revenue_perc
FROM 
	cte	c1
JOIN
	cte c2 ON c2.category_name IS NULL
WHERE 
	c1.category_name IS NOT NULL;

-- 9. What is the total transaction “penetration” for each product? 
-- (hint: penetration = number of transactions where at least 1 quantity of a product was purchased divided by total number of transactions)

SELECT * FROM sales;

WITH cte
AS
(
	SELECT
		txn_id, product_name,
		count(prod_id) AS cnt
	FROM 
		sales s
	JOIN 
		product_details pd ON s.prod_id = pd.product_id
	GROUP BY 
		txn_id, product_name
)
SELECT
	product_name,
	COUNT(product_name)*100.0/(SELECT count(DISTINCT txn_id) FROM sales) AS penetration_per_product
FROM
	cte	
GROUP BY 
	product_name
ORDER BY 
	penetration_per_product DESC;

-- 10. What is the most common combination of at least 1 quantity of any 3 products in a 1 single transaction?

WITH products 
 AS(
      SELECT
        txn_id,
        product_name
      FROM
        sales AS s
        JOIN product_details AS pd ON s.prod_id = pd.product_id
),
cte_2
AS
(
    SELECT
      p.product_name AS product_1,
      p1.product_name AS product_2,
      p2.product_name AS product_3,
      COUNT(*) AS times_bought_together,
      ROW_NUMBER() OVER(
        ORDER BY
          COUNT(*) DESC
      ) AS rank
    FROM
      products AS p
      JOIN products AS p1 ON p.txn_id = p1.txn_id
      AND p.product_name != p1.product_name
      AND p.product_name < p1.product_name
      JOIN products AS p2 ON p.txn_id = p2.txn_id
      AND p.product_name != p2.product_name
      AND p1.product_name != p2.product_name
      AND p.product_name < p2.product_name
      AND p1.product_name < p2.product_name
    GROUP BY
      p.product_name,
      p1.product_name,
      p2.product_name
 )
 SELECT 
  product_1,
  product_2,
  product_3,
  times_bought_together
FROM
	cte_2
WHERE 
	rank=1;
GO
----------------------
-- Reporting Challenge
----------------------

CREATE PROCEDURE ReportingChallenge
	@month int
AS
	-- set @month = 1;
	
	-- 1.
	SELECT
		product_name,
		amount
	FROM
		product_details
	JOIN
	(SELECT
		TOP 3
		prod_id,
		SUM(qty * price) AS amount
	FROM
		sales
	WHERE
		DATEPART(MONTH, start_txn_time) = @month
	GROUP BY 
		prod_id
	ORDER BY
		amount DESC) t ON t.prod_id =product_details.product_id
	ORDER BY 
		amount DESC;
	-- 2. 
	SELECT 
		segment_name,
		SUM(qty) AS total_quantity,
		SUM(qty * s.price) AS revenue,
		SUM(qty * discount *0.01 * s.price) AS total_discount
	FROM
		sales s
	JOIN 
		product_details pd ON s.prod_id = pd.product_id
	WHERE
		DATEPART(MONTH, start_txn_time) = @month
	GROUP BY
		segment_name;
	
	-- 3. 
	
	WITH cte
	AS
	(
		SELECT
			segment_name,
			product_name,
			SUM(qty) as qty_sold,
			DENSE_RANK() OVER(PARTITION BY segment_name ORDER BY SUM(qty) DESC) AS rnk
		FROM
			sales s
		JOIN 
			product_details pd ON s.prod_id = pd.product_id
		WHERE
			DATEPART(MONTH, start_txn_time) = @month 
		GROUP BY 
			segment_name, product_name
	)
	SELECT
		segment_name,
		product_name,
		qty_sold,
		rnk
	FROM
		cte
	WHERE
		rnk = 1;

	-- 4.

	SELECT 
		category_name,
		SUM(qty) AS total_quantity,
		SUM(qty * s.price) AS revenue,
		SUM(qty * discount *0.01 * s.price) AS total_discount
	FROM
		sales s
	JOIN 
		product_details pd ON s.prod_id = pd.product_id
	WHERE
		DATEPART(MONTH, start_txn_time) = @month
	GROUP BY
		category_name;

	-- 5. What is the top selling product for each category?

	WITH cte
	AS
	(
		SELECT
			category_name,
			product_name,
			SUM(qty) as qty_sold,
			ROW_NUMBER() OVER(PARTITION BY category_name ORDER BY COUNT(qty) DESC) AS rnk
		FROM
			sales s
		JOIN 
			product_details pd ON s.prod_id = pd.product_id
		WHERE
			DATEPART(MONTH, start_txn_time) = @month
		GROUP BY 
			category_name, product_name
	)
	SELECT
		category_name,
		product_name,
		qty_sold
	FROM
		cte
	WHERE
		rnk = 1;

	-- 6. 

	WITH cte
	AS
	(
		SELECT
			segment_name,
			product_name,
			SUM(qty * s.price) AS revenue
		FROM
			sales s
		JOIN 
			product_details pd ON s.prod_id = pd.product_id
		WHERE
			DATEPART(MONTH, start_txn_time) = @month
		GROUP BY 
			ROLLUP(segment_name, product_name)
	)
	SELECT 
		c1.segment_name,
		c1.product_name,
		CAST(c1.revenue*100.0/c2.revenue AS NUMERIC(5,2)) AS segment_perc
	FROM 
		cte	c1
	JOIN
		cte c2 ON c1.segment_name = c2.segment_name AND c2.product_name IS NULL
	WHERE 
		c1.product_name IS NOT NULL
	ORDER BY
		segment_name,
		segment_perc DESC;

	-- 7.

	WITH cte
	AS
	(
		SELECT
			category_name,
			segment_name,
			SUM(qty * s.price) AS revenue
		FROM
			sales s
		JOIN 
			product_details pd ON s.prod_id = pd.product_id
		WHERE
			DATEPART(MONTH, start_txn_time) = @month
		GROUP BY 
			ROLLUP(category_name, segment_name)
	)
	SELECT 
		c1.category_name,
		c1.segment_name,
		CAST(c1.revenue*100.0/c2.revenue AS NUMERIC(5,2)) AS category_perc
	FROM 
		cte	c1
	JOIN
		cte c2 ON c1.category_name = c2.category_name AND c2.segment_name IS NULL
	WHERE 
		c1.segment_name IS NOT NULL
	ORDER BY
		category_name,
		category_perc DESC;

	-- 8. 

	WITH cte
	AS
	(
		SELECT
			category_name,
			SUM(qty*s.price) AS revenue
		FROM
			sales s
		JOIN 
			product_details pd ON s.prod_id = pd.product_id
		WHERE
			DATEPART(MONTH, start_txn_time) = @month
		GROUP BY 
			ROLLUP(category_name)
	)
	SELECT 
		c1.category_name,
		CAST(ROUND(c1.revenue * 100.0 / c2.revenue, 2) AS NUMERIC(5,2)) AS revenue_perc
	FROM 
		cte	c1
	JOIN
		cte c2 ON c2.category_name IS NULL
	WHERE 
		c1.category_name IS NOT NULL;

	-- 9.

	WITH cte
	AS
	(
		SELECT
			txn_id, product_name,
			count(prod_id) AS cnt
		FROM 
			sales s
		JOIN 
			product_details pd ON s.prod_id = pd.product_id
		WHERE
			DATEPART(MONTH, start_txn_time) = @month
		GROUP BY 
			txn_id, product_name
	)
	SELECT
		product_name,
		COUNT(product_name)*100.0/(SELECT count(DISTINCT txn_id) FROM sales) AS penetration_per_product
	FROM
		cte	
	GROUP BY 
		product_name
	ORDER BY 
		penetration_per_product DESC;

	-- 10.

	WITH products 
	AS(
		SELECT
			txn_id,
			product_name
		FROM
		sales AS s
		JOIN product_details AS pd ON s.prod_id = pd.product_id
		WHERE
			DATEPART(MONTH, start_txn_time) = @month		
	),
	cte_2
	AS
	(
		SELECT
		  p.product_name AS product_1,
		  p1.product_name AS product_2,
		  p2.product_name AS product_3,
		  COUNT(*) AS times_bought_together,
		  ROW_NUMBER() OVER(
			ORDER BY
			  COUNT(*) DESC
		  ) AS rank
		FROM
		  products AS p
		  JOIN products AS p1 ON p.txn_id = p1.txn_id
		  AND p.product_name != p1.product_name
		  AND p.product_name < p1.product_name
		  JOIN products AS p2 ON p.txn_id = p2.txn_id
		  AND p.product_name != p2.product_name
		  AND p1.product_name != p2.product_name
		  AND p.product_name < p2.product_name
		  AND p1.product_name < p2.product_name
		GROUP BY
		  p.product_name,
		  p1.product_name,
		  p2.product_name
	 )
	 SELECT 
	  product_1,
	  product_2,
	  product_3,
	  times_bought_together
	FROM
		cte_2
	WHERE 
		rank=1;
GO

EXEC ReportingChallenge 2;

-----------------
-- Bonus Question
-----------------
SELECT * FROM 
product_hierarchy;

SELECT * FROM 
product_prices ;

SELECT * FROM 
product_details ;


SELECT 
	product_id, 
	price,  
	CONCAT(ph1.level_text, ' ',ph2.level_text, ' ', ph3.level_text) AS product_name,
	ph2.id as parentId,
	ph2.id AS segmentId,
	ph2.id AS style_id,
	ph3.level_text AS category_name,
	ph2.level_text AS segment_name,
	ph1.level_text AS style_name
FROM product_hierarchy ph1
JOIN product_hierarchy ph2 ON ph1.parent_id = ph2.id
JOIN product_hierarchy ph3 ON ph2.parent_id = ph3.id 
LEFT JOIN product_prices pp ON pp.id = ph1.id

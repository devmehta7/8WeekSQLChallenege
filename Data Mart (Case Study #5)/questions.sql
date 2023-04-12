SELECT * FROM weekly_sales;

--------------------------
--1. Data Cleansing Steps
--------------------------

SELECT CONVERT(DATE, week_date, 3) 
FROM weekly_sales;

SELECT DATEPART(week,  CONVERT(DATE, week_date, 3)) AS week_number
FROM weekly_sales
ORDER BY week_number;

SELECT DATEPART(month,  CONVERT(DATE, week_date, 3)) AS month_number
FROM weekly_sales
ORDER BY month_number;

SELECT DATEPART(year, CONVERT(DATE, week_date, 3)) AS calendar_year
FROM weekly_sales
ORDER BY calendar_year;

SELECT 
	CASE RIGHT(segment,1) 
		WHEN '1'THEN 'Young Adults'
		WHEN '2' THEN 'Middle Aged'
		WHEN '3' THEN 'Retirees'
		WHEN '4' THEN 'Retirees'
		ELSE 'Unknown'
	END	AS age_band
FROM weekly_sales;

SELECT 
	CASE LEFT(segment,1) 
		WHEN 'C'THEN 'Couples'
		WHEN 'F' THEN 'Families'
		ELSE 'Unknown'
	END	AS demographic
FROM weekly_sales;

SELECT 
	*,
	sales/transactions as avg_transaction
FROM 
	weekly_sales;

-- clean_weekly_sales TABLE
SELECT
	CONVERT(DATE, week_date, 3) AS week_date,
	DATEPART(week,  CONVERT(DATE, week_date, 3)) AS week_number,
	DATEPART(month,  CONVERT(DATE, week_date, 3)) AS month_number,
	DATEPART(year, CONVERT(DATE, week_date, 3)) AS calendar_year,
	CASE RIGHT(segment,1) 
		WHEN '1'THEN 'Young Adults'
		WHEN '2' THEN 'Middle Aged'
		WHEN '3' THEN 'Retirees'
		WHEN '4' THEN 'Retirees'
		ELSE 'Unknown'
	END	AS age_band,
	CASE LEFT(segment,1) 
		WHEN 'C'THEN 'Couples'
		WHEN 'F' THEN 'Families'
		ELSE 'Unknown'
	END	AS demographic,
	CAST((sales *1.0 /transactions) AS NUMERIC(10, 2)) as avg_transaction,
	transactions,
	CAST(sales AS BIGINT) sales, 
	region,
	platform,
	customer_type
INTO 
	clean_weekly_sales
FROM 
	weekly_sales;

--DROP TABLE clean_weekly_sales;
SELECT * FROM clean_weekly_sales;

----------------------
--2. Data Exploration
----------------------

-- 1. What day of the week is used for each week_date value?

SELECT 
	DISTINCT week_date,
	DATEPART(WEEKDAY, week_date) AS week_day
FROM
	clean_weekly_sales

-- 2. What range of week numbers are missing from the dataset?

SELECT DISTINCT week_number FROM clean_weekly_sales
ORDER BY week_number;

WITH cte 
AS
(
	SELECT 
		value as week_range 
	FROM generate_series(1, 52, 1)
)
SELECT 
	DISTINCT week_range
FROM 
	clean_weekly_sales
RIGHT JOIN 
	cte ON week_range = week_number 
WHERE 
	week_number IS NULL;

-- 3. How many total transactions were there for each year in the dataset?

SELECT * FROM weekly_sales;

SELECT 
	DATEPART(YEAR, CONVERT(DATE, week_date, 3)) AS year,
	SUM(transactions) AS total_transactions
FROM	
	weekly_sales
GROUP BY DATEPART(YEAR, CONVERT(DATE, week_date, 3));

-- 4. What is the total sales for each region for each month?

SELECT * FROM clean_weekly_sales;

SELECT 
	region,
	calendar_year,
	month_number,
	SUM(CAST(sales AS bigint)) AS total_sale
FROM	
	clean_weekly_sales
GROUP BY 
	region, calendar_year, month_number
ORDER BY 
	region, calendar_year, month_number;

-- 5. What is the total count of transactions for each platform

SELECT * FROM clean_weekly_sales;

SELECT platform, SUM(CAST(transactions AS BIGINT)) AS total_transactions
FROM weekly_sales
GROUP BY platform;

-- 6. What is the percentage of sales for Retail vs Shopify for each month?
WITH cte
AS
(
	SELECT 
		calendar_year,
		month_number,
		SUM(CAST(sales AS bigint)) AS monthly_sale
	FROM	
		clean_weekly_sales
	GROUP BY 
		calendar_year, month_number
)
SELECT
	cws.calendar_year,
	cws.month_number,
	platform,
	SUM(CAST(sales AS bigint)) AS platform_monthly_sales,
	CAST(SUM(CAST(sales AS bigint))*100.0/monthly_sale AS NUMERIC(20, 2)) as platform_perc 
FROM
	clean_weekly_sales cws
JOIN 
	cte ON cte.calendar_year = cws.calendar_year AND cte.month_number = cws.month_number
GROUP BY 
	platform, cws.calendar_year, cws.month_number, monthly_sale
ORDER BY
	cws.calendar_year, cws.month_number 

-- 7. What is the percentage of sales by demographic for each year in the dataset?

SELECT * FROM clean_weekly_sales;

WITH cte
as
(
SELECT 
	calendar_year,
	demographic,
	SUM(sales) as demographic_sales
FROM
	clean_weekly_sales
GROUP BY 
	calendar_year, demographic
),
cte_2 AS
(
	SELECT 
		calendar_year,
		SUM(sales) AS yearly_sales
	FROM clean_weekly_sales
	GROUP BY calendar_year
)
	SELECT
		cte.calendar_year,
		cte.demographic,
		demographic_sales,
		yearly_sales,
		CAST(demographic_sales * 100.0/ yearly_sales AS NUMERIC(20, 2)) AS demo_sales_perc
	FROM cte
	JOIN cte_2 ON cte.calendar_year = cte_2.calendar_year  
	ORDER BY cte.calendar_year, demographic

-- 8. Which age_band and demographic values contribute the most to Retail sales?

SELECT * FROM clean_weekly_sales;

SELECT 
	age_band,
	demographic,
	SUM(sales) AS total_sale
FROM
	clean_weekly_sales
WHERE 
	platform = 'Retail'
GROUP BY 
	age_band, demographic
ORDER BY 
	total_sale DESC;

-- 9. Can we use the avg_transaction column to find the average transaction size for each year for Retail vs Shopify?
--If not - how would you calculate it instead?

SELECT * FROM clean_weekly_sales;

--My approach (WRONG)
--SELECT 
--	calendar_year,
--	AVG(
--		CASE	
--			WHEN platform = 'Retail' THEN avg_transaction END) AS avg_Retail_transaction,
--	AVG(
--		CASE 
--			WHEN platform = 'Shopify' THEN avg_transaction END) AS avg_Shopify_transaction
--FROM 
--	clean_weekly_sales
--GROUP BY 
--	calendar_year
--ORDER BY 
--	calendar_year;

-------------------
-- CORRECT APPROACH
-- We can not use avg_transaction column to find the average transaction size per year and sales platform, 
-- because we need to aggregate it first. If we aggregate it as an average value the result will be incorrect. 
-- In other words, we can not use average of average to calculate the average.

SELECT calendar_year,
       platform,
       ROUND(SUM(sales)/SUM(transactions), 2) AS correct_avg,
       ROUND(AVG(avg_transaction), 2) AS incorrect_avg
FROM clean_weekly_sales
GROUP BY calendar_year,
         platform
ORDER BY calendar_year,
         platform;
GO

----------------------------
--3. Before & After Analysis
----------------------------
--2020-06-15

SELECT * FROM clean_weekly_sales;

ALTER TABLE clean_weekly_sales
ADD before_after VARCHAR(7)

UPDATE clean_weekly_sales
SET before_after = 'before'
WHERE week_date < '2020-06-15';

UPDATE clean_weekly_sales
SET before_after = 'after'
WHERE week_date >= '2020-06-15';


--1. What is the total sales for the 4 weeks before and after 2020-06-15? 
--What is the growth or reduction rate in actual values and percentage of sales?

SELECT week_date, DATEDIFF(WEEK, week_date, '2020-06-15')
FROM clean_weekly_sales;

WITH cte
AS
(
	SELECT
		SUM(
			CASE 
				WHEN before_after = 'before' THEN CAST(sales AS bigint) END
		) AS before_total_sales,
		SUM(
		CASE 
			WHEN before_after = 'after' THEN CAST(sales AS bigint) END
		) AS after_total_sales
	FROM clean_weekly_sales
	WHERE DATEDIFF(WEEK, week_date, '2020-06-15') BETWEEN -3 AND 4
)
SELECT 
	before_total_sales,
	after_total_sales,
	after_total_sales - before_total_sales AS change_in_sales,
	(after_total_sales-before_total_sales)*100.0/before_total_sales AS percentage_of_change
FROM cte;
GO

--FINDINGS
--4 week before '2020-06-15' total sales was : 2345878357
--Since '2020-06-15' total sales for next 4 weeks is: 2318994169
--so the sales after '2020-06-15' decreased by 1.15% and -26884188  

-- 2. What about the entire 12 weeks before and after?
WITH cte
AS
(
	SELECT
		SUM(
			CASE 
				WHEN before_after = 'before' THEN CAST(sales AS bigint) END
		) AS before_total_sales,
		SUM(
		CASE 
			WHEN before_after = 'after' THEN CAST(sales AS bigint) END
		) AS after_total_sales
	FROM clean_weekly_sales
	WHERE DATEDIFF(WEEK, week_date, '2020-06-15') BETWEEN -11 AND 12
)
SELECT 
	before_total_sales,
	after_total_sales,
	after_total_sales - before_total_sales AS change_in_sales,
	(after_total_sales-before_total_sales)*100.0/before_total_sales AS percentage_of_change
FROM cte

-- How do the sale metrics for these 2 periods before and after compare with the previous years in 2018 and 2019?


SELECT
	SUM(
		CASE 
			WHEN before_after = 'before' THEN CAST(sales AS bigint) END
	) AS before_total_sales,
	SUM(
	CASE 
		WHEN before_after = 'after' THEN CAST(sales AS bigint) END
	) AS after_total_sales
FROM clean_weekly_sales
WHERE DATEDIFF(WEEK, week_date, '2018-06-15') BETWEEN -11 AND 12
 


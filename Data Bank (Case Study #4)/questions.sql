--A. Customer Nodes Exploration


--1. How many unique nodes are there on the Data Bank system?

SELECT * FROM data_bank.customer_nodes
ORDER BY customer_id;
GO

SELECT DISTINCT region_id, node_id
FROM data_bank.customer_nodes
ORDER BY region_id, node_id;
GO

--2. What is the number of nodes per region?

SELECT region_id, count(DISTINCT node_id)
FROM data_bank.customer_nodes
GROUP BY region_id
ORDER BY region_id;
GO
--3. How many customers are allocated to each region?

SELECT region_id, node_id, COUNT(DISTINCT customer_id)
FROM data_bank.customer_nodes
GROUP BY region_id, node_id
ORDER BY region_id;
GO

-- 4. How many days on average are customers reallocated to a different node?

WITH cte_
AS
(SELECT 
	customer_id,
	region_id,
	node_id,
	DATEDIFF(day, start_date, end_date) AS duration
FROM
	data_bank.customer_nodes
WHERE end_date != '9999-12-31'
)
SELECT AVG(duration) AS average_days
FROM cte_;
GO

--5. What is the median, 80th and 95th percentile for this same reallocation days metric for each region?

SELECT *
FROM data_bank.customer_nodes;
GO

WITH cte
AS
(SELECT 
	customer_id,
	region_id,
	node_id,
	DATEDIFF(day, start_date, end_date) AS duration
FROM
	data_bank.customer_nodes
WHERE end_date != '9999-12-31')
SELECT 
	DISTINCT
	region_id,
	PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY duration) OVER(PARTITION BY region_id) AS median,
	PERCENTILE_CONT(0.8) WITHIN GROUP(ORDER BY duration) OVER(PARTITION BY region_id) AS "80th_percentile",
	PERCENTILE_CONT(0.95) WITHIN GROUP(ORDER BY duration) OVER(PARTITION BY region_id) AS "95th_percentile"
FROM 
	cte;
GO
----
--B. Customer Transactions
----

-- 1. What is the unique count and total amount for each transaction type?

SELECT * FROM data_bank.customer_transactions;

SELECT txn_type, count(*) as transactions, SUM(txn_amount) as total_amount
FROM data_bank.customer_transactions
GROUP BY txn_type; 
GO
-- 2. What is the average total historical deposit counts and amounts for all customers?

SELECT customer_id, COUNT(*) transactions, AVG(txn_amount) average_amount
FROM data_bank.customer_transactions
WHERE txn_type = 'deposit'
GROUP BY customer_id
ORDER BY customer_id;
GO
-- 3. For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?

WITH cte
AS
(SELECT 
	customer_id, 
	MONTH(txn_date) AS month,
	SUM(CASE WHEN txn_type = 'deposit' THEN 1 ELSE 0 END) AS deposit_count,
	SUM(CASE WHEN txn_type = 'withdrawal' THEN 1 ELSE 0 END) AS withdrawal_count,
	SUM(CASE WHEN txn_type = 'purchase' THEN 1 ELSE 0 END) AS purchase_count
FROM data_bank.customer_transactions
GROUP BY customer_id, MONTH(txn_date))
SELECT month, COUNT(customer_id) as customer_count
FROM cte
WHERE deposit_count >=2 AND (purchase_count >=1 OR withdrawal_count >= 1)
GROUP BY month;
GO

-- 4. What is the closing balance for each customer at the end of the month?

SELECT DISTINCT txn_type FROM data_bank.customer_transactions;

WITH cte
AS
(SELECT 
	MONTH(txn_date) AS month,
	customer_id,
	SUM(
		CASE
		WHEN txn_type = 'deposit' THEN txn_amount ELSE (-txn_amount) END) AS monthly_balance	
FROM 
	data_bank.customer_transactions
GROUP BY customer_id, MONTH(txn_date))
SELECT customer_id, 
    month,
    monthly_balance,
    sum(monthly_balance) over(PARTITION BY customer_id ORDER BY month) AS final_month_balance
INTO #closing_balance
FROM cte;
GO

SELECT * FROM #closing_balance

-- 5. What is the percentage of customers who increase their closing balance by more than 5%?

WITH cte 
AS
(select 
	customer_id,
	month,
	final_month_balance,
	LAG(final_month_balance, 1) OVER(PARTITION BY customer_id ORDER BY month) AS prev_month_closing
from
	#closing_balance
WHERE final_month_balance>0),
cte_2 AS
(SELECT 
	*,
	(final_month_balance - prev_month_closing) * 100/ prev_month_closing AS perc_increase
FROM
	cte)
SELECT 
	count(DISTINCT customer_id) * 100/ (SELECT COUNT(DISTINCT customer_id) FROM data_bank.customer_transactions) AS cust_perc 
FROM cte_2
WHERE perc_increase > 5;
GO

-------------
-- C. Data Allocation Challenge
-------------

SELECT * FROM #closing_balance;

-- OPTION-1
WITH cte
AS
(SELECT 
	customer_id,
	txn_type,
	txn_amount,
	CASE 
		WHEN txn_type = 'deposit' THEN txn_amount ELSE -txn_amount END as signed_amt,
	txn_date
FROM data_bank.customer_transactions )
SELECT 
	*,
	SUM(signed_amt) OVER(PARTITION BY customer_id ORDER BY txn_date) AS running_cust_bal
INTO #running_balance
FROM 
	cte

SELECT * FROM #running_balance;

-- OPTION-2

SELECT 
	DISTINCT customer_id,
	MONTH(txn_date) as month,
	LAST_VALUE(running_cust_bal) OVER(PARTITION BY customer_id,MONTH(txn_date)  ORDER BY month(txn_date)) as cust_end_month_bal
FROM #running_balance;
--ABOVE AND BELOW BOTH WORKS THE SAME, INITIALLY FACING ISSUE REGARDING LAST_VALUE() FUNCTION.
WITH cte AS
(	SELECT 
		customer_id,
		MONTH(txn_date) as mon,
		running_cust_bal
	FROM #running_balance)
SELECT 
	DISTINCT customer_id,
	mon,
	LAST_VALUE(running_cust_bal) OVER(PARTITION BY customer_id,mon  ORDER BY mon) as cust_end_month_bal
FROM cte;

--OPTION -3

SELECT 
	customer_id,
	MIN(running_cust_bal) as min_bal,
	AVG(running_cust_bal) as avg_bal,
	MAX(running_cust_bal) as max_bal
FROM 
	#running_balance
GROUP BY 
	customer_id
ORDER BY 
	customer_id;



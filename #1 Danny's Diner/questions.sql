-- SET search_path = dannys_diner;
SELECT *
FROM members;

SELECT *
FROM menu;

SELECT *
FROM sales;

-- 1. What is the total amount each customer spent at the restaurant?

SELECT customer_id, sum(price) as total_amount
FROM sales
JOIN menu USING(product_id)
GROUP BY customer_id;

-- 2. How many days has each customer visited the restaurant?

SELECT customer_id, count(distinct order_date) as days_visited
FROM sales
GROUP BY customer_id;

-- 3. What was the first item from the menu purchased by each customer?

WITH cte
AS
(SELECT customer_id, order_date, product_id, ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY order_date) as rnk
FROM sales)
SELECT customer_id, order_date, product_name
FROM cte
JOIN menu USING(product_id)
WHERE rnk = 1

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT product_name, count(*)
FROM sales
JOIN menu USING(product_id)
GROUP BY product_name
ORDER BY count(*) DESC
FETCH FIRST 1 ROW ONLY;

-- 5. Which item was the most popular for each customer?

WITH cte
AS
(SELECT customer_id, product_id, RANK() OVER(PARTITION BY customer_id ORDER BY count(product_id) DESC) as rnk
FROM sales
GROUP BY customer_id, product_id)
SELECT customer_id, product_name
FROM cte
JOIN menu USING(product_id)
WHERE rnk = 1
ORDER BY customer_id;

-- 6. Which item was purchased first by the customer after they became a member?

WITH cte
AS
	(SELECT customer_id, product_id, order_date, RANK() OVER(PARTITION BY customer_id ORDER BY order_date)
	FROM sales s
	JOIN members m using(customer_id)
	where m.join_date <= s.order_date)
SELECT customer_id, product_name
FROM cte
JOIN menu USING(product_id)
WHERE rank = 1;

-- 7. Which item was purchased just before the customer became a member?

WITH cte
AS
	(SELECT s.customer_id, product_id, order_date, RANK() OVER(PARTITION BY s.customer_id ORDER BY order_date DESC)
	FROM sales s
	JOIN members m ON m.customer_id = s.customer_id 
	WHERE m.join_date > s.order_date)
SELECT customer_id, product_name, order_date
FROM cte
JOIN menu USING(product_id)
WHERE rank = 1;

-- 8. What is the total items and amount spent for each member before they became a member?

SELECT s.customer_id, count(product_id), sum(price)
FROM sales s
JOIN menu m USING(product_id)
JOIN members mb ON mb.customer_id = s.customer_id AND mb.join_date > s.order_date
GROUP BY s.customer_id;

-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

SELECT 
	customer_id,
	SUM(CASE 	
		WHEN product_name = 'sushi' THEN
			price*20
		ELSE
			price*10
		END) AS points	
FROM sales
JOIN menu USING(product_id)
GROUP BY customer_id
ORDER BY points DESC;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi
-- - how many points do customer A and B have at the end of January?

SELECT 
	s.customer_id,
	SUM(
		CASE
			WHEN (order_date - join_date) BETWEEN 0 AND 6 OR product_name = 'sushi' THEN
				price*20
			ELSE
				price*10
			END
	) AS points
FROM sales s
JOIN members mb ON mb.customer_id = s.customer_id 
JOIN menu USING(product_id)
WHERE order_date <= '2021-01-31'
GROUP BY s.customer_id;

-- Bonus Question

WITH cte
AS
(SELECT 
	s.customer_id customer,
	s.order_date,
	m.product_name,
	m.price,
	(CASE
		WHEN order_date >= join_date
			THEN 'Y'
		ELSE
			'N'
	END) member
FROM menu m
JOIN sales s
ON s.product_id = m.product_id
LEFT JOIN members mb
ON s.customer_id = mb.customer_id
ORDER BY customer,order_date)
SELECT 
	customer
	member,
	CASE
		WHEN member = 'N' THEN
			null
		ELSE
			ROW_NUMBER() OVER(PARTITION BY customer,member)
		END
from cte 

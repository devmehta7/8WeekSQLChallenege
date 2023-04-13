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
	user_id,
	DATEPART(MONTH FROM event_time) AS month,
	COUNT(DISTINCT visit_id) AS visit_count
FROM
	users
JOIN
	events ON users.cookie_id = events.cookie_id
GROUP BY 
	user_id, DATEPART(MONTH FROM event_time);

SELECT * FROM weekly_sales;

--------------------------
--1. Data Cleansing Steps
--------------------------

SELECT CONVERT(DATE, week_date, 3) 
FROM weekly_sales;

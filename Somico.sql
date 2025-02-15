/*
------------------------

SOMICO ELIST SQL PROJECT

------------------------
*/

--1) What were the order counts, sales, and AOV for Macbooks sold in North America for each quarter across all years? 

-- SELECT > purchast_ts date trunc to quarters, count(id), sum(usd_price), avg(usd_price) / round by 2 decimals for cleaner output.
-- FROM > core.orders as co / this table is the main table I will use containing the most data to answer the question above.
-- LEFT JOIN > customers, and geo_lookup to connect the country but output the region. 
-- WHERE > prodduct name is macbook and region = NA.
-- GROUP BY > Quarter.
-- ORDER BY > Quarter desc.

SELECT date_trunc(orders.purchase_ts, quarter) as Purchase_quarter
  ,count(distinct orders.id) as Order_count
  ,round(sum(orders.usd_price),2) as Total_price
  ,round(avg(orders.usd_price),2) as Aov
FROM core.orders
LEFT JOIN core.customers 
  ON orders.customer_id = customers.id
LEFT JOIN core.geo_lookup
  ON gep_lookup.country = customers.country_code
WHERE lower(co.product_name) like '%macbook%'
  OR cg.region = 'NA'
GROUP BY 1
ORDER BY 1 desc;

-- What is the average quarterly order count and total sales for Macbooks sold in North America? 

-- This question is an aggragate within an aggrate meaning this requires a CTE.
-- CTE > labeled as Quarterly_avg.
-- SELECT > date trunc to quarter with purchase ts, count orders, sum the usd price/round by 2 decimals for readability.
-- FROM > core orders for the main table,
-- LEFT JOIN > customers, geo lookup as cg / connecting the IDs, and by country.
-- WHERE > product name like macbook
-- OR > region = NA
-- GROUP BY/ORDER BY 1

--SELECT > CTE columns order_count, and Total_orders to calculate the average.
-- from CTE Quarterly_avg.

WITH Quarterly_avg as (
SELECT date_trunc(orders.purchase_ts, quarter) as Purchase_quarter
  ,count(distinct orders.id) as Order_count
  ,round(sum(orders.usd_price),2) as Total_sales
FROM core.orders co
LEFT JOIN core.customers 
  ON orders.customer_id = customers.id
LEFT JOIN core.geo_lookup 
  ON geo_lookup.country = customers.country_code
WHERE lower(orders.product_name) like '%macbook%'
  OR geo_lookup.region = 'NA'
GROUP BY 1
ORDER BY 1 desc)

SELECT round(avg(Order_count),2) as avg_quarter_orders
  ,round(avg(Total_sales),2) as avg_quarter_sales
FROM Quarterly_avg;

--2) For products purchased in 2022 on the website or products purchased on mobile in any year, which region has the average highest time to deliver? 

-- SELECT > region, and avg date diff between delivery and purchase by the day.
-- FROM > core orders as the main table.
-- LEFT JOIN > order status, customers, and geo lookup to pull the delivery column, and region outside the core orders table.
-- WHERE > extract purchase ts = 2022 AND purchase platform > website
-- OR purchase platform = mobile app
-- GROUP BY/ORDER BY 1 desc

SELECT geo_lookup.region
  ,avg(date_diff(order_status.delivery_ts, order_status.purchase_ts, day)) as time_to_deliver 
FROM core.orders
LEFT JOIN core.order_status
  ON order_status.order_id = orders.id
LEFT JOIN core.customers 
  ON customers.id = orders.customer_id
LEFT JOIN core.geo_lookup
  ON geo_lookup.country = customers.country_code
WHERE (extract(year from orders.purchase_ts) = 2022 and orders.purchase_platform = 'website')
  OR orders.purchase_platform = 'mobile app'
GROUP BY 1
ORDER BY 1 desc;

-- Rewrite this query for website purchases made in 2022 or Samsung purchases made in 2021, expressing time to deliver in weeks instead of days.

-- Similar to the query above just updating the SELECT date diff to day, and WHERE has an additional extract to pull the year 2021 and purchase platform Samsung.

SELECT geo_lookup.region
  ,avg(date_diff(order_status.delivery_ts, order_status.purchase_ts, day)) as time_to_deliver 
FROM core.orders 
LEFT JOIN core.order_status
  ON order_status.order_id = orders.id
LEFT JOIN core.customers
  ON customers.id = orders.customer_id
LEFT JOIN core.geo_lookup
  ON geo_lookup.country = customers.country_code
WHERE (extract(year from orders.purchase_ts) = 2022 and orders.purchase_platform = 'website')
  OR (extract(year from orders.purchase_ts) = 2021 and orders.purchase_platform = 'Samsung')
GROUP BY 1
ORDER BY 1 desc;

-- 3) What was the refund rate and refund count for each product overall? 

-- SELECT > First we need to clean the product name column and consolidate 27in"" 4k gaming monitor / 27in 4K gaming monitor to one product name.
  -- SELECT > refund column is a binary column to calculating the average will give us the refund rate.
  -- SELECT > sum of the refund ts will give us the total count amount
-- FROM > core orders
-- LEFT JOIN > order status to pull the refund column
-- GROUP BY 1 / ORDER BY 2 desc

SELECT case when orders.product_name = '27in"" 4k gaming monitor' then '27in 4K gaming monitor' else co.product_name end as product_clean
  ,round(avg(case when order_status.refund_ts is not null then 1 else 0 end)*100,2) as refund_rate
  ,sum(case when order_status.refund_ts is not null then 1 else 0 end) as refund_count
FROM core.orders
LEFT JOIN core.order_status
  ON order_status.order_id = orders.id
GROUP BY 1
ORDER BY 2 desc;

--What was the refund rate and refund count for each product per year?

-- Similar to the query above, add a column to extract the year.

SELECT extract(year from orders.purchase_ts) as year
  ,case when orders.product_name = '27in"" 4k gaming monitor' then '27in 4K gaming monitor' else co.product_name end as product_clean
  ,round(avg(case when order_status.refund_ts is not null then 1 else 0 end)*100,2) as refund_rate
  ,sum(case when order_status.refund_ts is not null then 1 else 0 end) as refund_count
FROM core.orders
LEFT JOIN core.order_status
  ON order_status.order_id = orders.id
GROUP BY 1,2
ORDER BY 3 desc;

-- 4) Within each region, what is the most popular product? 

-- Another CTE is needed to query this question.
-- WITH > sales_by_product.
-- SELECT > region, product clean, and count of orders (id).
-- FROM > core orders as the main table.
-- LEFT JOIN > customers and geo lookup to pull the region specifically.
-- GROUP BY > 1,2.

-- SELECT > partition by region order by total orders for order ranking.
-- FROM > CTE sales by product.

-- SELECT > *
-- FROM > ranked orders.
-- WHERE > order tanking = 1.

WITH sales_by_product as (
SELECT region
  ,case when orders.product_name = '27in"" 4k gaming monitor' then '27in 4K gaming monitor' else co.product_name end as product_clean
  ,count(distinct orders.id) as total_orders
FROM core.orders
LEFT JOIN core.customers
  ON customers.id = orders.customer_id
LEFT JOIN core.geo_lookup
  ON geo_lookup.country = customers.country_code
GROUP BY 1,2),

ranked_orders as (
SELECT *
  ,row_number() over (partition by region order by total_orders desc) as order_ranking
FROM sales_by_product
ORDER BY 4 asc)

SELECT *
FROM ranked_orders
WHERE order_ranking = 1;

-- 5) How does the time to make a purchase differ between loyalty customers vs. non-loyalty customers?

-- SELECT > loyalty program, avg(datediff(purchase ts , created on, day and month))
-- FROM > core customers
-- LEFT JOIN > core orders
-- GROUP BY > 1

SELECT customers.loyalty_program
  ,round(avg(date_diff(orders.purchase_ts, customers.created_on, day)),1) as days_to_purchase
  ,round(avg(date_diff(orders.purchase_ts, customers.created_on, month)),1) as months_to_purchase
FROM core.customers
LEFT JOIN core.orders
  ON customers.id = orders.customer_id
GROUP BY 1;

-- Update this query to split the time to purchase per loyalty program, per purchase platform. Return the number of records to benchmark the severity of nulls.

-- SELECT > loyalty platform, loyalty program, avg(datediff(purchase ts , created on, day and month)), count * as row count
-- FROM > core customers
-- LEFT JOIN > core orders
-- GROUP BY > 1,2.

SELECT orders.purchase_platform
  ,customers.loyalty_program
  ,round(avg(date_diff(orders.purchase_ts, customers.created_on, day)),1) as days_to_purchase
  ,round(avg(date_diff(orders.purchase_ts, customers.created_on, month)),1) as months_to_purchase
  ,count(*) as row_count
FROM core.customers
LEFT JOIN core.orders
  ON customers.id = orders.customer_id
GROUP BY 1,2;




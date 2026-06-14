create database da
use da
select product_id,category,count(*) from productn
group by product_id,category
having count(*)>1

create table productn as
select distinct product_id,category from productp

select product_id,category from productn
where product_id = 'OFF-AVE-10002102'
start transaction;
update productp
set product_id = 'OFF-AVE-11102102'
where product_id = 'OFF-AVE-10002102' 
rollback
set sql_safe_updates=0

select count(*) from productn
where product_id = 'OFF-AVE-11102102'
group by product_id

start transaction;
delete from productp
where product_id = 'OFF-AVE-10002102'

select customer_id,customer_name,segment,count(*) from customern
group by customer_id,customer_name,segment
having count(*)>1

create table customern as
select distinct customer_id,customer_name,segment from customerp

drop table customerp
drop table productp

select * from salesp

select region,country from salesp
where region = 'east'

-region wise top 3 country-
with top_3 as(select region,country,round(sum(sales),2) as tt from salesp group by region,country)
select * from(select *,dense_rank() over(partition by region order by tt desc)rnk from top_3)d
where rnk<=3

-ship_mode wise sales- 
select ship_mode,round(sum(sales),2) from salesp 
group by ship_mode
order by sum(sales) desc

-country wise top 3 customers-
with top3 as(select s.country,c.customer_name,round(sum(s.sales),2) as tt from salesp s join customern c on s.customer_id = c.customer_id
group by s.country,c.customer_name)
select * from(select *,dense_rank() over(partition by country order by tt desc)rnk from top3)d
where rnk<=3

select * from salesp

-sales% by product-
with percent as(select p.category,round(sum(s.sales),2)tt from salesp s join productn p on s.product_id=p.product_id
group by p.category order by tt desc)

select category,round(tt*100/sum(tt) over(),2) from percent

with high as(select c.customer_name,p.category,s.country,round(sum(s.sales),2)tt from salesp s join productn p on s.product_id=p.product_id
join customern c on s.customer_id=c.customer_id 
group by p.category,c.customer_name,s.country)
select customer_name,category,round(tt*100/sum(tt) over(partition by country),2)t from high
order by t desc

-customer wise contribution% within each city-
with high as(select c.customer_name,s.country,round(sum(s.sales),2)tt from salesp s 
join customern c on s.customer_id=c.customer_id 
group by c.customer_name,s.country
order by tt desc)
select customer_name,country,round(tt*100/sum(tt) over(partition by country),2)t from high
order by t desc

select c.customer_name,s.country,sum(s.sales) from salesp s join customern c on s.customer_id=c.customer_id
where s.country = 'Equatorial Guinea' and c.customer_name = 'Emily Phan'
group by s.country,c.customer_name

select country,sum(sales) from salesp
where country = 'Equatorial Guinea'
group by country


select sales,year(order_date),sum(sales) over(order by year(order_date)) from salesp

-month wise running sales-
WITH yr_sales AS
(
    SELECT
        month(order_date) AS mn,
        year(order_date) AS yr,
        round(SUM(sales),0) AS total_sales
    FROM salesp
    GROUP BY month(order_date),year(order_date)
)
SELECT
    yr,
    mn,
    total_sales,
    round(SUM(total_sales) OVER(
        ORDER BY yr,mn
    ),0) AS running_sales
FROM yr_sales;

-country wise running sales-
WITH yr_sales AS
(
    SELECT
        month(order_date) AS mn,
        year(order_date) AS yr,
        country,
        round(SUM(sales),0) AS total_sales
    FROM salesp
    GROUP BY month(order_date),year(order_date),country
)
SELECT
    yr,
    mn,
    country,
    total_sales,
    round(SUM(total_sales) OVER(
       partition by country ORDER BY yr,mn
    ),0) AS running_sales
FROM yr_sales;

select order_date from salesp
where order_date is null

start transaction;
update salesp
set order_date =  case
when order_date regexp '^[0-9]{2}-[0-9]{2}-[0-9]{4}$'
then str_to_date(order_date,'%d-%m-%Y')
else order_date
end

-previous yr sales-
WITH yr_sales AS
(
    SELECT
        month(order_date) AS mn,
        year(order_date) AS yr,
        round(sum(sales),0) AS pre
    FROM salesp
    GROUP BY month(order_date),year(order_date)
    )
 select mn,yr,pre,lag(pre,1,0) over(order by yr,mn) from yr_sales   
 
-previous yr sales percentage
 WITH monthly_sales AS
(
    SELECT
        YEAR(order_date) AS yr,
        round(SUM(sales),0) AS total_sales
    FROM salesp
    GROUP BY YEAR(order_date)
)
SELECT
    yr,
    total_sales,
    LAG(total_sales,1,0) OVER(
        ORDER BY yr
    ) AS previous_sales,
    ROUND(
        (
            total_sales -
            LAG(total_sales,1,0) OVER(ORDER BY yr)
        ) * 100.0
        /
        LAG(total_sales,1,0) OVER(ORDER BY yr),
        2
    )t
FROM monthly_sales;

select * from salesp


-total profit by each product-
with pro as (select p.category,round(sum(profit),0)pt from salesp s join productn p on s.product_id=p.product_id
group by p.category
order by pt desc)

select*, round(pt*100/sum(pt) over(),2) from pro

-profit percentage wise category-
with pro as (select p.category,round(sum(profit),0)pt from salesp s join productn p on s.product_id=p.product_id
group by p.region
order by pt desc)

select*, round(pt*100/sum(pt) over(),2) from pro

-top 3 countries in a region by profit-
with country as (
select region,country,round(sum(profit),1)tt from salesp
group by region, country
)
select*from(
select*,dense_rank() over(partition by region order by tt desc)rnk
from country)t
where rnk<=3

-average order per value-
SELECT
    ROUND(
        SUM(sales) /
        COUNT(DISTINCT order_id),
        2
    ) AS avg_order_value
FROM salesp;

-high sales month-
SELECT
    MONTHNAME(order_date) AS month_name,
    ROUND(SUM(sales),2) AS total_sales
FROM salesp
GROUP BY MONTHNAME(order_date),
         MONTH(order_date)
ORDER BY total_sales DESC;

-top 3 city contributions towards sales-
with top3 as (select country,sum(sales)tt from salesp
group by country
order by tt desc
limit 3)
SELECT
    ROUND(
        sum(tt) * 100.0 /
       (select sum(sales) from salesp),
        2
    ) AS contribution_pct
FROM top3;
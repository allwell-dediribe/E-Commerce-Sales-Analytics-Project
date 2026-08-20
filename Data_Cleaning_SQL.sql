/* Imported the tables into SQL Server */

select * from customers;
select * from order_items;
select * from orders;
select * from products;

/* Exploring the Database Structure */

select *
from customers c
join orders o
on c.Customer_ID = o.Customer_ID
join order_items oi
on o.Order_ID = oi.Order_ID
join products p
on oi.Product_ID = p.Product_ID;

/* Data Cleaning */
-- Creating Backup Tables
select * 
into customers_copy
from customers;

select *
into products_copy
from products;

select * 
into orders_copy
from orders;

select * 
into order_items_copy
from order_items;

/* Identifying Missing Values */
-- Investigating NULL values (customers_copy table)
select count(*) as Missing_Email
from customers_copy
where Customer_Email is NULL; /* There are 96 missing emails */

select * 
from customers_copy
where Customer_Name is NULL
or City is NULL
or Age is null
or Country is null; /* There are no nulls in these other columns */

update customers_copy
set Customer_Email = 'Unknown Email'
where Customer_Email is null; /* The NULLs in the Customer_Email column are replaced with 'Unknown Email' */

-- Investigating NULL values (order_items_copy table)
select count(*) as Missing_Discounts
from order_items_copy
where Discount is null; /* There are 100 missing discounts */

update order_items_copy
set discount = 0
where Discount is null; /* Replaced NULLs in Discount column with 0 */

select *
from order_items_copy
where Discount is null; /* Verified */

-- Investigating NULL values (orders_copy table)
select count(*) as NullShippingDate
from orders_copy
where Shipping_Date is null; /* There are 103 NULLs in the Shipping_Date column */

select delivery_status, count(*) as NullShippingDate
from orders_copy
where Shipping_Date is null
group by Delivery_Status; /* It makes business sense to leave NULLs in that column if the order is Pending or Cancelled. 
							 Because they haven't shipped. */

select Order_ID, 
	   Order_Date, 
	   Shipping_Date, 
	   DATEDIFF(day, Order_Date, Shipping_Date) as Shipping_Days
from orders_copy
where Shipping_Date is not null; /* Calculating shipping days for completed shipments */

select avg(DATEDIFF(day, Order_Date, Shipping_Date)) as Average_Shipping_Days
from orders_copy
where Shipping_Date is not null; /* Calculating the average shipping days */

update orders_copy
set Shipping_Date = DATEADD(day,(select avg(DATEDIFF(day, Order_Date, Shipping_Date))
								 from orders_copy
                                 where Shipping_Date is not null), Order_Date)
where Shipping_Date is null
and Delivery_Status in ('Delivered', 'Shipped'); /* Updating the Shipping_Date column with the average shipping days where delivery status 
													is 'delivered' or 'shipped' */

/* Removing Duplicate Records */
-- Finding the duplicates
select Order_ID,
	   Customer_ID,
	   Order_Date,
	   count(*)  as Duplicate_Count
from orders_copy
group by Order_ID,
	   Customer_ID,
	   Order_Date
having count(*) > 1; /* There are 50 duplicates */

-- Removing the duplicates using ROW_NUMBER
with DupCTE as
(select *,ROW_NUMBER() over(partition by order_id,
										 customer_id, 
										 order_date
						    order by order_id) as row_num
from orders_copy)
delete from DupCTE
where row_num > 1; /* Deleted all duplicates */

/* Standardizing Text Fields */
update customers_copy
set city = UPPER(left(city,1)) + LOWER(SUBSTRING(city,2,len(city)));

update customers_copy
set Customer_Name = TRIM(Customer_Name),
	City = TRIM(City); /* Removing extra spaces */

/* Fixing Invalid Data */
-- Age Cleaning
select *
from customers_copy
where Age < 18 or Age > 100; /* There are 20 impossible ages */

update customers_copy
set Age = null
where Age < 18 or Age > 100; /* Updating impossible ages to display NULL */

/* Email Validation */
-- Finding Invalid Emails
select *
from customers_copy
where Customer_Email not like '%@%.%'; /* There are 116 invalid emails */

-- Replacing
update customers_copy
set Customer_Email = 'Unknown Email'
where Customer_Email not like '%@%.%'; 

/* Handling Incorrect Categories */
select distinct product_category 
from products_copy; /* All categories are correct */

/* Validating Sales Calculations */
select *, 
	   Quantity * Unit_Price * (1 - Discount) as Correct_Sales
from order_items_copy
where Total_Sales <> Quantity * Unit_Price * (1 - Discount); /* There are 6019 incorrect Total_Sales */

-- Update Records
update order_items_copy
set Total_Sales = Quantity * Unit_Price * (1 - Discount)
where Total_Sales <> Quantity * Unit_Price * (1 - Discount);

/* Identifying Outliers */
-- Quantity Column
select min(Quantity) as Min_Order_Amt,
	   max(Quantity) as Max_Order_Amt
from order_items_copy; /* No extremely high order amounts */

-- Unit_Price Column
select min(Unit_Price) as Min_Price,
	   max(Unit_Price) as Max_Price
from products_copy; /* No unrealistic product prices */

-- Total_Sales Column
select min(Total_Sales) as Min_Sale,
	   max(Total_Sales) as Max_Sale
from order_items_copy; /* No extremely large transactions */

-- Discount Column
select min(Discount) as Min_Discount,
       max(Discount) as Max_Discount
from order_items_copy; /* The value range is appropriate (1 > Discount >= 0) */

/* Final Data Quality Checks */
-- No Duplicates 
-- No NULLs

-- Checking Relationships
select * 
from orders_copy o
left join customers_copy c
on o.Customer_ID = c.Customer_ID
where c.Customer_ID is null; /* There are no unmatched records between orders and customers table */

select * 
from order_items_copy oi
left join orders_copy o
on oi.Order_ID = o.Order_ID
where o.Order_ID is null; /* There are no unmatched records between the order_items and orders tables */

select *
from order_items_copy oi
left join products_copy p
on oi.Product_ID = p.Product_ID
where p.Product_ID is null; /* There are no sales records referencing products that don't exist */




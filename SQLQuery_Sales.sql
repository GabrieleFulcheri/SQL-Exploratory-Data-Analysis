SELECT * 
FROM [sql_cleaning].[dbo].[Sales$]

--DATA CLEANING 

--First of all, it is possible to notice that the column Date contains time data that it is not useful

SELECT CAST(LEFT(Date, 11) AS date) as Purchase_Date
FROM [sql_cleaning].[dbo].[Sales$] --to obtain only the date information

update [sql_cleaning].[dbo].[Sales$]
set Date = CAST(LEFT(Date, 11) AS date)
FROM [sql_cleaning].[dbo].[Sales$] ----It doesn't work. I need to figure out a different way to clean it

alter table [sql_cleaning].[dbo].[Sales$]
add Purchase_Day as date  

alter table [sql_cleaning].[dbo].[Sales$]
drop column Date 

SELECT  CAST(CONCAT( Day,' ',Month,' ', Year) as date) as Purchase_Day
FROM [sql_cleaning].[dbo].[Sales$]

 ALTER TABLE [sql_cleaning].[dbo].[Sales$]
 ADD  Purchase_Day date

UPDATE [Sales$]
SET Purchase_Day = CAST(CONCAT( Day,' ',Month,' ', Year) as date) 
FROM [sql_cleaning].[dbo].[Sales$]

--Then, we transform the Months in Month column from text string to number, in order to be able to use correctly the ORDER BY statement 

SELECT MONTH(Purchase_Day) as Month 
FROM [sql_cleaning].[dbo].[Sales$]

UPDATE [sql_cleaning].[dbo].[Sales$]
SET Month = cast(MONTH(Purchase_Day) as nvarchar)

--In order to check if the other columns are consistent, it is useful to control the distinct values and check for any null values

SELECT DISTINCT Customer_Gender 
FROM [sql_cleaning].[dbo].[Sales$]

SELECT DISTINCT Age_Group
FROM [sql_cleaning].[dbo].[Sales$]

SELECT DISTINCT Product
FROM [sql_cleaning].[dbo].[Sales$]
ORDER BY Product

SELECT DISTINCT Product_Category 
FROM [sql_cleaning].[dbo].[Sales$]

SELECT DISTINCT Sub_Category 
FROM [sql_cleaning].[dbo].[Sales$]

SELECT DISTINCT Country, State 
FROM [sql_cleaning].[dbo].[Sales$]
ORDER BY Country

--Checking for null values
SELECT *
FROM [sql_cleaning].[dbo].[Sales$]
WHERE Country is null OR Customer_Gender is null OR [Country] is null OR State is null
or Product_Category is null
OR Sub_Category is null
OR Product is null
OR Order_Quantity is null
OR Unit_Cost is null
OR Unit_Price is null  --there aren't null values

--Regarding the profit, cost and Revenue columns, it is clear that the data are not consistent, since the values don't match


SELECT Total_Revenue-Total_Cost as Total_Profit
FROM  (SELECT Order_Quantity*Unit_Cost as Total_Cost,
       Order_Quantity*Unit_Price as Total_Revenue
	   FROM [sql_cleaning].[dbo].[Sales$]) [Sales$]

ALTER TABLE [sql_cleaning].[dbo].[Sales$]
ADD  Total_Cost numeric,

ALTER TABLE [sql_cleaning].[dbo].[Sales$]
ADD Total_Revenue numeric,
    Total_Profit numeric

UPDATE [sql_cleaning].[dbo].[Sales$]
SET Total_Cost = Order_Quantity*Unit_Cost,
    Total_Revenue = Order_Quantity*Unit_Price

UPDATE [sql_cleaning].[dbo].[Sales$]
SET Total_Profit = Total_Revenue-Total_Cost

alter table [sql_cleaning].[dbo].[Sales$]
drop column Profit, Cost, Revenue --In order to eliminate the columns with inconsistent data

 
--DATA ANALYSIS

--Our goal is to define the main targets of the various products, identify the most valuable items and gain insight on the sales trends. 
--We have five types of demographic information about customers and (i) two of them are part of a larger set(namely Customer_Age and State) and (ii) gender seems a too large set to have a meaningful customer segmentation
--Hence, customer Age_Group seems to be the most valid category for customer analysis 

--Let's test the difference in sales among the two gender in order to verify if gender is a interesting category for analysis

--PART 1: Product analysis, which are the most sold and profitable products?

SELECT distinct Product, SUM(Order_quantity) as Total_Quantity_Sold_M, sum(Total_Profit) as Total_Profit_Gained_M
FROM [sql_cleaning].[dbo].[Sales$]
where Customer_Gender = 'M'
GROUP BY Product
ORDER BY Total_Quantity_Sold_M desc --for the most sold items among males. To focus on the most profitable times it is sufficient to ORDER BY Total_Profit_Gained_M


--It is possible to notice that the Total Revenue from the Patch Kit/8 Patches is equal to the amount of product sold. Let's check if there is something incorrect

SELECT *
FROM [sql_cleaning].[dbo].[Sales$]
where Product= 'Patch Kit/8 Patches' --There is nothing incorrect, since the profit per item sold is 1

--let's now consider the other gender

SELECT distinct Product, SUM(Order_quantity) as Total_Quantity_Sold_F, SUM(Total_Profit) as Total_Profit_Gained_F
FROM [sql_cleaning].[dbo].[Sales$]
WHERE Customer_Gender = 'F'
GROUP BY Product
ORDER BY Total_Quantity_Sold_F desc

--Let's unite these two tables with a CTE 

WITH CTE_FSales as (SELECT distinct Product, SUM(Order_quantity) as Total_Quantity_Sold_F, SUM(Total_Profit) as Total_Profit_Gained_F
                    FROM [sql_cleaning].[dbo].[Sales$]
                    WHERE Customer_Gender = 'F'
                    GROUP BY Product), 
     CTE_MSales as (SELECT distinct Product as  Product_M, SUM(Order_quantity) as Total_Quantity_Sold_M, sum(Total_Profit) as Total_Profit_Gained_M
                    FROM [sql_cleaning].[dbo].[Sales$]
                    WHERE Customer_Gender = 'M'
                    GROUP BY Product)
SELECT distinct  Product, Total_Quantity_Sold_F, Total_Profit_Gained_F, Total_Quantity_Sold_M, Total_Profit_Gained_M
FROM CTE_FSales
FULL OUTER JOIN  CTE_MSales ON CTE_MSales.Product_M = CTE_FSales.Product
ORDER BY CTE_FSales.Total_Quantity_Sold_F desc, CTE_MSales.Total_Quantity_Sold_M desc --Answer Question 1

--Since there is not an important difference in customers' behaviour if gender is considered, let's focus on the differences among the age groups

SELECT distinct Product, 
                Age_Group, 
				SUM(Order_Quantity) over (partition by Product, Age_Group) as Total_Quantity,
				SUM(Total_Profit) over (Partition by Product, Age_Group) as Total_Profit_Age_Groups
FROM [sql_cleaning].[dbo].[Sales$]
ORDER BY Age_Group, Total_Profit_Age_Groups desc

SELECT distinct Product, 
				SUM(Order_Quantity) over (partition by Product) as Total_Quantity,
				SUM(Total_Profit) over (Partition by Product) as Total_Profit_Age_Groups
FROM [sql_cleaning].[dbo].[Sales$]
WHERE Age_Group = 'Adults (35-64)'
ORDER BY Total_Quantity desc  --This query specify a particular Age_Group and focus on the most sold item, rather than on the most profitable
                              --To obtain data about a different Age Group it is sufficient to specify it in the where statement
--e.g.

SELECT distinct Product, sum(Order_Quantity) over (partition by Product) as Total_Quantity
FROM [sql_cleaning].[dbo].[Sales$]
WHERE Age_Group = 'Youth (<25)'
ORDER BY Total_Quantity desc


--Total sales and profit for each Age Group

SELECT DISTINCT Age_Group, 
                SUM(Order_Quantity) over (partition by Age_Group) as Total_Quantity,
				SUM(Total_Profit) over (Partition by Age_Group) as Total_Profit_Age_Groups,
				SUM(Total_Revenue) over (Partition by Age_Group) as Total_Revenue_Age_Groups
FROM [sql_cleaning].[dbo].[Sales$]
  
ORDER BY Total_Profit_Age_Groups desc

--Let's add the Profit ratio for each age group using CTE and examine the total quantity, profit and revenue for each age group in each year

WITH CTE_Age_Group_Sales as 
                (SELECT DISTINCT Age_Group, Year,
                SUM(Order_Quantity) over (partition by Age_Group, Year) as Total_Quantity,
				SUM(Total_Profit) over (Partition by Age_Group, Year) as Total_Profit_Age_Groups,
				SUM(Total_Revenue) over (Partition by Age_Group, Year) as Total_Revenue_Age_Groups
FROM [sql_cleaning].[dbo].[Sales$])

SELECT DISTINCT Age_Group, 
                Year,
                Total_Quantity, 
				Total_Profit_Age_Groups, 
				Total_Revenue_Age_Groups,
                Cast(Cast((Total_Profit_Age_Groups/Total_Revenue_Age_Groups)*100 as decimal(18,2)) as varchar(5)) + '%' as  Total_Profit_Percentuage
FROM CTE_Age_Group_Sales
GROUP BY Year, Age_Group, Total_Quantity, Total_Profit_Age_Groups, 
				Total_Revenue_Age_Groups
ORDER BY Year, Total_Profit_Age_Groups desc --as We can see, while Senior are by far those who buy the least amount of items. However, their Profit Percentuage is the highest among the groups

--Let's explore what kind of items Seniors buy
SELECT DISTINCT Product, sum(Order_Quantity) as Total_Purchase
FROM [sql_cleaning].[dbo].[Sales$]
WHERE Age_Group = 'Seniors (64+)'
GROUP BY Product
order by Total_Purchase DESC

--Since We have found interesting data about percentuage of profit in Age Groups, let's add to each item its profit percentuage 

ALTER TABLE [sql_cleaning].[dbo].[Sales$]
ADD Unit_Profit_Percentuage decimal(18,2)

SELECT cast(cast(((Unit_Price-Unit_Cost)/Unit_Price)*100 as numeric(18,2)) as varchar(5)) +' %' 
FROM [sql_cleaning].[dbo].[Sales$]

UPDATE [sql_cleaning].[dbo].[Sales$]
SET Unit_Profit_Percentuage = cast(cast(((Unit_Price-Unit_Cost)/Unit_Price)*100 as numeric(18,2)) as varchar(5))
 
SELECT concat(Unit_Profit_Percentuage, ' %') 
FROM [sql_cleaning].[dbo].[Sales$]

ALTER TABLE [sql_cleaning].[dbo].[Sales$]
ADD Unit_Profit int 

SELECT Unit_Price-Unit_Cost 
FROM [sql_cleaning].[dbo].[Sales$]

UPDATE [sql_cleaning].[dbo].[Sales$]
SET Unit_Profit = Unit_Price-Unit_Cost 

--let's conclude the product analysis highlighting the highest values for each product
--For example: Which is the product with the highest unit profit percentuage?

SELECT distinct a.Product, a.Unit_Profit_Percentuage
FROM (SELECT distinct Product, 
             Unit_Profit_Percentuage,
			 ROW_NUMBER() over (ORDER BY Unit_Profit_Percentuage desc) as ranking
      FROM [sql_cleaning].[dbo].[Sales$]
	  GROUP BY Product, Unit_Profit_Percentuage) as a
WHERE ranking = 1  --Using the structure of this query, it is possible to find the min and max values for each product information and column in general



--PART 2: Sales's trends

--How did the total profit change over the period considered?

SELECT DISTINCT Year, 
                SUM(Total_Profit) over (partition by Year) as Annual_Profit, 
				SUM(Order_Quantity) over (partition by Year) as Annual_Items_Sold
FROM [sql_cleaning].[dbo].[Sales$]
ORDER BY year  --Answer 3.1: Sales has more than doubled over the 6 years considered, after an initial steady trend 

--Which is the day with the highest number of items sold in each year?


WITH CTE_DailySales AS (SELECT Purchase_Day, 
                        Year, 
                        SUM(Order_Quantity) as Daily_Quantity_Sold,
                        ROW_NUMBER() OVER(PARTITION BY Year ORDER BY SUM(Order_Quantity) DESC) as rank
                        FROM [sql_cleaning].[dbo].[Sales$]
                        GROUP BY Purchase_Day, Year)
SELECT   
    *
FROM 
    CTE_DailySales
WHERE rank = 1  

-- What is the sale's trend for adult women?

SELECT DISTINCT Year, 
       SUM(Order_Quantity) over (partition by Year) as Annual_Items_Sold,
	   SUM(Total_Profit) over (partition by Year) as Annual_Profit
FROM [sql_cleaning].[dbo].[Sales$]
WHERE Customer_Gender = 'F' and Age_Group = 'Adults (35-64)'
ORDER BY Year  --With the same query it is possible to explore the trends regarding the remaining gender and age groups.


--Let's now have a look at the annual items sold and profit for each age category and the variations of thesse values across the year considered (in percentuage)


CREATE VIEW [Annual_Sales_Report] as 

WITH CTE_Sales_Variation_Adults as 
                            
                          (SELECT DISTINCT Year, 
                          SUM(Order_Quantity) over (partition by Year) as Annual_Items_Sold_A,
	                      SUM(Total_Profit) over (partition by Year) as Annual_Profit_A
                          FROM [sql_cleaning].[dbo].[Sales$]
                          WHERE Customer_Gender = 'M' and Age_Group = 'Adults (35-64)'),

     CTE_Sales_Variation_Youth as 
	                      
						  (SELECT DISTINCT Year AS Year_Y, 
                          SUM(Order_Quantity) over (partition by Year) as Annual_Items_Sold_Y,
	                      SUM(Total_Profit) over (partition by Year) as Annual_Profit_Y
                          FROM [sql_cleaning].[dbo].[Sales$]
                          WHERE Customer_Gender = 'M' and Age_Group = 'Youth (<25)'),
	 
	 CTE_Sales_Variation_YA AS 

	                      (SELECT DISTINCT Year AS Year_YA, 
                          SUM(Order_Quantity) over (partition by Year) as Annual_Items_Sold_YA,
	                      SUM(Total_Profit) over (partition by Year) as Annual_Profit_YA
                          FROM [sql_cleaning].[dbo].[Sales$]
                          WHERE Customer_Gender = 'M' and Age_Group = 'Young Adults (25-34)'),

	 CTE_Sales_Variation_Seniors AS 
	     
		                 (SELECT DISTINCT Year AS Year_S, 
                          SUM(Order_Quantity) over (partition by Year) as Annual_Items_Sold_Seniors,
	                      SUM(Total_Profit) over (partition by Year) as Annual_Profit_Seniors
                          FROM [sql_cleaning].[dbo].[Sales$]
                          WHERE Customer_Gender = 'M' and Age_Group = 'Seniors (64+)')

SELECT Year, Annual_Items_Sold_A,
       CONCAT(CAST(((Annual_Items_Sold_A - LAG(Annual_Items_Sold_A) OVER (ORDER BY Year))/LAG(Annual_Items_Sold_A) OVER (ORDER BY Year)) *100 AS numeric(18,2)), '%') AS Variation_Adults,
	   Annual_Items_Sold_Y,
	   CONCAT(CAST(((Annual_Items_Sold_Y - LAG(Annual_Items_Sold_Y) OVER (ORDER BY Year_Y))/LAG(Annual_Items_Sold_Y) OVER (ORDER BY Year_Y)) *100 AS numeric(18,2)), '%') AS Variation_Youth,
	   Annual_Items_Sold_YA,
	   CONCAT(CAST(((Annual_Items_Sold_YA - LAG(Annual_Items_Sold_YA) OVER (ORDER BY Year_YA))/LAG(Annual_Items_Sold_YA) OVER (ORDER BY Year_YA)) *100 AS numeric(18,2)), '%') AS Variation_YoungAdults,
	   Annual_Items_Sold_Seniors,
	   CONCAT(CAST(((Annual_Items_Sold_Seniors - LAG(Annual_Items_Sold_Seniors) OVER (ORDER BY Year_S))/LAG(Annual_Items_Sold_Seniors) OVER (ORDER BY Year_S)) *100 AS numeric(18,2)), '%') AS Variation_Seniors

FROM CTE_Sales_Variation_Adults
FULL OUTER JOIN CTE_Sales_Variation_Youth ON CTE_Sales_Variation_Adults.Year=CTE_Sales_Variation_Youth.Year_Y
FULL OUTER JOIN CTE_Sales_Variation_YA ON CTE_Sales_Variation_Adults.Year=CTE_Sales_Variation_YA.Year_YA
FULL OUTER JOIN CTE_Sales_Variation_Seniors ON CTE_Sales_Variation_Adults.Year=CTE_Sales_Variation_Seniors.Year_S
GROUP BY Year, Year_Y, Year_YA, Year_S, Annual_Items_Sold_A, Annual_Items_Sold_Y, Annual_Items_Sold_YA, Annual_Items_Sold_Seniors

--Trends for profits across the different age groups

CREATE VIEW [Annual_Profit_Report] as

WITH CTE_Sales_Variation_Adults as 
                            
                          (SELECT DISTINCT Year, 
                          SUM(Order_Quantity) over (partition by Year) as Annual_Items_Sold_A,
	                      SUM(Total_Profit) over (partition by Year) as Annual_Profit_A
                          FROM [sql_cleaning].[dbo].[Sales$]
                          WHERE Customer_Gender = 'M' and Age_Group = 'Adults (35-64)'),

     CTE_Sales_Variation_Youth as 
	                      
						  (SELECT DISTINCT Year AS Year_Y, 
                          SUM(Order_Quantity) over (partition by Year) as Annual_Items_Sold_Y,
	                      SUM(Total_Profit) over (partition by Year) as Annual_Profit_Y
                          FROM [sql_cleaning].[dbo].[Sales$]
                          WHERE Customer_Gender = 'M' and Age_Group = 'Youth (<25)'),
	 
	 CTE_Sales_Variation_YA AS 

	                      (SELECT DISTINCT Year AS Year_YA, 
                          SUM(Order_Quantity) over (partition by Year) as Annual_Items_Sold_YA,
	                      SUM(Total_Profit) over (partition by Year) as Annual_Profit_YA
                          FROM [sql_cleaning].[dbo].[Sales$]
                          WHERE Customer_Gender = 'M' and Age_Group = 'Young Adults (25-34)'),

	 CTE_Sales_Variation_Seniors AS 
	     
		                 (SELECT DISTINCT Year AS Year_S, 
                          SUM(Order_Quantity) over (partition by Year) as Annual_Items_Sold_Seniors,
	                      SUM(Total_Profit) over (partition by Year) as Annual_Profit_Seniors
                          FROM [sql_cleaning].[dbo].[Sales$]
                          WHERE Customer_Gender = 'M' and Age_Group = 'Seniors (64+)')

SELECT Year, Annual_Profit_A, 
       CONCAT(CAST(((Annual_Profit_A - LAG(Annual_Profit_A) OVER (ORDER BY Year))/LAG(Annual_Profit_A) OVER (ORDER BY Year)) *100 AS numeric(18,2)), '%') AS Profit_Variation_Adults,
	   Annual_Profit_Y,
	   CONCAT(CAST(((Annual_Profit_Y - LAG(Annual_Profit_Y) OVER (ORDER BY Year_Y))/LAG(Annual_Profit_Y) OVER (ORDER BY Year_Y)) *100 AS numeric(18,2)), '%') AS Profit_Variation_Youth,
	   Annual_Profit_YA,
	   CONCAT(CAST(((Annual_Profit_YA - LAG(Annual_Profit_YA) OVER (ORDER BY Year))/LAG(Annual_Profit_YA) OVER (ORDER BY Year_YA)) *100 AS numeric(18,2)), '%') AS Profit_Variation_YoungAdults,
	   Annual_Profit_Seniors,
	   CONCAT(CAST(((Annual_Profit_Seniors - LAG(Annual_Profit_Seniors) OVER (ORDER BY Year_S))/LAG(Annual_Profit_Seniors) OVER (ORDER BY Year_S)) *100 AS numeric(18,2)), '%') AS Profit_Variation_Seniors

FROM CTE_Sales_Variation_Adults
FULL OUTER JOIN CTE_Sales_Variation_Youth ON CTE_Sales_Variation_Adults.Year=CTE_Sales_Variation_Youth.Year_Y
FULL OUTER JOIN CTE_Sales_Variation_YA ON CTE_Sales_Variation_Adults.Year=CTE_Sales_Variation_YA.Year_YA
FULL OUTER JOIN CTE_Sales_Variation_Seniors ON CTE_Sales_Variation_Adults.Year=CTE_Sales_Variation_Seniors.Year_S
GROUP BY Year, Year_Y, Year_YA, Year_S, Annual_Profit_A, Annual_Profit_Y, Annual_Profit_YA, Annual_Profit_Seniors  

--Let's take a peek of our new views

SELECT * 
FROM Annual_Sales_Report

SELECT *
FROM Annual_Profit_Report

--Finally, let's compare countries. 
--Which country was the least profitable in 2014?

SELECT distinct a.Country, a.Profit
FROM (SELECT distinct Country, 
             Year,
             SUM(Total_Profit) as Profit,
			 ROW_NUMBER() over (PARTITION BY Year ORDER BY SUM(Total_Profit)) as ranking
      FROM [sql_cleaning].[dbo].[Sales$]
	  GROUP BY Country, Year) as a
WHERE ranking = 1 AND Year = 2014 --With this query it is possible to answer the same question for each different year and demoghraphic information


CREATE DATABASE ENERGYDB;
USE ENERGYDB;

-- 1. country table
CREATE TABLE country (
    CID VARCHAR(10) PRIMARY KEY,
    Country VARCHAR(100) UNIQUE
);
desc country;

SELECT * FROM COUNTRY;

-- 2. emission_3 table
CREATE TABLE emission (
    country VARCHAR(100),
    energy_type VARCHAR(50),
    year INT,
    emission INT,
    per_capita_emission DOUBLE,
    FOREIGN KEY (country) REFERENCES country(Country)
);

DESC EMISSION;

SELECT * FROM EMISSION;


-- 3. population table
CREATE TABLE population (
    countries VARCHAR(100),
    year INT,
    Value DOUBLE,
    FOREIGN KEY (countries) REFERENCES country(Country)
);

desc population;

SELECT * FROM POPULATION;

-- 4. production table
CREATE TABLE production (
    country VARCHAR(100),
    energy VARCHAR(50),
    year INT,
    production INT,
    FOREIGN KEY (country) REFERENCES country(Country)
);

desc production;

SELECT * FROM PRODUCTION;

-- 5. gdp_3 table
CREATE TABLE gdp (
    Country VARCHAR(100),
    year INT,
    Value DOUBLE,
    FOREIGN KEY (Country) REFERENCES country(Country)
);

desc gdp;

SELECT * FROM GDP;

-- 6. consumption table
CREATE TABLE consumption (
    country VARCHAR(100),
    energy VARCHAR(50),
    year INT,
    consumption INT,
    FOREIGN KEY (country) REFERENCES country(Country)
);

DESC CONSUMPTION;

SELECT * FROM CONSUMPTION;

-- Data Analysis Questions
-- 1.What is the total emission per country for the most recent year available?
SELECT 
    COUNTRY, YEAR, SUM(EMISSION) AS TOTAL_EMISSION
FROM
    EMISSION
WHERE YEAR = (select MAX(YEAR) FROM EMISSION)
GROUP BY COUNTRY,YEAR
order by total_emission desc
limit 10;

-- 2.What are the top 5 countries by GDP in the most recent year?

SELECT 
    COUNTRY, YEAR, VALUE
FROM
    GDP
WHERE
    YEAR = (SELECT 
            MAX(YEAR)
        FROM
            GDP)
ORDER BY VALUE DESC
LIMIT 5;

-- 3.Compare energy production and consumption by country and year. 
select * from production;
select * from consumption;
SELECT 
    SUM(p.production) AS total_production,
    SUM(c.consumption) AS total_consumption,
    p.country,
    p.year
FROM production p
JOIN consumption c ON p.country = c.country 
                 AND p.year = c.year 
                 AND p.energy = c.energy
GROUP BY p.country,  p.year  
ORDER BY p.country, p.year;

-- 4.Which energy types contribute most to emissions across all countries?
select * from emission;

select energy_type, sum(emission) as emission
from emission
group by energy_type 
order by emission desc ;

-- Trend Analysis Over Time
-- 5.How have global emissions changed year over year?
WITH yearly AS (
    SELECT year, SUM(emission) AS total_emissions
    FROM emission
    GROUP BY year
)
SELECT
    year,
    total_emissions,
    ROUND(
        (total_emissions - LAG(total_emissions) OVER (ORDER BY year))
        / NULLIF(LAG(total_emissions) OVER (ORDER BY year), 0) * 100,
        2
    ) AS yoy_growth_percent
FROM yearly
ORDER BY year;

select year, sum(emission) as total_emission,
ROUND(
        (sum(emission) - LAG(sum(emission)) OVER (ORDER BY year))
        / NULLIF(LAG(sum(emission)) OVER (ORDER BY year), 0) * 100,
        2
    ) AS yoy_growth_percent
from emission 
group by year;




-- 6.What is the trend in GDP for each country over the given years?
select * from gdp;
select country,year,sum(value) as gdp,ROUND(
        (SUM(value) - LAG(SUM(value)) OVER (PARTITION BY country ORDER BY year))
        / NULLIF(LAG(SUM(value)) OVER (PARTITION BY country ORDER BY year), 0) * 100,
        2)
        as yoy_growth_percent
        from gdp
        group by country, year
        order by gdp desc;
        
        
SELECT country, year, value as gdp_3
FROM gdp
ORDER BY country, year desc;


        
-- 7.How has population growth affected total emissions in each country?
select * from population;
select * from emission;
SELECT 
    p.countries,
    p.year,
    p.value AS popu,
    SUM(e.emission) AS total_em,ROUND(
        (SUM(emission) - LAG(SUM(emission)) OVER (PARTITION BY country ORDER BY year))
        / NULLIF(LAG(SUM(emission)) OVER (PARTITION BY country ORDER BY year), 0) * 100,
        2)
        as yoy_emission_growth,
    ROUND(
        (SUM(p.value) - LAG(SUM(p.value)) OVER (PARTITION BY countries ORDER BY year))
        / NULLIF(LAG(SUM(p.value)) OVER (PARTITION BY countries ORDER BY year), 0) * 100,
        2)
        as yoy_popu_growth        
FROM population p
JOIN emission e ON p.countries = e.country AND p.year = e.year  -- Fixed join!
GROUP BY p.countries, p.year, p.value
ORDER BY p.countries, p.year;


SELECT e.country,
       e.year,
       p.Value AS population,
       SUM(e.emission) AS total_emissions
FROM emission e
JOIN population p
  ON e.country = p.countries
 AND e.year = p.year
GROUP BY e.country, e.year, p.Value
ORDER BY e.country, e.year;



-- 8.Has energy consumption increased or decreased over the years for major economies?
select * from consumption;
 WITH top_economies AS (
    SELECT country
    FROM gdp
    GROUP BY country
    ORDER BY MAX(value) DESC
    LIMIT 5
),
country_year AS (
    SELECT
        con.country,
        con.year,
        SUM(con.consumption) AS total_consumption,
        gdp.value AS gdp
    FROM consumption con
    JOIN gdp gdp 
      ON con.country = gdp.country 
     AND con.year   = gdp.year
    WHERE con.country IN (SELECT country FROM top_economies)
    GROUP BY con.country, con.year, gdp.value
)
SELECT
    country,
    year,
    total_consumption,
    gdp,
    total_consumption 
      - LAG(total_consumption) OVER (PARTITION BY country ORDER BY year) AS yoy_change
FROM country_year
ORDER BY country, year;


WITH major_economies AS (
    SELECT Country
    FROM gdp
    WHERE year = (SELECT MAX(year) FROM gdp)
    ORDER BY Value DESC
    LIMIT 5
),
consumption_trend AS (
    SELECT c.country,
           c.year,
           SUM(c.consumption) AS total_consumption
    FROM consumption c
    JOIN major_economies m
      ON c.country = m.Country
    GROUP BY c.country, c.year
)
SELECT *
FROM consumption_trend
ORDER BY country, year;

-- 9.What is the average yearly change in emissions per capita for each country?
WITH yearly_change AS (
    SELECT 
        country,
        year,
        per_capita_emission,
        LAG(per_capita_emission) OVER (PARTITION BY country ORDER BY year) AS prev_year_emission,
        per_capita_emission - LAG(per_capita_emission) OVER (PARTITION BY country ORDER BY year) AS changee
    FROM emission
)
SELECT 
    country,
    AVG(changee) AS avg_yearly_change
FROM yearly_change
WHERE changee IS NOT NULL
GROUP BY country
ORDER BY avg_yearly_change DESC;


-- Ratio & Per Capita Analysis
-- 10.What is the emission-to-GDP ratio for each country by year?
SELECT 
    e.country,
    e.year,
    SUM(e.emission) AS total_emission,
    g.value AS gdp,
    SUM(e.emission) / g.value AS emission_to_gdp_ratio
FROM emission e
JOIN gdp g 
    ON e.country = g.country 
   AND e.year = g.year
GROUP BY e.country, e.year, g.value
ORDER BY e.country, e.year;


-- 11.What is the energy consumption per capita for each country over the last decade?
select * from population;
select * from consumption;
select c.country ,
 c.year,
 c.total_consumption/ p.value as per_capita_En_Consumption
from (select
 country, 
 year,sum(consumption) as total_consumption
from consumption 
group by country, year) as c

join population p
on c.country=p.countries
 and c.year=p.year
 WHERE c.year >= 2015
ORDER BY c.country, c.year;


-- 12.How does energy production per capita vary across countries?
select * from population;
select p.country ,p.year,total_production/pop.value as percapita_production
from (select country , 
year , 
sum(production) as total_production
from production
group by country, year) as p
join population pop
on p.country=pop.countries
and p.year= pop.year;


-- 13.Which countries have the highest energy consumption relative to GDP?
WITH latest_year AS (
    SELECT MAX(year) AS max_year FROM consumption
),
country_agg AS (
    SELECT 
        c.country,
        SUM(c.consumption) AS total_consumption,
        SUM(g.value)       AS total_gdp
    FROM consumption c
    JOIN gdp g
      ON c.country = g.country 
     AND c.year    = g.year
    JOIN latest_year ly
      ON c.year = ly.max_year
    GROUP BY c.country
)
SELECT 
    country,
    total_consumption,
    total_gdp,
    total_consumption / total_gdp AS consumption_per_gdp
FROM country_agg
WHERE total_gdp > 0
ORDER BY consumption_per_gdp DESC;



-- 14.What is the correlation between GDP growth and energy production growth?
WITH gdp_growth AS (
    SELECT
        country,
        year,
        value AS gdp,
        LAG(value) OVER (PARTITION BY country ORDER BY year) AS prev_gdp,
        (value - LAG(value) OVER (PARTITION BY country ORDER BY year))
          / LAG(value) OVER (PARTITION BY country ORDER BY year) AS gdp_growth
    FROM gdp
)
SELECT * 
FROM gdp_growth
WHERE prev_gdp IS NOT NULL;

SELECT g.Country,
       COR(g.Value, p.production) AS gdp_production_correlation
FROM gdp g
JOIN production p
  ON g.Country = p.country
 AND g.year = p.year
GROUP BY g.Country;


-- Global Comparisons
-- 15.What are the top 10 countries by population and how do their emissions compare?

select p.countries,(p.Value),sum(e.emission) as Total_emission from population p
join emission e
on p.countries = e.country
group by p.countries,p.Value
order by p.value desc
limit 10;


select p.countries, p.value from population as p join emission as e
on p.countries = e.country and p.year = e.year
where year = (select max(year) from population) 
group by p.countries
order by value desc
limit 10;

with latest_year as (
select max(year) as year
from population
),
latest_population as (
select p.countries, p.value, p.year
from population p
join latest_year y
on p.year = y 
)
select p.countries,p.value as population, sum(e.emission) as total_emission
from latest_population p
join emission e
on p.countries = e.country
group by p.countires,p.value
order by p.value desc
limit 10;

select emission from emission;






-- 16.Which countries have improved (reduced) their per capita emissions the most over the last decade?
select count(*) from emission;

SELECT country,
       MAX(per_capita_emission) - MIN(per_capita_emission) AS reduction
FROM emission
WHERE year >= (SELECT MAX(year) - 10 FROM emission)
GROUP BY country
ORDER BY reduction DESC;


-- 17.What is the global share (%) of emissions by country?
SELECT 
    country,
    (SUM(emission) / (SELECT 
            SUM(emission)
        FROM
            emission)) * 100 AS emission_share
FROM
    emission
GROUP BY country;

-- 18.What is the global average GDP, emission, and population by year?
SELECT 
    g.year,
    AVG(g.value) AS avg_gdp,
    AVG(e.emission) AS avg_emission,
    AVG(p.Value) AS avg_population
FROM
    gdp g
        JOIN
    emission e ON g.country = e.country
        AND g.year = e.year
        JOIN
    population p ON g.country = p.countries
        AND g.year = p.year
GROUP BY g.year;







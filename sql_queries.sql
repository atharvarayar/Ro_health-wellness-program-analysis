-- Use the relevant database
USE ro_health;

-- Yearly and monthly claim counts
WITH yearly_claims AS (
    SELECT 
        YEAR(claim_date) AS year_of_claim,
        MONTH(claim_date) AS month_claim,
        COUNT(claim_id) AS number_of_claims
    FROM claims
    GROUP BY YEAR(claim_date), MONTH(claim_date)
    ORDER BY YEAR(claim_date), MONTH(claim_date)
),

-- Number of claims by product category
claims_by_prodcat AS (
    SELECT 
        product_name,
        COUNT(claim_id) AS number_of_claims
    FROM claims
    GROUP BY product_name
),

-- Yearly total and average claim amounts
claims_tally AS (
    SELECT 
        SUM(claim_amount) AS total_claim_amt,
        AVG(claim_amount) AS average_claim_amt,
        YEAR(claim_date) AS year_ofclaim
    FROM claims
    GROUP BY YEAR(claim_date)
    ORDER BY YEAR(claim_date)
),

-- Aggregated claim data for each product for the year 2023
product_claims_agg AS (
    SELECT 
        product_name,
        COUNT(claim_id) AS number_of_times_claimed,
        SUM(claim_amount) AS total_claim_amount,
        AVG(claim_amount) AS avg_claim_amount
    FROM claims
    WHERE YEAR(claim_date) = 2023
    GROUP BY product_name
),

-- Claim volumes and amounts trend for selected hair and wellness products over time
claim_trends AS (
    SELECT 
        product_name,
        YEAR(claim_date) AS year_of_claim,
        MONTH(claim_date) AS month_of_claim,
        COUNT(claim_id) AS number_of_claims,
        SUM(claim_amount) AS total_claim_amount,
        AVG(claim_amount) AS avg_claim_amount
    FROM claims
    WHERE product_name IN ('Hair Growth Supplements', 'Hair Vitamins Trio', 'Detox + Debloat Vitamin', 'Vitamin B+ Advanced Complex')
    GROUP BY product_name, YEAR(claim_date), MONTH(claim_date)
    ORDER BY product_name, year_of_claim, month_of_claim
),

-- Unique customers with claim counts by year
unique_customers1 AS (
    SELECT 
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        YEAR(cl.claim_date) AS claim_year,
        COUNT(cl.claim_id) AS total_claims
    FROM customers c
    JOIN claims cl ON c.customer_id = cl.customer_id
    GROUP BY c.customer_id, customer_name, claim_year
),

-- Days between multiple claims for customers with multiple claims
claims_with_lag AS (
    SELECT
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        cl.claim_date,
        LAG(cl.claim_date) OVER (PARTITION BY c.customer_id ORDER BY cl.claim_date) AS prev_claim_date
    FROM customers c
    JOIN claims cl ON c.customer_id = cl.customer_id
),

claim_intervals AS (
    SELECT
        customer_id,
        customer_name,
        DATEDIFF(claim_date, prev_claim_date) AS days_between
    FROM claims_with_lag
    WHERE prev_claim_date IS NOT NULL
),

multiple_claim_customers AS (
    SELECT
        c.customer_id
    FROM claims cl
    JOIN customers c ON cl.customer_id = c.customer_id
    GROUP BY c.customer_id
    HAVING COUNT(*) > 1
),

average_days_between_claims AS (
    SELECT
        ci.customer_id,
        ci.customer_name,
        AVG(ci.days_between) AS avg_days_between_claims
    FROM claim_intervals ci
    JOIN multiple_claim_customers mc ON ci.customer_id = mc.customer_id
    GROUP BY ci.customer_id, ci.customer_name
),

-- Claims by region and year, including total and average claim amounts
claim_byregion AS (
    SELECT
        c.state,
        cl.claim_id,
        cl.claim_amount,
        YEAR(cl.claim_date) AS claim_year
    FROM customers c
    JOIN claims cl ON c.customer_id = cl.customer_id
),

claims_by_region_summary AS (
    SELECT
        state,
        claim_year,
        COUNT(claim_id) AS total_claims,
        SUM(claim_amount) AS total_claim_amount,
        AVG(claim_amount) AS average_claim_amount
    FROM claim_byregion
    GROUP BY state, claim_year
    ORDER BY claim_year, total_claim_amount DESC
),

-- Customers with multiple distinct plans
customers_multiple_plans AS (
    SELECT customer_id
    FROM customers
    GROUP BY customer_id
    HAVING COUNT(DISTINCT plan) > 1
),

-- Count of customers with multiple distinct plans
count_customers_multiple_plans AS (
    SELECT customer_id, COUNT(DISTINCT plan) AS distinct_plans
    FROM customers
    GROUP BY customer_id
    HAVING COUNT(DISTINCT plan) > 1
),

-- Product frequency as the second claimed product for customers with multiple claims
customer_claims AS (
    SELECT
        customer_id,
        product_name,
        claim_date,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY claim_date) AS claim_rank
    FROM claims
),

customers_multiple_claims AS (
    SELECT customer_id
    FROM claims
    GROUP BY customer_id
    HAVING COUNT(*) > 1
),

second_claim_products AS (
    SELECT 
        product_name,
        COUNT(*) AS times_bought_as_second_product
    FROM customer_claims cc
    JOIN customers_multiple_claims cmc ON cc.customer_id = cmc.customer_id
    WHERE claim_rank = 2
    GROUP BY product_name
    ORDER BY times_bought_as_second_product DESC
),

-- Overall coverage ratio
overall_coverage_ratio AS (
    SELECT 
        SUM(covered_amount) / SUM(claim_amount) AS overall_coverage_ratio
    FROM claims
),

-- Coverage ratio by product
coverage_ratio_by_product AS (
    SELECT 
        product_name,
        SUM(covered_amount) / SUM(claim_amount) AS coverage_ratio
    FROM claims
    GROUP BY product_name
    ORDER BY coverage_ratio DESC
),

-- Monthly and yearly claim summaries with growth calculations
monthly_summary AS (
    SELECT
        DATE_FORMAT(claim_date, '%Y-%m') AS year_month_col,
        COUNT(*) AS total_claims,
        SUM(claim_amount) AS total_claim_value
    FROM claims
    GROUP BY year_month_col
),

monthly_growth AS (
    SELECT
        year_month_col,
        total_claims,
        total_claim_value,
        LAG(total_claims) OVER (ORDER BY year_month_col) AS prev_month_claims,
        LAG(total_claim_value) OVER (ORDER BY year_month_col) AS prev_month_value
    FROM monthly_summary
),

yearly_summary AS (
    SELECT
        YEAR(claim_date) AS year,
        COUNT(*) AS total_claims,
        SUM(claim_amount) AS total_claim_value
    FROM claims
    GROUP BY year
),

yearly_growth AS (
    SELECT
        year,
        total_claims,
        total_claim_value,
        LAG(total_claims) OVER (ORDER BY year) AS prev_year_claims,
        LAG(total_claim_value) OVER (ORDER BY year) AS prev_year_value
    FROM yearly_summary
)

-- Final select examples
-- Uncomment the desired select query to get the results

-- 1. Unique customers with year-wise claim counts
-- SELECT * FROM unique_customers1;

-- 2. Average days between multiple claims for customers with multiple claims
-- SELECT * FROM average_days_between_claims;

-- 3. Claims by region summary
-- SELECT * FROM claims_by_region_summary;

-- 4. Customers with multiple distinct plans
-- SELECT * FROM count_customers_multiple_plans;

-- 5. Times products were bought as a second claim
-- SELECT * FROM second_claim_products;

-- 6. Overall coverage ratio
-- SELECT * FROM overall_coverage_ratio;

-- 7. Coverage ratio by product
-- SELECT * FROM coverage_ratio_by_product;

-- 8. Year-over-year claim growth
SELECT
  y.year,
  y.total_claims,
  y.total_claim_value,
  ROUND((y.total_claims - y.prev_year_claims) / NULLIF(y.prev_year_claims, 0) * 100, 2) AS yoy_claim_growth_pct,
  ROUND((y.total_claim_value - y.prev_year_value) / NULLIF(y.prev_year_value, 0) * 100, 2) AS yoy_value_growth_pct
FROM yearly_growth y
ORDER BY y.year;

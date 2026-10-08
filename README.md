# E-Commerce Analytics

<p align="center">
  <b>Analyzing sales, customers, products, payments, reviews and delivery performance using SQL and Power BI</b>
</p>

---

## 📌 About the Project

This project analyzes the **Brazilian Olist E-Commerce dataset** to understand how an e-commerce marketplace is performing across sales, customers, products, sellers, payments, reviews and delivery operations.

The project combines **SQL analysis, data preparation and Power BI visualization** to move from raw data to business insights.

The focus was not just on creating charts, but on answering practical business questions and identifying areas where the business can improve.

---

## 🎯 Business Questions

The analysis focuses on questions such as:

## Business Problems & SQL Analysis

The SQL analysis was built around practical business questions related to sales, customers, products, payments and delivery performance.

### 1. What is the overall sales and order performance?

```sql
WITH order_sales AS (
    SELECT
        order_id,
        SUM(price) AS total_sales,
        SUM(freight_value) AS total_freight
    FROM order_items
    GROUP BY order_id
)

SELECT
    COUNT(o.order_id) AS total_orders,

    COUNT(*) FILTER (
        WHERE o.order_status = 'delivered'
    ) AS delivered_orders,

    COUNT(*) FILTER (
        WHERE o.order_status = 'canceled'
    ) AS canceled_orders,

    ROUND(
        COALESCE(SUM(s.total_sales), 0)::numeric,
        2
    ) AS total_sales,

    ROUND(
        COALESCE(SUM(s.total_freight), 0)::numeric,
        2
    ) AS total_freight,

    ROUND(
        AVG(s.total_sales)::numeric,
        2
    ) AS average_order_value

FROM orders o
LEFT JOIN order_sales s
    ON o.order_id = s.order_id;
```

### 2. Which product categories generate the most sales?

```sql
SELECT
    COALESCE(
        NULLIF(TRIM(c.product_category_name_english), ''),
        NULLIF(TRIM(p.product_category_name), ''),
        'Unknown'
    ) AS product_category,

    COUNT(DISTINCT i.order_id) AS total_orders,

    COUNT(*) AS items_sold,

    ROUND(
        SUM(i.price)::numeric,
        2
    ) AS total_sales,

    ROUND(
        SUM(i.freight_value)::numeric,
        2
    ) AS total_freight

FROM order_items i

JOIN orders o
    ON i.order_id = o.order_id

JOIN products p
    ON i.product_id = p.product_id

LEFT JOIN category_translation c
    ON p.product_category_name = c.product_category_name

WHERE o.order_status = 'delivered'

GROUP BY 1

ORDER BY total_sales DESC;
```

### 3. Which states contribute the most sales?

```sql
WITH order_sales AS (
    SELECT
        order_id,
        SUM(price) AS total_sales
    FROM order_items
    GROUP BY order_id
)

SELECT
    c.customer_state,

    COUNT(DISTINCT o.order_id) AS total_orders,

    COUNT(DISTINCT c.customer_id) AS total_customers,

    ROUND(
        COALESCE(SUM(os.total_sales), 0)::numeric,
        2
    ) AS total_sales,

    ROUND(
        AVG(os.total_sales)::numeric,
        2
    ) AS average_order_value

FROM orders o

JOIN customers c
    ON o.customer_id = c.customer_id

LEFT JOIN order_sales os
    ON o.order_id = os.order_id

WHERE o.order_status = 'delivered'

GROUP BY c.customer_state

ORDER BY total_sales DESC;
```

### 4. Which payment methods are most widely used?

```sql
SELECT
    p.payment_type,

    COUNT(DISTINCT p.order_id) AS total_orders,

    ROUND(
        SUM(p.payment_value)::numeric,
        2
    ) AS total_payment_value,

    ROUND(
        AVG(p.payment_value)::numeric,
        2
    ) AS average_payment_value,

    ROUND(
        AVG(p.payment_installments)::numeric,
        2
    ) AS average_installments

FROM payments p

JOIN orders o
    ON p.order_id = o.order_id

WHERE o.order_status = 'delivered'

GROUP BY p.payment_type

ORDER BY total_payment_value DESC;
```

### 5. How efficient is the delivery operation?

```sql
SELECT
    COUNT(*) AS total_orders,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date
              <= order_estimated_delivery_date
    ) AS on_time_orders,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date
              > order_estimated_delivery_date
    ) AS late_orders,

    ROUND(
        COUNT(*) FILTER (
            WHERE order_delivered_customer_date
                  <= order_estimated_delivery_date
        ) * 100.0
        / NULLIF(COUNT(*), 0),
        2
    ) AS on_time_delivery_percentage

FROM orders

WHERE order_status = 'delivered'

  AND order_delivered_customer_date IS NOT NULL

  AND order_estimated_delivery_date IS NOT NULL;
```

### 6. Are customers making repeat purchases?

```sql
WITH customer_orders AS (
    SELECT
        o.customer_id,

        COUNT(DISTINCT o.order_id) AS total_orders,

        SUM(oi.price) AS total_sales

    FROM orders o

    JOIN order_items oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY o.customer_id
)

SELECT

    CASE
        WHEN total_orders = 1 THEN '1 Order'
        WHEN total_orders = 2 THEN '2 Orders'
        ELSE '3+ Orders'
    END AS customer_order_group,

    COUNT(*) AS total_customers,

    ROUND(
        SUM(total_sales)::numeric,
        2
    ) AS total_sales,

    ROUND(
        AVG(total_sales)::numeric,
        2
    ) AS avg_sales_per_customer

FROM customer_orders

GROUP BY
    CASE
        WHEN total_orders = 1 THEN '1 Order'
        WHEN total_orders = 2 THEN '2 Orders'
        ELSE '3+ Orders'
    END

ORDER BY MIN(total_orders);
```

### 7. How are customers distributed by RFM value?

```sql
WITH customer_rfm AS (
    SELECT
        o.customer_id,

        MAX(o.order_purchase_timestamp) AS last_order_date,

        COUNT(DISTINCT o.order_id) AS frequency,

        SUM(oi.price) AS monetary

    FROM orders o

    JOIN order_items oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY o.customer_id
),

rfm_scores AS (
    SELECT
        customer_id,

        last_order_date,

        frequency,

        monetary,

        NTILE(5) OVER (
            ORDER BY last_order_date DESC
        ) AS recency_score,

        NTILE(5) OVER (
            ORDER BY frequency
        ) AS frequency_score,

        NTILE(5) OVER (
            ORDER BY monetary
        ) AS monetary_score

    FROM customer_rfm
)

SELECT
    customer_id,

    last_order_date,

    frequency,

    ROUND(
        monetary::numeric,
        2
    ) AS monetary,

    CASE

        WHEN recency_score >= 4
         AND frequency_score >= 4
         AND monetary_score >= 4
            THEN 'High Value Customers'

        WHEN frequency_score >= 4
            THEN 'Frequent Customers'

        WHEN recency_score >= 4
            THEN 'Recent Customers'

        WHEN recency_score <= 2
         AND frequency_score <= 2
            THEN 'At-Risk / Inactive Customers'

        ELSE 'Regular Customers'

    END AS customer_segment

FROM rfm_scores

ORDER BY monetary DESC;
```

### 8. Does delivery delay relate to lower review scores?

```sql
WITH delivery_reviews AS (
    SELECT
        r.review_score,

        EXTRACT(
            EPOCH FROM (
                o.order_delivered_customer_date
                - o.order_estimated_delivery_date
            )
        ) / 86400.0 AS delay_days

    FROM reviews r

    JOIN orders o
        ON r.order_id = o.order_id

    WHERE o.order_status = 'delivered'

      AND o.order_delivered_customer_date IS NOT NULL

      AND o.order_estimated_delivery_date IS NOT NULL
)

SELECT

    CASE
        WHEN delay_days <= 0
            THEN 'On Time / Early'

        WHEN delay_days <= 3
            THEN '1-3 Days Late'

        WHEN delay_days <= 7
            THEN '4-7 Days Late'

        ELSE 'More Than 7 Days Late'
    END AS delivery_status,

    COUNT(*) AS total_reviews,

    ROUND(
        AVG(review_score)::numeric,
        2
    ) AS average_review_score

FROM delivery_reviews

GROUP BY 1

ORDER BY
    CASE
        WHEN MIN(delay_days) <= 0 THEN 1
        WHEN MIN(delay_days) <= 3 THEN 2
        WHEN MIN(delay_days) <= 7 THEN 3
        ELSE 4
    END;
```

### Complete SQL Analysis

The complete set of SQL queries covering sales, products, customers, sellers, payments, reviews, delivery and customer segmentation is available in [`sql/summery.sql`](sql/summery.sql).

## 📊 Project Highlights

| Area | Analysis |
|---|---|
| Sales | Overall sales, monthly trends and category contribution |
| Orders | Order volume and order-status distribution |
| Products | Product and category performance |
| Customers | Spending, order behavior and segmentation |
| Sellers | Seller sales and state-wise performance |
| Payments | Payment method and payment value analysis |
| Reviews | Review-score distribution and category-level ratings |
| Delivery | Delivery time and on-time performance |
| Geography | State-wise sales and performance |

---

## 🗂️ Dataset

The project uses the **Olist Brazilian E-Commerce dataset**.

The analysis brings together the following datasets:

- Customers
- Orders
- Order Items
- Products
- Sellers
- Payments
- Reviews
- Product Category Translation
- Geolocation

This allows the project to look at the business from both the **commercial side** and the **customer/operations side**.

---

## 🔗 Data Model

The main relationships used in the analysis can be represented as:

```text
                    ┌─────────────┐
                    │  Customers  │
                    └──────┬──────┘
                           │
                           ▼
                    ┌─────────────┐
                    │   Orders    │
                    └──────┬──────┘
                           │
          ┌────────────────┼────────────────┐
          ▼                ▼                ▼
   ┌────────────┐   ┌────────────┐   ┌────────────┐
   │ OrderItems │   │ Payments   │   │  Reviews   │
   └──────┬─────┘   └────────────┘   └────────────┘
          │
      ┌───┴────┐
      ▼        ▼
┌──────────┐ ┌──────────┐
│ Products │ │ Sellers  │
└────┬─────┘ └──────────┘
     │
     ▼
┌───────────────────────┐
│ Category Translation  │
└───────────────────────┘
```

### Important Data-Grain Consideration

An order can contain multiple products, so **order-level and order-item-level data were treated differently** during the analysis.

Where required, order counts were calculated using distinct `order_id` to avoid overcounting.

---

## 🧹 Data Preparation

Before analysis, the datasets were prepared and checked for consistency.

The preparation included:

- Reviewing data types
- Handling date fields
- Checking missing values
- Standardizing category information
- Connecting tables using keys
- Preparing data for SQL analysis
- Preparing the Power BI data model
- Checking order-level vs. item-level calculations

The goal was to make the analysis consistent across SQL and Power BI.

---

## 🧮 SQL Analysis

SQL was used to answer detailed business questions across multiple areas.

### Sales & Revenue
- Total sales
- Monthly sales trends
- Sales by category
- Sales by state
- Average order value
- Category contribution

### Customer Analysis
- Customer spending
- Customer order behavior
- Delivered-order customers
- Customer segmentation
- RFM analysis

### Product & Category Analysis
- Category rankings
- Category contribution
- Product performance
- Review performance by category

### Seller Analysis
- Seller sales
- Orders handled
- Items sold
- Freight value
- Seller state performance

### Payment Analysis
- Payment method distribution
- Payment value by payment type
- Monthly payment trends

### Review Analysis
- Review-score distribution
- Review percentage
- Reviews with comments
- Category-level review performance

### Delivery Analysis
- Average delivery time
- Fastest and slowest delivery
- Delivery time buckets
- On-time delivery
- Regional delivery performance

### SQL Techniques Used

- `JOIN`
- `GROUP BY`
- Aggregate Functions
- `CASE`
- `CTE`
- Subqueries
- Conditional Aggregation
- Window Functions

---

## 📈 Power BI Dashboard

The SQL analysis was converted into an interactive Power BI dashboard focused on the most important business metrics.

### Dashboard Sections

**Sales**
- Total Sales
- Monthly Sales Trend
- Top Categories
- Sales by State

**Orders**
- Total Orders
- Order Status Distribution
- Delivered Order %

**Customers**
- Customer Segments
- Review Ratings

**Operations**
- Delivery Performance
- Delivery Time by State
- Seller Performance

**Payments**
- Payment Method Distribution
- Payment Value

### Dashboard Preview

![E-Commerce Analytics Dashboard](images/dashboard.png)

---

## 🔎 Key Insights

### 1. Sales Growth

The dashboard shows an overall upward trend in sales activity across the available period, with approximately **R$13.59M in total sales** in the current dashboard analysis.

### 2. Leading Categories

**Health & Beauty, Watches & Gifts and Bed & Bath** are among the strongest-performing categories.

### 3. Geographic Concentration

**São Paulo (SP)** contributes the highest sales among the states analyzed.

This highlights the importance of the region while also pointing towards opportunities in lower-performing markets.

### 4. Order Fulfilment

Approximately **96.1% of orders were delivered**.

The remaining cancelled, unavailable and delayed orders represent opportunities to improve operational performance.

### 5. Payment Behaviour

**Credit card** is the dominant payment method, contributing approximately **73.84% of sales**.

### 6. Customer Satisfaction

Five-star reviews are the most common rating, with approximately **53K five-star reviews** in the dashboard analysis.

### 7. Delivery Performance

Delivery time varies across regions, making state-level and seller-level delivery analysis useful for identifying operational improvement areas.

### 8. Customer Segmentation

RFM analysis provides a way to identify different customer groups based on **recency, frequency and monetary value**, which can support more targeted retention strategies.

---

## 💡 Business Recommendations

Based on the analysis, the main areas for improvement are:

- Investigate cancelled and unavailable orders.
- Monitor delivery performance by state and seller.
- Protect inventory and service levels for high-performing categories.
- Explore growth opportunities in lower-performing states.
- Promote high-performing and highly-rated products.
- Investigate consistently low-rated products and sellers.
- Use customer segmentation for targeted retention strategies.
- Continue monitoring payment performance, especially credit-card transactions.
- Reconcile SQL and Power BI KPIs regularly.

---

## 🛠️ Tools & Technologies

### Data Analysis
`PostgreSQL` `SQL` `Excel`

### Business Intelligence
`Power BI` `Power Query` `DAX`

### Version Control
`Git` `GitHub` `Git LFS`

---

## 📁 Project Structure

```text
ecommerce-analytics/
│
├── dashboard/
│   └── Project 1 dashboard.pbix
│
├── data/
│   ├── Raw Data/
│   ├── processed Data/
│   ├── excel/
│   └── exports Data/
│
├── images/
│   └── dashboard.png
│
├── sql/
│   └── summery.sql
│
├── .gitattributes
└── README.md
```

---

## 🚀 How to Explore the Project

### 1. SQL Analysis

Go to:

```text
sql/summery.sql
```

This file contains the SQL queries used for the business analysis.

### 2. Power BI Dashboard

Open:

```text
dashboard/Project 1 dashboard.pbix
```

using Power BI Desktop.

### 3. Dataset

The raw and processed datasets are available inside:

```text
data/
```

---

## 📌 Project Outcome

This project brings together **data preparation, SQL analysis, business intelligence and visualization** to provide a consolidated view of e-commerce performance.

The analysis helps identify:

**What is happening → Where it is happening → What may need attention → What the business can investigate next**

---

## 👤 Author

### Rohit Kumar

**Data Analytics | SQL | Power BI | Excel**

[GitHub](https://github.com/rohitkumartomar2000-eng)

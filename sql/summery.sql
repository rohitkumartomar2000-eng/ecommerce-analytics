---Step 1 — Overall Sales KPI


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

    ROUND(COALESCE(SUM(s.total_sales), 0)::numeric, 2)
        AS total_sales,

    ROUND(COALESCE(SUM(s.total_freight), 0)::numeric, 2)
        AS total_freight,

    ROUND(AVG(s.total_sales)::numeric, 2)
        AS average_order_value

FROM orders o
LEFT JOIN order_sales s
    ON o.order_id = s.order_id;

---Bhai, Step 2 — Monthly Sales Trend 📊

WITH order_sales AS (
    SELECT
        order_id,
        SUM(price) AS sales
    FROM order_items
    GROUP BY order_id
)

SELECT
    TO_CHAR(DATE_TRUNC('month', o.order_purchase_timestamp), 'YYYY-MM')
        AS sales_month,

    COUNT(o.order_id) AS total_orders,

    ROUND(COALESCE(SUM(s.sales), 0)::numeric, 2)
        AS total_sales,

    ROUND(AVG(s.sales)::numeric, 2)
        AS average_order_value

FROM orders o
LEFT JOIN order_sales s
    ON o.order_id = s.order_id

WHERE o.order_status = 'delivered'

GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)

ORDER BY DATE_TRUNC('month', o.order_purchase_timestamp);


---Bhai, Step 3 — Category-wise Sales Analysis 
WITH category_map AS (
    SELECT
        product_category_name,
        MAX(product_category_name_english) AS product_category_name_english
    FROM category_translation
    GROUP BY product_category_name
)

SELECT
    COALESCE(
        NULLIF(TRIM(c.product_category_name_english), ''),
        NULLIF(TRIM(p.product_category_name), ''),
        'Unknown'
    ) AS product_category,

    COUNT(DISTINCT i.order_id) AS total_orders,

    COUNT(*) AS items_sold,

    ROUND(SUM(i.price)::numeric, 2) AS total_sales,

    ROUND(SUM(i.freight_value)::numeric, 2) AS total_freight,

    ROUND(AVG(i.price)::numeric, 2) AS average_item_price

FROM order_items i

JOIN orders o
    ON i.order_id = o.order_id

JOIN products p
    ON i.product_id = p.product_id

LEFT JOIN category_map c
    ON p.product_category_name = c.product_category_name

WHERE o.order_status = 'delivered'

GROUP BY 1

ORDER BY total_sales DESC;




----NEXT: Payment Method Analysis

SELECT
    p.payment_type,

    COUNT(DISTINCT p.order_id) AS total_orders,

    COUNT(*) AS payment_records,

    ROUND(SUM(p.payment_value)::numeric, 2) AS total_payment_value,

    ROUND(AVG(p.payment_value)::numeric, 2) AS average_payment_value,

    ROUND(AVG(p.payment_installments)::numeric, 2) AS average_installments

FROM payments p

JOIN orders o
    ON p.order_id = o.order_id

WHERE o.order_status = 'delivered'

GROUP BY p.payment_type

ORDER BY total_payment_value DESC;


---	NEXT: Seller Performance Analysis

SELECT
    s.seller_id,

    COUNT(DISTINCT i.order_id) AS total_orders,

    COUNT(*) AS items_sold,

    ROUND(SUM(i.price)::numeric, 2) AS total_sales,

    ROUND(SUM(i.freight_value)::numeric, 2) AS total_freight,

    ROUND(AVG(i.price)::numeric, 2) AS average_item_price

FROM order_items i

JOIN orders o
    ON i.order_id = o.order_id

JOIN sellers s
    ON i.seller_id = s.seller_id

WHERE o.order_status = 'delivered'

GROUP BY s.seller_id

ORDER BY total_sales DESC

LIMIT 20;



---NEXT: State-wise Sales Analysis

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

    ROUND(COALESCE(SUM(os.total_sales), 0)::numeric, 2) AS total_sales,

    ROUND(AVG(os.total_sales)::numeric, 2) AS average_order_value

FROM orders o

JOIN customers c
    ON o.customer_id = c.customer_id

LEFT JOIN order_sales os
    ON o.order_id = os.order_id

WHERE o.order_status = 'delivered'

GROUP BY c.customer_state

ORDER BY total_sales DESC;


---NEXT: Customer Review Score Analysis

SELECT
    r.review_score,

    COUNT(*) AS total_reviews,

    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS review_percentage,

    COUNT(*) FILTER (
        WHERE r.review_comment_message IS NOT NULL
          AND TRIM(r.review_comment_message) <> ''
    ) AS reviews_with_comments

FROM reviews r

JOIN orders o
    ON r.order_id = o.order_id

WHERE o.order_status = 'delivered'

GROUP BY r.review_score

ORDER BY r.review_score DESC;


---NEXT: Delivery Time Analysis


WITH delivery_data AS (
    SELECT
        order_id,
        EXTRACT(
            EPOCH FROM (
                order_delivered_customer_date - order_purchase_timestamp
            )
        ) / 86400.0 AS delivery_days
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_purchase_timestamp IS NOT NULL
)

SELECT
    COUNT(*) AS total_delivered_orders,

    ROUND(AVG(delivery_days)::numeric, 2) AS avg_delivery_days,

    ROUND(MIN(delivery_days)::numeric, 2) AS fastest_delivery_days,

    ROUND(MAX(delivery_days)::numeric, 2) AS slowest_delivery_days,

    COUNT(*) FILTER (
        WHERE delivery_days <= 3
    ) AS delivered_within_3_days,

    COUNT(*) FILTER (
        WHERE delivery_days > 3
          AND delivery_days <= 7
    ) AS delivered_in_4_to_7_days,

    COUNT(*) FILTER (
        WHERE delivery_days > 7
    ) AS delivered_after_7_days

FROM delivery_data;


---NEXT: On-Time Delivery Analysis

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
        ) * 100.0 / NULLIF(COUNT(*), 0),
        2
    ) AS on_time_delivery_percentage,

    ROUND(
        AVG(
            EXTRACT(
                EPOCH FROM (
                    order_delivered_customer_date
                    - order_estimated_delivery_date
                )
            ) / 86400.0
        ) FILTER (
            WHERE order_delivered_customer_date
                  > order_estimated_delivery_date
        )::numeric,
        2
    ) AS avg_days_late

FROM orders

WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;



 ---NEXT: Monthly Order Trend Analysis

 SELECT
    TO_CHAR(
        DATE_TRUNC('month', order_purchase_timestamp),
        'YYYY-MM'
    ) AS order_month,

    COUNT(*) AS total_orders,

    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
    ) AS delivered_orders,

    COUNT(*) FILTER (
        WHERE order_status = 'canceled'
    ) AS canceled_orders,

    ROUND(
        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
        ) * 100.0 / NULLIF(COUNT(*), 0),
        2
    ) AS delivery_rate_percentage

FROM orders

WHERE order_purchase_timestamp IS NOT NULL

GROUP BY DATE_TRUNC('month', order_purchase_timestamp)

ORDER BY DATE_TRUNC('month', order_purchase_timestamp);


---NEXT: Repeat Customer Analysis

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

    ROUND(SUM(total_sales)::numeric, 2) AS total_sales,

    ROUND(AVG(total_sales)::numeric, 2) AS avg_sales_per_customer

FROM customer_orders

GROUP BY
    CASE
        WHEN total_orders = 1 THEN '1 Order'
        WHEN total_orders = 2 THEN '2 Orders'
        ELSE '3+ Orders'
    END

ORDER BY
    MIN(total_orders);


----NEXT: Payment Installment Analysis


SELECT
    CASE
        WHEN payment_installments = 1 THEN '1 Installment'
        WHEN payment_installments BETWEEN 2 AND 3 THEN '2-3 Installments'
        WHEN payment_installments BETWEEN 4 AND 6 THEN '4-6 Installments'
        WHEN payment_installments BETWEEN 7 AND 12 THEN '7-12 Installments'
        WHEN payment_installments > 12 THEN '13+ Installments'
        ELSE 'Unknown'
    END AS installment_group,

    COUNT(DISTINCT p.order_id) AS total_orders,

    COUNT(*) AS payment_records,

    ROUND(SUM(p.payment_value)::numeric, 2) AS total_payment_value,

    ROUND(AVG(p.payment_value)::numeric, 2) AS avg_payment_value

FROM payments p

JOIN orders o
    ON p.order_id = o.order_id

WHERE o.order_status = 'delivered'

GROUP BY 1

ORDER BY MIN(p.payment_installments);


--NEXT: Product Price Analysis

SELECT
    COALESCE(
        NULLIF(TRIM(c.product_category_name_english), ''),
        NULLIF(TRIM(p.product_category_name), ''),
        'Unknown'
    ) AS product_category,

    COUNT(DISTINCT p.product_id) AS total_products,

    COUNT(i.order_item_id) AS items_sold,

    ROUND(AVG(i.price)::numeric, 2) AS average_price,

    ROUND(MIN(i.price)::numeric, 2) AS minimum_price,

    ROUND(MAX(i.price)::numeric, 2) AS maximum_price

FROM products p

LEFT JOIN category_translation c
    ON p.product_category_name = c.product_category_name

LEFT JOIN order_items i
    ON p.product_id = i.product_id

GROUP BY 1

ORDER BY average_price DESC NULLS LAST;


----NEXT: Order Value Segmentation

WITH order_values AS (
    SELECT
        order_id,
        SUM(price) AS order_value
    FROM order_items
    GROUP BY order_id
)

SELECT
    CASE
        WHEN order_value < 100 THEN 'Low (<100)'
        WHEN order_value < 500 THEN 'Medium (100-499.99)'
        WHEN order_value < 1000 THEN 'High (500-999.99)'
        ELSE 'Premium (1000+)'
    END AS order_value_group,

    COUNT(*) AS total_orders,

    ROUND(SUM(order_value)::numeric, 2) AS total_sales,

    ROUND(AVG(order_value)::numeric, 2) AS average_order_value,

    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS order_percentage

FROM order_values

GROUP BY 1

ORDER BY MIN(order_value);


---NEXT: Monthly Revenue Growth Analysis

WITH monthly_sales AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp) AS sales_month,
        SUM(i.price) AS total_sales
    FROM orders o
    JOIN order_items i
        ON o.order_id = i.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY 1
),

sales_with_previous_month AS (
    SELECT
        sales_month,
        total_sales,
        LAG(total_sales) OVER (
            ORDER BY sales_month
        ) AS previous_month_sales
    FROM monthly_sales
)

SELECT
    TO_CHAR(sales_month, 'YYYY-MM') AS sales_month,

    ROUND(total_sales::numeric, 2) AS total_sales,

    ROUND(previous_month_sales::numeric, 2) AS previous_month_sales,

    ROUND(
        (
            (total_sales - previous_month_sales)
            / NULLIF(previous_month_sales, 0)
        )::numeric * 100,
        2
    ) AS mom_growth_percentage

FROM sales_with_previous_month

ORDER BY sales_month;


---NEXT: Seller Revenue Contribution Analysis

WITH seller_sales AS (
    SELECT
        i.seller_id,
        SUM(i.price) AS total_sales,
        COUNT(DISTINCT i.order_id) AS total_orders,
        COUNT(*) AS items_sold
    FROM order_items i
    JOIN orders o
        ON i.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY i.seller_id
)

SELECT
    seller_id,
    total_orders,
    items_sold,

    ROUND(total_sales::numeric, 2) AS total_sales,

    ROUND(
        total_sales * 100.0
        / NULLIF(SUM(total_sales) OVER (), 0),
        2
    ) AS sales_contribution_percentage,

    DENSE_RANK() OVER (
        ORDER BY total_sales DESC
    ) AS seller_rank

FROM seller_sales

ORDER BY total_sales DESC
LIMIT 20;


----NEXT: Customer Purchase Value Analysis

WITH customer_sales AS (
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(i.price) AS total_spent
    FROM orders o
    JOIN order_items i
        ON o.order_id = i.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.customer_id
)

SELECT
    CASE
        WHEN total_spent < 100 THEN 'Low Spender (<100)'
        WHEN total_spent < 500 THEN 'Medium Spender (100-499.99)'
        WHEN total_spent < 1000 THEN 'High Spender (500-999.99)'
        ELSE 'Premium Spender (1000+)'
    END AS customer_segment,

    COUNT(*) AS total_customers,

    ROUND(SUM(total_spent)::numeric, 2) AS total_sales,

    ROUND(AVG(total_spent)::numeric, 2) AS avg_spending_per_customer,

    ROUND(AVG(total_orders)::numeric, 2) AS avg_orders_per_customer

FROM customer_sales

GROUP BY 1

ORDER BY MIN(total_spent);


---NEXT: Review Score vs Delivery Delay

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
),

review_summary AS (
    SELECT
        CASE
            WHEN delay_days <= 0 THEN 'On Time / Early'
            WHEN delay_days <= 3 THEN '1-3 Days Late'
            WHEN delay_days <= 7 THEN '4-7 Days Late'
            ELSE 'More Than 7 Days Late'
        END AS delivery_status,

        CASE
            WHEN delay_days <= 0 THEN 1
            WHEN delay_days <= 3 THEN 2
            WHEN delay_days <= 7 THEN 3
            ELSE 4
        END AS sort_order,

        COUNT(*) AS total_reviews,
        ROUND(AVG(review_score)::numeric, 2) AS average_review_score,

        COUNT(*) FILTER (
            WHERE review_score <= 2
        ) AS low_rating_reviews,

        ROUND(
            COUNT(*) FILTER (
                WHERE review_score <= 2
            ) * 100.0 / NULLIF(COUNT(*), 0),
            2
        ) AS low_rating_percentage

    FROM delivery_reviews
    GROUP BY 1, 2
)

SELECT
    delivery_status,
    total_reviews,
    average_review_score,
    low_rating_reviews,
    low_rating_percentage
FROM review_summary
ORDER BY sort_order;


---NEXT: Order Status Distribution Analysis

WITH order_sales AS (
    SELECT
        order_id,
        SUM(price) AS total_sales
    FROM order_items
    GROUP BY order_id
)

SELECT
    o.order_status,

    COUNT(*) AS total_orders,

    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS order_percentage,

    ROUND(
        COALESCE(SUM(os.total_sales), 0)::numeric,
        2
    ) AS total_item_sales,

    ROUND(
        AVG(os.total_sales)::numeric,
        2
    ) AS average_order_value

FROM orders o

LEFT JOIN order_sales os
    ON o.order_id = os.order_id

GROUP BY o.order_status

ORDER BY total_orders DESC;



----NEXT: Freight Cost Analysis

WITH category_map AS (
    SELECT
        product_category_name,
        MAX(product_category_name_english) AS category_english
    FROM category_translation
    GROUP BY product_category_name
)

SELECT
    COALESCE(
        NULLIF(TRIM(c.category_english), ''),
        NULLIF(TRIM(p.product_category_name), ''),
        'Unknown'
    ) AS product_category,

    COUNT(*) AS items_sold,

    ROUND(SUM(i.price)::numeric, 2) AS total_product_sales,

    ROUND(SUM(i.freight_value)::numeric, 2) AS total_freight,

    ROUND(
        SUM(i.freight_value)::numeric
        / NULLIF(SUM(i.price), 0) * 100,
        2
    ) AS freight_percentage_of_sales,

    ROUND(AVG(i.freight_value)::numeric, 2) AS avg_freight_per_item

FROM order_items i

JOIN orders o
    ON i.order_id = o.order_id

JOIN products p
    ON i.product_id = p.product_id

LEFT JOIN category_map c
    ON p.product_category_name = c.product_category_name

WHERE o.order_status = 'delivered'

GROUP BY 1

ORDER BY freight_percentage_of_sales DESC NULLS LAST;



---NEXT: Top 20 Best-Selling Products

WITH category_map AS (
    SELECT
        product_category_name,
        MAX(product_category_name_english) AS category_english
    FROM category_translation
    GROUP BY product_category_name
)

SELECT
    i.product_id,

    COALESCE(
        NULLIF(TRIM(c.category_english), ''),
        NULLIF(TRIM(p.product_category_name), ''),
        'Unknown'
    ) AS product_category,

    COUNT(*) AS units_sold,

    COUNT(DISTINCT i.order_id) AS total_orders,

    ROUND(SUM(i.price)::numeric, 2) AS total_sales,

    ROUND(AVG(i.price)::numeric, 2) AS average_item_price

FROM order_items i

JOIN orders o
    ON i.order_id = o.order_id

JOIN products p
    ON i.product_id = p.product_id

LEFT JOIN category_map c
    ON p.product_category_name = c.product_category_name

WHERE o.order_status = 'delivered'

GROUP BY
    i.product_id,
    product_category

ORDER BY total_sales DESC

LIMIT 20;



---NEXT: Day-of-Week Order Analysis

WITH order_sales AS (
    SELECT
        order_id,
        SUM(price) AS total_sales
    FROM order_items
    GROUP BY order_id
)

SELECT
    TO_CHAR(
        o.order_purchase_timestamp,
        'FMDay'
    ) AS day_of_week,

    EXTRACT(
        ISODOW FROM o.order_purchase_timestamp
    ) AS day_number,

    COUNT(DISTINCT o.order_id) AS total_orders,

    ROUND(
        COALESCE(SUM(os.total_sales), 0)::numeric,
        2
    ) AS total_sales,

    ROUND(
        AVG(os.total_sales)::numeric,
        2
    ) AS average_order_value

FROM orders o

LEFT JOIN order_sales os
    ON o.order_id = os.order_id

WHERE o.order_purchase_timestamp IS NOT NULL
  AND o.order_status = 'delivered'

GROUP BY
    day_of_week,
    day_number

ORDER BY day_number;



---NEXT: Customer RFM Segmentation

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
    ROUND(monetary::numeric, 2) AS monetary,

    recency_score,
    frequency_score,
    monetary_score,

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

ORDER BY
    monetary DESC;




---NEXT: Product Category Ranking

WITH category_map AS (
    SELECT
        product_category_name,
        MAX(product_category_name_english) AS category_english
    FROM category_translation
    GROUP BY product_category_name
),

category_sales AS (
    SELECT
        COALESCE(
            NULLIF(TRIM(c.category_english), ''),
            NULLIF(TRIM(p.product_category_name), ''),
            'Unknown'
        ) AS product_category,

        SUM(i.price) AS total_sales,
        COUNT(*) AS items_sold,
        COUNT(DISTINCT i.order_id) AS total_orders

    FROM order_items i
    JOIN orders o
        ON i.order_id = o.order_id
    JOIN products p
        ON i.product_id = p.product_id
    LEFT JOIN category_map c
        ON p.product_category_name = c.product_category_name

    WHERE o.order_status = 'delivered'

    GROUP BY 1
),

ranked_categories AS (
    SELECT
        *,
        DENSE_RANK() OVER (
            ORDER BY total_sales DESC
        ) AS sales_rank,

        SUM(total_sales) OVER (
            ORDER BY total_sales DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_sales,

        SUM(total_sales) OVER () AS grand_total_sales

    FROM category_sales
)

SELECT
    sales_rank,
    product_category,
    total_orders,
    items_sold,

    ROUND(total_sales::numeric, 2) AS total_sales,

    ROUND(
        total_sales * 100.0 / NULLIF(grand_total_sales, 0),
        2
    ) AS sales_contribution_percentage,

    ROUND(
        cumulative_sales * 100.0 / NULLIF(grand_total_sales, 0),
        2
    ) AS cumulative_sales_percentage

FROM ranked_categories

ORDER BY sales_rank;



----NEXT: Monthly Payment Trends

SELECT
    TO_CHAR(
        DATE_TRUNC('month', o.order_purchase_timestamp),
        'YYYY-MM'
    ) AS sales_month,

    p.payment_type,

    COUNT(DISTINCT p.order_id) AS total_orders,

    ROUND(
        SUM(p.payment_value)::numeric,
        2
    ) AS total_payment_value,

    ROUND(
        AVG(p.payment_value)::numeric,
        2
    ) AS average_payment_value

FROM payments p

JOIN orders o
    ON p.order_id = o.order_id

WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp IS NOT NULL

GROUP BY
    DATE_TRUNC('month', o.order_purchase_timestamp),
    p.payment_type

ORDER BY
    DATE_TRUNC('month', o.order_purchase_timestamp),
    total_payment_value DESC;


---NEXT: Seller State-wise Performance

SELECT
    s.seller_state,

    COUNT(DISTINCT s.seller_id) AS total_sellers,

    COUNT(DISTINCT i.order_id) AS total_orders,

    COUNT(*) AS items_sold,

    ROUND(SUM(i.price)::numeric, 2) AS total_sales,

    ROUND(SUM(i.freight_value)::numeric, 2) AS total_freight,

    ROUND(AVG(i.price)::numeric, 2) AS average_item_price

FROM sellers s

JOIN order_items i
    ON s.seller_id = i.seller_id

JOIN orders o
    ON i.order_id = o.order_id

WHERE o.order_status = 'delivered'

GROUP BY s.seller_state

ORDER BY total_sales DESC;





---NEXT: Review Score by Product Category

WITH category_map AS (
    SELECT
        product_category_name,
        MAX(product_category_name_english) AS category_english
    FROM category_translation
    GROUP BY product_category_name
),

category_reviews AS (
    SELECT
        COALESCE(
            NULLIF(TRIM(c.category_english), ''),
            NULLIF(TRIM(p.product_category_name), ''),
            'Unknown'
        ) AS product_category,

        r.review_score,
        r.review_id

    FROM reviews r

    JOIN orders o
        ON r.order_id = o.order_id

    JOIN order_items i
        ON r.order_id = i.order_id

    JOIN products p
        ON i.product_id = p.product_id

    LEFT JOIN category_map c
        ON p.product_category_name = c.product_category_name

    WHERE o.order_status = 'delivered'
)

SELECT
    product_category,

    COUNT(DISTINCT review_id) AS total_reviews,

    ROUND(AVG(review_score)::numeric, 2) AS average_review_score,

    COUNT(DISTINCT review_id) FILTER (
        WHERE review_score <= 2
    ) AS low_rating_reviews,

    ROUND(
        COUNT(DISTINCT review_id) FILTER (
            WHERE review_score <= 2
        ) * 100.0
        / NULLIF(COUNT(DISTINCT review_id), 0),
        2
    ) AS low_rating_percentage

FROM category_reviews

GROUP BY product_category

HAVING COUNT(DISTINCT review_id) >= 10

ORDER BY average_review_score ASC;



---NEXT: Final Business KPI Summary


WITH order_sales AS (
    SELECT
        order_id,
        SUM(price) AS total_sales,
        SUM(freight_value) AS total_freight
    FROM order_items
    GROUP BY order_id
),

order_data AS (
    SELECT
        o.order_id,
        o.order_status,
        o.order_purchase_timestamp,
        os.total_sales,
        os.total_freight,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
    FROM orders o
    LEFT JOIN order_sales os
        ON o.order_id = os.order_id
)

SELECT
    COUNT(*) AS total_orders,

    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
    ) AS delivered_orders,

    COUNT(*) FILTER (
        WHERE order_status = 'canceled'
    ) AS canceled_orders,

    ROUND(
        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
        ) * 100.0 / NULLIF(COUNT(*), 0),
        2
    ) AS delivered_order_percentage,

    ROUND(
        COALESCE(SUM(total_sales) FILTER (
            WHERE order_status = 'delivered'
        ), 0)::numeric,
        2
    ) AS delivered_product_sales,

    ROUND(
        COALESCE(SUM(total_freight) FILTER (
            WHERE order_status = 'delivered'
        ), 0)::numeric,
        2
    ) AS delivered_freight,

    ROUND(
        AVG(total_sales) FILTER (
            WHERE order_status = 'delivered'
        )::numeric,
        2
    ) AS average_delivered_order_value,

    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
          AND order_delivered_customer_date
              <= order_estimated_delivery_date
    ) AS on_time_delivered_orders,

    ROUND(
        AVG(
            EXTRACT(
                EPOCH FROM (
                    order_delivered_customer_date
                    - order_purchase_timestamp
                )
            ) / 86400.0
        ) FILTER (
            WHERE order_status = 'delivered'
              AND order_delivered_customer_date IS NOT NULL
        )::numeric,
        2
    ) AS average_delivery_days

FROM order_data;
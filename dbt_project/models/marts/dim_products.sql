with descriptions as (
    select
        stock_code,
        description,
        count(*) as filas,
        count(*) filter (where price > 0) as filas_con_precio,
        max(invoice_date) as last_seen
    from {{ ref('stg_transactions') }}
    where description is not null
    group by 1, 2
),

best_description as (
    select stock_code, description
    from descriptions
    qualify row_number() over (
        partition by stock_code
        order by filas_con_precio desc, filas desc, last_seen desc, description
    ) = 1
),

unique_products as (
    select distinct
        s.stock_code,
        b.description
    from {{ ref('stg_transactions') }} s
    left join best_description b
        on s.stock_code = b.stock_code
),

classified_products as (
    select
        p.stock_code,
        p.description,
        n.stock_code is null as is_product,
        coalesce(n.item_type, 'product') as item_type
    from unique_products p
    left join {{ ref('non_product_stock_codes') }} n
        on p.stock_code = n.stock_code
)

select * from classified_products
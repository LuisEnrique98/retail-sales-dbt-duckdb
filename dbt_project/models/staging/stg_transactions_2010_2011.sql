with source as (
    select *
    from {{ source('raw','online_retail_ii_year_2010_2011') }}
), 

renamed as (
    select 
        "Invoice" as invoice,
        "StockCode" as stock_code,
        "Description" as description,
        cast("Quantity" as integer) as quantity,
        cast("InvoiceDate" as timestamp) as invoice_date,
        cast("Price" as decimal(12,4)) as price,
        "Customer ID" as customer_id,
        "Country" as country
    from source
)

select *
from renamed
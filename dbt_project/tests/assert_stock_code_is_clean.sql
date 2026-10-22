select stock_code
from {{ ref('dim_products') }}
where stock_code <> upper(trim(stock_code))
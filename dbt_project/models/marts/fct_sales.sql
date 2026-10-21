select
    invoice,
    stock_code,
    customer_id,
    country,
    invoice_date                                  as invoiced_at,
    cast(invoice_date as date)                    as purchase_date,
    quantity,
    price                                         as unit_price,
    quantity * price                              as line_total,
    case
        when invoice like 'C%' and quantity < 0 then 'cancellation'
        when invoice like 'C%'                  then 'cancellation_anomaly'
        when stock_code = 'B'                   then 'adjustment'
        when quantity < 0                       then 'adjustment'
        when price = 0                          then 'zero_price'
        else 'sale'
    end as transaction_type
from {{ ref('stg_transactions') }}
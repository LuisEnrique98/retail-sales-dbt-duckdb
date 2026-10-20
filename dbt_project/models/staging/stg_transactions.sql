with first_sheet as (
    select *
    from {{ ref('stg_transactions_2009_2010') }}
), 

second_sheet as (
    select *
    from {{ ref('stg_transactions_2010_2011') }}
), 

second_sheet_new_rows as (
    select invoice, stock_code, description, quantity, invoice_date, price, customer_id, country
    from second_sheet
    except all
    select invoice, stock_code, description, quantity, invoice_date, price, customer_id, country
    from first_sheet
), 

unioned as (
    select invoice, stock_code, description, quantity, invoice_date, price, customer_id, country 
    from first_sheet
    union all
    select invoice, stock_code, description, quantity, invoice_date, price, customer_id, country
    from second_sheet_new_rows
)

select * from unioned
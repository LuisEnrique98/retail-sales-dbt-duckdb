select count(*) as n
from {{ ref('fct_sales') }}
having count(*) <> 1044848
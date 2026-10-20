select
    count(*) as n
from {{ ref('stg_transactions') }}
having count(*) <> 1044848
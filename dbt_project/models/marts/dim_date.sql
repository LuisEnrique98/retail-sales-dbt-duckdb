select
    cast(d as date)           as date_day,
    year(d)                   as year,
    month(d)                  as month,
    strftime(d, '%Y-%m')      as year_month,
    monthname(d)              as month_name,
    dayname(d)                as day_name
from generate_series(date '2009-12-01', date '2011-12-31', interval 1 day) as t(d)
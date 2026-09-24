-- Simulates reading slv_merchants. In the real project, swap the ref() below
-- for {{ source('silver', 'slv_merchants') }} once Silver access exists, and
-- confirm these column names against the real DDL (see README §"Swapping in
-- real Silver data").

select
    source_system,
    source_key,
    merchant_name,
    tax_id,
    platform_sid
from {{ ref('seed_slv_merchants') }}

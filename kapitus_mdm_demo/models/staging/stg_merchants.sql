-- Simulates reading slv_merchants. NOTE: once real Silver access exists,
-- swap the ref() below for a proper source() call pointing at the real
-- Silver database/schema, and confirm these column names against the
-- real DDL.

select
    source_system,
    source_key,
    merchant_name,
    tax_id,
    platform_sid
from {{ ref('seed_slv_merchants') }}
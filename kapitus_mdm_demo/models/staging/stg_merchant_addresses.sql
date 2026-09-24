-- Simulates reading slv_merchant_addresses. This is also where the real
-- zip-as-NUMBER defect (documented in the FND walkthrough) gets fixed: zip
-- is stored numeric, so 07307 becomes 7307. LPAD restores the leading zero.
-- Swap ref() for {{ source('silver','slv_merchant_addresses') }} once real
-- Silver access exists.

select
    source_system,
    source_key,
    address_1,
    city,
    state_code,
    lpad(zip::string, 5, '0') as zip5
from {{ ref('seed_slv_merchant_addresses') }}

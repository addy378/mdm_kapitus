-- gc_prep_merchant (demo)
-- Demonstrates the required pattern: joins Silver to the xref and attaches
-- golden attributes. NO matching/identity logic here, by ruling (16 Sep,
-- Akash, per the walkthrough) - this model must never decide who two
-- records belong to; it only looks the answer up in mdm_merchant_xref.

select
    x.golden_key as merchant_golden_key,
    m.source_system,
    m.source_key,
    m.merchant_name,
    m.tax_id,
    a.address_1,
    a.city,
    a.state_code,
    a.zip5
from {{ ref('mdm_merchant_xref') }} x
join {{ ref('stg_merchants') }} m
    on x.source_system = m.source_system and x.source_key = m.source_key
left join {{ ref('stg_merchant_addresses') }} a
    on m.source_system = a.source_system and m.source_key = a.source_key
where x.active = 'Y'

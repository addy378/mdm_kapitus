-- gc_merchant (demo)
-- In production this commits SCD2 on merchant_golden_key. This demo just
-- selects current state - no history tracking, no SCD2 macro. The point
-- to demonstrate is structural: this model contains ZERO matching,
-- scoring, or survivorship logic. Everything here is already decided
-- upstream in MDM_CORE.mdm_merchant_golden. If you ever find yourself
-- adding a CASE WHEN here that picks between two source values, that
-- logic belongs in MDM, not here - that's the ruling this demo is meant
-- to make concrete.

select
    golden_key as merchant_golden_key,
    legal_name,
    street,
    city,
    zip5,
    ein_hash,
    current_timestamp() as scd_effective_from
from {{ ref('mdm_merchant_golden') }}

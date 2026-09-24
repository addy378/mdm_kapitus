-- MDM_STAGE.mdm_merchant_candidate_pair
-- All candidate pairs from every tier, tagged with which tier/rule produced
-- them. Tier 3 (Cortex Search) is not implemented in this demo - see README
-- for why, and what that means for pairs that never get compared at all
-- (e.g. "1 Way Transportation" vs "One Way Transport").

select record_a, record_b, tier, rule, raw_score
from {{ ref('mdm_merchant_candidate_pair_tier1') }}

union all

select record_a, record_b, tier, rule, raw_score
from {{ ref('mdm_merchant_candidate_pair_tier2') }}

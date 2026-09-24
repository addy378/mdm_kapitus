-- MDM_STEWARD.mdm_steward_case
-- One row per pair that landed in STEWARD_REVIEW band. This demo has no
-- UI (matches the walkthrough's "tables only, no UI" design) - a human
-- would work these via direct table access or a future interface.

select
    least(record_a, record_b) || '__' || greatest(record_a, record_b) as case_id,
    record_a,
    record_b,
    case
        when ein_status = 'CONFLICT' then 'EIN conflict at ' || weighted_score::string
        when gap_to_runner_up is not null and gap_to_runner_up < 0.05 then 'gap ' || gap_to_runner_up::string
        else 'score ' || weighted_score::string
    end as reason,
    'OPEN' as status
from {{ ref('mdm_merchant_match_score') }}
where band = 'STEWARD_REVIEW'

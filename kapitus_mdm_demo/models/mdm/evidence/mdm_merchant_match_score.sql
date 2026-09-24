-- MDM_EVIDENCE.mdm_merchant_match_score
-- One row per candidate pair, from any tier. Never overwritten in the real
-- system (this demo does a full-refresh table each run - see README for
-- what real incremental/history handling would need to add).
-- This table is your audit trail: every score, every component, every rule
-- version, permanently retained.

with pairs as (
    select * from {{ ref('mdm_merchant_candidate_pair') }}
),

norm as (
    select record_id, ein_hash, ein_valid from {{ ref('mdm_merchant_normalized') }}
),

thresholds as (
    select
        max(case when band = 'AUTO_MATCH' then min_score end) as auto_match_min,
        max(case when band = 'STEWARD_REVIEW' then min_score end) as steward_review_min
    from {{ ref('seed_mdm_match_thresholds') }}
    where version = 'v1'
),

joined as (
    select
        p.record_a,
        p.record_b,
        p.tier,
        p.rule,
        p.raw_score,
        na.ein_valid as ein_valid_a,
        na.ein_hash as ein_hash_a,
        nb.ein_valid as ein_valid_b,
        nb.ein_hash as ein_hash_b
    from pairs p
    left join norm na on p.record_a = na.record_id
    left join norm nb on p.record_b = nb.record_id
),

with_ein_status as (
    select
        *,
        case
            when ein_valid_a and ein_valid_b and ein_hash_a = ein_hash_b then 'AGREE'
            when ein_valid_a and ein_valid_b and ein_hash_a != ein_hash_b then 'CONFLICT'
            else 'ABSTAIN'   -- at least one missing/placeholder - says nothing either way
        end as ein_status
    from joined
),

banded as (
    select
        w.*,
        t.auto_match_min,
        t.steward_review_min,
        case
            when ein_status = 'CONFLICT' then 'STEWARD_REVIEW'
            when raw_score >= t.auto_match_min then 'AUTO_MATCH'
            when raw_score >= t.steward_review_min then 'STEWARD_REVIEW'
            else 'NO_MATCH'
        end as band
    from with_ein_status w
    cross join thresholds t
)

select
    record_a,
    record_b,
    tier,
    rule,
    raw_score as weighted_score,
    ein_status,
    cast(null as float) as gap_to_runner_up,  -- only meaningful once Tier 3 exists
    band,
    'v1' as rule_version,
    current_timestamp() as scored_at
from banded

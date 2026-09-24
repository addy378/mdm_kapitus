-- Tier 2 fuzzy match. Only compares records inside the same "block"
-- (same zip5 + same first token of name_norm) - never all-to-all.
-- KNOWN GAP (by design, matches the walkthrough): records whose first name
-- token differs won't be compared here even if they're the same business -
-- e.g. "1 Way Transportation" vs "One Way Transport". That gap is what
-- Tier 3 (Cortex Search - not built in this demo, see README) is meant to
-- cover. Run this project and check: which of your sample pairs fall
-- into that gap? That's a good thing to bring back to the Tier-3 decision.

with base as (
    select
        *,
        split_part(name_norm, ' ', 1) as first_token
    from {{ ref('mdm_merchant_normalized') }}
),

weights as (
    select
        max(case when field = 'name_norm' then weight end) as w_name,
        max(case when field = 'street_norm' then weight end) as w_street,
        max(case when field = 'zip5' then weight end) as w_zip,
        max(case when field = 'city_norm' then weight end) as w_city
    from {{ ref('seed_mdm_field_weights') }}
    where version = 'v1'
),

blocked_pairs as (
    select
        a.record_id as record_a,
        b.record_id as record_b,
        a.name_norm as name_norm_a, b.name_norm as name_norm_b,
        a.street_norm as street_norm_a, b.street_norm as street_norm_b,
        a.city_norm as city_norm_a, b.city_norm as city_norm_b,
        a.zip5 as zip5_a, b.zip5 as zip5_b
    from base a
    join base b
        on a.record_id < b.record_id
        and a.zip5 = b.zip5
        and a.first_token = b.first_token
),

scored as (
    select
        bp.record_a,
        bp.record_b,
        'T2' as tier,
        'fuzzy_blocked' as rule,
        (
            (jarowinkler_similarity(name_norm_a, name_norm_b) / 100.0) * w.w_name +
            (jarowinkler_similarity(street_norm_a, street_norm_b) / 100.0) * w.w_street +
            (case when zip5_a = zip5_b then 1 else 0 end) * w.w_zip +
            (case when city_norm_a = city_norm_b then 1 else 0 end) * w.w_city
        ) as raw_score
    from blocked_pairs bp
    cross join weights w
)

select s.record_a, s.record_b, s.tier, s.rule, s.raw_score
from scored s
left join {{ ref('mdm_merchant_candidate_pair_tier1') }} t1
    on s.record_a = t1.record_a and s.record_b = t1.record_b
where t1.record_a is null   -- exclude pairs Tier 1 already resolved

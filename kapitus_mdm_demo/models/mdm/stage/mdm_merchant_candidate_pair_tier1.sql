-- Tier 1 exact match. Three rules, in order, per the walkthrough:
--   1. same valid EIN hash
--   2. same source ID across systems (platform_sid = another source's key)
--   3. same normalized name + street + zip5
-- Guard: if both records have valid EINs and they DIFFER, this tier does
-- NOT fire even if rules 2/3 would otherwise match - that goes to Tier 2/
-- scoring instead, where the EIN-conflict override forces steward review.

with base as (
    select * from {{ ref('mdm_merchant_normalized') }}
),

pairs as (
    select
        a.record_id as record_a,
        b.record_id as record_b,
        a.ein_hash as ein_hash_a, b.ein_hash as ein_hash_b,
        a.ein_valid as ein_valid_a, b.ein_valid as ein_valid_b,
        a.name_norm as name_norm_a, b.name_norm as name_norm_b,
        a.street_norm as street_norm_a, b.street_norm as street_norm_b,
        a.zip5 as zip5_a, b.zip5 as zip5_b,
        a.platform_sid as platform_sid_a, a.source_key as source_key_a,
        b.platform_sid as platform_sid_b, b.source_key as source_key_b
    from base a
    join base b
        on a.record_id < b.record_id   -- avoid self-pairs and duplicate reversed pairs
),

eligible as (
    select
        *,
        -- if both EINs are present and valid but differ, Tier 1 never fires
        (ein_valid_a and ein_valid_b and ein_hash_a != ein_hash_b) as ein_hard_conflict
    from pairs
)

select
    record_a,
    record_b,
    'T1' as tier,
    case
        when ein_valid_a and ein_valid_b and ein_hash_a = ein_hash_b then 'hashed_ein'
        when platform_sid_a = source_key_b or platform_sid_b = source_key_a then 'shared_source_id'
        when name_norm_a = name_norm_b and street_norm_a = street_norm_b and zip5_a = zip5_b then 'name_street_zip'
    end as rule,
    1.00 as raw_score
from eligible
where not ein_hard_conflict
  and (
        (ein_valid_a and ein_valid_b and ein_hash_a = ein_hash_b)
        or (platform_sid_a = source_key_b or platform_sid_b = source_key_a)
        or (name_norm_a = name_norm_b and street_norm_a = street_norm_b and zip5_a = zip5_b)
      )

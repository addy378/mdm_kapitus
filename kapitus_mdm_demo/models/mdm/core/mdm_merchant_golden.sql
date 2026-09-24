-- MDM_CORE.mdm_merchant_golden
-- One golden record per cluster. Per-field winner picked using the config
-- seeds (source priority, survivorship policy) - not hardcoded logic.
--
-- *** IMPORTANT CAVEAT - DO NOT COPY THIS KEY-GENERATION LOGIC AS-IS ***
-- The real system (PHDAT-366, MDM Golden Key Authority) mints keys ONLY
-- from a dedicated Snowflake sequence, per mdm_golden_key_standard, with
-- collision_policy = FAIL_RUN. This demo uses ROW_NUMBER() instead, purely
-- because there's no real sequence object to point at yet in a sandbox.
-- ROW_NUMBER() is NOT safe for production: it is not stable across reruns
-- and could reassign different keys to the same cluster. Swap this out for
-- a real sequence the moment this touches anything beyond this demo.

with clustered as (
    select cl.cluster_id, n.*
    from {{ ref('mdm_merchant_cluster') }} cl
    join {{ ref('mdm_merchant_normalized') }} n on cl.record_id = n.record_id
),

source_priority as (
    select field, source_system, priority
    from {{ ref('seed_mdm_source_priority') }}
    where policy = 'PRIORITY' and version = 'v1'
),

name_pick as (
    select
        c.cluster_id,
        c.name_norm,
        row_number() over (
            partition by c.cluster_id
            order by coalesce(sp.priority, 999)
        ) as rn
    from clustered c
    left join source_priority sp
        on sp.field = 'legal_name' and sp.source_system = c.source_system
),

-- Address survivorship policy is RECENCY in config, but this demo has no
-- real record timestamp to sort by yet (Silver doesn't expose one in the
-- walkthrough's sample columns) - falls back to an arbitrary pick.
-- Flagging this explicitly: real system needs a genuine "most recent"
-- signal (e.g. a last_modified_ts from Silver) before RECENCY can work.
address_pick as (
    select
        c.cluster_id,
        c.street_norm, c.city_norm, c.zip5,
        row_number() over (partition by c.cluster_id order by c.record_id desc) as rn
    from clustered c
),

ein_pick as (
    select
        c.cluster_id,
        c.ein_hash,
        row_number() over (
            partition by c.cluster_id
            order by case when ein_valid then 0 else 1 end
        ) as rn
    from clustered c
),

clusters as (
    select distinct cluster_id from clustered
)

select
    -- DEMO-ONLY key generation - see caveat above. Real system uses the
    -- sequence in mdm_golden_key_standard, never row_number().
    'ENT-' || lpad(row_number() over (order by c.cluster_id)::string, 9, '0') as golden_key,
    c.cluster_id,
    (select name_norm from name_pick np where np.cluster_id = c.cluster_id and np.rn = 1) as legal_name,
    (select street_norm from address_pick ap where ap.cluster_id = c.cluster_id and ap.rn = 1) as street,
    (select city_norm from address_pick ap where ap.cluster_id = c.cluster_id and ap.rn = 1) as city,
    (select zip5 from address_pick ap where ap.cluster_id = c.cluster_id and ap.rn = 1) as zip5,
    (select ein_hash from ein_pick ep where ep.cluster_id = c.cluster_id and ep.rn = 1) as ein_hash
from clusters c

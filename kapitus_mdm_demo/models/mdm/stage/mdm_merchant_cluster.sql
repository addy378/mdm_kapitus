-- MDM_STAGE.mdm_merchant_cluster
-- Chains AUTO_MATCH pairs (and steward MERGE decisions) into one group per
-- real-world entity, transitively: if A-B and B-C are linked, A/B/C become
-- one cluster even though A-C was never directly compared. KEEP_SEPARATE
-- decisions are a wall the chain cannot cross.
--
-- *** IMPORTANT CAVEAT ***
-- The recursive CTE below is a simplified connected-components approach
-- that works for THIS SMALL DEMO DATASET ONLY. It has not been validated
-- at production scale (1.1M+ merchant records, per the FND walkthrough).
-- At real volume, evaluate a proper graph/union-find implementation (e.g.
-- via Snowpark or a dedicated library) rather than naive recursive SQL -
-- recursive CTEs like this do not scale well and can be slow or hit
-- recursion limits on large, densely-connected graphs. Treat this as a
-- learning/testing tool, not a template to copy into production as-is.

with autos as (
    select record_a, record_b
    from {{ ref('mdm_merchant_match_score') }}
    where band = 'AUTO_MATCH'
),

merges as (
    select record_a, record_b
    from {{ ref('mdm_steward_decision_ledger') }}
    where decision = 'MERGE'
),

keep_separate as (
    select record_a, record_b
    from {{ ref('mdm_steward_decision_ledger') }}
    where decision = 'KEEP_SEPARATE'
),

edges_one_way as (
    select record_a, record_b from autos
    union
    select record_a, record_b from merges
),

-- KEEP_SEPARATE is a hard wall: strip any edge that a steward has
-- explicitly said should NOT be merged, even if scoring said AUTO_MATCH
edges_filtered as (
    select e.record_a, e.record_b
    from edges_one_way e
    left join keep_separate k
        on e.record_a = k.record_a and e.record_b = k.record_b
    where k.record_a is null
),

edges_symmetric as (
    select record_a, record_b from edges_filtered
    union
    select record_b as record_a, record_a as record_b from edges_filtered
),

all_records as (
    select record_id from {{ ref('mdm_merchant_normalized') }}
),

-- depth-limited recursive walk: each record starts as its own root, then
-- propagates the smallest reachable record_id to its neighbors, capped at
-- 10 hops (this demo's graphs are at most 2-3 hops deep - raise the cap if
-- you add longer chains, but re-read the caveat above first)
closure as (
    select record_id, record_id as cluster_root, 0 as depth
    from all_records

    union all

    select e.record_b as record_id, c.cluster_root, c.depth + 1
    from closure c
    join edges_symmetric e on c.record_id = e.record_a
    where c.depth < 10
)

select
    record_id,
    min(cluster_root) as cluster_id
from closure
group by record_id

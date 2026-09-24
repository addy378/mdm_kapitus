-- Passes if this returns zero rows. Encodes the walkthrough's rule: "one
-- active row per source record is a dbt test."

select source_system, source_key, count(*) as active_count
from {{ ref('mdm_merchant_xref') }}
where active = 'Y'
group by source_system, source_key
having count(*) > 1

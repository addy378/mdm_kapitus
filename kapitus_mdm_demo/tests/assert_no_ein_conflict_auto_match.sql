-- Passes if this returns zero rows. Encodes the walkthrough's hard rule:
-- an EIN conflict must NEVER be auto-matched, regardless of how high the
-- fuzzy score is.

select record_a, record_b, ein_status, band
from {{ ref('mdm_merchant_match_score') }}
where ein_status = 'CONFLICT' and band = 'AUTO_MATCH'

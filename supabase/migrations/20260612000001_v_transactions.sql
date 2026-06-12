-- ============================================================
-- MIGRATION: v_transactions view (tag_ids array for SQL-side tag filtering)
--
-- The Transactions list filtered tags in JavaScript after fetching, because the
-- "(Blanks)/untagged" facet (and the tag junction table generally) could not be
-- expressed in the row-level SQL the rest of the filters use. That post-fetch
-- step blocked server-side pagination: a windowed query's row count would be
-- wrong whenever a tag facet was active.
--
-- This view aggregates each transaction's tag IDs into a `tag_ids` array, so the
-- tag facet becomes an ordinary SQL predicate:
--   specific tags -> tag_ids && '{id,...}'   (overlaps)
--   untagged      -> tag_ids = '{}'
-- The whole list query is then server-side and paginatable (.range + count).
--
-- security_invoker = on so the base tables' RLS (user_id = auth.uid()) applies
-- to the querying user, matching the other reporting views
-- (see 20260605000001_views_security_invoker.sql).
-- ============================================================

create or replace view public.v_transactions
with (security_invoker = on) as
select
  t.*,
  coalesce(
    array_agg(tt.tag_id) filter (where tt.tag_id is not null),
    '{}'::uuid[]
  ) as tag_ids
from public.transactions t
left join public.transaction_tags tt on tt.transaction_id = t.id
group by t.id;

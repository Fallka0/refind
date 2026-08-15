-- German compound search.
--
-- to_tsvector('german', …) stems but does not decompose compounds: "Rennvelo"
-- stems to "rennvelo" and never matches a search for "Velo". Proper splitting
-- needs an ispell/hunspell dictionary installed on the server, which is not
-- available on hosted Postgres (Neon, Vercel Postgres).
--
-- Trigrams solve it portably: "velo" is a substring of "rennvelo", so a
-- trigram index answers the compound case that stemming misses. Full-text
-- search still runs, and still ranks — this is the fallback that catches what
-- it cannot see, not a replacement for it.

create extension if not exists pg_trgm;

create index if not exists wants_title_trgm_idx
  on wants using gin (lower(title) gin_trgm_ops);

create index if not exists wants_description_trgm_idx
  on wants using gin (lower(coalesce(description, '')) gin_trgm_ops);

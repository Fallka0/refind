-- refind schema v1
--
-- Money is stored the way the client models it: integer minor units plus a
-- currency code. No numeric/float anywhere near a price.

create extension if not exists "pgcrypto";

-- Users -----------------------------------------------------------------

create table if not exists users (
  id             text primary key default 'usr_' || encode(gen_random_bytes(6), 'hex'),
  email          text not null unique,
  -- scrypt, stored as salt:hash. Never reversible, never logged.
  password_hash  text not null,
  display_name   text not null,
  city           text not null default 'Zürich',
  radius_km      int  not null default 30,
  member_since   timestamptz not null default now(),
  rating         numeric(2,1) not null default 0,
  deal_count     int  not null default 0,
  verified       bool not null default false,
  verification_status text not null default 'unverified'
    check (verification_status in ('unverified','pending','verified','rejected')),
  avatar_url     text,
  created_at     timestamptz not null default now()
);

create index if not exists users_email_idx on users (lower(email));

-- Refresh tokens are rotated on use, so each row is single-use. Storing the
-- hash (not the token) means a database leak cannot mint sessions.
create table if not exists refresh_tokens (
  id          text primary key default 'rt_' || encode(gen_random_bytes(8), 'hex'),
  user_id     text not null references users(id) on delete cascade,
  token_hash  text not null unique,
  expires_at  timestamptz not null,
  revoked_at  timestamptz,
  created_at  timestamptz not null default now()
);

create index if not exists refresh_tokens_user_idx on refresh_tokens (user_id);

-- Wants -----------------------------------------------------------------

create table if not exists wants (
  id            text primary key default 'wnt_' || encode(gen_random_bytes(6), 'hex'),
  owner_id      text not null references users(id) on delete cascade,
  title         text not null check (length(trim(title)) >= 3),
  category      text not null check (category in
                  ('uhren','moebel','velo','vinyl','kameras','werkzeug')),
  budget_minor  int  not null check (budget_minor > 0 and budget_minor <= 10000000),
  currency      text not null default 'CHF',
  condition     text not null check (condition in ('original','serviced','any')),
  region        text not null,
  radius_km     int  not null default 30,
  description   text,
  status        text not null default 'live'
                  check (status in ('live','paused','expired','fulfilled')),
  created_at    timestamptz not null default now(),
  expires_at    timestamptz not null
);

create index if not exists wants_owner_idx on wants (owner_id);
create index if not exists wants_discover_idx on wants (status, created_at desc);

-- Full-text search. German config so compounds stem sensibly — "Rennvelo"
-- has to find "Velo", which a substring match would miss.
alter table wants add column if not exists search tsvector
  generated always as (
    to_tsvector('german', coalesce(title,'') || ' ' || coalesce(description,''))
  ) stored;

create index if not exists wants_search_idx on wants using gin (search);

create table if not exists saved_wants (
  user_id  text not null references users(id) on delete cascade,
  want_id  text not null references wants(id) on delete cascade,
  saved_at timestamptz not null default now(),
  primary key (user_id, want_id)
);

-- Offers ----------------------------------------------------------------

create table if not exists offers (
  id           text primary key default 'ofr_' || encode(gen_random_bytes(6), 'hex'),
  want_id      text not null references wants(id) on delete cascade,
  seller_id    text not null references users(id) on delete cascade,
  price_minor  int  not null check (price_minor > 0),
  currency     text not null default 'CHF',
  message      text not null default '' check (length(message) <= 500),
  status       text not null default 'sent'
                 check (status in ('sent','accepted','declined','withdrawn')),
  created_at   timestamptz not null default now(),
  -- One live offer per seller per want; re-offering means editing.
  unique (want_id, seller_id)
);

create index if not exists offers_want_idx on offers (want_id, price_minor);

create table if not exists photos (
  id          text primary key default 'pho_' || encode(gen_random_bytes(8), 'hex'),
  owner_id    text not null references users(id) on delete cascade,
  url         text,
  offer_id    text references offers(id) on delete cascade,
  message_id  text,
  created_at  timestamptz not null default now()
);

-- Chat ------------------------------------------------------------------

create table if not exists threads (
  id            text primary key default 'thr_' || encode(gen_random_bytes(6), 'hex'),
  offer_id      text not null unique references offers(id) on delete cascade,
  want_id       text not null references wants(id) on delete cascade,
  buyer_id      text not null references users(id) on delete cascade,
  seller_id     text not null references users(id) on delete cascade,
  last_activity timestamptz not null default now(),
  created_at    timestamptz not null default now()
);

create index if not exists threads_participants_idx on threads (buyer_id, seller_id);

create table if not exists messages (
  id         text primary key default 'msg_' || encode(gen_random_bytes(8), 'hex'),
  thread_id  text not null references threads(id) on delete cascade,
  sender_id  text references users(id) on delete set null,
  kind       text not null check (kind in ('text','photo','system')),
  body       text not null default '',
  photo_id   text references photos(id) on delete set null,
  created_at timestamptz not null default now(),
  read_at    timestamptz
);

create index if not exists messages_thread_idx on messages (thread_id, created_at);

-- Deals and escrow ------------------------------------------------------

create table if not exists deals (
  id             text primary key default 'del_' || encode(gen_random_bytes(6), 'hex'),
  offer_id       text not null unique references offers(id) on delete cascade,
  thread_id      text not null references threads(id) on delete cascade,
  price_minor    int  not null check (price_minor > 0),
  currency       text not null default 'CHF',
  handover_at    timestamptz not null,
  handover_place text not null,
  rated_by_buyer  bool not null default false,
  rated_by_seller bool not null default false,
  created_at     timestamptz not null default now()
);

create table if not exists escrows (
  id             text primary key default 'esc_' || encode(gen_random_bytes(6), 'hex'),
  deal_id        text not null unique references deals(id) on delete cascade,
  method         text not null check (method in ('escrow','card','cash')),
  amount_minor   int not null,
  fee_minor      int not null,
  currency       text not null default 'CHF',
  receipt_number text not null unique,
  stage          text not null default 'paid'
                   check (stage in ('paid','handover','released','disputed','refunded')),
  paid_at        timestamptz not null default now(),
  -- The 72-hour promise screen 15 makes. Enforced by a job, shown by the client.
  auto_refund_at timestamptz,
  created_at     timestamptz not null default now()
);

create table if not exists ratings (
  deal_id   text not null references deals(id) on delete cascade,
  rater_id  text not null references users(id) on delete cascade,
  stars     int  not null check (stars between 1 and 5),
  created_at timestamptz not null default now(),
  primary key (deal_id, rater_id)
);

-- Safety ----------------------------------------------------------------

create table if not exists reports (
  id           text primary key default 'rep_' || encode(gen_random_bytes(6), 'hex'),
  reporter_id  text not null references users(id) on delete cascade,
  subject_type text not null check (subject_type in ('user','want','offer','message')),
  subject_id   text not null,
  reason       text not null,
  detail       text not null default '',
  created_at   timestamptz not null default now()
);

create table if not exists blocks (
  blocker_id text not null references users(id) on delete cascade,
  blocked_id text not null references users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create table if not exists devices (
  token       text primary key,
  user_id     text not null references users(id) on delete cascade,
  environment text not null check (environment in ('sandbox','production')),
  locale      text not null default 'de-CH',
  updated_at  timestamptz not null default now()
);

-- Rate limiting ---------------------------------------------------------
-- Sliding window, counted per user per endpoint. Offer creation is the
-- surface that reaches someone else's notifications.

create table if not exists rate_events (
  user_id  text not null references users(id) on delete cascade,
  bucket   text not null,
  at       timestamptz not null default now()
);

create index if not exists rate_events_lookup on rate_events (user_id, bucket, at desc);

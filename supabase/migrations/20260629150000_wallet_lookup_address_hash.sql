alter table public.wallet_lookup_events
  add column if not exists public_address_hash text,
  alter column public_address drop not null;

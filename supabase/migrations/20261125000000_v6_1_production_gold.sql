-- ═══════════════════════════════════════════════════════════════════════════
-- LevelUp Life · v6.1 Production Gold
--
-- v6 güvenlik şemasının ÜZERİNE çalıştırılır:
--   1) Kalıcı rol kurtarma: reclaim_couple_role / leave_couple_room
--   2) Optimistic concurrency: couple_rooms.state_revision
--   3) Alıcı okundu/tepki: mark_messages_read(p_up_to) / toggle_message_reaction
--   4) Cihaz sağlığı: room_members.last_seen_at/push_enabled/sessiz saat
--   5) Push idempotency: push_deliveries + claim/complete RPC'leri
--
-- Kurulum sırası:
--   supabase/migrations/20261123000000_v6_security.sql   (önce)
--   supabase/migrations/20261125000000_v6_1_production_gold.sql (bu dosya)
-- ═══════════════════════════════════════════════════════════════════════════

begin;

create extension if not exists pgcrypto;

-- ── 1) Oda: concurrency + kurtarma ────────────────────────────────────────
alter table public.couple_rooms
  add column if not exists state_revision bigint not null default 0,
  add column if not exists recovery_secret text;

-- ── 2) Cihaz sağlığı ve alıcı sessiz saatleri ─────────────────────────────
alter table public.room_members
  add column if not exists last_seen_at timestamptz not null default now(),
  add column if not exists push_enabled boolean not null default true,
  add column if not exists quiet_start_minute integer,
  add column if not exists quiet_end_minute integer,
  add column if not exists utc_offset_minutes integer not null default 0,
  add column if not exists timezone text;

alter table public.room_members
  drop constraint if exists room_members_quiet_start_check,
  drop constraint if exists room_members_quiet_end_check,
  drop constraint if exists room_members_utc_offset_check;

alter table public.room_members
  add constraint room_members_quiet_start_check
    check (quiet_start_minute is null or quiet_start_minute between 0 and 1439),
  add constraint room_members_quiet_end_check
    check (quiet_end_minute is null or quiet_end_minute between 0 and 1439),
  add constraint room_members_utc_offset_check
    check (utc_offset_minutes between -840 and 840);

create index if not exists room_members_last_seen_idx
  on public.room_members (room_code, last_seen_at desc);

-- ── 3) Okundu / tepki kolonları ───────────────────────────────────────────
alter table public.chat_messages
  add column if not exists read_at timestamptz,
  add column if not exists reactions jsonb not null default '{}'::jsonb;

create index if not exists chat_messages_unread_idx
  on public.chat_messages (room_code, sender_id)
  where read_at is null;

-- ── 4) Servis rolü yardımcısı ─────────────────────────────────────────────
create or replace function public.is_service_role()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role',
    ''
  ) = 'service_role';
$$;

revoke all on function public.is_service_role() from public;
grant execute on function public.is_service_role() to authenticated, service_role;



-- ── 5) Odaya katılma: null kontrolü + oda satırı FOR UPDATE ───────────────
create or replace function public.join_couple_room(
  p_room_code text,
  p_role      text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code      text := upper(trim(p_room_code));
  v_uid       uuid := auth.uid();
  v_role      text := lower(trim(p_role));
  v_existing  text;
begin
  if p_room_code is null or p_role is null then
    raise exception 'invalid room code or role' using errcode = '22023';
  end if;
  if v_uid is null then
    raise exception 'auth required' using errcode = '28000';
  end if;
  if v_role not in ('yusuf', 'ceyda') then
    raise exception 'invalid role' using errcode = '22023';
  end if;
  if length(v_code) < 6 or length(v_code) > 64 then
    raise exception 'invalid room code' using errcode = '22023';
  end if;

  -- Oda satırını kilitle: aynı anda iki cihaz farklı rolü kapmaya çalışırsa
  -- biri bekler, diğeri tutarlı biçimde "role taken" alır.
  insert into public.couple_rooms (room_code, recovery_secret)
  values (v_code, v_code)
  on conflict (room_code) do nothing;

  perform 1 from public.couple_rooms where room_code = v_code for update;

  select m.role into v_existing
    from public.room_members m
   where m.room_code = v_code and m.user_id = v_uid
   for update;

  if v_existing is not null then
    if v_existing <> v_role then
      if exists (
        select 1 from public.room_members
         where room_code = v_code and role = v_role
      ) then
        raise exception 'role taken' using errcode = '23505';
      end if;
      update public.room_members
         set role = v_role
       where room_code = v_code and user_id = v_uid;
    end if;
    return;
  end if;

  if exists (
    select 1 from public.room_members
     where room_code = v_code and role = v_role
  ) then
    raise exception 'role taken' using errcode = '23505';
  end if;

  if (select count(*) from public.room_members where room_code = v_code) >= 2 then
    raise exception 'room full' using errcode = '23514';
  end if;

  insert into public.room_members (room_code, user_id, role)
  values (v_code, v_uid, v_role);
end;
$$;

revoke all on function public.join_couple_room(text, text) from public;
grant execute on function public.join_couple_room(text, text)
  to authenticated, service_role;

-- ── 6) Kalıcı kilitlenme çözümü: uygulama silinip yeniden kurulunca rol geri
--      alınabilir. Kurtarma sırrı = odayı kuran cihazın bildiği paylaşılan
--      oda kodu / kurtarma PIN'i. ──────────────────────────────────────────
create or replace function public.reclaim_couple_role(
  p_room_code text,
  p_role text,
  p_recovery_secret text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code     text := upper(trim(p_room_code));
  v_role     text := lower(trim(p_role));
  v_secret   text;
  v_uid      uuid := auth.uid();
begin
  if p_room_code is null or p_role is null or p_recovery_secret is null then
    raise exception 'invalid reclaim payload' using errcode = '22023';
  end if;
  if v_uid is null then
    raise exception 'auth required' using errcode = '28000';
  end if;
  if v_role not in ('yusuf', 'ceyda') then
    raise exception 'invalid role' using errcode = '22023';
  end if;

  select recovery_secret into v_secret
    from public.couple_rooms
   where room_code = v_code
   for update;

  if v_secret is null and not exists (
    select 1 from public.couple_rooms where room_code = v_code
  ) then
    raise exception 'room not found' using errcode = 'P0002';
  end if;

  -- Oda kodu paylaşılan davet sırrıdır; kurtarma sırrı boşsa oda kodu kabul
  -- edilir (geriye dönük uyumluluk).
  if coalesce(v_secret, v_code) <> p_recovery_secret then
    raise exception 'invalid recovery secret' using errcode = '42501';
  end if;

  -- Bu kullanıcının odadaki varsa eski rolünü bırak; ardından hedef rolü devral.
  delete from public.room_members
   where room_code = v_code and user_id = v_uid and role <> v_role;

  update public.room_members
     set user_id = v_uid
   where room_code = v_code and role = v_role;

  if not found then
    insert into public.room_members (room_code, user_id, role)
    values (v_code, v_uid, v_role);
  end if;
end;
$$;

revoke all on function public.reclaim_couple_role(text, text, text) from public;
grant execute on function public.reclaim_couple_role(text, text, text)
  to authenticated, service_role;

create or replace function public.leave_couple_room(p_room_code text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text := upper(trim(p_room_code));
  v_uid  uuid := auth.uid();
begin
  if p_room_code is null then
    raise exception 'invalid room code' using errcode = '22023';
  end if;
  if v_uid is null then
    raise exception 'auth required' using errcode = '28000';
  end if;
  delete from public.room_members
   where room_code = v_code and user_id = v_uid;
end;
$$;

revoke all on function public.leave_couple_room(text) from public;
grant execute on function public.leave_couple_room(text)
  to authenticated, service_role;


-- ── 7) Sohbet RLS düzeltmesi ──────────────────────────────────────────────
-- Gönderen kendi mesajını güncelleyebilir; alıcı partner doğrudan UPDATE
-- yapamaz. Alıcının okundu/tepki yazımı aşağıdaki SECURITY DEFINER RPC'lerden
-- geçer ve yalnızca read_at + reactions alanlarını değiştirir.
drop policy if exists chat_messages_update on public.chat_messages;
create policy chat_messages_update on public.chat_messages
  for update to authenticated
  using (
    public.is_room_member(room_code)
    and sender_id = public.member_role(room_code)
  )
  with check (
    public.is_room_member(room_code)
    and sender_id = public.member_role(room_code)
  );

-- ── 8) Alıcı okundu RPC'si (p_up_to anına kadar) ──────────────────────────
create or replace function public.mark_messages_read(
  p_room_code text,
  p_up_to timestamptz
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code  text := upper(trim(p_room_code));
  v_uid   uuid := auth.uid();
  v_role  text := public.member_role(p_room_code);
  v_count integer := 0;
begin
  if p_room_code is null or p_up_to is null then
    raise exception 'invalid read payload' using errcode = '22023';
  end if;
  if v_uid is null then
    raise exception 'auth required' using errcode = '28000';
  end if;
  if v_role is null or not public.is_room_member(v_code) then
    raise exception 'not a room member' using errcode = '42501';
  end if;

  update public.chat_messages
     set read_at = now(),
         payload = jsonb_set(
           coalesce(payload, '{}'::jsonb),
           '{is_read}',
           'true'::jsonb,
           true
         )
   where room_code = v_code
     and created_at <= p_up_to
     and sender_id <> v_role
     and read_at is null;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.mark_messages_read(text, timestamptz) from public;
grant execute on function public.mark_messages_read(text, timestamptz)
  to authenticated, service_role;

-- ── 9) Alıcı emoji tepkisi ────────────────────────────────────────────────
create or replace function public.toggle_message_reaction(
  p_room_code text,
  p_message_id text,
  p_emoji text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code      text := upper(trim(p_room_code));
  v_uid       uuid := auth.uid();
  v_role      text := public.member_role(p_room_code);
  v_emoji     text := trim(p_emoji);
  v_reactions jsonb := '{}'::jsonb;
  v_ids       jsonb := '[]'::jsonb;
begin
  if p_room_code is null or p_message_id is null or p_emoji is null then
    raise exception 'invalid reaction payload' using errcode = '22023';
  end if;
  if v_uid is null then
    raise exception 'auth required' using errcode = '28000';
  end if;
  if v_role is null or not public.is_room_member(v_code) then
    raise exception 'not a room member' using errcode = '42501';
  end if;
  if length(v_emoji) = 0 or length(v_emoji) > 16 then
    raise exception 'invalid emoji' using errcode = '22023';
  end if;

  select coalesce(reactions, '{}'::jsonb)
    into v_reactions
    from public.chat_messages
   where room_code = v_code and id = p_message_id
   for update;

  if not found then
    raise exception 'message not found' using errcode = 'P0002';
  end if;

  v_ids := coalesce(v_reactions -> v_emoji, '[]'::jsonb);

  if v_ids ? v_role then
    select coalesce(jsonb_agg(to_jsonb(item)), '[]'::jsonb)
      into v_ids
      from jsonb_array_elements_text(v_ids) as item
     where item <> v_role;
  else
    v_ids := v_ids || to_jsonb(v_role);
  end if;

  if jsonb_array_length(v_ids) = 0 then
    v_reactions := v_reactions - v_emoji;
  else
    v_reactions := jsonb_set(v_reactions, array[v_emoji], v_ids, true);
  end if;

  update public.chat_messages
     set reactions = v_reactions,
         payload = jsonb_set(
           coalesce(payload, '{}'::jsonb),
           '{reactions}',
           v_reactions,
           true
         )
   where room_code = v_code and id = p_message_id;

  return v_reactions;
end;
$$;

revoke all on function public.toggle_message_reaction(text, text, text)
  from public;
grant execute on function public.toggle_message_reaction(text, text, text)
  to authenticated, service_role;

-- ── 10) Cihaz sağlık nabzı ────────────────────────────────────────────────
create or replace function public.touch_room_member(
  p_room_code text,
  p_push_enabled boolean default true,
  p_quiet_start_minute integer default null,
  p_quiet_end_minute integer default null,
  p_utc_offset_minutes integer default 0
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text := upper(trim(p_room_code));
  v_uid  uuid := auth.uid();
begin
  if p_room_code is null then
    raise exception 'invalid room code' using errcode = '22023';
  end if;
  if v_uid is null then
    raise exception 'auth required' using errcode = '28000';
  end if;
  if not public.is_room_member(v_code) then
    raise exception 'not a room member' using errcode = '42501';
  end if;

  update public.room_members
     set last_seen_at = now(),
         push_enabled = coalesce(p_push_enabled, true),
         quiet_start_minute = p_quiet_start_minute,
         quiet_end_minute = p_quiet_end_minute,
         utc_offset_minutes = greatest(-840, least(840, coalesce(p_utc_offset_minutes, 0)))
   where room_code = v_code and user_id = v_uid;

  if not found then
    raise exception 'not a room member' using errcode = '42501';
  end if;
end;
$$;


-- ── 11) Push idempotency (istemci + webhook çifte push atamaz) ────────────
create table if not exists public.push_deliveries (
  message_id    text primary key
    references public.chat_messages(id) on delete cascade,
  room_code     text not null,
  recipient_id  text not null check (recipient_id in ('yusuf', 'ceyda')),
  status        text not null default 'sending'
    check (status in ('sending', 'sent', 'failed')),
  onesignal_id  text,
  error         text,
  attempts      integer not null default 1,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists push_deliveries_room_idx
  on public.push_deliveries (room_code, created_at desc);

alter table public.push_deliveries enable row level security;
revoke all on table public.push_deliveries from anon, authenticated;

create or replace function public.claim_push_delivery(
  p_message_id text,
  p_room_code text,
  p_recipient_id text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code      text := upper(trim(p_room_code));
  v_recipient text := lower(trim(p_recipient_id));
  v_claimed   boolean := false;
begin
  if p_message_id is null or p_room_code is null or p_recipient_id is null then
    raise exception 'invalid claim payload' using errcode = '22023';
  end if;
  if not public.is_service_role() and not public.is_room_member(v_code) then
    raise exception 'not a room member' using errcode = '42501';
  end if;
  if v_recipient not in ('yusuf', 'ceyda') then
    raise exception 'invalid recipient' using errcode = '22023';
  end if;
  -- Alıcı, mesajı gönderen partnerin karşı tarafı olmalıdır.
  if not exists (
    select 1 from public.chat_messages
     where id = p_message_id
       and room_code = v_code
       and sender_id <> v_recipient
  ) then
    raise exception 'message not found' using errcode = 'P0002';
  end if;

  insert into public.push_deliveries (
    message_id, room_code, recipient_id, status
  )
  values (p_message_id, v_code, v_recipient, 'sending')
  on conflict (message_id) do update
    set status = 'sending',
        error = null,
        attempts = push_deliveries.attempts + 1,
        updated_at = now()
    where push_deliveries.status = 'failed'
       or (
         push_deliveries.status = 'sending'
         and push_deliveries.updated_at < now() - interval '2 minutes'
       )
  returning true into v_claimed;

  return coalesce(v_claimed, false);
end;
$$;

revoke all on function public.claim_push_delivery(text, text, text)
  from public;
grant execute on function public.claim_push_delivery(text, text, text)
  to authenticated, service_role;

create or replace function public.complete_push_delivery(
  p_message_id text,
  p_success boolean,
  p_onesignal_id text default null,
  p_error text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room text;
begin
  if p_message_id is null then
    return;
  end if;
  select room_code into v_room
    from public.push_deliveries
   where message_id = p_message_id;

  if v_room is null then
    return;
  end if;
  if not public.is_service_role() and not public.is_room_member(v_room) then
    raise exception 'not a room member' using errcode = '42501';
  end if;

  update public.push_deliveries
     set status = case when p_success then 'sent' else 'failed' end,
         onesignal_id = coalesce(p_onesignal_id, onesignal_id),
         error = case when p_success then null else p_error end,
         updated_at = now()
   where message_id = p_message_id;
end;
$$;

revoke all on function public.complete_push_delivery(
  text, boolean, text, text
) from public;
grant execute on function public.complete_push_delivery(
  text, boolean, text, text
) to authenticated, service_role;

commit;

revoke all on function public.touch_room_member(
  text, boolean, integer, integer, integer
) from public;
grant execute on function public.touch_room_member(
  text, boolean, integer, integer, integer
) to authenticated, service_role;



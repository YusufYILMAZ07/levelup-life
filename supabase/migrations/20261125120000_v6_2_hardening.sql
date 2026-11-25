-- ═══════════════════════════════════════════════════════════════════════════
-- LevelUp Life · v6.2 Hardening
--
-- v6.1 Production Gold'un ÜZERİNE çalıştırılır:
--   1) Oda kurtarma sırrı artık düz metin değil: pgcrypto `crypt()` (bcrypt)
--      özeti `couple_rooms.recovery_secret_hash` içinde tutulur. `room_code`
--      hiçbir koşulda kurtarma sırrı olarak yazılmaz.
--   2) `reclaim_couple_role` brute-force koruması: 5 hatalı denemede 15 dk
--      kilit; sayaç ve kilit zamanı kalıcıdır.
--   3) `push_deliveries.message_id` üzerindeki `on delete cascade` kaldırılır:
--      silinen mesajın idempotency kaydı yaşamaya devam eder, aynı kimlik
--      yeniden kullanılsa bile partner ikinci push almaz.
--
-- Kurulum sırası:
--   supabase/migrations/20261123000000_v6_security.sql        (önce)
--   supabase/migrations/20261125000000_v6_1_production_gold.sql
--   supabase/migrations/20261125120000_v6_2_hardening.sql      (bu dosya)
--
-- Kurtarma akışı (uygulama tarafı):
--   * Odaya üye olan cihaz `select public.issue_couple_recovery_secret('ODA');`
--     çağırır → düz metin kod **yalnızca bu yanıtta** döner ve kullanıcıya bir
--     kez gösterilir; sunucuda yalnızca bcrypt özeti kalır.
--   * Kullanıcı kendi parolasını seçmek isterse
--     `select public.set_couple_recovery_secret('ODA', 'uzun-parola');`
--   * Cihaz değişiminde `select public.reclaim_couple_role('ODA','ceyda','KOD');`
--     dönen değer: 'ok' | 'invalid' | 'locked'.
-- ═══════════════════════════════════════════════════════════════════════════

begin;

create extension if not exists pgcrypto;

-- ── 1) Kurtarma sırrı: bcrypt özeti + deneme sayacı ───────────────────────
alter table public.couple_rooms
  add column if not exists recovery_secret_hash text,
  add column if not exists recovery_failed_attempts integer not null default 0,
  add column if not exists recovery_locked_until timestamptz;

-- v6.1'de `recovery_secret` düz metin (çoğu zaman oda kodunun kopyası) olarak
-- tutuluyordu. Gerçek bir sır varsa tek yönlü hash'e çevrilir; oda koduyla
-- aynı olan anlamsız değerler silinir ve sütun kaldırılır.
do $$
begin
  if exists (
    select 1
      from information_schema.columns
     where table_schema = 'public'
       and table_name = 'couple_rooms'
       and column_name = 'recovery_secret'
  ) then
    execute $migrate$
      update public.couple_rooms
         set recovery_secret_hash = crypt(recovery_secret, gen_salt('bf', 12))
       where recovery_secret is not null
         and recovery_secret <> room_code
         and recovery_secret_hash is null
    $migrate$;
    execute 'alter table public.couple_rooms drop column recovery_secret';
  end if;
end;
$$;

alter table public.couple_rooms
  drop constraint if exists couple_rooms_recovery_attempts_check;

alter table public.couple_rooms
  add constraint couple_rooms_recovery_attempts_check
    check (recovery_failed_attempts between 0 and 1000);

-- ── 2) Odaya katılma: oda kodu kurtarma sırrı olarak YAZILMAZ ─────────────
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
  v_inserted  integer := 0;
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

  -- Oda ilk kez oluşturulurken yüksek entropili bir kurtarma sırrı üretilir ve
  -- yalnızca bcrypt özeti saklanır (düz metin asla yazılmaz). Kullanıcı bu
  -- kodu `issue_couple_recovery_secret` ile bir kez görüntüleyebilir.
  insert into public.couple_rooms (room_code)
  values (v_code)
  on conflict (room_code) do nothing;
  get diagnostics v_inserted = row_count;

  if v_inserted > 0 then
    update public.couple_rooms
       set recovery_secret_hash = crypt(
             encode(gen_random_bytes(16), 'hex'),
             gen_salt('bf', 12)
           )
     where room_code = v_code;
  end if;

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

-- ── 3) Kurtarma kodu üretimi (düz metin yalnızca bir kez döner) ───────────
create or replace function public.issue_couple_recovery_secret(
  p_room_code text
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code   text := upper(trim(p_room_code));
  v_uid    uuid := auth.uid();
  v_secret text;
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

  v_secret := encode(gen_random_bytes(16), 'hex');

  update public.couple_rooms
     set recovery_secret_hash = crypt(v_secret, gen_salt('bf', 12)),
         recovery_failed_attempts = 0,
         recovery_locked_until = null
   where room_code = v_code;

  if not found then
    raise exception 'room not found' using errcode = 'P0002';
  end if;

  -- Düz metin yalnızca bu yanıtta; veritabanında sadece bcrypt özeti kalır.
  return v_secret;
end;
$$;

revoke all on function public.issue_couple_recovery_secret(text) from public;
grant execute on function public.issue_couple_recovery_secret(text)
  to authenticated, service_role;

-- ── 4) Kullanıcının kendi seçtiği kurtarma parolası ──────────────────────
create or replace function public.set_couple_recovery_secret(
  p_room_code text,
  p_secret    text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code     text := upper(trim(p_room_code));
  v_uid      uuid := auth.uid();
  v_secret   text := trim(coalesce(p_secret, ''));
begin
  if p_room_code is null or v_secret = '' then
    raise exception 'invalid recovery payload' using errcode = '22023';
  end if;
  if v_uid is null then
    raise exception 'auth required' using errcode = '28000';
  end if;
  if length(v_secret) < 8 or length(v_secret) > 128 then
    raise exception 'recovery secret length' using errcode = '22023';
  end if;
  if not public.is_room_member(v_code) then
    raise exception 'not a room member' using errcode = '42501';
  end if;

  update public.couple_rooms
     set recovery_secret_hash = crypt(v_secret, gen_salt('bf', 12)),
         recovery_failed_attempts = 0,
         recovery_locked_until = null
   where room_code = v_code;

  if not found then
    raise exception 'room not found' using errcode = 'P0002';
  end if;
end;
$$;

revoke all on function public.set_couple_recovery_secret(text, text) from public;
grant execute on function public.set_couple_recovery_secret(text, text)
  to authenticated, service_role;

-- ── 5) Rol geri alma: bcrypt doğrulama + kalıcı brute-force kilidi ────────
--
-- Dönüş tipi `void` → `text` olarak değiştiği için önce DROP gerekir.
-- Hatalı denemede `raise exception` kullanılsaydı tüm transaction (sayaç
-- güncellemesi dahil) geri alınırdı; bu yüzden durum metin olarak döner.
drop function if exists public.reclaim_couple_role(text, text, text);

create function public.reclaim_couple_role(
  p_room_code text,
  p_role text,
  p_recovery_secret text
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code         text := upper(trim(p_room_code));
  v_role         text := lower(trim(p_role));
  v_uid          uuid := auth.uid();
  v_hash         text;
  v_attempts     integer := 0;
  v_locked_until timestamptz;
  v_next_attempt integer;
  v_next_lock    timestamptz;
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

  select recovery_secret_hash,
         recovery_failed_attempts,
         recovery_locked_until
    into v_hash, v_attempts, v_locked_until
    from public.couple_rooms
   where room_code = v_code
   for update;

  if not found then
    raise exception 'room not found' using errcode = 'P0002';
  end if;

  if v_locked_until is not null and v_locked_until > now() then
    -- Kilitliyken sır denenmez; durum istemciye taşınır.
    raise exception 'recovery locked until %', v_locked_until
      using errcode = 'LR001';
  end if;

  if v_hash is null then
    raise exception 'recovery secret not configured' using errcode = 'LR002';
  end if;

  if crypt(p_recovery_secret, v_hash) <> v_hash then
    v_next_attempt := v_attempts + 1;
    v_next_lock := case
      when v_next_attempt >= 5 then now() + interval '15 minutes'
      else null
    end;
    update public.couple_rooms
       set recovery_failed_attempts = v_next_attempt,
           recovery_locked_until = v_next_lock
     where room_code = v_code;
    return case when v_next_lock is null then 'invalid' else 'locked' end;
  end if;

  update public.couple_rooms
     set recovery_failed_attempts = 0,
         recovery_locked_until = null
   where room_code = v_code;

  -- Bu kullanıcının odadaki eski rolünü bırak; ardından hedef rolü devral.
  delete from public.room_members
   where room_code = v_code and user_id = v_uid and role <> v_role;

  update public.room_members
     set user_id = v_uid
   where room_code = v_code and role = v_role;

  if not found then
    insert into public.room_members (room_code, user_id, role)
    values (v_code, v_uid, v_role);
  end if;

  return 'ok';
end;
$$;

revoke all on function public.reclaim_couple_role(text, text, text) from public;
grant execute on function public.reclaim_couple_role(text, text, text)
  to authenticated, service_role;

-- ── 6) Push idempotency kaydı mesaj silinince yaşamaya devam eder ─────────
do $$
begin
  if to_regclass('public.push_deliveries') is not null then
    alter table public.push_deliveries
      drop constraint if exists push_deliveries_message_id_fkey;
    -- Idempotency anahtarı artık bağımsız: `chat_messages` silinse bile kayıt
    -- korunur (FK yok), aynı mesaj kimliği yeniden kullanılsa bile çift push yok.
    comment on column public.push_deliveries.message_id is
      'Idempotency anahtarı; chat_messages silinse bile kayıt korunur (FK yok).';
  end if;
end;
$$;

commit;



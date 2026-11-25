-- ═══════════════════════════════════════════════════════════════════════════
-- LevelUp Life · v6.3 Polish
--
-- v6.2 Hardening'in ÜZERİNE çalıştırılır:
--   1) `pgcrypto` şema düzeltmesi: Supabase'de eklenti varsayılan olarak
--      `extensions` şemasına kurulur. v6.1/v6.2 fonksiyonları
--      `set search_path = public` ile tanımlıydı; bu yüzden `crypt`,
--      `gen_salt`, `gen_random_bytes` canlıda
--      "function ... does not exist" hatası verebiliyordu. Dört fonksiyon da
--      `set search_path = public, extensions` ile yeniden tanımlanır.
--   2) `reclaim_couple_role`: boş/whitespace kurtarma sırrı bcrypt çalıştırmaz
--      ve deneme sayacını artırmaz (`22023`).
--   3) `reclaim_couple_role`: 15 dakikalık kilit süresi dolduğunda sayaç
--      sıfırlanır; kullanıcı yeniden 5 deneme hakkı alır (aksi hâlde kilit
--      bittikten sonraki ilk hatalı deneme anında yeniden kilitleniyordu).
--
-- Kurulum sırası:
--   supabase/migrations/20261123000000_v6_security.sql
--   supabase/migrations/20261125000000_v6_1_production_gold.sql
--   supabase/migrations/20261125120000_v6_2_hardening.sql
--   supabase/migrations/20261125180000_v6_3_polish.sql          (bu dosya)
--
-- Kurtarma akışı (uygulama tarafı):
--   * Odaya üye cihaz → `select public.issue_couple_recovery_secret('ODA');`
--     Düz metin kod **yalnızca bu yanıtta** döner; sunucuda bcrypt özeti kalır.
--   * Kullanıcı kendi parolasını seçebilir →
--     `select public.set_couple_recovery_secret('ODA', 'uzun-parola');`
--   * Cihaz değişiminde →
--     `select public.reclaim_couple_role('ODA','ceyda','KOD');`
--     dönen değer: 'ok' | 'invalid' | 'locked'.
-- ═══════════════════════════════════════════════════════════════════════════

begin;

-- ── 0) pgcrypto: Supabase'in `extensions` şemasında bulunur ───────────────
create extension if not exists pgcrypto with schema extensions;

do $$
begin
  if to_regprocedure('extensions.crypt(text,text)') is null
     and to_regprocedure('public.crypt(text,text)') is null then
    raise exception
      'pgcrypto bulunamadı: create extension pgcrypto with schema extensions;';
  end if;
end;
$$;

alter table public.couple_rooms
  add column if not exists recovery_secret_hash text,
  add column if not exists recovery_failed_attempts integer not null default 0,
  add column if not exists recovery_locked_until timestamptz;

-- ── 1) Odaya katılma: oda kodu kurtarma sırrı olarak YAZILMAZ ─────────────
create or replace function public.join_couple_room(
  p_room_code text,
  p_role      text
)
returns void
language plpgsql
security definer
set search_path = public, extensions
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


-- ── 2) Kurtarma kodu üretimi (düz metin yalnızca bir kez döner) ───────────
create or replace function public.issue_couple_recovery_secret(
  p_room_code text
)
returns text
language plpgsql
security definer
set search_path = public, extensions
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

-- ── 3) Kullanıcının kendi seçtiği kurtarma parolası ──────────────────────
create or replace function public.set_couple_recovery_secret(
  p_room_code text,
  p_secret    text
)
returns void
language plpgsql
security definer
set search_path = public, extensions
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

-- ── 4) Rol geri alma: bcrypt doğrulama + kalıcı brute-force kilidi ────────
--
-- Dönüş tipi `void` → `text` olduğu için önce DROP gerekir (v6.2'de yapıldı,
-- tekrar çalıştırılabilirlik için burada da korunur).
drop function if exists public.reclaim_couple_role(text, text, text);

create function public.reclaim_couple_role(
  p_room_code text,
  p_role text,
  p_recovery_secret text
)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_code         text := upper(trim(p_room_code));
  v_role         text := lower(trim(p_role));
  v_secret       text := trim(coalesce(p_recovery_secret, ''));
  v_uid          uuid := auth.uid();
  v_hash         text;
  v_attempts     integer := 0;
  v_locked_until timestamptz;
  v_next_attempt integer;
  v_next_lock    timestamptz;
begin
  if p_room_code is null or p_role is null then
    raise exception 'invalid reclaim payload' using errcode = '22023';
  end if;
  -- Boş / yalnızca whitespace sır bcrypt'e gitmez: pencereyi boşa harcamaz ve
  -- deneme sayacını artırmaz (kullanıcı yanlışlıkla kendini kilitlemez).
  if v_secret = '' then
    raise exception 'invalid recovery secret' using errcode = '22023';
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

  -- Kilit süresi doldu: sayaç sıfırlanır, kullanıcı 5 yeni deneme hakkı alır.
  if v_locked_until is not null and v_locked_until <= now() then
    v_attempts := 0;
    v_locked_until := null;
    update public.couple_rooms
       set recovery_failed_attempts = 0,
           recovery_locked_until = null
     where room_code = v_code;
  end if;

  if v_hash is null then
    raise exception 'recovery secret not configured' using errcode = 'LR002';
  end if;

  if crypt(v_secret, v_hash) <> v_hash then
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

commit;


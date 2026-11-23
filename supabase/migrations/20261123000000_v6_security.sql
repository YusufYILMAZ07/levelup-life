-- ═══════════════════════════════════════════════════════════════════════════
-- LevelUp Life · v6 güvenlik migrasyonu
--
-- v5'teki "for all using (true)" politikaları ve public `couple-media` kovası
-- kaldırılır. Erişim yalnızca doğrulanmış oda üyelerine açıktır.
--
-- Kurulum: Supabase Dashboard → SQL Editor → bu dosyanın tamamını çalıştır.
-- Anonymous sign-in: Authentication → Providers → Anonymous → Enable.
-- ═══════════════════════════════════════════════════════════════════════════

begin;

create extension if not exists pgcrypto;

-- ── Tablolar ──────────────────────────────────────────────────────────────
create table if not exists public.couple_rooms (
  room_code  text primary key,
  state_json jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.room_members (
  room_code text not null references public.couple_rooms(room_code) on delete cascade,
  user_id   uuid not null references auth.users(id) on delete cascade,
  role      text not null check (role in ('yusuf', 'ceyda')),
  joined_at timestamptz not null default now(),
  primary key (room_code, user_id),
  constraint room_members_role_unique unique (room_code, role)
);

create table if not exists public.chat_messages (
  id         text primary key,
  room_code  text not null references public.couple_rooms(room_code) on delete cascade,
  sender_id  text not null check (sender_id in ('yusuf', 'ceyda')),
  payload    jsonb not null,
  created_at timestamptz not null default now()
);

create index if not exists chat_messages_room_created_idx
  on public.chat_messages (room_code, created_at desc);

-- Realtime DELETE / UPDATE olaylarında eski satırın tamamını taşır.
alter table public.chat_messages replica identity full;
alter table public.couple_rooms  replica identity full;

-- ── Üyelik yardımcıları ───────────────────────────────────────────────────
create or replace function public.is_room_member(p_room_code text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.room_members m
     where m.room_code = upper(trim(p_room_code))
       and m.user_id = auth.uid()
  );
$$;

create or replace function public.member_role(p_room_code text)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select m.role
    from public.room_members m
   where m.room_code = upper(trim(p_room_code))
     and m.user_id = auth.uid()
   limit 1;
$$;

revoke all on function public.is_room_member(text) from public;
revoke all on function public.member_role(text) from public;
grant execute on function public.is_room_member(text) to authenticated;
grant execute on function public.member_role(text) to authenticated;

-- ── Odaya katılma (tek yetkili giriş kapısı) ──────────────────────────────
-- Oda kodu davet sırrıdır. En fazla 2 üye, rol başına 1 cihaz.
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
  v_code   text := upper(trim(p_room_code));
  v_uid    uuid := auth.uid();
  v_role   text := lower(trim(p_role));
  v_existing text;
begin
  if v_uid is null then
    raise exception 'auth required' using errcode = '28000';
  end if;
  if v_role not in ('yusuf', 'ceyda') then
    raise exception 'invalid role' using errcode = '22023';
  end if;
  if length(v_code) < 6 or length(v_code) > 64 then
    raise exception 'invalid room code' using errcode = '22023';
  end if;

  insert into public.couple_rooms (room_code)
  values (v_code)
  on conflict (room_code) do nothing;

  select m.role into v_existing
    from public.room_members m
   where m.room_code = v_code and m.user_id = v_uid;

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
grant execute on function public.join_couple_room(text, text) to authenticated;

-- ── updated_at otomatiği ──────────────────────────────────────────────────
create or replace function public.touch_couple_room()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists couple_rooms_touch on public.couple_rooms;
create trigger couple_rooms_touch
before update on public.couple_rooms
for each row execute function public.touch_couple_room();

-- ── RLS ───────────────────────────────────────────────────────────────────
alter table public.couple_rooms  enable row level security;
alter table public.room_members  enable row level security;
alter table public.chat_messages enable row level security;

-- v5 politikalarını temizle (güvenlik açığı).
drop policy if exists "couple_rooms_all"   on public.couple_rooms;
drop policy if exists "chat_messages_all"  on public.chat_messages;
drop policy if exists "couple_media_all"   on storage.objects;

-- Oda: yalnızca üyeler okur/yazar. İlk oda kaydı RPC (definer) tarafından atılır.
drop policy if exists couple_rooms_select on public.couple_rooms;
create policy couple_rooms_select on public.couple_rooms
  for select to authenticated
  using (public.is_room_member(room_code));

drop policy if exists couple_rooms_update on public.couple_rooms;
create policy couple_rooms_update on public.couple_rooms
  for update to authenticated
  using (public.is_room_member(room_code))
  with check (public.is_room_member(room_code));

-- Üyeler: yalnızca kendi odasının üyelerini görür; yazma RPC'ye kapalıdır.
drop policy if exists room_members_select on public.room_members;
create policy room_members_select on public.room_members
  for select to authenticated
  using (public.is_room_member(room_code));

-- Mesajlar: gönderen kimliği üyelik rolüyle eşleşmek zorunda.
drop policy if exists chat_messages_select on public.chat_messages;
create policy chat_messages_select on public.chat_messages
  for select to authenticated
  using (public.is_room_member(room_code));

drop policy if exists chat_messages_insert on public.chat_messages;
create policy chat_messages_insert on public.chat_messages
  for insert to authenticated
  with check (
    public.is_room_member(room_code)
    and sender_id = public.member_role(room_code)
  );

drop policy if exists chat_messages_update on public.chat_messages;
create policy chat_messages_update on public.chat_messages
  for update to authenticated
  using (sender_id = public.member_role(room_code))
  with check (sender_id = public.member_role(room_code));

drop policy if exists chat_messages_delete on public.chat_messages;
create policy chat_messages_delete on public.chat_messages
  for delete to authenticated
  using (sender_id = public.member_role(room_code));

-- ── Özel medya kovası + Storage RLS ───────────────────────────────────────
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'couple-media',
  'couple-media',
  false,
  26214400,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'video/mp4', 'video/quicktime']
)
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists couple_media_select on storage.objects;
create policy couple_media_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'couple-media'
    and public.is_room_member((storage.foldername(name))[1])
  );

drop policy if exists couple_media_insert on storage.objects;
create policy couple_media_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'couple-media'
    and public.is_room_member((storage.foldername(name))[1])
  );

drop policy if exists couple_media_update on storage.objects;
create policy couple_media_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'couple-media'
    and public.is_room_member((storage.foldername(name))[1])
  );

drop policy if exists couple_media_delete on storage.objects;
create policy couple_media_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'couple-media'
    and public.is_room_member((storage.foldername(name))[1])
  );

-- ── Realtime yayını (v5 yalnızca insert dinliyordu) ───────────────────────
do $$
begin
  alter publication supabase_realtime add table public.chat_messages;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.couple_rooms;
exception
  when duplicate_object then null;
end $$;

commit;

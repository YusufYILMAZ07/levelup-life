-- ═══════════════════════════════════════════════════════════════════════════
-- LevelUp Life · v6.1 · OPSİYONEL sunucu tarafı push garantisi (pg_net)
--
-- Bu dosya `.example.sql` uzantılıdır; `supabase db push` tarafından otomatik
-- çalıştırılmaz. İstemci outbox'ı zaten push garantisi verir. İstemci kapanmış
-- olsa bile HER INSERT'te push istiyorsan aşağıdaki adımları Supabase SQL
-- Editor'da çalıştır:
--
--   1) Edge Function'ı deploy et (önce v6.1 migration'ı uygulanmış olmalı):
--        supabase functions deploy send-couple-push
--   2) Aşağıdaki iki `alter database` satırındaki değerleri kendi projenle
--      değiştir (service role anahtarı yalnızca veritabanı ayarında durur).
--   3) Dosyanın geri kalanını çalıştır.
--
-- İdempotency: `push_deliveries` + `claim_push_delivery` sayesinde istemci ile
-- webhook aynı mesajı iki kez göndermez; ikinci çağrı `duplicate:true` döner.
-- ═══════════════════════════════════════════════════════════════════════════

create extension if not exists pg_net;

-- ⚠️ Aşağıdaki iki satırı kendi proje ref'in ve service_role anahtarınla
--    değiştir. Bu dosyayı secret'larla birlikte commit ETME.
-- alter database postgres set app.settings.edge_push_url =
--   'https://<PROJECT_REF>.supabase.co/functions/v1/send-couple-push';
-- alter database postgres set app.settings.edge_push_service_key =
--   '<SERVICE_ROLE_KEY>';

create or replace function public.notify_couple_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url     text := current_setting('app.settings.edge_push_url', true);
  v_key     text := current_setting('app.settings.edge_push_service_key', true);
  v_type    text;
  v_preview text;
begin
  if v_url is null or v_url = '' or v_key is null or v_key = '' then
    return new;
  end if;

  v_type := case
    when coalesce(new.payload ->> 'kind', '') = 'nudge' then 'nudge'
    else 'chat'
  end;

  v_preview := coalesce(
    nullif(new.payload ->> 'text', ''),
    nullif(new.payload ->> 'photo_caption', ''),
    'Partnerinden yeni bir bildirim var.'
  );

  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_key
    ),
    body := jsonb_build_object(
      'type', v_type,
      'message_id', new.id,
      'room_code', new.room_code,
      'sender_id', new.sender_id,
      'recipient_id', case
        when new.sender_id = 'yusuf' then 'ceyda'
        else 'yusuf'
      end,
      'headings', 'LevelUp Life 💞',
      'contents', left(v_preview, 140),
      'urgent', v_type = 'nudge'
    ),
    timeout_milliseconds := 10000
  );
  return new;
end;
$$;

drop trigger if exists chat_messages_push_webhook on public.chat_messages;
create trigger chat_messages_push_webhook
after insert on public.chat_messages
for each row execute function public.notify_couple_push();

-- Geri almak için:
-- drop trigger if exists chat_messages_push_webhook on public.chat_messages;
-- drop function if exists public.notify_couple_push();
-- alter database postgres reset app.settings.edge_push_url;
-- alter database postgres reset app.settings.edge_push_service_key;

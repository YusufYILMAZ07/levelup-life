// LevelUp Life · v6.1 · `send-couple-push` Edge Function
//
// OneSignal REST API anahtarı YALNIZCA sunucuda durur. Fonksiyon:
//   1) istemci çağrısında Anonymous Auth oturumunu doğrular,
//   2) Database Webhook çağrısında service_role JWT'sini doğrular,
//   3) oda üyeliğini / mesaj sahibini / alıcıyı doğrular,
//   4) alıcının push_enabled + sessiz saat ayarını uygular,
//   5) `push_deliveries` atomik claim ile çifte push'u engeller,
//   6) OneSignal'a yüksek öncelikli, oda kapsamlı `external_id` push'u atar.
//
// Secret'lar:
//   supabase secrets set ONESIGNAL_APP_ID=... ONESIGNAL_REST_API_KEY=...
// Deploy:
//   supabase functions deploy send-couple-push
//
// Webhook rehberi: supabase/migrations/20261123002000_v6_1_push_webhook.example.sql

import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const ROLES = new Set(["yusuf", "ceyda"]);
const CHANNEL_ID = "levelup_couple_messages";

interface PushBody {
  recipient_id?: string;
  sender_id?: string;
  room_code?: string;
  type?: string;
  message_id?: string;
  headings?: string;
  contents?: string;
  urgent?: boolean;
  data?: Record<string, unknown>;
}

interface MessageRow {
  id: string;
  room_code: string;
  sender_id: string;
  payload: Record<string, unknown> | null;
}

interface MemberRow {
  role: string;
  push_enabled: boolean | null;
  quiet_start_minute: number | null;
  quiet_end_minute: number | null;
  utc_offset_minutes: number | null;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

function cleanText(value: unknown, max: number): string {
  const text = typeof value === "string" ? value.trim() : "";
  return text.length > max ? `${text.slice(0, max - 1)}…` : text;
}

/// Doğrulanması gereken kimlik alanları için: kırpma YAPMAZ, yalnızca trim
/// eder. Uzunluk/form hataları aşağıda `invalid_payload` ile reddedilir.
function cleanIdentifier(value: unknown, max: number): string | null {
  if (typeof value !== "string") return null;
  const text = value.trim();
  if (text.length === 0 || text.length > max) return null;
  return text;
}

function displayName(role: string): string {
  return role === "ceyda" ? "Ceyda 🌸" : "Yusuf 💻";
}

function otherRole(role: string): string {
  return role === "ceyda" ? "yusuf" : "ceyda";
}

/** `<oda>__<rol>` — istemcideki MessageDeliveryPolicy ile aynı. */
function scopedExternalId(roomCode: string, role: string): string {
  return `${roomCode.trim().toLowerCase()}__${role.trim().toLowerCase()}`;
}

function payloadPreview(payload: Record<string, unknown> | null): string {
  if (!payload) return "Partnerinden yeni bir bildirim var.";
  const text = cleanText(payload.text, 140);
  const kind = cleanText(payload.kind, 24);
  const mediaType = cleanText(payload.media_type, 16);
  if (mediaType === "video") return "Yeni bir video gönderdi 🎥";
  if (kind === "proof") return "Plan kanıtı paylaştı 📅";
  if (kind === "nudge") {
    return text.length > 0 ? text : "Sana bir dürtme gönderdi 💫";
  }
  if (mediaType === "image") return "Yeni bir fotoğraf gönderdi 📸";
  if (kind === "love_note" && text.length === 0) {
    return "Sana bir aşk notu bıraktı 💌";
  }
  return text.length > 0 ? text : "Sana yeni bir mesaj gönderdi 💌";
}

/** Alıcının yerel saatini UTC offset ile hesaplar. */
function recipientMinute(now: Date, utcOffsetMinutes: number): number {
  const utc = now.getUTCHours() * 60 + now.getUTCMinutes();
  return ((utc + utcOffsetMinutes) % 1440 + 1440) % 1440;
}

function isQuietNow(
  start: number | null,
  end: number | null,
  utcOffsetMinutes: number,
  now: Date,
): boolean {
  if (start === null || end === null) return false;
  if (start < 0 || start > 1439 || end < 0 || end > 1439) return false;
  if (start === end) return false;
  const minute = recipientMinute(now, utcOffsetMinutes);
  return start < end
    ? minute >= start && minute < end
    : minute >= start || minute < end;
}

function nudgeCollapseId(roomCode: string, senderId: string): string {
  const raw = `nudge-${roomCode}-${senderId}`
    .toLowerCase()
    .replace(/[^a-z0-9-]+/g, "-")
    .slice(0, 60);
  return raw.replace(/-+$/g, "");
}

async function claimDelivery(
  db: SupabaseClient,
  messageId: string,
  roomCode: string,
  recipientId: string,
): Promise<boolean> {
  const { data, error } = await db.rpc("claim_push_delivery", {
    p_message_id: messageId,
    p_room_code: roomCode,
    p_recipient_id: recipientId,
  });
  if (error) throw error;
  return data === true;
}

async function completeDelivery(
  db: SupabaseClient,
  messageId: string,
  success: boolean,
  oneSignalId: string | null,
  errorText: string | null,
): Promise<void> {
  const { error } = await db.rpc("complete_push_delivery", {
    p_message_id: messageId,
    p_success: success,
    p_onesignal_id: oneSignalId,
    p_error: errorText,
  });
  if (error) {
    console.error("complete_push_delivery failed", error.message);
  }
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey =
    Deno.env.get("SUPABASE_ANON_KEY") ??
    Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
    "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const oneSignalAppId = Deno.env.get("ONESIGNAL_APP_ID") ?? "";
  const oneSignalKey = Deno.env.get("ONESIGNAL_REST_API_KEY") ?? "";

  if (!supabaseUrl || !anonKey) {
    return json({ error: "supabase_env_missing" }, 500);
  }
  if (!oneSignalAppId || !oneSignalKey) {
    return json({ error: "onesignal_env_missing" }, 500);
  }

  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization.toLowerCase().startsWith("bearer ")) {
    return json({ error: "auth_required" }, 401);
  }
  const isServiceRole =
    serviceRoleKey.length > 0 && authorization === `Bearer ${serviceRoleKey}`;

  let body: PushBody;
  try {
    body = await req.json() as PushBody;
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const rawRoomCode = cleanIdentifier(body.room_code, 64);
  const rawSenderId = cleanIdentifier(body.sender_id, 16);
  const rawRecipientId = cleanIdentifier(body.recipient_id, 16);
  const rawType = cleanIdentifier(body.type, 16);
  const rawMessageId = cleanIdentifier(body.message_id, 128);

  // Kimlik alanları kısaltılmaz; geçersiz uzunluk/form doğrudan reddedilir.
  if (
    rawRoomCode === null ||
    rawRoomCode.length < 6 ||
    rawSenderId === null ||
    !ROLES.has(rawSenderId.toLowerCase()) ||
    rawRecipientId === null ||
    !ROLES.has(rawRecipientId.toLowerCase()) ||
    rawType === null ||
    !["chat", "nudge", "test"].includes(rawType)
  ) {
    return json({ error: "invalid_payload" }, 400);
  }

  const roomCode = rawRoomCode.toUpperCase();
  const senderId = rawSenderId.toLowerCase();
  const requestedRecipient = rawRecipientId.toLowerCase();
  const type = rawType;
  const messageId = rawMessageId ?? "";
  const urgent = body.urgent === true || type === "nudge";

  const db: SupabaseClient = isServiceRole
    ? createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })
    : createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });

  if (!isServiceRole) {
    const { data: userData, error: userError } = await db.auth.getUser();
    if (userError || !userData.user) {
      return json({ error: "auth_required" }, 401);
    }
    const { data: membership, error: memberError } = await db
      .from("room_members")
      .select("role")
      .eq("room_code", roomCode)
      .eq("user_id", userData.user.id)
      .maybeSingle();
    if (memberError) {
      return json({ error: "membership_check_failed" }, 500);
    }
    if (!membership || membership.role !== senderId) {
      return json({ error: "not_a_room_member" }, 403);
    }
  }

  let recipientId = requestedRecipient;
  let headings = cleanText(body.headings, 80);
  let contents = cleanText(body.contents, 160);
  let canonicalMessageId: string | null = messageId.length > 0 ? messageId : null;

  if (type === "chat" || type === "nudge") {
    if (!canonicalMessageId) {
      return json({ error: "message_id_required" }, 400);
    }
    const { data: row, error: rowError } = await db
      .from("chat_messages")
      .select("id, room_code, sender_id, payload")
      .eq("id", canonicalMessageId)
      .eq("room_code", roomCode)
      .maybeSingle<MessageRow>();
    if (rowError) {
      return json({ error: "message_lookup_failed" }, 500);
    }
    if (!row) {
      return json({ error: "message_not_found" }, 404);
    }
    if (row.sender_id !== senderId) {
      return json({ error: "sender_mismatch" }, 403);
    }
    recipientId = otherRole(row.sender_id);
    if (
      requestedRecipient.length > 0 &&
      requestedRecipient !== recipientId
    ) {
      return json({ error: "invalid_recipient" }, 400);
    }
    const preview = payloadPreview(row.payload);
    headings = headings || `LevelUp Life · ${displayName(senderId)}`;
    contents = contents || preview;
    if (type === "nudge") {
      headings = `💫 Dürtme · ${displayName(senderId)}`;
      if (contents.length === 0) contents = "Hadi bir puan daha! 💫";
    }
  } else {
    if (!ROLES.has(recipientId) || recipientId === senderId) {
      return json({ error: "invalid_recipient" }, 400);
    }
    if (recipientId !== otherRole(senderId)) {
      return json({ error: "invalid_recipient" }, 400);
    }
    headings = headings || "LevelUp Life · OneSignal 💞";
    contents = contents || "Partnerinden yeni bir bildirim var.";
  }

  if (!ROLES.has(recipientId)) {
    return json({ error: "invalid_recipient" }, 400);
  }


  // Alıcının cihaz sağlığı ve sessiz saatleri (opsiyonel; migration yoksa
  // select hata verirse push yine gönderilir).
  let recipient: MemberRow | null = null;
  const { data: memberData, error: memberLookupError } = await db
    .from("room_members")
    .select(
      "role, push_enabled, quiet_start_minute, quiet_end_minute, utc_offset_minutes",
    )
    .eq("room_code", roomCode)
    .eq("role", recipientId)
    .maybeSingle<MemberRow>();
  if (!memberLookupError && memberData) recipient = memberData;

  if (recipient?.push_enabled === false) {
    if (canonicalMessageId) {
      await completeDelivery(db, canonicalMessageId, true, null, null);
    }
    return json({ ok: true, suppressed: "push_disabled" });
  }

  const quiet = !urgent &&
    isQuietNow(
      recipient?.quiet_start_minute ?? null,
      recipient?.quiet_end_minute ?? null,
      recipient?.utc_offset_minutes ?? 0,
      new Date(),
    );
  if (quiet) {
    if (canonicalMessageId) {
      await completeDelivery(db, canonicalMessageId, true, null, null);
    }
    return json({ ok: true, suppressed: "quiet_hours" });
  }

  // Atomik idempotency: istemci ve DB webhook'u aynı anda çağırsa bile yalnızca
  // biri `sending` hakkını alır. Diğeri `duplicate:true` alır.
  if (canonicalMessageId) {
    let claimed = false;
    try {
      claimed = await claimDelivery(
        db,
        canonicalMessageId,
        roomCode,
        recipientId,
      );
    } catch (error) {
      const text = error instanceof Error ? error.message : String(error);
      return json({ error: "push_claim_failed", detail: text }, 500);
    }
    if (!claimed) {
      return json({ ok: true, duplicate: true });
    }
  }

  const nudge = type === "nudge";
  const data = {
    ...(body.data ?? {}),
    type,
    message_id: canonicalMessageId,
    sender_id: senderId,
    room_code: roomCode,
    route: "chat",
  };

  const notification: Record<string, unknown> = {
    app_id: oneSignalAppId,
    include_aliases: {
      external_id: [scopedExternalId(roomCode, recipientId)],
    },
    target_channel: "push",
    headings: { tr: headings, en: headings },
    contents: { tr: contents, en: contents },
    data,
    priority: 10,
    android_priority: "high",
    android_channel_id: CHANNEL_ID,
    android_sound: "default",
    android_visibility: nudge ? "public" : "private",
    ios_sound: "default",
    ios_interruption_level: nudge ? "timeSensitive" : "active",
    ios_badgeType: "Increase",
    ios_badgeCount: 1,
    ttl: nudge ? 86400 : 259200,
  };
  if (nudge) {
    notification.collapse_id = nudgeCollapseId(roomCode, senderId);
  }

  let response: Response;
  let payload: Record<string, unknown> = {};
  try {
    response = await fetch("https://api.onesignal.com/notifications", {
      method: "POST",
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        Authorization: `Key ${oneSignalKey}`,
      },
      body: JSON.stringify(notification),
      signal: AbortSignal.timeout(8000),
    });
    // OneSignal non-JSON (502/503) yanıt da dönebilir; önce text oku, sonra
    // güvenli JSON.parse yap.
    const rawText = await response.text();
    try {
      payload = rawText.trim().length > 0
        ? JSON.parse(rawText) as Record<string, unknown>
        : {};
    } catch {
      payload = {};
    }
  } catch (error) {
    const text = error instanceof Error ? error.message : String(error);
    if (canonicalMessageId) {
      await completeDelivery(db, canonicalMessageId, false, null, text);
    }
    return json({ error: "onesignal_unreachable", detail: text }, 502);
  }

  const rawOneSignalId = payload["id"];
  const oneSignalId = rawOneSignalId === null || rawOneSignalId === undefined
    ? null
    : String(rawOneSignalId);
  if (canonicalMessageId) {
    await completeDelivery(
      db,
      canonicalMessageId,
      response.ok,
      oneSignalId,
      response.ok ? null : `HTTP ${response.status}`,
    );
  }

  return json(
    {
      ok: response.ok,
      duplicate: false,
      onesignal_status: response.status,
      id: oneSignalId,
      external_id: scopedExternalId(roomCode, recipientId),
    },
    response.ok ? 200 : 502,
  );
});

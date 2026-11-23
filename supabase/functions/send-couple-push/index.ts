// LevelUp Life · v6 · `send-couple-push` Edge Function
//
// OneSignal REST API anahtarı **yalnızca sunucuda** durur. İstemci bu
// fonksiyonu çağırır; fonksiyon:
//   1) çağıranın oturumunu doğrular (Anonymous Auth),
//   2) oda üyeliğini ve rolünü kontrol eder,
//   3) alıcının karşı partner olduğunu doğrular,
//   4) OneSignal REST API'sine push gönderir.
//
// Secret'lar:
//   supabase secrets set ONESIGNAL_APP_ID=... ONESIGNAL_REST_API_KEY=...
// Deploy:
//   supabase functions deploy send-couple-push

import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface PushBody {
  recipient_id?: string;
  sender_id?: string;
  room_code?: string;
  type?: string;
  message_id?: string;
  headings?: string;
  contents?: string;
  data?: Record<string, unknown>;
}

const ROLES = new Set(["yusuf", "ceyda"]);

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

  let body: PushBody;
  try {
    body = await req.json() as PushBody;
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const roomCode = cleanText(body.room_code, 64).toUpperCase();
  const senderId = cleanText(body.sender_id, 16).toLowerCase();
  const recipientId = cleanText(body.recipient_id, 16).toLowerCase();
  const type = cleanText(body.type, 16) || "chat";

  if (roomCode.length < 6 || !ROLES.has(senderId) || !ROLES.has(recipientId)) {
    return json({ error: "invalid_payload" }, 400);
  }
  if (senderId === recipientId) {
    return json({ error: "invalid_recipient" }, 400);
  }

  const supabase = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) {
    return json({ error: "auth_required" }, 401);
  }

  const { data: membership, error: memberError } = await supabase
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

  const headings = cleanText(body.headings, 80) || "LevelUp Life 💞";
  const contents = cleanText(body.contents, 160) ||
    "Partnerinden yeni bir bildirim var.";
  const data = {
    ...(body.data ?? {}),
    type,
    sender_id: senderId,
    room_code: roomCode,
  };

  const response = await fetch("https://api.onesignal.com/notifications", {
    method: "POST",
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      Authorization: `Key ${oneSignalKey}`,
    },
    body: JSON.stringify({
      app_id: oneSignalAppId,
      include_aliases: { external_id: [recipientId] },
      target_channel: "push",
      headings: { tr: headings, en: headings },
      contents: { tr: contents, en: contents },
      data,
      ios_badgeType: "Increase",
      ios_badgeCount: 1,
    }),
  });

  const payload = await response.json().catch(() => ({}));
  return json(
    {
      ok: response.ok,
      onesignal_status: response.status,
      id: (payload as Record<string, unknown>).id ?? null,
    },
    response.ok ? 200 : 502,
  );
});

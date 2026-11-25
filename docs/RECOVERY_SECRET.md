# Oda kurtarma sırrı (v6.3)

v6.1'de `couple_rooms.recovery_secret` düz metin tutuluyordu ve oda
oluşturulurken **oda kodunun kendisi** yazılıyordu. Bu, paylaşılan davet
kodunu aynı zamanda bir yönetici parolası yapıyordu. v6.2
(`supabase/migrations/20261125120000_v6_2_hardening.sql`) bunu kaldırdı; v6.3
(`supabase/migrations/20261125180000_v6_3_polish.sql`) canlı şema/UX
pürüzlerini giderir:

- `recovery_secret` sütunu silinir; yerine yalnızca **bcrypt** özeti tutan
  `recovery_secret_hash` gelir.
- `recovery_failed_attempts` + `recovery_locked_until` ile 5 hatalı denemede
  **15 dakika** kilit uygulanır (sayaç ve kilit kalıcıdır). Kilit süresi
  dolduğunda v6.3 sayacı sıfırlar → kullanıcı yeniden 5 deneme alır.
- Dört RPC (`join_couple_room`, `issue_couple_recovery_secret`,
  `set_couple_recovery_secret`, `reclaim_couple_role`) artık
  `set search_path = public, extensions` ile tanımlıdır. Supabase `pgcrypto`
  eklentisini `extensions` şemasına kurduğu için eski tanım canlıda
  `function crypt(text, text) does not exist` verebiliyordu.
- `reclaim_couple_role` boş/whitespace kodu `22023` ile reddeder: bcrypt
  çalışmaz, deneme sayacı artmaz.
- `push_deliveries.message_id` üzerindeki `on delete cascade` kaldırılır;
  silinen mesajın idempotency kaydı korunur.

## Akış

1. **Kurtarma kodunu bir kez oluştur** (odaya üye cihazdan):

   ```sql
   select public.issue_couple_recovery_secret('YUSUF-CEYDA-2026');
   ```

   Dönen 32 karakterlik kod **yalnızca bu yanıtta** görünür (16 rastgele
   baytın hex hâli). Sunucuda yalnızca bcrypt özeti kalır. Kodu güvenli bir
   yere not edin (parola yöneticisi).

2. **Kendi parolanızı seçmek isterseniz** (en az 8 karakter):

   ```sql
   select public.set_couple_recovery_secret('YUSUF-CEYDA-2026', 'uzun-ve-ozel-parola');
   ```

   Bu çağrı deneme sayacını ve kilidi sıfırlar.

3. **Cihaz değişiminde rolü geri alın** (yeni cihaz anonim oturum açtıktan
   sonra):

   ```sql
   select public.reclaim_couple_role('YUSUF-CEYDA-2026', 'ceyda', 'NOT-EDILEN-KOD');
   ```

   Dönen değer:

   | Değer       | Anlamı                                                        |
   | ----------- | ------------------------------------------------------------- |
   | `ok`        | Rol devralındı, sayaç sıfırlandı                              |
   | `invalid`   | Kod yanlış; sayaç arttı (5'te `locked` döner)                 |
   | `locked`    | 5 hatalı deneme → 15 dakika bekle                             |

   Kilitliyken çağrı `LR001`, kurtarma kodu hiç oluşturulmadıysa `LR002`
   SQLSTATE'i ile hata döner.

## Notlar

- Oda kodu artık **hiçbir** koşulda kurtarma sırrı olarak kabul edilmez.
- Kurtarma kodunu yalnızca odaya üye bir cihaz oluşturabilir/yenileyebilir
  (`is_room_member` kontrolü). Çalınan oda kodu tek başına rol devralmaya
  yetmez.
- Kodu yenilemek eski kodu geçersiz kılar ve bekleyen kilidi açar.
- **Uygulama içi akış (v6.3):** Ayarlar → **☁️ İki Telefon Canlı
  Senkronizasyon** → **🔑 Oda Kurtarma Kodu** kartı.
  - *Kurtarma Kodu Oluştur*: `issue_couple_recovery_secret` RPC'sini çağırır,
    kodu **tek seferlik** diyalogda gösterir (kopyalanabilir).
  - *Rolümü Geri Al*: `reclaim_couple_role` RPC'sini çağırır. Yeni cihazda
    bağlantı `role taken` hatası verirse bu diyalog kendiliğinden açılır.
    Sonuçlar anlamlı mesaja çevrilir: `ok` → rol devralındı ve bağlantı
    yeniden kurulur, `invalid` → kod hatalı, `locked` → 15 dakika bekle,
    `LR002` → odada kurtarma kodu tanımlı değil.
- Kurtarma kodu yalnızca odaya üye cihazdan üretilebilir; kod hiçbir yerde
  düz metin olarak saklanmaz (yalnızca bcrypt özeti).

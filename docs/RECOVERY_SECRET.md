# Oda kurtarma sırrı (v6.2)

v6.1'de `couple_rooms.recovery_secret` düz metin tutuluyordu ve oda
oluşturulurken **oda kodunun kendisi** yazılıyordu. Bu, paylaşılan davet
kodunu aynı zamanda bir yönetici parolası yapıyordu. v6.2
(`supabase/migrations/20261125120000_v6_2_hardening.sql`) bunu kaldırır:

- `recovery_secret` sütunu silinir; yerine yalnızca **bcrypt** özeti tutan
  `recovery_secret_hash` gelir.
- `recovery_failed_attempts` + `recovery_locked_until` ile 5 hatalı denemede
  **15 dakika** kilit uygulanır (sayaç ve kilit kalıcıdır).
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
- Uygulama arayüzünde henüz "Kurtarma kodu oluştur" düğmesi yoktur; akış
  Supabase SQL Editor veya ileride eklenecek bir RPC çağrısıyla yürütülür.

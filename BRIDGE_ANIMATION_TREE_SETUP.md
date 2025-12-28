# Bridge AnimationTree Setup

## 1. Bridge Scene Setup

**Bridge.tscn Yapısı:**
```
Bridge (Node3D) - root node
├── Script: BridgeController.gd
├── AnimationPlayer (mevcut)
│   └── Animations: "A", "B", "C", ... (hepsi aynı anda çalışacak)
└── AnimTree (AnimationTree) - Script otomatik oluşturur veya manuel ekle
    └── anim_player = ../AnimationPlayer
    └── active = true (script ayarlar)
```

**BridgeController.gd Ataması:**
- Bridge root node'una `Scripts/BridgeController.gd` script'ini bağla
- Inspector'da:
  - `exclude_anims`: ["RESET"] (isteğe bağlı animasyonları hariç tut)
  - `auto_start = true` (otomatik başlat)
  - `speed = 1.0` (normal hız)
  - `rewind_speed = -1.0` (rewind hızı)

## 2. AnimationTree Kurulumu

**Manuel Kurulum (Opsiyonel):**
1. Bridge node'una `AnimationTree` ekle (name: AnimTree)
2. Inspector'da:
   - `anim_player = ../AnimationPlayer` (path)
   - `active = false` (script aktif edecek)

**Otomatik Kurulum:**
- Script `_ready()` içinde AnimationTree yoksa otomatik oluşturur
- BlendTree'yi programatik olarak kurar
- Tüm animasyonları paralel çalıştıracak şekilde Mix node'ları ile birleştirir

## 3. BlendTree Yapısı

Script otomatik olarak şu yapıyı oluşturur:
```
BlendTree (root)
├── anim_0 (AnimationNodeAnimation) - İlk animasyon
├── anim_1 (AnimationNodeAnimation) - İkinci animasyon
├── mix_1 (AnimationNodeBlend2) - anim_0 + anim_1
├── anim_2 (AnimationNodeAnimation) - Üçüncü animasyon
├── mix_2 (AnimationNodeBlend2) - mix_1 + anim_2
└── ... (zincirleme devam eder)
└── output (son Mix node'u output'a bağlı)
```

**Nasıl Çalışır:**
- Her animasyon bir AnimationNodeAnimation olarak eklenir
- Zincirleme Mix node'ları ile tüm animasyonlar toplanır
- Mix node'ları blend_amount = 1.0 ile ikinci input'u tam güçte ekler
- Sonuç: Tüm animasyonlar aynı anda paralel çalışır

## 4. Kullanım

**Otomatik Başlatma:**
- `auto_start = true` ise animasyonlar otomatik başlar
- `auto_start = false` ise `start_all_animations()` manuel çağrılmalı

**Speed Kontrolü:**
```gdscript
bridge_controller.speed = 2.0  # 2x hız
bridge_controller.speed = 0.5  # Yarı hız
```

**Rewind:**
```gdscript
bridge_controller.rewind_all()  # Tersten oynat
bridge_controller.resume_normal()  # Normal oynatmaya dön
```

## 5. Debug

**Console Log'lar:**
- `[Bridge] Found X animations: [...]`
- `[Bridge] Parallel animation setup complete: X animations mixed`
- `[Bridge] AnimationTree setup complete`
- `[Bridge] All animations started via AnimationTree`

**Debug Modu:**
- `debug_enabled = true` yaparak detaylı log'ları görebilirsiniz

## 6. Notlar

- **AnimationPlayer**: Artık doğrudan `play()` ile kullanılmaz, AnimationTree kontrol eder
- **Paralel Çalışma**: Tüm animasyonlar aynı anda loop olarak çalışır
- **Exclude**: `exclude_anims` array'ine eklenen animasyonlar dahil edilmez
- **Speed**: AnimationPlayer'ın `speed_scale`'i kullanılır (AnimationTree üzerinden)
- **Rewind**: `speed = -1.0` yaparak tersten oynatılabilir

## 7. Örnek

**AnimationPlayer içinde:**
- "bridge_sway" (loop)
- "flag_wave" (loop)
- "rope_swing" (loop)
- "RESET" (exclude edilir)

**Sonuç:**
- "bridge_sway", "flag_wave", "rope_swing" aynı anda paralel çalışır
- "RESET" animasyonu dahil edilmez


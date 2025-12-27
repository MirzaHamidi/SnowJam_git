# Shield Physics Layers - Notlar

## 📋 Physics Layer Kullanımı

### Varsayılan Layer Yapısı (Godot 4.x)

Godot'da physics layer'lar 1-32 arası index'lerle çalışır. Varsayılan olarak:

- **Layer 1**: Default/World (zemin, statik objeler)
- **Layer 2**: Player (opsiyonel - ayrı layer kullanılıyorsa)
- **Layer 3**: Enemy (opsiyonel - ayrı layer kullanılıyorsa)
- **Layer 4+**: Diğer özel layer'lar

### Mevcut Proje Yapısı

Kod incelemesine göre:
- **Player**: Layer 1 (default) kullanıyor
- **Enemy**: Layer 1 (default) kullanıyor
- **Shield**: Layer 1 (default) başlangıçta, eldeyken 0 (hiçbir şeyle çarpışmaz)
- **World/Ground**: Layer 1 (default)

### Shield Collision Mantığı

#### Elde Tutulurken (is_held = true):
- `collision_layer = 0` → Hiçbir layer'da değil (çarpışmaz)
- `collision_mask = 0` → Hiçbir layer'ı algılamaz
- `CollisionShape3D.disabled = true` → Collision shape kapalı
- `freeze = true` → Physics donduruldu (player'a kuvvet vermez)
- `BlockArea` açık kalır → Sadece enemy_attack ile etkileşir

#### Bırakılınca (is_held = false):
- `collision_layer = original_collision_layer` → Orijinal layer'a döner (genelde 1)
- `collision_mask = original_collision_mask` → Orijinal mask'e döner (genelde 1)
- `CollisionShape3D.disabled = false` → Collision shape açık
- `freeze = false` → Normal fizik aktif

### Önerilen Layer Yapısı (Gelişmiş)

Eğer daha organize bir sistem isterseniz:

```
Layer 1: World/Ground (zemin, duvarlar, statik objeler)
Layer 2: Player
Layer 3: Enemy
Layer 4: Items (shield, pickups)
Layer 5: Projectiles
Layer 6: Enemy Attack (Area3D'ler)
```

Bu durumda:
- **Shield eldeyken**: `collision_layer = 0`, `collision_mask = 0`
- **Shield bırakınca**: `collision_layer = 4`, `collision_mask = 1` (sadece world ile çarpışır)

### BlockArea Mantığı

BlockArea (Area3D) her zaman açık kalır:
- `monitoring = true` → Enemy attack'ları algılar
- `monitorable = false` → Başka şeyler tarafından algılanmaz
- `collision_layer = 0` → Hiçbir layer'da değil (çarpışmaz)
- `collision_mask = 6` → Sadece enemy attack layer'ını algılar (eğer layer 6 kullanılıyorsa)

### Notlar

1. **CollisionShape3D Disable**: Daha güvenli, kesin çözüm
2. **Collision Layer/Mask = 0**: Ekstra güvenlik katmanı
3. **Freeze = true**: Player'a kuvvet vermeyi tamamen engeller
4. **Transform Interpolation**: Jitter-free, stabil takip

### Test Senaryoları

- [ ] Shield eldeyken player'a çarpmıyor
- [ ] Shield eldeyken enemy'lere takılmıyor
- [ ] Shield eldeyken HoldPoint'e yakın ve stabil duruyor
- [ ] Shield bırakılınca normal fizik çalışıyor
- [ ] Shield bırakılınca yere düşüyor
- [ ] BlockArea enemy attack'ları algılıyor

---

**Hazırlayan:** Shield Physics Fix v1.0  
**Tarih:** 2025


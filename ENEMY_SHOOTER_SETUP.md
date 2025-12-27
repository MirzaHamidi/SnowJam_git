# Enemy Shooter & Projectile System - Kurulum Rehberi

## 📋 İçindekiler
1. [EnemyShooter Sahne Yapısı](#enemyshooter-sahne-yapısı)
2. [Projectile Sahne Yapısı](#projectile-sahne-yapısı)
3. [ShieldItem Güncellemeleri](#shielditem-güncellemeleri)
4. [Physics Layer Ayarları](#physics-layer-ayarları)
5. [Test ve Kontrol](#test-ve-kontrol)
6. [Sorun Giderme](#sorun-giderme)

---

## 🎯 EnemyShooter Sahne Yapısı

### Node Hiyerarşisi (EnemyShooter.tscn)

```
EnemyShooter (CharacterBody3D) - Root
├── CollisionShape3D
├── NavAgent (NavigationAgent3D)
├── Visual (Node3D)
│   └── Enemy_05(DanceAnim)_blend1 (Blend scene instance)
├── Muzzle (Node3D) - YENİ (silah ucu)
└── LineOfSight (RayCast3D) - YENİ (opsiyonel)
```

### Kurulum Adımları

1. **EnemyShooter.tscn Oluştur**
   - ✅ Root node: `EnemyShooter` (CharacterBody3D)
   - ✅ Script: `EnemyShooter.gd` bağlı

2. **Muzzle Node Ekle**
   - ✅ Node: `Muzzle` (Node3D)
   - ✅ Parent: `EnemyShooter` (root)
   - ✅ Position: `(0, 1.5, 0.8)` (enemy'nin el/silah pozisyonu)
   - ✅ Not: Projectile buradan çıkacak

3. **LineOfSight (Opsiyonel)**
   - ✅ Node: `LineOfSight` (RayCast3D)
   - ✅ Parent: `EnemyShooter` (root)
   - ✅ `target_position`: `(0, 0, 50)` (uzun mesafe)
   - ✅ `collision_mask`: 1 (default layer)

4. **Export Parametreleri (Inspector)**
   - **Projectile Scene**: `res://Scenes/Projectile.tscn`
   - **Desired Distance**: 10.0 (ideal mesafe)
   - **Stop Distance**: 8.0 (durma mesafesi)
   - **Retreat Distance**: 6.0 (geri kaçma mesafesi)
   - **Fire Rate**: 1.2 (saniyede bir atış)
   - **Projectile Speed**: 18.0
   - **Projectile Damage**: 1
   - **Max Range**: 35.0

---

## 🚀 Projectile Sahne Yapısı

### Node Hiyerarşisi (Projectile.tscn)

```
Projectile (Area3D) - Root
├── CollisionShape3D (SphereShape3D)
└── MeshInstance3D (SphereMesh)
```

### Kurulum Adımları

1. **Projectile.tscn Oluştur**
   - ✅ Root node: `Projectile` (Area3D)
   - ✅ Script: `Projectile.gd` bağlı
   - ✅ Group: `"projectile"` (otomatik eklenir)

2. **CollisionShape3D**
   - ✅ Shape: `SphereShape3D`
   - ✅ Radius: 0.15 (küçük mermi)

3. **MeshInstance3D**
   - ✅ Mesh: `SphereMesh`
   - ✅ Radius: 0.15
   - ✅ Not: Görsel için (opsiyonel)

4. **Export Parametreleri**
   - **Speed**: 18.0 (varsayılan)
   - **Damage**: 1 (varsayılan)
   - **Life Time**: 3.0 (saniye)

---

## 🛡️ ShieldItem Güncellemeleri

### Yeni Fonksiyonlar

1. **consume_block()**
   - Projectile veya başka bir şey tarafından çağrılır
   - `blocks_left -= 1`
   - `blocks_left <= 0` ise shield yok olur

2. **BlockArea Projectile Algılama**
   - `_on_block_area_area_entered()` → Projectile kontrolü eklendi
   - `_on_block_area_entered()` → Projectile kontrolü eklendi
   - `_hit_by_projectile()` → Projectile ile etkileşim

### Mantık

- Projectile BlockArea'ya çarptığında:
  1. Projectile yok olur
  2. Shield'in `consume_block()` çağrılır
  3. Shield 1 blok tüketir
  4. Shield blocks_left = 0 ise yok olur

---

## ⚙️ Physics Layer Ayarları

### Önerilen Layer Yapısı

```
Layer 1: World/Ground (zemin, duvarlar, statik objeler)
Layer 2: Player
Layer 3: Enemy
Layer 4: Items (shield, pickups)
Layer 6: Projectile
Layer 7: Enemy Attack (Area3D'ler)
Layer 8: Shield BlockArea
```

### Collision Mask Ayarları

#### Projectile (Area3D)
- **Collision Layer**: 6 (Projectile)
- **Collision Mask**: 
  - Layer 2 (Player) ✅
  - Layer 4 (Shield) ✅
  - Layer 8 (Shield BlockArea) ✅
  - Layer 1 (World) ✅

#### Shield BlockArea (Area3D)
- **Collision Layer**: 8 (Shield BlockArea)
- **Collision Mask**:
  - Layer 7 (Enemy Attack) ✅
  - Layer 6 (Projectile) ✅

#### Player (CharacterBody3D)
- **Collision Layer**: 2 (Player)
- **Collision Mask**: 1 (World)

#### Enemy (CharacterBody3D)
- **Collision Layer**: 3 (Enemy)
- **Collision Mask**: 1 (World)

### Varsayılan Layer (Mevcut Sistem)

Eğer layer'ları değiştirmek istemiyorsanız:
- **Projectile**: `collision_mask = 1` (default layer - player, world, shield)
- **Shield BlockArea**: `collision_mask = 1` (default layer - enemy_attack, projectile)

### Godot'da Layer Ayarlama

1. **Project Settings** → **Layer Names** → **3D Physics**
2. Layer'ları isimlendir:
   - Layer 1: "World"
   - Layer 2: "Player"
   - Layer 3: "Enemy"
   - Layer 4: "Items"
   - Layer 6: "Projectile"
   - Layer 7: "EnemyAttack"
   - Layer 8: "ShieldBlock"

3. **Inspector'da** her node için:
   - `Collision Layer`: Node'un hangi layer'da olduğu
   - `Collision Mask`: Hangi layer'ları algılayacağı

---

## 🧪 Test ve Kontrol

### Test Senaryoları

1. **EnemyShooter Spawn**
   - [ ] EnemyShooter spawn oluyor
   - [ ] Player'ı takip ediyor
   - [ ] İdeal mesafede duruyor (10m)
   - [ ] Çok yakınsa geri kaçıyor (6m)

2. **Projectile Fırlatma**
   - [ ] EnemyShooter projectile fırlatıyor
   - [ ] Projectile doğru yönde gidiyor
   - [ ] Fire rate çalışıyor (1.2s cooldown)

3. **Projectile Collision**
   - [ ] Projectile player'a çarptığında hasar veriyor
   - [ ] Projectile world'e çarptığında yok oluyor
   - [ ] Projectile shield'e çarptığında ikisi de yok oluyor

4. **Shield Block**
   - [ ] Shield eldeyken projectile'i blokluyor
   - [ ] Shield 1 blok tüketiyor
   - [ ] Shield blocks_left = 0 ise yok oluyor
   - [ ] Projectile yok olduğu için player'a hasar vermiyor

### Debug Print'ler

- ✅ `"EnemyShooter: Fired projectile at player!"` → Projectile fırlatıldı
- ✅ `"Projectile: Hit player for X damage!"` → Player'a hasar verildi
- ✅ `"Projectile: Hit shield, both destroyed!"` → Shield ve projectile yok oldu
- ✅ `"ShieldItem: Block consumed! (X blocks left)"` → Shield block tüketti

---

## 🔧 Sorun Giderme

### Problem: EnemyShooter projectile fırlatmıyor

**Çözümler:**
1. `projectile_scene` export parametresi set edilmiş mi? (`res://Scenes/Projectile.tscn`)
2. Muzzle node var mı? Node adı tam olarak `Muzzle` mi?
3. Player bulunuyor mu? (`"player"` grubunda mı?)
4. Fire cooldown bitmiş mi? (1.2s)
5. Mesafe kontrolü: `max_range` (35m) içinde mi?

### Problem: Projectile player'a çarpmıyor

**Çözümler:**
1. Projectile `"projectile"` grubunda mı?
2. Player `"player"` grubunda mı?
3. Collision mask doğru mu? (Player layer'ını algılıyor mu?)
4. Projectile hareket ediyor mu? (`dir` ve `speed` set edilmiş mi?)

### Problem: Shield projectile'i bloklamıyor

**Çözümler:**
1. Shield `is_held = true` mi? (tutuluyor mu?)
2. BlockArea var mı? Node adı `BlockArea` mi?
3. BlockArea `monitoring = true` mi?
4. Projectile `"projectile"` grubunda mı?
5. Collision mask: BlockArea projectile layer'ını algılıyor mu?

### Problem: Projectile shield'e çarptığında ikisi de yok olmuyor

**Çözümler:**
1. ShieldItem'de `consume_block()` metodu var mı?
2. Projectile'de `_hit_shield()` çağrılıyor mu?
3. Shield `is_held = true` mi? (sadece eldeyken block yapar)

### Problem: EnemyShooter çok yakına geliyor

**Çözümler:**
1. `desired_distance` değeri yeterli mi? (10.0)
2. `retreat_distance` değeri doğru mu? (6.0)
3. `_retreat_from_player()` çağrılıyor mu?

---

## 📝 Önemli Notlar

1. **Node İsimleri Kritik:**
   - `Muzzle` (Node3D) - tam isim
   - `LineOfSight` (RayCast3D) - opsiyonel
   - `Projectile` (Area3D) - root node
   - `BlockArea` (Area3D) - Shield'de

2. **Gruplar:**
   - Projectile: `"projectile"` (otomatik eklenir)
   - Player: `"player"` (manuel ekle)
   - Shield: `"shield"` (otomatik eklenir)

3. **Projectile Setup:**
   - EnemyShooter `setup(direction, speed, damage)` çağırır
   - Duck typing: direkt property'ler de set edilebilir

4. **Shield Block:**
   - Sadece `is_held = true` iken block yapar
   - Projectile block = 1 blok tüketir
   - Shield ve projectile ikisi de yok olur

5. **Physics Layers:**
   - Varsayılan layer (1) kullanılıyorsa collision mask'leri kontrol et
   - Özel layer'lar kullanılıyorsa yukarıdaki önerilen yapıyı kullan

---

## ✅ Final Kontrol Listesi

- [ ] EnemyShooter.tscn oluşturuldu
- [ ] EnemyShooter.gd script bağlı
- [ ] Muzzle node eklendi
- [ ] Projectile Scene export parametresi set edildi
- [ ] Projectile.tscn oluşturuldu
- [ ] Projectile.gd script bağlı
- [ ] Projectile `"projectile"` grubunda
- [ ] ShieldItem.gd'de `consume_block()` eklendi
- [ ] ShieldItem BlockArea projectile algılıyor
- [ ] EnemyShooter spawn oluyor
- [ ] Projectile fırlatılıyor
- [ ] Projectile player'a hasar veriyor
- [ ] Projectile shield'e çarptığında ikisi de yok oluyor

---

**Hazırlayan:** Enemy Shooter & Projectile System v1.0  
**Tarih:** 2025


# Shield (Kalkan) Sistemi - Kurulum Rehberi

## 📋 İçindekiler
1. [Shield Sahne Yapısı](#shield-sahne-yapısı)
2. [Player Scene Güncellemeleri](#player-scene-güncellemeleri)
3. [Input Map Ayarları](#input-map-ayarları)
4. [Shield Spawner Kurulumu](#shield-spawner-kurulumu)
5. [Block Sistemi (Enemy Attack)](#block-sistemi-enemy-attack)
6. [Test ve Kontrol](#test-ve-kontrol)
7. [Sorun Giderme](#sorun-giderme)

---

## 🛡️ Shield Sahne Yapısı

### Node Hiyerarşisi (shield.tscn)

```
Shield (RigidBody3D) - Root
├── CollisionShape3D
├── MeshInstance3D (Kalkan.blend mesh)
└── BlockArea (Area3D) [Opsiyonel - block detection için]
    └── CollisionShape3D
```

### Kurulum Adımları

1. **Shield.tscn Oluştur**
   - ✅ Root node: `Shield` (RigidBody3D)
   - ✅ Script: `Shield.gd` bağlı
   - ✅ Groups: `"grabbable"` ve `"shield"` (otomatik eklenir)

2. **CollisionShape3D**
   - ✅ Shape: `BoxShape3D` (veya kalkan şekline uygun shape)
   - ✅ Size: Shield boyutuna göre ayarla (örn: 1.0 x 1.5 x 0.2)

3. **MeshInstance3D**
   - ✅ Mesh: `Kalkan.blend` dosyasını import et ve buraya bağla
   - ✅ Not: Blend dosyası import edildikten sonra mesh olarak kullanılabilir

4. **BlockArea (Opsiyonel)**
   - ✅ Area3D node: `BlockArea`
   - ✅ `monitorable = false` (sadece detect eder)
   - ✅ CollisionShape3D: Shield ile aynı shape

### Blend Dosyası Import

1. Godot'da `Assets/Kalkan.blend` dosyasını seç
2. Import sekmesinde ayarları kontrol et
3. Mesh olarak kullanılabilir hale gelir
4. Shield.tscn'de MeshInstance3D'ye bağla

---

## 👤 Player Scene Güncellemeleri

### Node Hiyerarşisi (player.tscn)

```
CharacterBody3D (Player root)
├── Camera3D
│   ├── RayCast3D (mevcut - attack için)
│   ├── GrabRay (YENİ - grab için)
│   ├── HoldPoint (YENİ - tutma noktası)
│   └── ... (diğer node'lar)
└── PlayerGrab (YENİ - Node, script: PlayerGrab.gd)
```

### Kurulum Adımları

1. **GrabRay Ekle**
   - ✅ Node: `GrabRay` (RayCast3D)
   - ✅ Parent: `CharacterBody3D/Camera3D`
   - ✅ `target_position`: `(0, 0, -7)` (7m ileri)
   - ✅ `collision_mask`: 1 (default layer)
   - ✅ `enabled`: true

2. **HoldPoint Ekle**
   - ✅ Node: `HoldPoint` (Node3D)
   - ✅ Parent: `CharacterBody3D/Camera3D`
   - ✅ `position`: `(0.3, -0.2, -1.8)` (kameranın önünde 1.8m, sağda 0.3m, aşağıda 0.2m)

3. **PlayerGrab Script Ekle**
   - ✅ Node: `PlayerGrab` (Node)
   - ✅ Parent: `CharacterBody3D`
   - ✅ Script: `PlayerGrab.gd`
   - ✅ Not: Script otomatik olarak GrabRay ve HoldPoint'i bulur/oluşturur

### Mevcut Yapı Kontrolü

- ✅ Camera3D mevcut
- ✅ RayCast3D mevcut (attack için kullanılıyor)
- ✅ GrabRay eklendi (grab için)
- ✅ HoldPoint eklendi (tutma noktası)

---

## 🎮 Input Map Ayarları

### "grab" Action Ekle

1. **Project Settings Aç**
   - `Project` → `Project Settings`
   - `Input Map` sekmesine git

2. **"grab" Action Oluştur**
   - `Action` kutusuna `grab` yaz
   - `Add` butonuna tıkla

3. **RMB (Mouse Right) Bağla**
   - `grab` action'ını seç
   - `+` butonuna tıkla
   - `Mouse Button` seç
   - `Button`: `Right` (Mouse Button Right)
   - `OK`

### Kontrol

- ✅ Input Map'te `grab` action var
- ✅ RMB (Mouse Button Right) bağlı
- ✅ PlayerGrab.gd script `Input.is_action_pressed("grab")` ile kontrol eder

### Not

PlayerGrab.gd hem Input Map action hem de direkt mouse button kontrolü yapar:
- `Input.is_action_pressed("grab")` → Input Map action
- `InputEventMouseButton` (MOUSE_BUTTON_RIGHT) → Direkt mouse kontrolü

---

## 🌍 Shield Spawner Kurulumu

### Game Scene'e ShieldSpawner Ekle

1. **ShieldSpawner Node Oluştur**
   - Game scene'de (game_scene.tscn) root'a sağ tık
   - `Add Child Node` → `Node3D`
   - Adını `ShieldSpawner` yap

2. **Script Bağla**
   - ShieldSpawner node'unu seç
   - Inspector'da `Script` → `Load`
   - `ShieldSpawner.gd` seç

3. **Export Parametreleri Ayarla**
   - `Shield Scene`: `res://Scenes/shield.tscn` (Shield sahnesi)
   - `Spawn Count`: 8 (spawn edilecek shield sayısı)
   - `Spawn Radius`: 40.0 (player'dan maksimum mesafe)
   - `Min Distance From Player`: 8.0 (player'dan minimum mesafe)
   - `Min Distance Between Shields`: 5.0 (shield'ler arası minimum mesafe)

### Node Hiyerarşisi

```
Game_scene (Node3D)
├── ... (diğer node'lar)
└── ShieldSpawner (Node3D) - YENİ
    └── Script: ShieldSpawner.gd
```

### Spawn Mantığı

- ✅ Oyun başladığında otomatik spawn eder
- ✅ Player pozisyonuna göre rastgele spawn
- ✅ Zemin bulma: Yüksekten raycast ile zemin bulur
- ✅ Mesafe kontrolü: Player'dan ve diğer shield'lerden uzak spawn

---

## ⚔️ Block Sistemi (Enemy Attack)

### Enemy Attack Area3D Oluştur

Enemy'lerin saldırıları için Area3D oluştur:

1. **Enemy Scene'e AttackHitbox Ekle**
   - Enemy scene'de (enemy.tscn veya EnemyFollow kullanıyorsanız)
   - `AttackHitbox` (Area3D) node ekle
   - Group: `"enemy_attack"` ekle
   - CollisionShape3D ekle (saldırı menzili)

2. **Enemy Script'te Attack Trigger**
   - Enemy saldırı yaptığında AttackHitbox'ı aktif et
   - Saldırı bitince deaktif et

### Shield Block Mantığı

- ✅ Shield `"shield"` grubunda
- ✅ Shield `is_held = true` iken block aktif
- ✅ Enemy attack Area3D `"enemy_attack"` grubunda olmalı
- ✅ Shield BlockArea veya doğrudan collision ile attack'ı yakalar
- ✅ `shield_blocked` signal emit edilir

### Block Signal Kullanımı

```gdscript
# Shield'de signal bağla
shield.shield_blocked.connect(_on_shield_blocked)

func _on_shield_blocked(hit_position: Vector3):
    # Block efekti (ses, particle, vb.)
    print("Shield blocked attack at: ", hit_position)
```

---

## 🧪 Test ve Kontrol

### Test Senaryoları

1. **Grab Test**
   - [ ] Shield spawn oldu
   - [ ] RMB basılı tutunca shield tutuluyor
   - [ ] Shield HoldPoint'e çekiliyor (spring force)
   - [ ] RMB bırakınca shield düşüyor

2. **Block Test**
   - [ ] Shield tutulurken enemy saldırısı bloklanıyor
   - [ ] Shield yerdeyken block çalışmıyor
   - [ ] Block signal emit ediliyor

3. **Spawn Test**
   - [ ] Oyun başladığında shield'ler spawn oluyor
   - [ ] Shield'ler player'dan uzak spawn oluyor
   - [ ] Shield'ler birbirine çok yakın değil

### Debug Print'ler

- ✅ `"PlayerGrab: Grabbed [name]"` → Shield tutuldu
- ✅ `"PlayerGrab: Dropped object"` → Shield bırakıldı
- ✅ `"Shield blocked attack from: [name]"` → Block çalıştı
- ✅ `"ShieldSpawner: Spawned shield X at [pos]"` → Shield spawn oldu

---

## 🔧 Sorun Giderme

### Problem: Shield tutulmuyor

**Çözümler:**
1. GrabRay var mı? Node adı tam olarak `GrabRay` mi?
2. Shield `"grabbable"` grubunda mı?
3. GrabRay collision_mask doğru mu? (1 = default layer)
4. Input Map'te `grab` action var mı?
5. RMB çalışıyor mu? (console'da hata var mı?)

### Problem: Shield titriyor (jitter)

**Çözümler:**
1. `pull_strength` değerini artır (örn: 80.0)
2. `damping` değerini artır (örn: 15.0)
3. `held_linear_damp` ve `held_angular_damp` değerlerini artır
4. `rotation_strength` değerini artır

### Problem: Shield çok yavaş çekiliyor

**Çözümler:**
1. `pull_strength` değerini artır (PlayerGrab.gd export parametresi)
2. `held_gravity_scale` değerini düşür (0.1 gibi)
3. Shield'in `mass` değerini düşür (RigidBody3D)

### Problem: Shield spawn olmuyor

**Çözümler:**
1. ShieldSpawner'da `shield_scene` export parametresi set edilmiş mi?
2. Player `"player"` grubunda mı?
3. Zemin collision var mı? (raycast zemin bulamıyor olabilir)
4. Spawn radius çok küçük mü? (player yakınında yer yok)

### Problem: Block çalışmıyor

**Çözümler:**
1. Shield `is_held = true` mi? (tutuluyor mu?)
2. Enemy attack Area3D `"enemy_attack"` grubunda mı?
3. Shield BlockArea var mı? (veya doğrudan collision çalışıyor mu?)
4. Enemy attack trigger ediliyor mu?

### Problem: Blend dosyası import edilemiyor

**Çözümler:**
1. Godot'da `Assets/Kalkan.blend` dosyasını seç
2. Import sekmesinde `Import` butonuna tıkla
3. Mesh olarak kullanılabilir hale gelir
4. Shield.tscn'de MeshInstance3D'ye bağla

---

## 📝 Önemli Notlar

1. **Node İsimleri Kritik:**
   - `GrabRay` (RayCast3D) - tam isim
   - `HoldPoint` (Node3D) - tam isim
   - `Shield` (RigidBody3D) - root node
   - `BlockArea` (Area3D) - opsiyonel

2. **Gruplar:**
   - Shield: `"grabbable"` ve `"shield"` (otomatik eklenir)
   - Enemy Attack: `"enemy_attack"` (manuel ekle)

3. **Physics:**
   - Shield tutulurken `freeze = false` kalır (physics aktif)
   - Spring force ile kontrol edilir
   - Gravity scale düşürülür (0.2)

4. **Input:**
   - RMB (Mouse Right) = grab/hold
   - Input Map'te `grab` action oluştur

5. **Spawn:**
   - Oyun başladığında otomatik spawn
   - Player pozisyonuna göre rastgele
   - Zemin raycast ile bulunur

---

## ✅ Final Kontrol Listesi

- [ ] Shield.tscn oluşturuldu (RigidBody3D, CollisionShape3D, MeshInstance3D)
- [ ] Shield.gd script bağlı
- [ ] Shield `"grabbable"` ve `"shield"` gruplarında
- [ ] Player scene'de GrabRay var
- [ ] Player scene'de HoldPoint var
- [ ] PlayerGrab.gd script CharacterBody3D'ye bağlı
- [ ] Input Map'te `grab` action var (RMB)
- [ ] ShieldSpawner game scene'de var
- [ ] ShieldSpawner export parametreleri ayarlandı
- [ ] Shield spawn oluyor
- [ ] Shield tutuluyor (RMB)
- [ ] Block çalışıyor (enemy attack)

---

**Hazırlayan:** Shield System v1.0  
**Tarih:** 2025


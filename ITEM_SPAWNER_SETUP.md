# Item Spawner & Shield Item (1-hit Block) - Kurulum Rehberi

## 📋 İçindekiler
1. [ItemSpawner Kurulumu](#itemspawner-kurulumu)
2. [Shield Item Sahne Yapısı](#shield-item-sahne-yapısı)
3. [Player Grab Entegrasyonu](#player-grab-entegrasyonu)
4. [Enemy Attack Sistemi](#enemy-attack-sistemi)
5. [Input Map Ayarları](#input-map-ayarları)
6. [Test ve Kontrol](#test-ve-kontrol)
7. [Sorun Giderme](#sorun-giderme)

---

## 🌍 ItemSpawner Kurulumu

### Node Hiyerarşisi

```
Game_scene (Node3D)
├── ... (diğer node'lar)
└── ItemSpawner (Node3D) - YENİ
    └── Script: ItemSpawner.gd
```

### Kurulum Adımları

1. **ItemSpawner Node Oluştur**
   - Game scene'de (game_scene.tscn) root'a sağ tık
   - `Add Child Node` → `Node3D`
   - Adını `ItemSpawner` yap

2. **Script Bağla**
   - ItemSpawner node'unu seç
   - Inspector'da `Script` → `Load`
   - `ItemSpawner.gd` seç

3. **Export Parametreleri Ayarla (Inspector)**
   - **Items**: Array[PackedScene] - Item sahnelerini buraya ekle
     - `Size`: 1 (veya daha fazla)
     - `[0]`: `res://Scenes/shield.tscn` (Shield item)
     - Daha fazla item eklemek için Size'ı artır
   - **Spawn Count**: 10 (spawn edilecek item sayısı)
   - **Spawn Radius**: 40.0 (player'dan maksimum mesafe)
   - **Min Distance From Player**: 8.0 (player'dan minimum mesafe)
   - **Ground Ray Height**: 30.0 (zemin bulma için yükseklik)
   - **Max Ground Ray**: 80.0 (maksimum raycast mesafesi)
   - **Avoid Overlap Radius**: 2.0 (item'ler arası minimum mesafe)
   - **Respawn**: false (otomatik respawn açık mı?)
   - **Respawn Interval**: 10.0 (respawn süresi - saniye)
   - **Max Alive**: 20 (maksimum canlı item sayısı)

### Items Array'e Item Ekleme

1. Inspector'da `Items` → `Size` → `1` (veya daha fazla)
2. `[0]` → `Load` → `res://Scenes/shield.tscn` seç
3. Daha fazla item için `Size`'ı artır ve yeni item sahnelerini ekle

---

## 🛡️ Shield Item Sahne Yapısı

### Node Hiyerarşisi (shield.tscn)

```
Shield (RigidBody3D) - Root
├── CollisionShape3D
├── MeshInstance3D (Kalkan.blend mesh)
└── BlockArea (Area3D) - Block detection için
    └── CollisionShape3D
```

### Kurulum Adımları

1. **Shield.tscn Kontrolü**
   - ✅ Root node: `Shield` (RigidBody3D)
   - ✅ Script: `ShieldItem.gd` bağlı
   - ✅ Groups: `"grabbable"` ve `"shield"` (script otomatik ekler)

2. **CollisionShape3D**
   - ✅ Shape: `BoxShape3D` (veya kalkan şekline uygun)
   - ✅ Size: Shield boyutuna göre ayarla

3. **MeshInstance3D**
   - ✅ Mesh: `Kalkan.blend` import edilmiş mesh
   - ✅ Not: Blend dosyası import edildikten sonra mesh olarak kullanılabilir

4. **BlockArea (Area3D)**
   - ✅ Node adı: `BlockArea` (tam olarak bu isim)
   - ✅ `monitorable = false` (sadece detect eder)
   - ✅ CollisionShape3D: Shield ile aynı veya biraz daha büyük shape

### ShieldItem.gd Export Parametreleri

- **Blocks Left**: 1 (kaç saldırı bloklayabilir)
- **Block Enabled**: true
- **Held Gravity Scale**: 0.2 (tutulurken gravity)
- **Held Linear Damp**: 5.0 (tutulurken linear damping)
- **Held Angular Damp**: 5.0 (tutulurken angular damping)

---

## 👤 Player Grab Entegrasyonu

### Mevcut Yapı Kontrolü

Player scene'de (player.tscn):
- ✅ `GrabRay` (RayCast3D) - Camera3D altında
- ✅ `HoldPoint` (Node3D) - Camera3D altında
- ✅ `PlayerGrab` (Node) - CharacterBody3D altında, script: PlayerGrab.gd

### PlayerGrab.gd Entegrasyonu

PlayerGrab.gd zaten `set_held()` metodunu çağırıyor:
- `_grab()`: `body.set_held(true, player)` çağırır
- `_drop()`: `body.set_held(false, null)` çağırır

**Ek bir şey yapmanıza gerek yok!** Sistem otomatik çalışır.

---

## ⚔️ Enemy Attack Sistemi

### Enemy Attack Hitbox Oluştur

Enemy'lerin saldırıları için Area3D oluştur:

1. **Enemy Scene'e AttackHitbox Ekle**
   - Enemy scene'de (enemy.tscn veya EnemyFollow kullanıyorsanız)
   - `AttackHitbox` (Area3D) node ekle
   - **Group**: `"enemy_attack"` ekle (Inspector → Groups → Add)
   - CollisionShape3D ekle (saldırı menzili)

2. **Enemy Script'te Attack Trigger**
   - Enemy saldırı yaptığında AttackHitbox'ı aktif et
   - Saldırı bitince deaktif et

### Attack Hitbox Örnek Kodu

```gdscript
# Enemy script'te
var attack_hitbox: Area3D = null

func _ready():
    attack_hitbox = get_node_or_null("AttackHitbox")
    if attack_hitbox:
        attack_hitbox.monitoring = false  # Başlangıçta kapalı

func attack():
    if attack_hitbox:
        attack_hitbox.monitoring = true
        # Saldırı animasyonu bitince kapat
        await get_tree().create_timer(0.5).timeout
        attack_hitbox.monitoring = false
```

### Block Mantığı

- ✅ Shield `"shield"` grubunda
- ✅ Shield `is_held = true` iken block aktif
- ✅ Enemy attack Area3D `"enemy_attack"` grubunda olmalı
- ✅ Shield BlockArea veya doğrudan collision ile attack'ı yakalar
- ✅ `blocked` signal emit edilir
- ✅ `blocks_left -= 1`
- ✅ `blocks_left <= 0` ise shield yok olur

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

---

## 🧪 Test ve Kontrol

### Test Senaryoları

1. **Item Spawn Test**
   - [ ] Oyun başladığında item'ler spawn oluyor
   - [ ] Item'ler player'dan uzak spawn oluyor
   - [ ] Item'ler birbirine çok yakın değil
   - [ ] Respawn açıksa item'ler yeniden spawn oluyor

2. **Grab Test**
   - [ ] RMB basılı tutunca shield tutuluyor
   - [ ] Shield HoldPoint'e çekiliyor (spring force)
   - [ ] RMB bırakınca shield düşüyor
   - [ ] Shield `is_held = true` oluyor

3. **Block Test**
   - [ ] Shield tutulurken enemy saldırısı bloklanıyor
   - [ ] Shield yerdeyken block çalışmıyor
   - [ ] Block signal emit ediliyor
   - [ ] `blocks_left` azalıyor
   - [ ] `blocks_left = 0` olunca shield yok oluyor

### Debug Print'ler

- ✅ `"ItemSpawner: Spawned item X at [pos]"` → Item spawn oldu
- ✅ `"PlayerGrab: Grabbed [name]"` → Shield tutuldu
- ✅ `"PlayerGrab: Dropped object"` → Shield bırakıldı
- ✅ `"ShieldItem: Blocked attack from: [name] (X blocks left)"` → Block çalıştı
- ✅ `"ShieldItem: Shield destroyed after blocking attack!"` → Shield yok oldu

---

## 🔧 Sorun Giderme

### Problem: Item'ler spawn olmuyor

**Çözümler:**
1. ItemSpawner'da `items` array boş mu? (Inspector'da kontrol et)
2. Player `"player"` grubunda mı?
3. Zemin collision var mı? (raycast zemin bulamıyor olabilir)
4. Spawn radius çok küçük mü? (player yakınında yer yok)

### Problem: Shield tutulmuyor

**Çözümler:**
1. GrabRay var mı? Node adı tam olarak `GrabRay` mi?
2. Shield `"grabbable"` grubunda mı?
3. GrabRay collision_mask doğru mu? (1 = default layer)
4. Input Map'te `grab` action var mı?

### Problem: Block çalışmıyor

**Çözümler:**
1. Shield `is_held = true` mi? (tutuluyor mu?)
2. Enemy attack Area3D `"enemy_attack"` grubunda mı?
3. Shield BlockArea var mı? (node adı `BlockArea` mi?)
4. Enemy attack trigger ediliyor mu?
5. `blocks_left > 0` mi?

### Problem: Shield 1 hit'ten sonra yok olmuyor

**Çözümler:**
1. `blocks_left` export parametresi 1 mi?
2. Block signal doğru emit ediliyor mu?
3. `_destroy_shield()` çağrılıyor mu?

### Problem: Respawn çalışmıyor

**Çözümler:**
1. `respawn` export parametresi `true` mu?
2. `respawn_interval` değeri uygun mu?
3. `max_alive` değeri spawn_count'tan büyük mü?

---

## 📝 Önemli Notlar

1. **Node İsimleri Kritik:**
   - `BlockArea` (Area3D) - tam isim
   - `Shield` (RigidBody3D) - root node
   - `ItemSpawner` (Node3D) - spawner node

2. **Gruplar:**
   - Shield: `"grabbable"` ve `"shield"` (script otomatik ekler)
   - Enemy Attack: `"enemy_attack"` (manuel ekle - Inspector → Groups)

3. **Physics:**
   - Shield tutulurken `freeze = false` kalır (physics aktif)
   - Spring force ile kontrol edilir
   - Gravity scale düşürülür (0.2)

4. **Block Sistemi:**
   - Sadece `is_held = true` iken block çalışır
   - 1 hit block (blocks_left = 1)
   - Block sonrası shield yok olur

5. **Spawn Sistemi:**
   - Oyun başladığında otomatik spawn
   - Player pozisyonuna göre rastgele
   - Zemin raycast ile bulunur
   - Overlap kontrolü yapılır (max 15 deneme)

---

## ✅ Final Kontrol Listesi

- [ ] ItemSpawner game scene'de var
- [ ] ItemSpawner export parametreleri ayarlandı
- [ ] Items array'e shield.tscn eklendi
- [ ] Shield.tscn oluşturuldu (RigidBody3D, CollisionShape3D, MeshInstance3D, BlockArea)
- [ ] ShieldItem.gd script bağlı
- [ ] Shield `"grabbable"` ve `"shield"` gruplarında
- [ ] Player scene'de GrabRay var
- [ ] Player scene'de HoldPoint var
- [ ] PlayerGrab.gd script CharacterBody3D'ye bağlı
- [ ] Input Map'te `grab` action var (RMB)
- [ ] Enemy attack Area3D `"enemy_attack"` grubunda
- [ ] Item spawn oluyor
- [ ] Shield tutuluyor (RMB)
- [ ] Block çalışıyor (1-hit)
- [ ] Shield yok oluyor (1 hit sonrası)

---

**Hazırlayan:** Item Spawner & Shield Item System v1.0  
**Tarih:** 2025


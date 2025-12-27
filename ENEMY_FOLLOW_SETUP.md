# Enemy Follow System - Kurulum Rehberi

## 📋 İçindekiler
1. [Enemy Sahne Yapısı](#enemy-sahne-yapısı)
2. [Navigation Kurulumu](#navigation-kurulumu)
3. [Player Grubu Ayarları](#player-grubu-ayarları)
4. [Test ve Kontrol](#test-ve-kontrol)
5. [Sorun Giderme](#sorun-giderme)

---

## 🎯 Enemy Sahne Yapısı

### Node Hiyerarşisi (enemy.tscn)

```
Enemy (CharacterBody3D) - Root
├── CollisionShape3D
├── NavAgent (NavigationAgent3D)
├── Visual (Node3D)
│   └── Enemy_05(DanceAnim)_blend1 (Blend scene instance)
└── AttackRange (Area3D) [Opsiyonel]
    └── CollisionShape3D
```

### Kurulum Adımları

1. **Root Node Kontrolü**
   - ✅ Root node adı: `Enemy`
   - ✅ Type: `CharacterBody3D`
   - ✅ Script: `EnemyFollow.gd` bağlı

2. **NavigationAgent3D Ekleme**
   - ✅ Node adı: `NavAgent` (tam olarak bu isim)
   - ✅ Parent: `Enemy` (root)
   - ✅ Varsayılan ayarlar yeterli (script içinde ayarlanıyor)

3. **Visual Node Ekleme**
   - ✅ Node adı: `Visual` (tam olarak bu isim)
   - ✅ Type: `Node3D`
   - ✅ Parent: `Enemy` (root)
   - ✅ Mesh/Animation blend dosyasını buraya taşı
   - ✅ Mevcut: `Enemy_05(DanceAnim)_blend1` buraya taşındı

4. **AttackRange (Opsiyonel)**
   - ✅ Node adı: `AttackRange` (tam olarak bu isim)
   - ✅ Type: `Area3D`
   - ✅ Parent: `Enemy` (root)
   - ✅ `monitorable = false` (sadece detect eder, detect edilmez)
   - ✅ CollisionShape3D child olarak ekle
   - ✅ Shape: `SphereShape3D` (radius: 3.0 veya attack_distance değeri)

5. **CollisionShape3D**
   - ✅ Zaten mevcut, değişiklik yok

---

## 🗺️ Navigation Kurulumu

### NavigationRegion3D ve NavMesh Setup

#### 1. Game Scene'e NavigationRegion3D Ekle

```
Game_scene (Node3D)
├── NavigationRegion3D (YENİ)
│   └── MeshInstance3D (terrain mesh)
└── ... (diğer node'lar)
```

#### 2. NavigationRegion3D Ayarları

1. **NavigationRegion3D Node'u Oluştur**
   - Scene tree'de `Game_scene` root'una sağ tık → `Add Child Node`
   - `NavigationRegion3D` seç
   - Adını `NavigationRegion3D` bırak

2. **Terrain Mesh'i NavigationRegion3D Altına Taşı**
   - Mevcut `MeshInstance3D` (terrain) node'unu seç
   - Cut (Ctrl+X) yap
   - `NavigationRegion3D` node'unu seç
   - Paste (Ctrl+V) yap
   - VEYA: Terrain mesh'i NavigationRegion3D'in child'ı yap

3. **NavMesh Bake**
   - `NavigationRegion3D` node'unu seç
   - Inspector'da `Navigation` sekmesine git
   - `Bake NavMesh` butonuna tıkla
   - NavMesh oluşturulacak (mavi çizgiler görünür)

#### 3. NavigationRegion3D Ayarları (Inspector)

- **Agent Settings:**
  - `Agent Radius`: 0.5 (enemy collision radius ile uyumlu)
  - `Agent Height`: 2.0 (enemy yüksekliği)
  - `Max Slope`: 45.0 (derece)
  - `Max Climb`: 0.5 (basamak yüksekliği)

- **Region Settings:**
  - `Cell Size`: 0.25 (daha küçük = daha detaylı, daha yavaş)
  - `Cell Height`: 0.25
  - `Edge Connection`: Enabled

#### 4. Hızlı Kontrol Checklist

- [ ] NavigationRegion3D node'u var
- [ ] Terrain mesh NavigationRegion3D altında
- [ ] NavMesh bake edildi (mavi çizgiler görünüyor)
- [ ] Agent settings enemy boyutlarına uygun
- [ ] Enemy spawn olduğunda NavAgent NavigationRegion3D'i görüyor

---

## 👤 Player Grubu Ayarları

### Player Node'unu "player" Grubuna Ekle

1. **Player Scene'de (player.tscn)**
   - Root node'u seç (`Player` - Node3D)
   - Inspector'da `Groups` sekmesine git
   - `Add to Group` butonuna tıkla
   - Grup adı: `player` (küçük harf)
   - ✅ Ekle

2. **VEYA Game Scene'de**
   - Player instance'ını seç
   - Inspector → Groups → `player` grubuna ekle

### Kontrol
- Enemy script `get_tree().get_first_node_in_group("player")` ile player'ı bulur
- Console'da "Enemy - Player found: Player" mesajı görünmeli

---

## 🧪 Test ve Kontrol

### Test Senaryoları

1. **Temel Follow Test**
   - [ ] Enemy spawn oluyor
   - [ ] Player'ı buluyor (console mesajı)
   - [ ] Player'a doğru hareket ediyor
   - [ ] Smooth rotation yapıyor

2. **Mesafe Kontrolü**
   - [ ] `stop_distance` (1.5m) yakınında duruyor
   - [ ] `attack_distance` (3.0m) içinde `attack_ready = true`
   - [ ] Çok yakında titreme yapmıyor

3. **Navigation Test**
   - [ ] Engelleri aşıyor (NavMesh üzerinden)
   - [ ] Path bulamazsa direkt follow yapıyor (fallback)
   - [ ] Path update spam yapmıyor

4. **Animation Test**
   - [ ] `mixamo_com_001` animasyonu loop'ta çalışıyor
   - [ ] Animasyon kesintisiz devam ediyor

### Debug Print'ler

Script'te şu mesajlar görünebilir:
- ✅ `"Enemy - Player found: Player"` → Player bulundu
- ⚠️ `"WARNING: Enemy - NavAgent not found!"` → NavAgent eksik, direkt follow kullanılıyor
- ⚠️ `"WARNING: Enemy - Player not found!"` → Player grubu eksik

---

## 🔧 Sorun Giderme

### Problem: Enemy hareket etmiyor

**Çözümler:**
1. Player grubu kontrolü: Player `"player"` grubunda mı?
2. NavAgent var mı? Node adı tam olarak `NavAgent` mi?
3. NavigationRegion3D bake edildi mi?
4. Enemy spawn pozisyonu NavMesh üzerinde mi?

### Problem: Enemy engellere takılıyor

**Çözümler:**
1. NavigationRegion3D NavMesh'i güncel mi? (Bake tekrar yap)
2. Agent Radius/Height ayarları doğru mu?
3. Engeller NavigationLayer'da mı? (StaticBody3D collision)

### Problem: Enemy titriyor (jitter)

**Çözümler:**
1. `stop_distance` değerini artır (örn: 2.0)
2. `path_desired_distance` değerini artır (örn: 1.0)
3. `path_update_interval` değerini artır (örn: 0.3)

### Problem: Animasyon çalışmıyor

**Çözümler:**
1. Visual node var mı? Node adı tam olarak `Visual` mi?
2. AnimationPlayer Visual node altında mı?
3. Animasyon adı `mixamo_com_001` mi? (console'da mevcut animasyonlar listelenir)

### Problem: Attack ready çalışmıyor

**Çözümler:**
1. AttackRange Area3D var mı? (Opsiyonel, mesafe kontrolü zaten var)
2. AttackRange CollisionShape3D shape'i doğru mu?
3. Player collision layer'ı doğru mu?

---

## 📝 Önemli Notlar

1. **Node İsimleri Kritik:** Script node'ları isimle buluyor. İsimler tam olarak eşleşmeli:
   - `NavAgent` (NavigationAgent3D)
   - `Visual` (Node3D)
   - `AttackRange` (Area3D, opsiyonel)

2. **Player Grubu:** Player mutlaka `"player"` grubunda olmalı (küçük harf).

3. **NavigationRegion3D:** Enemy'nin çalışması için NavigationRegion3D + NavMesh gerekli. Yoksa fallback direkt follow çalışır (engelsiz).

4. **Export Parametreleri:** EnemyFollow.gd'de export parametrelerini Inspector'dan ayarlayabilirsiniz:
   - `move_speed`: Hareket hızı
   - `stop_distance`: Durma mesafesi
   - `attack_distance`: Attack hazır mesafesi
   - `rotation_speed`: Dönüş hızı

5. **Fallback Sistemi:** NavAgent yoksa sistem direkt follow'a geçer (engelsiz takip). Bu durumda console'da uyarı görünür.

---

## ✅ Final Kontrol Listesi

- [ ] Enemy.tscn node yapısı doğru (NavAgent, Visual, AttackRange)
- [ ] EnemyFollow.gd script bağlı
- [ ] NavigationRegion3D game scene'de var
- [ ] NavMesh bake edildi
- [ ] Player "player" grubunda
- [ ] Enemy spawn oluyor ve hareket ediyor
- [ ] Animasyon loop'ta çalışıyor
- [ ] Mesafe kontrolleri çalışıyor
- [ ] Engelleri aşıyor (NavMesh üzerinden)

---

**Hazırlayan:** Enemy Follow System v1.0  
**Tarih:** 2025


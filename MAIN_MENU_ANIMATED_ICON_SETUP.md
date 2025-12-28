# Main Menu - Animated Icon Button System - Kurulum Rehberi

## 📋 İçindekiler
1. [Scene Yapısı](#scene-yapısı)
2. [Button Icon Yapısı](#button-icon-yapısı)
3. [Inspector Ayarları](#inspector-ayarları)
4. [Kullanım Örnekleri](#kullanım-örnekleri)
5. [Test ve Kontrol](#test-ve-kontrol)

---

## 🎯 Scene Yapısı

### Mevcut Yapı (main_menu.tscn)

```
Main_Menu (Node2D)
├── Buttons (Node)
│   ├── Play (Button)
│   │   └── Icon (TextureRect veya AnimatedSprite2D)
│   ├── Settings (Button)
│   │   └── Icon (TextureRect veya AnimatedSprite2D)
│   ├── Exit (Button)
│   │   └── Icon (TextureRect veya AnimatedSprite2D)
│   └── Credit (Button)
│       └── Icon (TextureRect veya AnimatedSprite2D)
├── MainMenu_Music (AudioStreamPlayer2D)
├── WitchIt2 (Sprite2D)
└── TransitionLayer (CanvasLayer) [YENİ]
    └── FadeRect (ColorRect) [YENİ]
```

---

## 🖼️ Button Icon Yapısı

### Yöntem 1: TextureRect + AnimatedTexture2D

```
Play (Button)
└── Icon (TextureRect)
    - texture: AnimatedTexture2D (press_anim)
    - autoplay: false (script tarafından kontrol edilir)
```

### Yöntem 2: AnimatedSprite2D + SpriteFrames

```
Play (Button)
└── Icon (AnimatedSprite2D)
    - sprite_frames: SpriteFrames (press_anim)
    - autoplay: false (script tarafından kontrol edilir)
```

### Yöntem 3: TextureRect + Normal Texture (Basit)

```
Play (Button)
└── Icon (TextureRect)
    - texture: Texture2D (idle_icon)
```

---

## ⚙️ Inspector Ayarları

### MainMenu.gd Script Ayarları

**Inspector'da şu export'ları görürsünüz:**

#### Timing
- **Button Delay**: `0.5` (buton basıldıktan sonra action'a kadar bekleme)
- **Fade Duration**: `0.3` (fade in/out süresi)

#### Button Icons - Play
- **Play Idle Icon**: Texture2D (normal durum icon'u)
- **Play Press Anim**: AnimatedTexture2D veya SpriteFrames (basıldığında oynatılacak animasyon)

#### Button Icons - Settings
- **Settings Idle Icon**: Texture2D
- **Settings Press Anim**: AnimatedTexture2D veya SpriteFrames

#### Button Icons - Exit
- **Exit Idle Icon**: Texture2D
- **Exit Press Anim**: AnimatedTexture2D veya SpriteFrames

#### Button Icons - Credit
- **Credit Idle Icon**: Texture2D
- **Credit Press Anim**: AnimatedTexture2D veya SpriteFrames

#### Debug
- **Debug Enabled**: `false` (console log'ları aç/kapa)

---

## 📝 Kurulum Adımları

### Adım 1: TransitionLayer Ekle

1. **Main_Menu** root node'una sağ tık → **Add Child Node**
2. **CanvasLayer** seç
3. Node adını **TransitionLayer** yap
4. **TransitionLayer**'a sağ tık → **Add Child Node** → **ColorRect**
5. Node adını **FadeRect** yap

**FadeRect Ayarları:**
- Color: `#000000` (Siyah)
- Anchor Presets: **Full Rect**
- Mouse Filter: **Ignore**
- Modulate → Alpha: `0` (başlangıçta görünmez)

### Adım 2: Button Icon Node'ları Ekle

Her butona Icon node'u ekle:

**Örnek: Play Button**
1. **Play** button'una sağ tık → **Add Child Node**
2. **TextureRect** veya **AnimatedSprite2D** seç
3. Node adını **Icon** yap
4. **Autoplay**: `false` (script tarafından kontrol edilecek)

### Adım 3: Inspector'dan Icon'ları Atama

**MainMenu.gd** script'ini seç, Inspector'da:

1. **Button Icons - Play** bölümünde:
   - **Play Idle Icon**: Normal durum icon'unu sürükle (Texture2D)
   - **Play Press Anim**: Basıldığında oynatılacak animasyonu sürükle (AnimatedTexture2D veya SpriteFrames)

2. Diğer butonlar için de aynı şekilde

---

## 🎬 Davranış Akışı

1. **Buton Basıldığında:**
   - Icon node'unda `press_anim` animasyonu oynatılır
   - Buton disable edilir (spam click önleme)

2. **0.5 Saniye Sonra:**
   - Eğer `use_fade = true` ise: Fade out başlar (0.3 sn)
   - Fade tamamlanınca: Action çalışır (scene change / quit / vs.)

3. **Fade In (Main Menu Açılışında):**
   - Otomatik fade in yapılır (opsiyonel)

---

## 🔧 Desteklenen Animasyon Tipleri

### AnimatedTexture2D
- TextureRect'te kullanılır
- `current_frame = 0` ile reset edilir
- `pause = false` ile oynatılır

### SpriteFrames
- AnimatedSprite2D'de kullanılır
- `sprite_frames = press_anim` ile assign edilir
- `play()` ile oynatılır

### Texture2D (Normal)
- Basit texture değişimi için
- Direkt `texture` property'sine atanır

---

## 📌 Kullanım Örnekleri

### Örnek 1: TextureRect + AnimatedTexture2D

```gdscript
# Button yapısı:
# Play (Button)
#   └── Icon (TextureRect)

# Inspector'dan:
# - Play Idle Icon: res://Assets/Icons/play_idle.png
# - Play Press Anim: res://Assets/Icons/play_press_anim.tres (AnimatedTexture2D)
```

### Örnek 2: AnimatedSprite2D + SpriteFrames

```gdscript
# Button yapısı:
# Play (Button)
#   └── Icon (AnimatedSprite2D)

# Inspector'dan:
# - Play Idle Icon: res://Assets/Icons/play_idle.png
# - Play Press Anim: res://Assets/Icons/play_press_anim.tres (SpriteFrames)
```

### Örnek 3: Manuel Button Kaydı

```gdscript
# Script'te manuel olarak:
var my_button = $Buttons/MyButton
var my_icon = my_button.get_node("Icon")
var idle_icon = preload("res://Assets/Icons/my_idle.png")
var press_anim = preload("res://Assets/Icons/my_press_anim.tres")

register_button(
	my_button,
	my_icon,
	idle_icon,
	press_anim,
	func(): print("My button clicked!"),
	true  # use_fade
)
```

---

## 🧪 Test ve Kontrol

### Test Senaryoları

1. **Buton Basma:**
   - ✅ Icon animasyonu oynuyor mu?
   - ✅ Buton disable ediliyor mu?
   - ✅ 0.5 sn sonra action çalışıyor mu?

2. **Fade:**
   - ✅ Fade out çalışıyor mu? (use_fade=true ise)
   - ✅ Scene değişimi doğru çalışıyor mu?
   - ✅ Fade in yapılıyor mu? (main menu açılışında)

3. **Animasyon:**
   - ✅ AnimatedTexture2D oynatılıyor mu?
   - ✅ SpriteFrames oynatılıyor mu?
   - ✅ Animasyon baştan başlıyor mu? (current_frame = 0)

### Debug Modu

`debug_enabled = true` yapınca console'da şu log'lar görünecek:
- `MainMenu: Registered button: Play`
- `MainMenu: Set idle icon for: Icon`
- `MainMenu: Playing animation on TextureRect: Icon`
- `MainMenu: Playing animation on AnimatedSprite2D: Icon`
- `MainMenu: Fade out completed`
- `MainMenu: Fade in completed`

---

## 🔧 Sorun Giderme

### Sorun: Icon animasyonu oynatılmıyor
- **Çözüm**: Icon node'unun adı "Icon" olmalı ve doğru tipte olmalı (TextureRect veya AnimatedSprite2D)
- **Kontrol**: `_register_existing_buttons()` fonksiyonunda Icon node'u bulunuyor mu?

### Sorun: AnimatedTexture2D oynatılmıyor
- **Çözüm**: AnimatedTexture2D'nin `pause = false` olmalı ve `current_frame = 0` ile reset edilmeli
- **Kontrol**: `_play_texture_rect()` fonksiyonunu kontrol edin

### Sorun: SpriteFrames oynatılmıyor
- **Çözüm**: AnimatedSprite2D kullanılmalı, TextureRect'e SpriteFrames atanamaz
- **Kontrol**: Icon node'unun tipi AnimatedSprite2D mi?

### Sorun: Fade çalışmıyor
- **Çözüm**: TransitionLayer ve FadeRect node'larının doğru kurulduğundan emin olun
- **Kontrol**: FadeRect'in anchor'ları Full Rect olmalı

---

## 📌 Notlar

- Icon'lar opsiyoneldir (`null` olabilir). Icon yoksa animasyon oynatılmaz ama delay ve fade çalışır.
- Fade sadece scene değişimlerinde kullanılır. Quit için fade kullanılmaz (`use_fade=false`).
- Tüm butonlar otomatik olarak `_register_existing_buttons()` ile kaydedilir.
- Yeni buton eklemek için `register_button()` fonksiyonunu kullanın.
- Animasyon sadece buton basıldığında oynatılır, otomatik oynatılmaz.


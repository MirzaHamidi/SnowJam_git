# Main Menu Button Transition System - Kurulum Rehberi

## 📋 İçindekiler
1. [Scene Yapısı](#scene-yapısı)
2. [TransitionLayer Kurulumu](#transitionlayer-kurulumu)
3. [Button Icon Atama](#button-icon-atama)
4. [Kullanım Örnekleri](#kullanım-örnekleri)
5. [Test ve Kontrol](#test-ve-kontrol)

---

## 🎯 Scene Yapısı

### Mevcut Yapı (main_menu.tscn)

```
Main_Menu (Node2D)
├── Buttons (Node)
│   ├── Play (Button)
│   ├── Settings (Button)
│   ├── Exit (Button)
│   └── Credit (Button)
├── MainMenu_Music (AudioStreamPlayer2D)
└── WitchIt2 (Sprite2D)
```

### Yeni Yapı (TransitionLayer eklenecek)

```
Main_Menu (Node2D)
├── Buttons (Node)
│   ├── Play (Button)
│   ├── Settings (Button)
│   ├── Exit (Button)
│   └── Credit (Button)
├── MainMenu_Music (AudioStreamPlayer2D)
├── WitchIt2 (Sprite2D)
└── TransitionLayer (CanvasLayer) [YENİ]
    └── FadeRect (ColorRect) [YENİ]
```

---

## 🎨 TransitionLayer Kurulumu

### Adım 1: CanvasLayer Ekle

1. **Main_Menu** root node'una sağ tık → **Add Child Node**
2. **CanvasLayer** seç
3. Node adını **TransitionLayer** yap

### Adım 2: ColorRect Ekle

1. **TransitionLayer**'a sağ tık → **Add Child Node**
2. **ColorRect** seç
3. Node adını **FadeRect** yap

### Adım 3: ColorRect Ayarları

**Inspector'da şu ayarları yap:**

- **Color**: `#000000` (Siyah)
- **Anchor Presets**: **Full Rect** (sağ üstteki menüden)
  - Anchor Left: `0`
  - Anchor Top: `0`
  - Anchor Right: `1`
  - Anchor Bottom: `1`
- **Mouse Filter**: **Ignore**
- **Modulate** → **Alpha**: `0` (başlangıçta görünmez)

**Not:** Modulate alpha değeri script tarafından otomatik ayarlanacak, ama başlangıçta 0 olmalı.

---

## 🖼️ Button Icon Atama

### Yöntem 1: Script'te Manuel Atama (Önerilen)

`main_menu.gd` script'inde `_register_existing_buttons()` fonksiyonunu güncelleyin:

```gdscript
func _register_existing_buttons() -> void:
	var play_button = buttons_node.get_node_or_null("Play")
	var play_normal_icon = preload("res://Assets/Icons/play_normal.png")
	var play_pressed_icon = preload("res://Assets/Icons/play_pressed.png")
	
	if play_button:
		register_button(
			play_button,
			play_normal_icon,
			play_pressed_icon,
			_on_play_action,
			true  # use_fade
		)
	
	# Diğer butonlar için de aynı şekilde...
```

### Yöntem 2: Export Dictionary (Alternatif)

Script'e export dictionary ekleyebilirsiniz:

```gdscript
@export var button_icons: Dictionary = {
	"Play": {
		"normal": preload("res://Assets/Icons/play_normal.png"),
		"pressed": preload("res://Assets/Icons/play_pressed.png"),
		"use_fade": true
	},
	"Settings": {
		"normal": preload("res://Assets/Icons/settings_normal.png"),
		"pressed": preload("res://Assets/Icons/settings_pressed.png"),
		"use_fade": true
	},
	# ...
}
```

---

## 📝 Kullanım Örnekleri

### Örnek 1: Basit Button Kaydı

```gdscript
var my_button = $Buttons/MyButton
var normal_icon = preload("res://Assets/Icons/my_normal.png")
var pressed_icon = preload("res://Assets/Icons/my_pressed.png")

register_button(
	my_button,
	normal_icon,
	pressed_icon,
	func(): print("Button clicked!"),
	true  # fade kullan
)
```

### Örnek 2: Fade Olmadan Button

```gdscript
register_button(
	exit_button,
	normal_icon,
	pressed_icon,
	_on_exit_action,
	false  # fade kullanma (quit için)
)
```

### Örnek 3: Custom Action

```gdscript
register_button(
	settings_button,
	normal_icon,
	pressed_icon,
	func():
		get_node("/root/SceneState").previous_scene_path = "res://Scenes/main_menu.tscn"
		get_tree().change_scene_to_file("res://Scenes/uı.tscn"),
	true
)
```

---

## ⚙️ Export Parametreleri

**Inspector'da ayarlanabilir:**

- **Button Delay**: `0.5` (buton basıldıktan sonra action'a kadar bekleme süresi)
- **Fade Duration**: `0.3` (fade in/out süresi)
- **Scale Punch Duration**: `0.12` (buton press animasyonu süresi)
- **Scale Punch Amount**: `0.96` (buton press animasyonu scale değeri)
- **Debug Enabled**: `false` (console log'ları aç/kapa)

---

## 🎬 Davranış Akışı

1. **Buton Basıldığında:**
   - Icon `pressed_icon`'a değişir
   - Scale animasyonu (0.96 → 1.0, 0.12 sn)
   - Buton disable edilir (spam click önleme)

2. **0.5 Saniye Sonra:**
   - Eğer `use_fade = true` ise: Fade out başlar (0.3 sn)
   - Fade tamamlanınca: Action çalışır (scene change / quit / vs.)

3. **Fade In (Oyun Başlangıcı):**
   - Main menu açılırken otomatik fade in yapılır (isteğe bağlı)

---

## 🧪 Test ve Kontrol

### Test Senaryoları

1. **Buton Basma:**
   - ✅ Icon değişiyor mu?
   - ✅ Scale animasyonu çalışıyor mu?
   - ✅ Buton disable ediliyor mu?

2. **Delay ve Fade:**
   - ✅ 0.5 sn sonra action çalışıyor mu?
   - ✅ Fade out çalışıyor mu? (use_fade=true ise)
   - ✅ Scene değişimi doğru çalışıyor mu?

3. **Fade In:**
   - ✅ Main menu açılırken fade in yapılıyor mu?

### Debug Modu

`debug_enabled = true` yapınca console'da şu log'lar görünecek:
- `MainMenu: Created TransitionLayer`
- `MainMenu: Created FadeRect`
- `MainMenu: Button press animation: Play`
- `MainMenu: Fade out completed`
- `MainMenu: Fade in completed`

---

## 🔧 Sorun Giderme

### Sorun: Icon değişmiyor
- **Çözüm**: Button'ın `icon` property'si destekleniyor mu kontrol edin. Godot 4'te Button'lar icon destekler.

### Sorun: Fade çalışmıyor
- **Çözüm**: TransitionLayer ve FadeRect node'larının doğru kurulduğundan emin olun.
- FadeRect'in anchor'ları Full Rect olmalı.

### Sorun: Buton spam click edilebiliyor
- **Çözüm**: `button.disabled = true` zaten yapılıyor. Eğer hala spam edilebiliyorsa, `is_transitioning` flag'i kontrol edin.

### Sorun: Scene değişimi çalışmıyor
- **Çözüm**: Action callable'ın doğru bağlandığından emin olun. `register_button` çağrısını kontrol edin.

---

## 📌 Notlar

- Icon'lar opsiyoneldir (`null` olabilir). Icon yoksa sadece scale animasyonu çalışır.
- Fade sadece scene değişimlerinde kullanılır. Quit için fade kullanılmaz (use_fade=false).
- Tüm butonlar otomatik olarak `_register_existing_buttons()` ile kaydedilir.
- Yeni buton eklemek için `register_button()` fonksiyonunu kullanın.


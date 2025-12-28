# Loading Screen Setup

## 1. Loading.tscn Scene Oluşturma

**Scene Yapısı:**
```
Loading (Control) - root node
└── LoadingLayer (CanvasLayer)
    └── BG (ColorRect)
        - Anchor: Full Rect (0,0,1,1)
        - Color: Black (0,0,0,1)
        - Mouse Filter: Ignore
    └── VBoxContainer
        - Anchor: Center
        - Offset: (-200, -100, 400, 200)  # Orta ekranda
        - Alignment: Center
        └── StatusLabel (Label)
            - Text: "Loading..."
            - Horizontal Alignment: Center
            - Vertical Alignment: Center
        └── LoadingBar (ProgressBar)
            - Min: 0
            - Max: 100
            - Value: 1
            - Show Percentage: false (percent_label kullanıyoruz)
        └── PercentLabel (Label)
            - Text: "1%"
            - Horizontal Alignment: Center
            - Vertical Alignment: Center
```

**Script Assignment:**
- Root node (Loading/Control) → `Scripts/LoadingScreen.gd`

**Node Paths (LoadingScreen.gd'de kullanılan):**
- `$LoadingLayer/VBoxContainer/StatusLabel`
- `$LoadingLayer/VBoxContainer/LoadingBar`
- `$LoadingLayer/VBoxContainer/PercentLabel`

## 2. LoadingManager Autoload Setup

**Project Settings → Autoload:**
- Name: `LoadingManager`
- Path: `res://Scripts/LoadingManager.gd`
- Enable: ✓

## 3. MainMenu Entegrasyonu

✅ **Tamamlandı!** `MainMenu.gd`'de Play butonu artık `LoadingManager.change_scene_with_loading()` kullanıyor.

## 4. Test

1. Oyunu çalıştır
2. MainMenu'de Play butonuna bas
3. Loading screen görünmeli
4. Progress bar 1%'den 100%'e kadar ilerlemeli
5. GameScene yüklendikten sonra geçiş yapılmalı

## Notlar

- Loading screen minimal tasarım (siyah arka plan, progress bar, label'lar)
- Threaded loading kullanılıyor (ana thread bloklanmıyor)
- Progress polling `_process` içinde yapılıyor
- Node referansları cache'leniyor (performans)
- Hata durumunda fallback: direkt scene change


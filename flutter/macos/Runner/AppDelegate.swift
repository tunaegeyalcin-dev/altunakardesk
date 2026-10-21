import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
    var launched = false;
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
      dummy_method_to_enforce_bundling()
    // https://github.com/leanflutter/window_manager/issues/214
    return false
  }
    
    override func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        if (launched) {
            handle_applicationShouldOpenUntitledFile();
        }
        return true
    }
    
    override func applicationDidFinishLaunching(_ aNotification: Notification) {
        launched = true;
        altunakarMenuyuCevir();
        NSApplication.shared.activate(ignoringOtherApps: true);
    }
}

/// Altunakar: menu cubugu MainMenu.xib'de Turkce yazili. Sistem dili Turkce olmayan Mac'te
/// basliklar Almancaya (de) ya da Ingilizceye (diger diller) cevrilir; programin arayuzu de
/// varsayilan olarak sistem dilini izler (lang.rs). Karsiliklar Apple'in kendi menu adlari.
private let altunakarMenuCeviri: [String: (en: String, de: String)] = [
    "AltunakarDesk Hakkında": ("About AltunakarDesk", "Über AltunakarDesk"),
    "Ayarlar…": ("Settings…", "Einstellungen …"),
    "Servisler": ("Services", "Dienste"),
    "AltunakarDesk'i Gizle": ("Hide AltunakarDesk", "AltunakarDesk ausblenden"),
    "Diğerlerini Gizle": ("Hide Others", "Andere ausblenden"),
    "Tümünü Göster": ("Show All", "Alle einblenden"),
    "AltunakarDesk'ten Çık": ("Quit AltunakarDesk", "AltunakarDesk beenden"),
    "Düzen": ("Edit", "Bearbeiten"),
    "Geri Al": ("Undo", "Widerrufen"),
    "Yinele": ("Redo", "Wiederholen"),
    "Kes": ("Cut", "Ausschneiden"),
    "Kopyala": ("Copy", "Kopieren"),
    "Yapıştır": ("Paste", "Einsetzen"),
    "Yapıştır ve Stili Eşleştir": ("Paste and Match Style", "Einsetzen und Stil anpassen"),
    "Sil": ("Delete", "Löschen"),
    "Tümünü Seç": ("Select All", "Alles auswählen"),
    "Bul": ("Find", "Suchen"),
    "Bul…": ("Find…", "Suchen …"),
    "Bul ve Değiştir…": ("Find and Replace…", "Suchen und ersetzen …"),
    "Sonrakini Bul": ("Find Next", "Weitersuchen"),
    "Öncekini Bul": ("Find Previous", "Rückwärts suchen"),
    "Bulmak İçin Seçimi Kullan": ("Use Selection for Find", "Auswahl suchen"),
    "Seçime Atla": ("Jump to Selection", "Zur Auswahl springen"),
    "Yazım ve Dilbilgisi": ("Spelling and Grammar", "Rechtschreibung und Grammatik"),
    "Yazım": ("Spelling", "Rechtschreibung"),
    "Yazım ve Dilbilgisini Göster": ("Show Spelling and Grammar", "Rechtschreibung und Grammatik einblenden"),
    "Belgeyi Şimdi Denetle": ("Check Document Now", "Dokument jetzt prüfen"),
    "Yazarken Yazımı Denetle": ("Check Spelling While Typing", "Während der Texteingabe prüfen"),
    "Dilbilgisini Yazımla Denetle": ("Check Grammar With Spelling", "Grammatik mit Rechtschreibung prüfen"),
    "Yazımı Otomatik Düzelt": ("Correct Spelling Automatically", "Rechtschreibung automatisch korrigieren"),
    "Yerine Koymalar": ("Substitutions", "Ersetzungen"),
    "Yerine Koymaları Göster": ("Show Substitutions", "Ersetzungen einblenden"),
    "Akıllı Kopyala/Yapıştır": ("Smart Copy/Paste", "Intelligentes Kopieren/Einsetzen"),
    "Akıllı Tırnaklar": ("Smart Quotes", "Intelligente Anführungszeichen"),
    "Akıllı Tireler": ("Smart Dashes", "Intelligente Gedankenstriche"),
    "Akıllı Bağlantılar": ("Smart Links", "Intelligente Links"),
    "Veri Algılayıcıları": ("Data Detectors", "Datenerkennung"),
    "Metin Değiştirme": ("Text Replacement", "Textersetzung"),
    "Dönüşümler": ("Transformations", "Transformationen"),
    "Büyük Harf Yap": ("Make Upper Case", "In Großbuchstaben"),
    "Küçük Harf Yap": ("Make Lower Case", "In Kleinbuchstaben"),
    "Baş Harfleri Büyüt": ("Capitalize", "Großschreibung"),
    "Konuşma": ("Speech", "Sprachausgabe"),
    "Konuşmayı Başlat": ("Start Speaking", "Sprachausgabe starten"),
    "Konuşmayı Durdur": ("Stop Speaking", "Sprachausgabe stoppen"),
    "Görüntü": ("View", "Darstellung"),
    "Tam Ekrana Gir": ("Enter Full Screen", "Vollbildmodus aktivieren"),
    "Pencere": ("Window", "Fenster"),
    "Küçült": ("Minimize", "Im Dock ablegen"),
    "Büyüt/Küçült": ("Zoom", "Zoomen"),
    "Tümünü Öne Getir": ("Bring All to Front", "Alle nach vorne bringen"),
    "Yardım": ("Help", "Hilfe"),
]

private func altunakarMenuyuCevir() {
    let dil = (Locale.preferredLanguages.first ?? "en").lowercased()
    if dil.hasPrefix("tr") { return }
    let almanca = dil.hasPrefix("de")
    func cevir(_ menu: NSMenu) {
        if let c = altunakarMenuCeviri[menu.title] { menu.title = almanca ? c.de : c.en }
        for oge in menu.items {
            if let c = altunakarMenuCeviri[oge.title] { oge.title = almanca ? c.de : c.en }
            if let alt = oge.submenu { cevir(alt) }
        }
    }
    if let ana = NSApp.mainMenu { cevir(ana) }
}

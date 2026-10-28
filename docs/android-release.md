# Android release Swift Photo

Build produksi tidak lagi memakai debug key. Keystore yang sama wajib digunakan
untuk seluruh pembaruan aplikasi; kehilangan keystore dapat membuat APK/AAB lama
tidak bisa diperbarui.

Build release sengaja dihentikan jika `android/key.properties` belum tersedia.
Jangan distribusikan APK release lama atau artefak tanpa tanda tangan produksi.

## 1. Buat keystore satu kali

Jalankan dari root proyek:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\create_android_release_key.ps1
```

Masukkan password minimal 12 karakter. Password tidak perlu dibagikan. Setelah
selesai, cadangkan kedua file berikut secara aman dan terpisah dari repository:

- `android/app/swift-photo-release.jks`
- `android/key.properties`

Jika password pernah terlihat di terminal, log, tangkapan layar, atau chat,
hapus keystore yang belum pernah dirilis lalu buat ulang dengan password baru.

## 2. Build dan validasi

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\flutter.ps1 analyze --no-pub
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\flutter.ps1 test --no-pub --concurrency=1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\flutter.ps1 build appbundle --no-pub --release
```

Artefak Play Store berada di `build/app/outputs/bundle/release/app-release.aab`.
Untuk distribusi APK langsung, gunakan `build apk --release` dan publikasikan
checksum SHA-256 bersama file unduhan.

## 3. OAuth Google Android

Tambahkan SHA-1 dan SHA-256 dari **release keystore** ke OAuth Android/Firebase
yang memakai package `com.swiftphoto.swift_photo`. Debug SHA hanya berlaku untuk
build pengembangan.

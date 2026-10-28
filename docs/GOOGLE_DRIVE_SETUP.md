# Google Drive langsung dari Swift Photo

Konfigurasi ini menyiapkan OAuth untuk login dan akses Drive langsung melalui API, tanpa aplikasi Google Drive di perangkat. Integrasi langsung kini memakai google_sign_in dan Drive REST API, browser folder di dalam aplikasi, serta antrean SQLite dan WorkManager. Pemilih direktori sistem lama sudah diganti.

## 1. Aktifkan API

1. Buka https://console.cloud.google.com/ dan buat/pilih proyek **Swift Photo**.
2. Buka **APIs & Services > Library**, cari **Google Drive API**, lalu **Enable**.
3. Buka **Google Auth Platform**. Jika belum dikonfigurasi, pilih **Get started**.
4. Isi **Branding**: nama Swift Photo, email dukungan, dan email kontak developer.
5. Untuk akun Gmail pribadi pilih **Audience: External**. Selama pengujian, tambahkan email penguji di **Test users**.

## 2. Buat OAuth client Android

Buka **Google Auth Platform > Clients > Create client**, pilih **Android**.

| Isian | Nilai build lokal saat ini |
|---|---|
| Name | Swift Photo Android |
| Package name | `com.swiftphoto.swift_photo` |
| SHA-1 | `C3:A2:D7:A0:AB:95:9C:98:3A:3E:B1:2F:8A:32:06:1E:E3:55:8F:06` |

SHA-1 dibaca dari debug.keystore komputer pengembangan pada 26 Oktober 2026. Build release lokal saat ini juga memakai debug signing. Untuk distribusi/Play Store, tambahkan OAuth client untuk sertifikat signing produksi/Play App Signing yang sebenarnya.

## 3. Buat OAuth client Web

Pada proyek yang sama, buat client kedua dengan jenis **Web application**, nama **Swift Photo Sign-In**. Client ID jenis Web dipakai sebagai `serverClientId` oleh plugin Google Sign-In Android; ini tetap diperlukan walaupun aplikasi Flutter adalah aplikasi mobile.

Untuk integrasi native tanpa backend yang direncanakan ini, tidak perlu mengisi JavaScript origins/redirect URI web. Jangan menambahkan alamat contoh. Jangan memasukkan client secret ke aplikasi atau membagikannya dalam percakapan.

Salin **Client ID** yang berakhiran `.apps.googleusercontent.com`. Client ID bukan API key atau client secret.

## 4. iOS (ketika siap menguji di Mac/iPhone)

Buat client jenis **iOS** dengan Bundle ID `com.swiftphoto.swiftPhoto`. Implementasi memerlukan Client ID iOS serta URL scheme dari reversed client ID. Tidak dapat diuji di lingkungan Windows ini.

## 5. Izin data dan langkah integrasi

Gunakan **Data Access** untuk mendaftarkan scope yang akan diminta aplikasi. Rencana awal menggunakan `https://www.googleapis.com/auth/drive.file` untuk file/folder yang dibuat atau diberikan akses kepada Swift Photo. Scope ini tidak membuat seluruh folder lama otomatis terlihat; akses folder lama memerlukan Google Picker atau desain izin yang sesuai. Jangan meminta akses penuh Drive hanya untuk mengunggah foto baru.

Client ID Web yang diberikan sudah dipasang di GoogleDriveAuth (dapat diganti dengan GOOGLE_WEB_CLIENT_ID melalui dart-define). Login Android tetap memerlukan client Android dengan package/SHA-1 yang benar pada proyek yang sama. Uji login dengan akun test user sebelum publikasi. Kredensial yang dibutuhkan untuk melanjutkan pengembangan adalah Client ID Web dan (untuk iOS) Client ID iOS, bukan password atau client secret.

## Referensi

- https://developers.google.com/workspace/guides/configure-oauth-consent
- https://developers.google.com/workspace/guides/create-credentials
- https://pub.dev/packages/google_sign_in_android
- https://pub.dev/packages/google_sign_in_ios
- https://developers.google.com/workspace/drive/api/guides/api-specific-auth


## Menjalankan integrasi

1. Buka **Drive > Sync Google Drive > Login dengan Google** di Swift Photo.
2. Pilih akun dan izinkan akses file Drive yang diminta.
3. Pilih **Buat folder**, misalnya Swift Photo, lalu **Gunakan folder ini**. drive.file hanya menampilkan folder yang dapat diakses aplikasi; semua folder lama tidak otomatis muncul.
4. **Sync foto baru otomatis** aktif setelah folder dipilih. Matikan untuk menghentikan antrean. Data yang sudah dikirim ke server tidak dapat ditarik kembali dengan sakelar ini.
5. **Sync foto lokal sekarang** juga memasukkan foto lama Swift Photo. Tidak memindai seluruh galeri perangkat.
6. Antrean menyimpan akun dan folder per foto. Mengganti folder hanya memengaruhi foto baru; foto dalam antrean tetap memakai folder semula. Mengganti akun menjeda antrean akun lama.

Token akses ditangani SDK Google dan diminta ulang secara senyap untuk akun yang tersimpan; token tidak ditulis ke database aplikasi atau log. Izin yang dicabut memerlukan login/otorisasi ulang. Worker tidak membuka layar login dari latar belakang.

Di Android, worker memakai batasan jaringan dan retry eksponensial, ditambah pemeriksaan periodik minimal 15 menit. Jadwal bergantung OS dan penghematan baterai. Di iOS, jadwal BGTaskScheduler dikendalikan OS, bukan interval pasti; swipe-kill dapat menghentikan pekerjaan latar belakang sampai aplikasi dibuka kembali.

### Konfigurasi iOS yang masih dibutuhkan

Client ID Web tidak dapat menggantikan Client ID iOS. Setelah client iOS dibuat, pasang reversed client ID pada CFBundleURLTypes/CFBundleURLSchemes di ios/Runner/Info.plist dan build dengan --dart-define=GOOGLE_IOS_CLIENT_ID=CLIENT_ID_IOS. Login iOS menampilkan pesan konfigurasi jika ID belum diberikan. Registrant worker, processing/fetch background modes dan identifier BGTaskScheduler telah disiapkan, tetapi build iOS harus diverifikasi di Mac.

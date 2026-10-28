# Swift Photo - pemeriksaan 26 Oktober 2026

## Batas dukungan

- Flutter 3.47 / Dart 3.13; batas Dart proyek 3.12 mengikuti camera 0.12.1.
- Android minSdk 24 (Android 7), APK mencakup ARM32, ARM64, x64.
- iOS deployment target 15.0; image_picker_ios memerlukan iOS 15.
- Matriks resmi: https://docs.flutter.dev/reference/supported-platforms
- iOS belum dibangun/dijalankan: lingkungan pengembangan Windows, tanpa Xcode.
- Build Android multi-ABI tidak sama dengan pengujian pada seluruh perangkat/versi OS.

## Pemeriksaan otomatis

40 tes lulus pada run suite penuh sebelum perbaikan cold-start; satu tes regresi tambahan dan pengulangan 8 tes UI + 9 tes render lulus setelah perbaikan (41 kasus total). Cakupan meliputi antrean operasi kamera, crop/zoom, session Real/Fake,
pencarian lokasi, penyimpanan salinan dan sidecar, pengaturan kualitas dan desain,
render seluruh 39 template, batas logo, alpha/posisi pada ekspor, serta UI berikut:

- 320x568, 390x844, 768x1024, 1024x768.
- Layar kecil dengan text scale 1.4.
- Splash, katalog template, editor template, dan drawer tanpa overflow.
- Drag logo mengubah posisi tersimpan dan tombol Simpan mengembalikan desain.
- Reduce motion menghentikan kepakan/pulse; efek sentuh tidak memblokir tombol.

Analyzer bersih. Empat tes service diulang dan lulus setelah perapihan constructor
sesuai Dart 3.12. Efek visual tidak dirender ke file foto.

## Cakupan yang belum tersedia

Cloud switch adalah preferensi lokal; OAuth/folder/worker unggah belum tersedia.
Video belum tersedia pada UI. Peta mini pada watermark merupakan kartu pin,
bukan snapshot peta; arah/elevasi/cuaca belum menggunakan sensor/data online.
Logo merek berupa wordmark sampai pengguna memilih logo asli. Foto lama tanpa
sidecar tidak dapat diedit per elemen. Flash fisik, lensa ultra-wide dan iOS masih
memerlukan perangkat yang sesuai. Klaim tidak ada error di semua perangkat tidak
dapat diberikan hanya dari emulator dan widget test.


## Kendala lingkungan yang ditemukan

Ulangan suite penuh sempat berhenti karena crash native flutter_tester.exe pada
Windows (Application Error 1000, access violation 0xc0000005). Suite UI dan render
kemudian dijalankan terpisah dan semuanya lulus. Ini dicatat sebagai keterbatasan
runner; hasil tersebut tidak digunakan untuk mengklaim uji iOS.

Emulator API36 sempat tidak merespons setelah screen recording/screencap dan
pembukaan picker. Getprop/logcat turut tidak merespons; perangkat virtual direstart
menggunakan renderer SwiftShader. Hasil native selanjutnya dicatat terpisah.

Cold-start sebelumnya dapat melewati animasi sebelum frame pertama terlihat.
Countdown splash kini menunggu waitUntilFirstFrameRasterized; regression test
memastikan callback selesai tidak berjalan sebelum frame siap.


## Hasil pemeriksaan native dan tindak lanjut

- Rekaman cold-start sesudah perbaikan memperlihatkan splash biru, Snap for Proof
  dan posisi sayap berubah selama sekitar dua detik sebelum dialog Real/Fake.
  Artefak: artifacts/startup-animation-fixed.mp4, startup-fixed-frames/frame-023.png
  dan frame-026.png.
- Pemilih gambar Android terbuka, membatalkan pilihan memulihkan tombol Simpan,
  dan memilih PNG logo berhasil menampilkan logo di editor.
- Drag native mengungkap delta yang hilang jika beberapa event datang sebelum
  rebuild. Perhitungan kini membaca konfigurasi terbaru pada setiap event;
  regression test mengirim tiga gerakan sebelum pump dan memeriksa jumlah tepat.
- Delapan tes UI lulus ulang setelah perbaikan drag.
- Emulator dengan SwiftShader kemudian mengalami crash host qemu-system-x86_64.exe
  (Windows Application Error 1000, 0xc0000005, module unknown). Ini membatasi
  pemeriksaan native lengkap; jangan ditafsirkan sebagai seluruh menu/OS sudah
  diuji tanpa error. Bukti log Windows diperiksa, bukan hanya timeout adb.
- Teks keadaan kamera gagal kini kontras pada latar putih. Aksen UI biru dan
  sakelar hijau konsisten dengan layar Preview.


## Pemeriksaan akhir pada renderer swangle, Vulkan dimatikan

Build terakhir berhasil untuk armeabi-v7a, arm64-v8a, x86_64; analyzer bersih.
Native flow akhir pada API36:

| Alur | Hasil |
| --- | --- |
| Splash cold-start | Biru, kepakan sayap, Snap for Proof terlihat sebelum Real/Fake |
| Pemilih logo | Buka, batal, dan impor PNG berhasil |
| Drag | 240 px kanan / 260 px atas menghasilkan perpindahan tepat yang sama |
| Simpan desain dan capture | Konfigurasi JSON sama pada settings dan sidecar foto baru |
| Drive | Preview foto dan pesan berhasil menyimpan salinan ke galeri terverifikasi |
| Edit Photo | Kode diganti, salinan baru tersimpan, konfigurasi logo tetap sama |
| Kualitas | Rendah lalu HD tersimpan; dipulihkan HD |
| Cloud | Preferensi aktif/nonaktif dan pesan akun belum terhubung terverifikasi; dipulihkan mati |
| Kamera | Zoom 1/2, rasio 3:4/1:1, siklus mode flash, depan/belakang terverifikasi |
| Fake | Peta, ikon cari/lokasi tersedia; dialog tanggal dan waktu dibuka/dibatalkan; kembali Real |

Log flutter:E / AndroidRuntime:E pada pemeriksaan akhir kosong. Satu alur otomasi
sempat kehilangan target karena task aplikasi ditutup: Android exit-info menunjukkan
USER REQUESTED / REMOVE TASK, bukan crash aplikasi. Pemeriksaan diulang dan berhasil.
Aplikasi ditinggalkan pada kamera Real, HD, cloud mati, rasio 3:4. Flash fisik,
ultra-wide, versi OS lain dan iOS tetap memerlukan perangkat yang sesuai.

Perintah renderer emulator yang berhasil digunakan:
`emulator -avd SwiftOS_Phone_API36 -gpu swangle -feature -Vulkan -camera-front emulated -camera-back emulated -no-snapshot-load -no-snapshot-save`

Artefak: startup-demo.mp4 (cuplikan animasi), final-camera-screen.png,
final-logo-photo.png. Seluruhnya berada dalam folder artifacts lokal.


## Perbaikan ruang aman splash

Ikon splash Android 12+ dipisahkan dari ikon launcher dan diberi padding untuk
masker lingkaran OS. Artwork 260x260 berada pada kanvas 432x432. Logo animasi
Flutter diperkecil dari 90% menjadi 72% ukuran dasar, di dalam bingkai putih 86%.
Amplitudo ujung sayap dikurangi sehingga titik tertingginya tetap di dalam kanvas
pada seluruh fase. Ikon launcher tidak diubah ukurannya. Analyzer dan build
Android multi-ABI berhasil; perubahan ini bersifat visual.


## Tombol keluar aplikasi

Pengaturan menyediakan Keluar aplikasi, dinonaktifkan selama penyimpanan
pengaturan. Android menggunakan SystemNavigator.pop, tanpa menghapus foto atau
pengaturan. Smoke test di API36 mengembalikan topResumedActivity ke NexusLauncher
serta UI Home. iOS menampilkan petunjuk pengalih aplikasi, tanpa memanggil exit(0).
Analyzer dan build Android multi-ABI lulus; APK terbaru telah dipasang.


## Mode pembuka cepat

Durasi animasi setelah frame pertama menjadi 650 ms, transisi 180 ms, siklus
kepakan 500 ms. Logo statis native dihilangkan: Android memakai drawable transparan
pada splash OS dan latar biru polos; launch storyboard iOS hanya latar biru.
Ikon launcher tidak dihilangkan. Regresi memastikan default splash selesai
kurang dari satu detik setelah frame siap. Waktu inisialisasi engine/OS tidak
termasuk durasi animasi dan bergantung perangkat. XML storyboard terverifikasi
well-formed; build dan runtime iOS tetap memerlukan Mac/Xcode.


Build release pertama berhasil (58.5 MB, ARM32/ARM64/x64) dan sudah dipasang ke
emulator dengan install -r. Signature lokal sama sehingga data aplikasi tetap ada.
Rekaman startup-quick.mp4 mengonfirmasi tidak ada logo statis native; animasi
Flutter muncul sebelum pilihan Real/Fake. Kamera Real berhasil diinisialisasi
(tombol Ambil foto aktif), tanpa error Flutter/AndroidRuntime pada pemeriksaan ini.
Durasi animasi 650 ms bukan jaminan seluruh cold start selesai dalam 650 ms.
APK release tidak mengizinkan adb run-as; gunakan build debug untuk inspeksi
sidecar internal saat QA. Build release memakai signing debug lokal yang sudah
ada pada proyek, belum merupakan konfigurasi signing untuk publikasi store.

### Cloud directory selection (26 October 2026)
- Drive and Settings now launch the system directory picker when Sync is enabled or the directory button is pressed. Cancel preserves the previous enabled state and destination.
- Android uses ACTION_OPEN_DOCUMENT_TREE, requires write permission, persists the URI grant and displays provider/folder. A subsequent selection starts at the previous destination where supported.
- iOS uses UIDocumentPickerViewController (.folder), saves a minimal bookmark, and handles cancellation. Requires verification on macOS/iOS; Windows cannot build this target.
- Cloud providers must be installed, signed in, and expose directory selection through the system picker. Some provider versions do not support folder grants. A local folder can also be selected; this is not proof of a connected cloud account.
- This change selects a destination only. OAuth adapters, background upload, retry and queue processing remain unimplemented. The UI states that automatic upload is unavailable.
- References: https://developer.android.com/training/data-storage/shared/documents-files and https://developer.apple.com/documentation/uikit/providing-access-to-directories
- Android emulator verification: Sync launched DocumentsUI; Back cancelled without enabling Sync. Selecting Documents and granting folder access returned Local storage / Documents, checked=true, and saved its content URI. Test destination was cleared afterwards and Sync restored to disabled. Real cloud account transfer was not tested.
- flutter analyze --no-pub: clean. Android debug APK built and installed successfully.

### Direct Google Drive integration (26 October 2026)
- Supersedes the preceding system-directory-picker experiment. Drive and Settings now open an in-app Google Drive sync screen. No installed Drive app is used by this flow.
- Web OAuth Client ID supplied by the project owner is configured in GoogleDriveAuth; Android package/SHA registration, Drive API enablement, consent scope and test users must be configured in the same Google Cloud project.
- Uses google_sign_in 7.2, account-specific silent Drive authorization, REST folder listing/creation and chunked PNG uploads. Scope drive.file exposes only app-authorized folders, not the entire historical Drive tree. The UI states this limitation and allows folder creation.
- Durable SQLite queue stores destination account, folder and pre-generated Drive file ID per photo. Jobs are claimed transactionally, retried after network failure, and recovered after lease expiry/process death. Preallocated file ID plus remote size verification avoids duplicate creates after an ambiguous completion response.
- Sync is disabled by default. Selecting a destination enables future photos. Disabling pauses work; changing accounts leaves the previous account's jobs paused. An explicit Sync foto lokal sekarang action adds older app photos, not arbitrary device-gallery content.
- Worker: network-constrained one-off and 15-minute periodic jobs, exponential Android retry. SDK obtains authorization for the saved account, with no interactive login in the background. iOS BGTask execution timing is OS-controlled; its OAuth client ID/reversed URL scheme and a Mac build remain required.
- Validation: analyze clean. Seven cloud API/queue tests pass, covering pagination, token invalidation, aligned chunk uploads, acknowledged completion, pause, opt-in/deduplication, account isolation, stale lease recovery and offline retries with the same remote ID. The existing local filename-save test also passed.
- Regression run: 44 cases passed before the existing native watermark-render test runner exited during the all-template rendering case. Isolated rerun again stopped at that case; this Windows renderer-host limitation is not counted as a full suite pass. Existing responsive UI suite passed in the regression run.
- Android debug APK built successfully, including the newly added native plugins. Live user-account login/consent and an actual Drive transfer require the user's Google session; mock tests do not establish those results.
- Native smoke: installed latest debug APK preserving app data, selected Real, opened Drive > Sync Google Drive and pressed Login dengan Google. Android launched Google Play Services MinuteMaidActivity (Google account onboarding/sign-in). No Flutter/AndroidRuntime errors appeared in the checked log. User must finish login; OAuth consent, directory listing against a real account and real transfer remain unverified. Screenshot: artifacts/drive-google-login.png.

### Public website and privacy links (26 October 2026)
- Published static website to the existing Swift Photo Cloud project (`swift-photo`, number 907898476409) using Firebase Hosting only. Billing confirmed disabled before setup and after deployment. No billing account was linked.
- Public homepage, privacy policy, terms and support/data-deletion instructions are available at https://swift-photo.web.app/, /privacy, /terms and /support. User explicitly supplied email/phone for public contact. Developer identity remains a generic role because no legal name was supplied.
- Policies reflect the implementation: local originals/sidecars, visible watermark metadata, opt-in direct Drive upload using drive.file, account/folder-specific queue retention, SDK authorization, OS geocoding and OpenStreetMap tiles. No claim of public store availability or Google verification.
- Browser QA: six tests passed in Edge across 320/390/768/1440px widths, mobile menu, demo toggles/shutter simulation, anchor navigation, reduced motion, 404; no console errors or horizontal overflow. Normal website interactions made no external requests/cookies. Static link/anchor check passed for five HTML pages.
- Production HTTP checks: 200 for homepage, privacy, terms, support, robots and sitemap; 404 for an unknown route; CSP headers served. Logo and fonts served locally; no analytics/form/upload backend.
- Added public policy links to Settings and pre-login cloud screen. Dart analyzer passed. OAuth Console Branding and Search Console ownership were not modified automatically; public website deployment does not mean brand verification approval.
- APK debug dengan tautan privasi/ketentuan/bantuan berhasil dibangun; belum mengganti sesi aplikasi yang sedang dibuka pengguna di emulator. SHA-256 konten HTML produksi cocok dengan build lokal untuk homepage, privacy, terms dan support.

### Search Console verification tag (26 October 2026)
- User supplied an HTML site-verification token. Saved it in website/site.config.json so future builds retain the tag, then rebuilt and deployed Firebase Hosting project swift-photo.
- Static site check passed. Verified that the exact token appears once inside the homepage head, and production HTTP 200 responses at https://swift-photo.web.app/ and its no-trailing-slash form contain the same tag.
- Hosting release: projects/907898476409/sites/swift-photo/versions/07cc429c61eee735. Installing the public tag does not assert successful ownership verification or OAuth brand approval. The owner still needs to click Verify in Search Console, then follow Google's requested 24-hour wait before branding re-verification.

### About screen (26 October 2026)
- Added Settings > Tentang aplikasi with the existing Swift Photo logo/tagline, installed application version/build via package_info_plus, development status, developer Eko Ardianto, and the email/phone explicitly supplied by the user.
- Contact values are selectable, have copy buttons, and offer mailto/tel links that open an external app rather than sending a message or placing a call automatically. Missing handlers show a readable fallback. Includes official website and open-source license links.
- Public identity constants live in lib/models/app_identity.dart. Version is not hard-coded into the screen; current pubspec is 0.1.0+1.
- Dart analysis: no issues. iOS compilation remains unverified in this Windows environment.

# Swift Photo

Google Drive kini terintegrasi langsung melalui login Google di Swift Photo, tanpa aplikasi Google Drive. Buka **Drive > Sync Google Drive** untuk login, membuat/memilih folder yang diizinkan, mengaktifkan sync foto baru, atau memasukkan foto lokal lama. Foto tetap disimpan lokal dahulu; antrean unggah SQLite diproses WorkManager dengan retry. Konfigurasi dan batasan izin: [Google Drive setup](docs/GOOGLE_DRIVE_SETUP.md). Bagian catatan pengembangan lama yang menyatakan belum ada upload merujuk versi sebelumnya.

Kamera Flutter Android/iOS untuk dokumentasi dengan watermark permanen dan
penyimpanan lokal. Tampilan kamera menggunakan kontrol putih, tombol shutter
lingkaran, serta dua navigasi: **Drive** dan **Template**.
Header menyediakan menu samping, flash Mati/Otomatis/Menyala, dan ganti kamera
depan/belakang. Drawer bergeser dengan animasi bawaan Flutter dan menutup dahulu
sebelum membuka Drive atau Edit.
Ikon kamera menggunakan vector outline dengan ketebalan garis konsisten.
Kontrol zoom mengambang vertikal di kanan preview; pilihan aktif memakai ring
putih tipis. Tombol jepret memakai ring hitam dengan bagian tengah putih.

Area kamera menyediakan rasio **3:4**, **1:1**, **9:16**, dan **Asli**, serta zoom
**0,5×**, **1×**, **2×**. Rasio default 3:4. Preview dan hasil ekspor di-crop dari
tengah, tanpa meregangkan gambar, lalu watermark dirender di dalam crop hasil.
Zoom dikirim ke kamera melalui SDK sehingga berlaku pada preview dan foto.
0,5× memakai rentang zoom kamera yang mendukungnya, atau beralih ke lensa
ultra-wide terpisah bila tersedia. Pilihan zoom dan pergantian kamera yang tidak
didukung perangkat dinonaktifkan; flash kamera depan dinonaktifkan.

## Alur kamera

Saat proses aplikasi dibuka, kamera belum diinisialisasi. Pop-up meminta mode:

- **Real**: jam mengikuti perangkat, lokasi dicari dari GPS dan alamat melalui
  reverse geocoding. Lokasi diperbarui saat resume dan setiap 30 detik selama
  kamera digunakan. Jika GPS/jaringan tidak tersedia, statusnya ditampilkan;
  pemotretan tidak menunggu jaringan.
- **Fake**: pilih pin pada peta, atau masukkan latitude/longitude; isi alamat,
  tanggal, dan waktu. Tekan **OK, buka kamera** untuk masuk ke kamera. Waktu dan
  lokasi manual tetap sesuai pilihan, bukan mengikuti jam/GPS berikutnya.
  Membatalkan formulir awal mengembalikan pemilihan mode, tanpa membuka kamera.

Mode dapat diganti lewat badge Real/Fake atau **Template > Data**.
Peta menggunakan OpenStreetMap dengan atribusi. Peta dan reverse geocoding
memerlukan jaringan; koordinat dan alamat tetap dapat diketik saat offline.
Kolom **Cari tempat atau alamat** menerima nama tempat/alamat melalui tombol
cari atau tombol Search keyboard. Pilih hasil untuk memusatkan peta dan mengisi
pin, koordinat, serta alamat watermark. Tombol crosshair **Lokasi saat ini** di
kanan atas peta mengambil GPS perangkat (dan meminta izin bila diperlukan).
Kegagalan GPS mempertahankan pilihan sebelumnya; pemilihan pin lain saat GPS
masih diproses tidak ditimpa hasil GPS yang terlambat.

## Watermark dan foto

Preview dan hasil foto menggunakan painter yang sama: jam besar `HH:mm`, garis
kuning, tanggal berbahasa Indonesia, hari, alamat, koordinat, dan kode foto.
Brand Swift Photo berada di kanan atas dan logo perusahaan opsional di kiri atas.
Template menyediakan tiga posisi, pemilihan/penghapusan logo, serta perubahan mode.
Layout dan logo dipersistenkan antar sesi; mode selalu dipilih ulang saat proses
aplikasi dimulai. Hasil manual diberi keterangan kecil `Manual`, hasil data
perangkat `Perangkat`. Kode foto adalah ID referensi, bukan sertifikat keaslian.
Waktu Real menggunakan jam sistem perangkat, belum sinkronisasi waktu server.

Foto diambil dari kamera, metadata dibekukan, lalu watermark dibakar ke piksel
pada resolusi maksimum crop rasio pilihan. PNG ditulis ke dokumen internal `SwiftPhoto` melalui
file sementara dan rename, kemudian disalin ke galeri Android/iOS. Kegagalan
galeri tidak menghapus foto internal. Drive dapat membuka dan memperbesar foto
serta mencoba menyimpan ulang salinan ke galeri.

**Drive menampilkan galeri foto lokal dan akses Sync Google Drive.** Login Google,
pemilihan/pembuatan folder yang diizinkan, antrean unggah dan worker tersedia.
OneDrive, video, dan aktivasi Pro belum diimplementasikan. Permintaan
terbaru menyediakan pemilihan Fake langsung tanpa pembatas aktivasi.

## Menjalankan di komputer ini

Flutter 3.47.8 / Dart 3.13.7 dipasang di `%USERPROFILE%\develop\flutter`, Git di
`%USERPROFILE%\develop\mingit`, Android SDK/JDK di `%LOCALAPPDATA%\SwiftOSAndroid`.
Wrapper menyiapkan PATH dan environment hanya pada proses yang dijalankan:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/flutter.ps1 pub get
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/flutter.ps1 analyze
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/flutter.ps1 test --concurrency=1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/flutter.ps1 run -d emulator-5554
```

Emulator harus sudah berjalan. Perintah juga tersedia pada **Terminal > Run Task**
di VS Code. Untuk memposisikan jendela emulator di tengah dan fit tinggi layar:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/center-emulator.ps1
```

Pengujian pergantian kamera menggunakan AVD `SwiftOS_Phone_API36` dengan opsi
`-camera-front emulated -camera-back emulated -no-snapshot-load -no-snapshot-save`.
Jika AVD dijalankan dengan kamera depan nonaktif, tombol ganti kamera dinonaktifkan
sesuai daftar kamera yang dilaporkan perangkat.

APK debug yang diuji menggunakan ABI Android x64 untuk emulator. Untuk APK
perangkat Android jalankan build Flutter dengan ABI perangkat yang sesuai.
Konfigurasi izin Android/iOS dapat diulang dengan
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/configure-platforms.ps1`.
Android minimum SDK 24; proyek iOS menggunakan target iOS 15 dan memerlukan macOS
serta Xcode untuk build. Build iOS belum diuji pada lingkungan Windows ini.

Kotlin incremental dinonaktifkan agar cache Pub pada C: dapat digunakan oleh
proyek di D:. Worker Gradle dibatasi untuk memori komputer ini. Tes dijalankan
satu per satu agar tidak berebut memori dengan emulator dan build Android.

## Struktur

- `lib/screens/camera_screen.dart`: viewfinder, shutter, navigasi dan lifecycle.
- `lib/screens/camera_navigation_drawer.dart`: menu samping Drive, Template dan Edit Photo.
- `lib/screens/viewfinder_controls.dart`: rasio foto dan pilihan zoom.
- `lib/screens/capture_mode_dialog.dart`: pilihan Real / Fake sebelum kamera aktif.
- `lib/screens/manual_capture_screen.dart`: peta pin, alamat, tanggal, waktu.
- `lib/screens/edit_watermark_sheet.dart`: pengaturan template dan logo.
- `lib/screens/gallery_screen.dart`: Drive lokal dan preview hasil foto.
- `lib/models/capture_session.dart`: pemisahan sumber data Real dan Fake.
- `lib/models/camera_options.dart`: crop rasio, batas zoom, dan pilihan lensa.
- `lib/services/watermark_renderer.dart`: canvas preview dan ekspor PNG.
- `lib/services/location_service.dart`: GPS dan reverse geocoding dengan timeout.
- `lib/services/place_search_service.dart`: pencarian alamat, hasil pin valid, dan fallback alamat.
- `lib/services/settings_service.dart`: file pengaturan dan logo.
- `lib/services/local_media_service.dart`: internal storage dan galeri.
- `lib/services/async_operation_queue.dart`: mengurutkan buka/tutup kamera.

Font Barlow Condensed dibundel agar watermark tetap bekerja offline. Lisensi
SIL Open Font License disertakan pada `assets/fonts/OFL.txt` dan registri lisensi
Flutter. Tidak ada foto referensi pengguna yang dibundel ke dalam aplikasi.

## Validasi dan batas praktis

Sembilan belas tes mencakup sumber waktu Real, waktu Fake yang tetap, validasi pin,
format tanggal/hari, piksel watermark ketiga layout, urutan lifecycle kamera,
hasil pencarian, deduplikasi koordinat dan fallback ketika alamat gagal dibaca,
serta crop rasio, hasil piksel crop, batas zoom dan pemilihan lensa depan/ultra-wide.
Analisis kode bersih. APK debug Android x64 telah dibangun dan dipasang di emulator
API 36. Pengujian emulator mencakup peta/pin, formulir tanggal/waktu, mode Fake
24 Oktober 2026 17:05, ekspor watermark ke internal dan galeri, menu Edit/Drive,
konfirmasi Fake saat keyboard terbuka, serta pengambilan foto offline. Real juga
diuji dengan GPS simulasi Monas: koordinat dan alamat otomatis berbeda dari data
manual, dengan waktu perangkat saat ini. GPS emulator menggunakan lokasi simulasi;
akurasi GPS lapangan dan perilaku izin OEM tetap perlu perangkat fisik.
Pencarian alamat juga diuji di emulator: hasil Bandung dapat dipilih menjadi pin,
lalu tombol Lokasi saat ini memindahkan pin dan alamat ke GPS simulasi Monas.
Kontrol header flash diuji berganti Mati/Otomatis/Menyala, kamera dapat berpindah
depan dan belakang, zoom 2× memperbesar hasil foto, dan drawer dapat membuka Drive/Edit.
Ekspor 1:1 terverifikasi 720×720 dan 3:4 terverifikasi 720×960 di emulator, dengan
watermark lengkap setelah crop. Zoom 0,5× nonaktif pada emulator yang tidak
memiliki kamera ultra-wide.

PNG lebih besar daripada JPEG. Orientasi kamera dikunci portrait; field of view
preview/capture native bisa berbeda pada perangkat tertentu. Crop ekspor tetap
mengikuti rasio yang dipilih. Cahaya flash fisik dan lensa ultra-wide perlu diuji
pada perangkat yang memiliki hardware tersebut. Alamat dibatasi dua baris pada
watermark. Data internal mengikuti kebijakan uninstall perangkat. Pemulihan
pemilihan logo yang belum selesai setelah proses dimatikan Android belum tersedia.

Referensi API: [camera](https://pub.dev/packages/camera),
[gal](https://pub.dev/packages/gal), [flutter_map](https://pub.dev/packages/flutter_map),
[geolocator](https://pub.dev/packages/geolocator),
[geocoding](https://pub.dev/packages/geocoding).

Preview kamera mengisi seluruh area antara header dan kontrol bawah dengan BoxFit.cover, tanpa letterbox hitam. Rasio dan zoom mengambang di atas preview. Bagian tepi preview dapat terpotong untuk memenuhi layar; rasio ekspor tetap mengikuti pilihan pengguna.


### Template dan pilihan cloud

Template membuka grid 39 template dasar dengan pencarian, preview dari canvas yang sama
seperti ekspor, pilihan satu template, atau tombol nonaktifkan semua. Logo lokal
dapat diganti/dihapus; template, status watermark dan preferensi cloud tersimpan
setelah aplikasi ditutup. Model visual mengikuti kategori referensi, belum merupakan
salinan persis seluruh template bermerek. Logo merek tidak dibundel: pilih logo
perusahaan melalui galeri. Preview kamera tetap aktif saat panel template terbuka.

Sync Google Drive bersifat opt-in. Pengguna login Google dan memilih folder sebelum
sync aktif. Antrean tersimpan di SQLite; worker mengunggah langsung melalui Drive
API dan mencoba ulang gangguan jaringan. Counter tersinkron bertambah hanya setelah
server mengonfirmasi file. Akses akun nyata tetap memerlukan pengujian login pengguna.

Photo Code memakai 14 karakter acak kapital/angka tanpa awalan, dibuat lokal untuk setiap foto. Ikon centang adalah dekorasi
referensi dokumen, bukan sertifikasi Timemark. Data manual tetap berlabel Manual.
Aplikasi ini tidak membuat atau menjamin kode yang dapat lolos verifikasi Timemark.

Validasi terakhir: flutter analyze bersih; 20 tes lulus termasuk ekspor crop dan
kesamaan seluruh piksel sumber ketika watermark dinonaktifkan.


### Edit Photo

Tombol kamera **Template** mengatur watermark pengambilan berikutnya. Menu samping
**Edit Photo** membuka pemilih foto lokal dan editor terpisah. Ketuk area watermark
atau tombol Tanggal, Jam, Lokasi, GPS, dan Photo Code untuk mengubah nilainya.
Timestamp gabungan membuka pilihan tanggal/jam. Photo Code menerima 14 huruf/angka.

Setiap capture baru menyimpan folder sidecar `.png.project` dengan sumber asli,
logo PNG, rasio crop dan JSON data watermark. Editor merender ulang dari sumber
bersih, mempertahankan template/logo/rasio, menambahkan label Diedit dan menyimpan
salinan baru. Foto awal tidak ditimpa. Salinan juga mempunyai sidecar untuk edit
berikutnya. Jika penyalinan ke galeri gagal, hasil tetap tersedia di Drive lokal.
Foto dari versi lama tidak dapat diedit per elemen karena watermark sudah menyatu;
editor menampilkan penjelasan dan tidak mengubah foto tersebut.

Validasi: 22 tes lulus termasuk roundtrip data edit dan deteksi foto lama; analyzer bersih.


### Logo, kualitas, dan nama salinan

Ikon baru memakai walet berkepala kamera yang tersenyum; sumber ada di
`assets/branding/swift_photo.png`. `scripts/package-app-icon.ps1` menghasilkan
ukuran launcher Android dan katalog AppIcon iOS dalam RGB tanpa alpha.
Menu Pengaturan menyediakan Rendah, Sedang, dan HD; pilihan persisten digunakan
langsung sebagai camera ResolutionPreset low, medium, dan veryHigh. Resolusi
aktual tergantung kemampuan hardware; kualitas tidak memperbesar foto secara artifisial.

Label Perangkat dihapus. Label Manual dan Diedit tetap tampil bila sesuai.
Salinan edit memakai nama berkas asal dengan tepat satu karakter kapital/angka
sebelum ekstensi, misalnya swift_123.png menjadi swift_123A.png. Kandidat nama
diperiksa agar tidak menimpa berkas yang ada. Maksimal 36 nama satu karakter
tersedia untuk tiap nama sumber. Daftar foto mengikuti waktu modifikasi terbaru.

Katalog sekarang berisi 39 preset dengan badge clock-in, completed, patrol,
services, activity, tabel, clock/date, portrait, serta preset merek. Preview grid
menggunakan latar abu-abu dan canvas yang sama seperti ekspor. Posisi sentuh editor
mengikuti layout template. Hasil belum identik piksel dengan seluruh screenshot:
logo merek memakai wordmark teks sampai logo asli dipilih pengguna; kartu pin
menampilkan koordinat, bukan snapshot peta; portrait memakai placeholder sampai
logo/foto dipilih; arah/elevasi/cuaca yang belum tersedia ditampilkan sebagai --.

Validasi: 28 tes suite utama lulus, ditambah tes penyimpanan salinan/urutan galeri
lulus; analyzer bersih. Ikon iOS disiapkan tetapi build iOS memerlukan macOS.

Uji Android tambahan: pengaturan Rendah tersimpan dan menghasilkan crop 240x320;
HD menghasilkan crop 720x960 pada kamera virtual. Salinan edit terverifikasi
swift_1792939525511456.png -> swift_1792939525511456J.png, dengan sidecar baru
serta foto sumber tetap ada. Log runtime Flutter/Android tidak menunjukkan error.


### Splash animasi dan editor template

Saat startup, layar native Android/iOS menggunakan latar biru polos selama engine disiapkan.
Flutter menampilkan maskot walet yang mengepak, gradient biru dan **Snap for Proof**
selama 650 ms, lalu transisi 180 ms ke dialog Real/Fake. Tidak ada tahap logo statis tambahan. Kepakan menggunakan
CustomPainter; aset launcher tetap memakai logo raster. Reduce motion mematikan
kepakan dan efek pulse. Efek sentuh global mengabaikan hit test dan tidak masuk
ke hasil foto.

Ketuk kartu template untuk membuka Preview. Logo dapat digeser dalam batas
kanvas; slider Posisi menyediakan alternatif aksesibel. Ukuran, Alpha, Sudut,
serta sakelar logo/waktu/alamat/koordinat/Photo Code benar-benar mengubah preview
dan ekspor. Simpan menyimpan desain per template; kembali tanpa Simpan membatalkan
perubahan. Ganti logo memakai galeri. Sumber logo global tetap dapat diganti,
sementara posisi dan tampilan disimpan per template. Sidecar versi 2 mempertahankan
konfigurasi saat dibuka lewat Edit Photo; sidecar versi lama tetap dapat dibaca.

Batas dukungan: Android 7/API24+ dan iOS15+, bukan seluruh versi OS historis.
Lihat [catatan QA](docs/QA.md) untuk cakupan uji dan keterbatasan.


Pemeriksaan akhir menambahkan tes regresi cold-start dan memperkuat tes drag
beberapa event sebelum rebuild (41 kasus total; suite UI dan render diulang
terpisah karena crash native runner Windows). Native Android memverifikasi
startup, impor/drag logo, capture, Drive/galeri, Edit Photo, kualitas/cloud,
zoom/rasio/flash/front-back, dan menu Fake/tanggal/waktu. Log exception terakhir
kosong. Lihat docs/QA.md untuk batas cakupan dan kendala emulator/runner yang terjadi.


Versi untuk uji kecepatan startup memakai app-release.apk (58.5 MB) dengan AOT dan
optimasi R8; sudah dipasang ke emulator. Animasi sendiri 650 ms setelah frame
pertama, transisi 180 ms. Waktu inisialisasi OS/engine tetap mengikuti perangkat.
Konfigurasi signing release proyek masih memakai key debug lokal; belum untuk
publikasi store. adb run-as hanya tersedia pada build debug.

## Website publik Swift Photo

Homepage, kebijakan privasi, ketentuan dan bantuan tersedia gratis melalui Firebase Hosting di https://swift-photo.web.app/. Source, konfigurasi deploy, hasil pemeriksaan dan panduan Google Auth Platform ada di [website/README.md](website/README.md). Kepemilikan domain dan persetujuan OAuth harus diselesaikan melalui Google; website tidak menyatakan aplikasi sudah terverifikasi.

## Tentang aplikasi

Pengaturan > Tentang aplikasi menampilkan versi/build yang dibaca dari paket terpasang, nama pengembang Eko Ardianto, email ekoardianto.pro@gmail.com, dan nomor 089633427198. Kontak dapat disalin atau dibuka melalui aplikasi email/dialer perangkat; halaman juga menautkan website dan lisensi sumber terbuka.

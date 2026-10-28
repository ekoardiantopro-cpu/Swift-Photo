# Swift Photo public website

Website statis tanpa framework, font eksternal, pelacakan, atau formulir unggah. Semua konten kebijakan dirender sebagai HTML agar dapat dibaca tanpa JavaScript.

## Website yang sudah diterbitkan

- Homepage: https://swift-photo.web.app/
- Privacy Policy: https://swift-photo.web.app/privacy
- Terms of Service: https://swift-photo.web.app/terms
- Bantuan dan penghapusan data: https://swift-photo.web.app/support

Firebase Hosting berada di proyek `swift-photo`, project number `907898476409`, sama dengan proyek OAuth aplikasi. Billing diperiksa tidak aktif sebelum penyiapan dan setelah deployment pada 26 Oktober 2026. Tidak ada akun billing yang dihubungkan, upgrade Blaze, database, Storage bucket, atau backend website yang dibuat. Firebase ditambahkan ke proyek Cloud yang sudah ada dan hanya Hosting yang dideploy.

Kontak email dan nomor telepon pada `site.config.json` diberikan pengguna secara eksplisit untuk publikasi. Identitas pengelola memakai peran generik “Pengembang Swift Photo” karena nama badan usaha/orang belum ditentukan. Tidak ada klaim bahwa Google sudah memverifikasi aplikasi atau bahwa aplikasi sudah tersedia di toko publik.

## Mengubah dan memeriksa

Jalankan dari folder `website`:

```powershell
npm.cmd ci
npm.cmd run build
npm.cmd run check
npm.cmd run test:ui
npm.cmd run preview
```

Build tidak membutuhkan dependency. `npm ci` hanya diperlukan untuk pengujian browser Playwright; pengujian memakai Microsoft Edge yang sudah terpasang. Preview lokal: http://127.0.0.1:4183.

- `site.config.json`: nama, kontak, origin, tanggal kebijakan, dan token publik verifikasi Search Console jika diperlukan.
- `src/legal.mjs`: Privacy Policy, Terms of Service, bantuan.
- `build.mjs`: template halaman, ilustrasi interaktif berlabel, metadata, sitemap.
- `src/styles.css` dan `src/site.js`: tata letak responsif, menu mobile, simulasi watermark, reduced motion.
- `dist/`: HANYA konten yang dikirim ke Hosting. File aplikasi, foto pengguna, kunci dan kredensial bukan bagian website.

Logo kecil berasal dari launcher resmi aplikasi, bukan logo merek pihak ketiga. Kontak memakai `mailto:` dan `tel:`; tidak mengirim pesan otomatis.

## Deploy pembaruan

Firebase CLI sudah terpasang dan akun yang benar sudah login pada komputer pengembangan saat deployment. Tidak menyimpan token CLI atau client secret di proyek ini.

```powershell
node build.mjs
node scripts/check.mjs
firebase.cmd deploy --only hosting --project swift-photo
```

Gunakan hanya Hosting. Tidak perlu menjalankan Firebase App Hosting, menambahkan Cloud Functions, menghubungkan billing, atau meng-upgrade ke Blaze untuk halaman statis ini. Batas kuota Hosting gratis tetap berlaku; pantau penggunaan di console. Jangan memakai `login:list --json` dalam output yang dibagikan karena versi CLI dapat menyertakan data autentikasi.

## Mengaktifkan tombol download Android

File APK tidak disimpan di Firebase Hosting paket Spark. Gunakan folder Google
Drive publik atau asset GitHub Release, lalu isi nilai pada `site.config.json`:

```json
"downloadUrl": "https://drive.google.com/drive/folders/FOLDER_ID?usp=sharing",
"downloadProvider": "google-drive-folder",
"androidVersion": "0.1.0 Beta",
"androidFileSize": "58 MB",
"androidSha256": "CHECKSUM_SHA256"
```

Saat `downloadUrl` kosong, tombol dan bagian download tidak diterbitkan. Untuk
Google Drive pastikan akses folder adalah **Anyone with the link / Viewer**.
Setelah URL HTTPS diisi, jalankan build, check, dan deploy seperti di atas.

## Nilai untuk Google Auth Platform

Pada **Branding**, isi:

| Kolom | Nilai |
|---|---|
| App name | Swift Photo |
| User support email | ekoardianto.pro@gmail.com |
| Homepage | https://swift-photo.web.app/ |
| Privacy Policy | https://swift-photo.web.app/privacy |
| Terms of Service | https://swift-photo.web.app/terms |
| Authorized domain | swift-photo.web.app |
| App logo | `dist/assets/logo.png` (PNG persegi, di bawah 1 MB) |

Pengaturan Branding, Audience, dan pengajuan OAuth belum diubah otomatis. Website ini memenuhi pemeriksaan teknis dasar (konten publik, identitas aplikasi, kontak, informasi pemakaian Google Drive, Privacy Policy/Terms yang saling tertaut). Ini bukan persetujuan verifikasi oleh Google. Penerimaan subdomain gratis tetap tunduk pada pemeriksaan kepemilikan dan hasil review Google.

### Verifikasi kepemilikan melalui Search Console

1. Buka https://search.google.com/search-console dengan akun yang menjadi owner/editor proyek OAuth.
2. Tambah properti **URL prefix**: `https://swift-photo.web.app/`.
3. Jika otomatis terverifikasi, catat statusnya; tidak perlu mengubah website.
4. Jika diminta, pilih metode **HTML tag**. Salin hanya nilai `content` dari meta `google-site-verification` ke `googleSiteVerification` pada `site.config.json`. Ini token verifikasi publik, bukan password/OTP/token login.
5. Build dan deploy pembaruan, kemudian klik **Verify** di Search Console. Pertahankan tag tersebut pada deploy berikutnya.
6. Lengkapi Branding dan jalankan proses verifikasi yang ditampilkan Google Auth Platform. Mengubah Audience ke In production tidak sama dengan mendapatkan persetujuan brand.

Jika pemeriksa Google menolak subdomain gratis walaupun Search Console terverifikasi, simpan alasan penolakannya dan tinjau bersama; jangan mengklaim persetujuan atau membeli domain sebelum alasan tersebut dipahami.

## Validasi 26 Oktober 2026

- Static check: 5 halaman, tautan/anchor internal, kontak publik dan pengungkapan Google data lolos.
- Playwright/Edge: 6 tes lolos pada lebar 320, 390, 768, 1440; tidak ada overflow horizontal atau error console. Menu mobile, tombol demo, link kebijakan, reduced motion dan 404 diuji.
- Website tidak membuat request eksternal atau cookie selama pengujian interaksi normal.
- Inspeksi visual desktop, mobile dan halaman privasi selesai; gambar QA lokal ada di `test-results` (diabaikan Git).
- HTTP produksi: homepage, privacy, terms, support, robots dan sitemap mengembalikan 200; URL tidak dikenal mengembalikan 404. Header CSP tersedia.
- Tautan kebijakan juga ditambahkan ke source aplikasi pada Pengaturan dan layar sebelum login Google. APK Android diperbarui melalui build terpisah; source iOS tetap membutuhkan validasi Mac.

## Referensi resmi

- https://firebase.google.com/docs/hosting/quickstart
- https://firebase.google.com/docs/projects/billing/firebase-pricing-plans
- https://developers.google.com/terms/api-services-user-data-policy
- https://support.google.com/cloud/answer/15549049
- https://support.google.com/webmasters/answer/9008080

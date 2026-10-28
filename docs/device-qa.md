# Matriks QA perangkat Swift Photo

Otomasi memeriksa crop rasio, kemampuan zoom, penamaan file, integritas proyek,
antrean Drive, dan UI responsif. Perilaku kamera fisik tetap harus diuji pada
perangkat nyata sebelum rilis publik.

## Perangkat minimum

| Kelas | Contoh kondisi | Yang diverifikasi |
|---|---|---|
| Android 7 / API 24 | perangkat lama, RAM rendah | startup, izin, foto, galeri |
| Android 10–12 | scoped storage dan izin lama | simpan lokal/galeri, edit |
| Android 13–16 | izin dan background modern | kamera, lokasi, WorkManager |
| Kamera tunggal | tanpa ultrawide | tombol 0.5x tidak ditampilkan |
| Multi-kamera | ultrawide + wide + depan | perpindahan 0.5x/1x/2x |
| Layar kecil/tablet | portrait/landscape | tidak overflow, kontrol terjangkau |

## Skenario wajib

1. Tolak lalu berikan izin kamera, lokasi, dan galeri.
2. Ambil foto untuk rasio Asli, 3:4, 1:1, dan 9:16; cocokkan dimensi file.
3. Uji 0.5x hanya jika lensa ultrawide benar-benar tersedia; uji 1x dan 2x.
4. Ambil foto Live dan Manual; pastikan label permanen terlihat.
5. Edit tanggal/lokasi; pastikan salinan bernama unik dan bertanda Diedit.
6. Buka preview; pastikan status integritas lokal cocok.
7. Aktifkan Drive, putuskan internet, ambil foto, lalu pulihkan internet.
8. Pastikan status bergerak Menunggu → Mengunggah → Tersinkron.
9. Cabut akses Google dan pastikan item menjadi Perlu tindakan serta bisa retry.
10. Instal build release di atas versi lama dan pastikan foto lokal tetap ada.

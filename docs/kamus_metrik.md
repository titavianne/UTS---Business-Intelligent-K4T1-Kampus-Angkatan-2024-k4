# D6 — Kamus metrik (12 field)

> UTS item 5 menilai **satu** metrik lengkap; UAS menilai tiga. Setiap metrik wajib punya berkas SQL
> di `sql/50_metrics/` — definisi yang tidak bisa dijalankan belum tentu benar.

## Metrik 1 — Rasio Kehadiran Mahasiswa (Attendance Rate)

| # | Field | Isi |
|---|---|---|
| 1 | Nama metrik | Rasio Kehadiran Mahasiswa (Attendance Rate) |
| 2 | Definisi (satu kalimat, tanpa jargon) | Persentase pertemuan yang benar-benar dihadiri seorang mahasiswa dari seluruh pertemuan yang tercatat untuknya di satu mata kuliah. |
| 3 | Rumus (SQL-nya, bukan bahasa manusia) | `SUM(is_hadir)::DOUBLE / COUNT(*)` dari `fact_presensi`, dikelompokkan sesuai dimensi yang dipilih (lihat `sql/50_metrics/rasio_kehadiran.sql`). |
| 4 | Grain | Satu baris hasil = satu kombinasi (mahasiswa, mata kuliah) — hasil agregasi dari grain fact yang lebih halus (mahasiswa, mata kuliah, pertemuan). |
| 5 | Tabel sumber | `fact_presensi` JOIN `dim_mahasiswa`, JOIN `dim_matakuliah` |
| 6 | Owner (jabatan bernama) | Kepala Program Studi Sains Data |
| 7 | Time basis | Kumulatif sejak awal semester berjalan sampai tanggal query dijalankan (bukan snapshot harian tetap) |
| 8 | Satuan | Rasio 0.0–1.0 (ditampilkan sebagai persen di laporan) |
| 9 | Dimensi yang boleh dipotong | mahasiswa, mata kuliah, angkatan, prodi, kota_asal, rentang tanggal (via `dim_date`) |
| 10 | Filter default | `dim_mahasiswa.is_current = TRUE` (hanya versi status terbaru per SCD2), `mahasiswa_sk <> -1` (buang anggota Unknown) |
| 11 | Arti nilai kosong | Tidak ada data — mahasiswa yang belum punya satu pun baris presensi untuk mata kuliah itu TIDAK muncul di hasil sama sekali (bukan ditampilkan sebagai 0%). Nilai 0% hanya valid untuk mahasiswa yang punya baris presensi tapi seluruhnya izin/sakit/alpa. |
| 12 | Versi | v1, berlaku sejak desain ini disahkan (checkpoint Sesi 8, 2026-09-30) |

### Cara metrik ini di-gaming

Karena penyebutnya (`COUNT(*)`) hanya menghitung baris presensi yang **ada**, cara paling mudah
membuat rasio ini terlihat bagus tanpa kehadiran sungguhan membaik adalah dengan **berhenti
mencatat presensi** untuk pertemuan yang biasanya banyak bolongnya (dibanding tetap mencatatnya
sebagai `alpa`). Mahasiswa yang datanya "hilang" untuk suatu pertemuan tidak menurunkan rasio
sama sekali, sementara mahasiswa yang datang dan tercatat `alpa` menurunkan rasio — jadi
mengurangi pencatatan pada kelas yang kehadirannya buruk justru menaikkan angka metrik.

### Guard test-nya

Bandingkan jumlah pertemuan yang tercatat untuk tiap (mahasiswa, mata kuliah) terhadap jumlah
total sesi unik yang tercatat untuk mata kuliah itu di seluruh mahasiswa lain. Mahasiswa dengan
jumlah pertemuan tercatat jauh di bawah median mata kuliahnya kemungkinan besar "presensinya
hilang", bukan "kehadirannya bagus" — lihat `sql/50_metrics/rasio_kehadiran.sql` bagian
`guard_test` (severity: warning, karena ini indikasi butuh investigasi, bukan pasti data salah).

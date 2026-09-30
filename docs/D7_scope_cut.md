# D7 — Batas lingkup capstone (ditandatangani di Sesi 8)

> Diisi tim **sebelum** menghadap dosen. Dosen hanya mencoret dan tanda tangan.
> Form ini yang jadi acuan rubrik di Sesi 15–16: yang kamu potong tidak dihitung sebagai kekurangan.

Tim: K4  Topik / slice: T1 Kampus — Presensi & Kelulusan / k4 (Angkatan 2024)  Tanggal: 2026-09-30

## AKAN DIBANGUN (maksimal 1 fact table + 1 conformed dimension per RPS butir 8)

| # | Artefak | Ukuran selesai | Deadline |
|---|---|---|---|
| 1 | fact: `fact_presensi` (grain: satu mahasiswa pada satu pertemuan satu mata kuliah, angkatan 2024) | `sql/load.sql` jalan idempoten (`--twice` row count sama), 0 baris duplikat pada grain (nim, kode_mk, tanggal) | Sesi 4 (build) |
| 2 | conformed dim: `dim_date` (diberikan, dipakai `fact_presensi`; siap dipakai fact topik lain kalau ada) | Rentang 2024-01-01 s.d. 2027-12-31 ter-generate, anggota Unknown (-1) ada | Sudah selesai (diberikan dosen) |
| 3 | metrik di kamus: 1 dari 3 (Rasio Kehadiran Mahasiswa) | `docs/kamus_metrik.md` 12/12 field terisi + `sql/50_metrics/rasio_kehadiran.sql` bisa dieksekusi | Sesi 8 (desain, UTS ini) |
| 4 | dashboard: 0 tile | Tidak dibangun pada fase UTS ini (desain saja); dashboard baru masuk cakupan UAS | Di luar cakupan UTS |

## TIDAK LAGI DIBANGUN (sebut namanya, jangan "kalau ada waktu")

| # | Yang dicabut | Alasan |
|---|---|---|
| 1 | `fact_nilai` (fact kedua untuk nilai akhir mata kuliah, dari `nilai.csv`) | Tugas membatasi desain ke SATU fact table. `nilai.csv` punya grain berbeda (per nim+kode_mk, bukan per pertemuan) dan 158 baris duplikat grain yang butuh aturan resolusi bisnis (nilai terakhir vs terbaik) yang belum diputuskan pemilik data — lihat `docs/BATAS_DESAIN.md`. |
| 2 | Dimensi ke-4 `dim_prodi`/`dim_wilayah` (kota_asal mahasiswa sebagai dimensi tersendiri) | `kota_asal` (8 varian) dan `prodi` (1 varian saja di seed: "Sains Data") tetap disimpan sebagai atribut di `dim_mahasiswa`, tidak dipisah jadi dimensi konformed sendiri, karena kardinalitasnya rendah dan tidak dipakai ulang oleh fact lain di luar cakupan satu-fact-table ini. |
| 3 | Dashboard (tile/visualisasi) | Secara eksplisit di luar cakupan UTS ini (desain saja, tidak ada yang dijalankan/dibangun) — akan masuk cakupan UAS setelah `sql/load.sql` dan `tests/` terbukti jalan. |

## Tanda tangan

| Tim | Dosen |
|---|---|
| (diisi/ditandatangani manual oleh anggota tim K4 saat menghadap dosen) | (dicoret dan ditandatangani dosen saat verifikasi checkpoint Sesi 8) |
| [tanda tangan] | [tanda tangan] |

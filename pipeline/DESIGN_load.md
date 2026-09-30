# DESIGN_load — strategi load (UTS item 2)

Topik **T1 Kampus — Presensi & Kelulusan**, slice **k4 (Angkatan 2024)**.

## Alur: sumber → staging → dim → fact

Tidak ada lapisan staging fisik terpisah (tidak ada `stg_*` table): DuckDB membaca CSV langsung
lewat `read_csv_auto(..., all_varchar=true)` sebagai "staging virtual" di dalam CTE tiap DDL
(`sumber` di `30_fact_presensi.sql`). Ini disengaja untuk skala data seed (117.936 baris presensi
muat di memori); kalau volume tumbuh, `sumber` itu adalah titik yang paling gampang dipisah jadi
tabel `stg_presensi` fisik tanpa mengubah logika dim/fact di bawahnya.

| # | Tabel | Sumber | Strategi | Kolom partisi/window | Kapan menggandakan baris kalau dijalankan ulang |
|---|---|---|---|---|---|
| 1 | `dim_date` | generator (diberikan) | **Full reload** (`CREATE OR REPLACE`) | — | Tidak bisa. Dibangun dari `generate_series` atas rentang tanggal tetap, bukan dari data sumber — hasilnya selalu identik di setiap run. |
| 2 | `dim_mahasiswa` | `mahasiswa.csv`, filter `{SLICE_mahasiswa}` (`angkatan='2024'`) | **SCD Type 2 — insert versi baru** | filter slice = `angkatan` (bukan kolom partisi tanggal, karena mahasiswa.csv bukan data historis) | Bisa, kalau loader "menutup versi lama + insert versi baru" dijalankan TANPA membandingkan dulu apakah atributnya benar-benar berubah. Run kedua pada data yang SAMA akan tetap insert baris versi baru (mahasiswa_sk baru, valid_from = tanggal load), sehingga satu nim punya ≥2 baris `is_current=TRUE` sekaligus — kunci mahasiswa jadi tidak unik untuk query "siapa mahasiswa aktif hari ini". Skrip di `sql/load.sql` saat ini memakai `CREATE OR REPLACE` penuh (aman untuk seed satu-snapshot ini), TAPI itu bukan implementasi Type-2 sungguhan untuk load incremental berikutnya — lihat "Catatan implementasi" di bawah. |
| 3 | `dim_matakuliah` | `matakuliah.csv` (tanpa filter slice, kurikulum berlaku semua angkatan) | **Full reload** (`CREATE OR REPLACE`) | — | Tidak bisa selama tetap `CREATE OR REPLACE`: setiap run menimpa seluruh isi tabel, jadi hasilnya idempoten secara konstruksi. Baru bisa menggandakan kalau tim mengganti jadi `INSERT INTO` polos tanpa `CREATE OR REPLACE` di depannya (lihat alternatif ditolak). |
| 4 | `dim_status_kehadiran` | kamus tetap (hardcoded `VALUES`, bukan dari CSV) | **Full reload** (`CREATE OR REPLACE`) | — | Tidak bisa, alasan sama seperti `dim_date`: isi tabel adalah konstanta yang ditulis ulang total tiap run. |
| 5 | `fact_presensi` | `presensi.csv`, JOIN ke `dim_mahasiswa` (INNER, otomatis membatasi ke slice k4) | **Incremental upsert berbasis natural key** (`nim, kode_mk, tanggal`), dieksekusi sebagai window per `tanggal` | `tanggal` (kolom yang dipetakan ke `date_sk`) | Bisa, kalau job harian di-rerun untuk window tanggal yang SAMA memakai `INSERT INTO` polos tanpa lebih dulu **menghapus baris existing pada window tanggal itu** (`DELETE FROM fact_presensi WHERE tanggal BETWEEN :awal AND :akhir`) atau tanpa anti-join ke natural key (`WHERE NOT EXISTS (SELECT 1 FROM fact_presensi f WHERE f.nim=... AND f.kode_mk=... AND f.tanggal=...)`). Tanpa salah satu guard itu, setiap re-run window yang sama menduplikasi seluruh baris presensi pada window tersebut — persis mekanisme `--strategy insert_only` yang didemonstrasikan `pipeline/load.py` sebagai "contoh yang sengaja jebol". |

### Catatan implementasi (kejujuran soal seed data vs desain incremental)

`sql/load.sql` yang dikumpulkan untuk UTS ini menulis **semua** tabel — termasuk `dim_mahasiswa`
dan `fact_presensi` — sebagai `CREATE OR REPLACE TABLE ... AS SELECT` (full rebuild), karena
`pipeline/load.py` bawaan dosen hanya menyediakan dua mode (`full` dan `insert_only` demo-jebol),
bukan mode upsert/MERGE. Ini AMAN dan idempoten untuk seed data yang memang cuma satu snapshot.
Kolom "Strategi" di tabel atas (SCD2 insert-versi-baru untuk `dim_mahasiswa`, incremental upsert
untuk `fact_presensi`) adalah **strategi yang dituju untuk operasi harian/semesteran** setelah
tim mengimplementasikan MERGE/upsert kustom di luar `pipeline/load.py` bawaan — bukan literal apa
yang `sql/load.sql` jalankan hari ini. Baris "kapan menggandakan baris" di atas menjelaskan
kegagalan strategi TUJUAN tersebut, bukan strategi `full` yang sedang dipakai (yang memang tidak
bisa menggandakan, sesuai definisinya).

## Tiga pertanyaan wajib

1. **Natural key** yang dipakai untuk upsert/incremental:
   - `dim_mahasiswa`: `nim`
   - `fact_presensi`: kombinasi `(nim, kode_mk, tanggal)` — sama persis dengan grain fact dan
     dengan kunci yang diuji test `presensi_duplikat_grain`.
2. **Kolom partisi/window** kalau incremental: `tanggal` pada `fact_presensi` (window harian —
   presensi direkam per hari perkuliahan). `dim_mahasiswa` tidak dipartisi tanggal karena
   perubahannya berbasis kejadian (status berubah), bukan berbasis waktu kalender.
3. **Kapan strategi ini menggandakan baris kalau dijalankan dua kali** — lihat kolom terakhir
   tabel di atas untuk tiap tabel; ringkas: hanya `dim_mahasiswa` (Type-2 tanpa guard
   "berubah/tidak") dan `fact_presensi` (incremental tanpa DELETE-partisi/anti-join) yang punya
   risiko nyata. Ketiga tabel `full reload` lainnya tidak bisa menggandakan baris selama tetap
   `CREATE OR REPLACE`.

## Urutan dependency

1. `dim_date` — tidak bergantung tabel lain (generator murni).
2. `dim_mahasiswa`, `dim_matakuliah`, `dim_status_kehadiran` — tidak saling bergantung, bisa
   dibangun paralel/urutan bebas; masing-masing hanya bergantung pada CSV sumbernya sendiri.
3. `fact_presensi` — **harus terakhir**, karena isinya adalah hasil JOIN ke ketiga dimensi di
   atas plus `dim_date`. Kalau dijalankan sebelum salah satu dimensi ada, JOIN akan gagal
   (tabel belum ada) atau — kalau tabel dim kosong — semua `matakuliah_sk`/`status_sk`/`date_sk`
   jatuh ke fallback `-1` (Unknown) lewat `coalesce`, yang secara diam-diam menyembunyikan
   masalah urutan eksekusi alih-alih menggagalkannya. Urutan di `sql/load.sql` sudah mengikuti
   ini: `dim_date` → `dim_mahasiswa` → `dim_matakuliah` → `dim_status_kehadiran` → `fact_presensi`.

## Alternatif yang dipertimbangkan tapi ditolak (strategi load, level keseluruhan)

- **Full reload untuk `fact_presensi` juga** (seperti tiga dimensi lain) — paling sederhana dan
  nol risiko duplikasi. Ditolak sebagai strategi TUJUAN karena presensi adalah data operasional
  yang tumbuh harian di dunia nyata (bukan snapshot seperti kurikulum); rebuild penuh 117rb+
  baris setiap hari tidak akan skalabel untuk satu semester penuh, dan tidak mendemonstrasikan
  cara desain menangani load incremental yang justru jadi salah satu poin penilaian UTS ini.
  Full reload tetap dipakai sebagai fallback aman untuk seed data saat ini (lihat "Catatan
  implementasi").
- **DELETE partisi + INSERT (bukan anti-join by natural key)** untuk `fact_presensi` — juga
  valid dan lebih murah dari MERGE penuh. Dipertimbangkan setara dengan incremental upsert;
  yang dipilih untuk didokumentasikan adalah upsert by natural key karena natural key fact ini
  (`nim, kode_mk, tanggal`) sudah identik dengan grain dan dengan kunci uji kualitas data yang
  sudah ada, jadi lebih mudah dijaga konsisten satu sama lain.

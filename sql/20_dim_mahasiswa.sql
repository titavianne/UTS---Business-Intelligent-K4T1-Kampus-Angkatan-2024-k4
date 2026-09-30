-- ============================================================
-- dim_mahasiswa — dimensi entitas utama (D2 / UTS item 1.2-1.3)
-- Topik T1 Kampus, slice k4 (Angkatan 2024)
--
-- SCD Type 2 (valid_from / valid_to / is_current).
-- ALASAN: kolom `status` (aktif/cuti/lulus/do) mengubah makna setiap baris presensi yang
-- menunjuk ke mahasiswa itu. Kalau seorang mahasiswa berstatus 'cuti' tapi warehouse hanya
-- menyimpan status TERBARU (Type 1/overwrite), maka baris presensi historis di masa dia masih
-- 'aktif' akan ikut terbaca sebagai "presensi mahasiswa cuti" — analitik retensi/DO jadi salah.
-- Type 2 menjaga status apa adanya pada titik waktu presensi terjadi.
--
-- ALTERNATIF YANG DIPERTIMBANGKAN TAPI DITOLAK:
--   Type 1 (overwrite) — lebih sederhana, tapi menghapus jejak "kapan mahasiswa berubah status",
--   padahal status itu justru dimensi paling sering ditanyakan dosbing/BAAK ("siapa yang cuti
--   semester ini"). Ditolak karena kehilangan informasi yang jadi tujuan utama tabel ini.
--
-- Catatan jujur soal seed data: mahasiswa.csv adalah SATU snapshot flat (bukan CDC/log
-- perubahan). Load pertama karena itu hanya punya SATU versi per nim (valid_from=tanggal_masuk,
-- valid_to=9999-12-31, is_current=TRUE). Struktur Type 2 sudah dibangun sejak load pertama
-- supaya load BERIKUTNYA (saat status berubah) tinggal menutup versi lama, bukan mendesain ulang
-- tabel. Ini didokumentasikan di pipeline/DESIGN_load.md.
-- ============================================================

CREATE OR REPLACE TABLE dim_mahasiswa AS
SELECT row_number() OVER (ORDER BY nim)      AS mahasiswa_sk,   -- surrogate key
       nim                                    AS nim_nk,         -- natural key (kunci bisnis)
       nama,
       CAST(angkatan AS INTEGER)              AS angkatan,
       prodi,
       -- Normalisasi 8 varian kapitalisasi status (AKTIF/aktif/Aktif, cuti/Cuti, do, Lulus/lulus)
       -- jadi 4 anggota kanonik. Lihat tests/test_definitions.yml (data quality di lapisan sumber).
       CASE upper(trim(status))
            WHEN 'AKTIF' THEN 'AKTIF'
            WHEN 'CUTI'  THEN 'CUTI'
            WHEN 'LULUS' THEN 'LULUS'
            WHEN 'DO'    THEN 'DO'
            ELSE 'TIDAK_DIKETAHUI'
       END                                    AS status,
       kota_asal,
       CAST(tanggal_masuk AS DATE)            AS tanggal_masuk,
       CAST(tanggal_masuk AS DATE)            AS valid_from,     -- Type 2: versi berlaku sejak masuk
       DATE '9999-12-31'                      AS valid_to,
       TRUE                                   AS is_current
FROM read_csv_auto('{D}/mahasiswa.csv', all_varchar=true)
WHERE {SLICE_mahasiswa}                                          -- slice k4: angkatan = '2024'
  AND angkatan IS NOT NULL AND angkatan <> ''                    -- lihat test mahasiswa_angkatan_kosong
UNION ALL
SELECT -1, 'UNKNOWN', 'Tidak diketahui', NULL, 'Tidak diketahui', 'TIDAK_DIKETAHUI',
       'Tidak diketahui', DATE '1900-01-01', DATE '1900-01-01', DATE '9999-12-31', TRUE;

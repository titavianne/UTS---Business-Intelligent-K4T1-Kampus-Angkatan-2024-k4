-- ============================================================
-- dim_matakuliah — dimensi kedua (kategori) (D2 / UTS item 1)
--
-- SCD Type 1 (overwrite in place, TANPA valid_from/valid_to/is_current).
-- ALASAN: matakuliah.csv adalah master data kurikulum (kode_mk, nama_mk, sks, semester, dosen).
-- Seed data hanya satu snapshot flat, tidak ada sinyal temporal (tidak ada kolom tanggal
-- perubahan dosen/sks). `dosen` pengampu SECARA BISNIS bisa berganti tiap semester, tapi
-- sumber data ini tidak merekam kapan pergantian terjadi — menyimpan histori palsu (Type 2)
-- untuk data yang tidak benar-benar punya jejak waktu lebih menyesatkan daripada berguna.
-- Overwrite penuh saat load berikutnya (dosen baru menimpa dosen lama) adalah representasi
-- paling jujur dari apa yang benar-benar diketahui sistem ini.
--
-- ALTERNATIF YANG DIPERTIMBANGKAN TAPI DITOLAK:
--   Type 2 untuk melacak histori dosen pengampu — ditolak karena sumber tidak punya kolom
--   "berlaku sejak"; Type 2 tanpa sinyal perubahan asli hanya akan mengarang valid_from/valid_to
--   yang tidak bisa diverifikasi ke data mentah.
-- ============================================================

CREATE OR REPLACE TABLE dim_matakuliah AS
SELECT row_number() OVER (ORDER BY kode_mk) AS matakuliah_sk,   -- surrogate key
       kode_mk                               AS kode_mk_nk,      -- natural key
       nama_mk,
       CAST(sks AS INTEGER)                  AS sks,
       CAST(semester AS INTEGER)             AS semester_kurikulum,
       dosen                                 AS dosen_pengampu
FROM read_csv_auto('{D}/matakuliah.csv', all_varchar=true)
UNION ALL
SELECT -1, 'UNKNOWN', 'Tidak diketahui', NULL, NULL, 'Tidak diketahui';

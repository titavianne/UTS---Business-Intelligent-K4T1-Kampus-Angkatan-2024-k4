-- ============================================================
-- dim_status_kehadiran — dimensi ketiga (referensi/kamus) (D2 / UTS item 1)
--
-- SCD Type 0 (fixed reference, tidak pernah berubah).
-- ALASAN: ini kamus internal warehouse, bukan hasil ekstraksi kolom sumber apa adanya.
-- Kolom `status` di presensi.csv punya 10 varian mentah (izin, IZIN, hadir, HADIR, H, sakit,
-- SAKIT, alpa, ALPA, dan '-' sebagai penanda kosong/tidak terbaca) untuk hanya 4 makna bisnis
-- yang sebenarnya berbeda. Dimensi ini adalah kamus kanonik 5 anggota (4 status sah + 1 Tidak
-- Diketahui) yang dipetakan dari status mentah saat membangun fact (lihat 30_fact_presensi.sql).
-- Kamus ini sendiri tidak berasal dari data yang berubah-ubah, jadi Type 0 cukup.
--
-- ALTERNATIF YANG DIPERTIMBANGKAN TAPI DITOLAK:
--   Menyimpan 10 varian mentah apa adanya sebagai 10 anggota dimensi — ditolak karena itu
--   memecah metrik yang seharusnya sama ('hadir' dan 'HADIR' akan dihitung sebagai dua kategori
--   berbeda di setiap GROUP BY/dashboard), persis masalah "kode 0/1 sama-sama Cerah" yang jadi
--   contoh dosen di starter.
-- ============================================================

CREATE OR REPLACE TABLE dim_status_kehadiran AS
SELECT * FROM (VALUES
    (1,  'HADIR',           'Hadir',                                  TRUE),
    (2,  'IZIN',            'Izin (dengan keterangan)',                FALSE),
    (3,  'SAKIT',           'Sakit (dengan keterangan)',               FALSE),
    (4,  'ALPA',            'Alpa (tanpa keterangan)',                 FALSE),
    (-1, 'TIDAK_DIKETAHUI', 'Status tidak terbaca dari sumber (mis. "-")', FALSE)
) AS t(status_sk, kode_status, deskripsi, dihitung_hadir);

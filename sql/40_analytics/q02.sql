-- ============================================================
-- q02 — Tren kehadiran kumulatif per mata kuliah sepanjang semester (UTS item 4)
-- Wajib: pakai window function (SUM() OVER ... ORDER BY, running total).
-- Kolom keluaran: kode_mk | nama_mk | tanggal | pertemuan_ke | hadir_hari_ini |
--                 kumulatif_hadir | kumulatif_pertemuan | rasio_hadir_berjalan
-- ============================================================

-- Jawaban yang diharapkan (satu kalimat):
--   Kueri ini menunjukkan, untuk tiap mata kuliah, bagaimana rasio kehadiran berjalan
--   (running attendance rate) berubah dari pertemuan ke pertemuan sepanjang semester —
--   dipakai untuk melihat mata kuliah mana yang kehadirannya menurun tajam menjelang akhir
--   semester, bukan cuma rata-rata datar satu angka.

WITH per_hari AS (
    SELECT f.matakuliah_sk,
           d.full_date                         AS tanggal,
           sum(f.is_hadir)                     AS hadir_hari_ini,
           count(*)                            AS pertemuan_hari_ini
    FROM fact_presensi f
    JOIN dim_date d ON d.date_sk = f.date_sk
    WHERE d.date_sk <> -1                       -- buang baris tanpa tanggal valid
    GROUP BY 1, 2
)
SELECT mk.kode_mk_nk AS kode_mk,
       mk.nama_mk,
       ph.tanggal,
       ph.hadir_hari_ini,
       ph.pertemuan_hari_ini,
       sum(ph.hadir_hari_ini) OVER (
           PARTITION BY ph.matakuliah_sk ORDER BY ph.tanggal
       )                                                        AS kumulatif_hadir,
       sum(ph.pertemuan_hari_ini) OVER (
           PARTITION BY ph.matakuliah_sk ORDER BY ph.tanggal
       )                                                        AS kumulatif_pertemuan,
       round(
           sum(ph.hadir_hari_ini) OVER (PARTITION BY ph.matakuliah_sk ORDER BY ph.tanggal)::DOUBLE
           / sum(ph.pertemuan_hari_ini) OVER (PARTITION BY ph.matakuliah_sk ORDER BY ph.tanggal),
       3)                                                        AS rasio_hadir_berjalan
FROM per_hari ph
JOIN dim_matakuliah mk ON mk.matakuliah_sk = ph.matakuliah_sk
ORDER BY mk.kode_mk_nk, ph.tanggal;

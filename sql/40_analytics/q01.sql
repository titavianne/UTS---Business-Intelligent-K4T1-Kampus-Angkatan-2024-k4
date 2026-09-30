-- ============================================================
-- q01 — Sepuluh mahasiswa dengan rasio ALPA tertinggi per mata kuliah (UTS item 4)
-- Wajib: pakai window function (RANK()) di atas CTE agregasi.
-- Kolom keluaran: nim | nama | kode_mk | nama_mk | total_pertemuan | total_alpa |
--                 rasio_alpa | peringkat
-- ============================================================

-- Jawaban yang diharapkan (satu kalimat):
--   Kueri ini menunjukkan 10 pasangan mahasiswa-mata kuliah dengan proporsi ketidakhadiran
--   tanpa keterangan (alpa) tertinggi di angkatan 2024, sehingga bisa diprioritaskan untuk
--   intervensi akademik dini (early-warning) sebelum berujung ke status 'do'.

WITH agregasi AS (
    SELECT f.mahasiswa_sk,
           f.matakuliah_sk,
           count(*)          AS total_pertemuan,
           sum(f.is_alpa)     AS total_alpa,
           round(sum(f.is_alpa)::DOUBLE / count(*), 3) AS rasio_alpa
    FROM fact_presensi f
    GROUP BY 1, 2
    HAVING count(*) >= 5          -- buang pasangan dengan riwayat pertemuan terlalu sedikit
),
peringkat AS (
    SELECT a.*,
           rank() OVER (ORDER BY a.rasio_alpa DESC, a.total_alpa DESC) AS peringkat
    FROM agregasi a
)
SELECT m.nim_nk        AS nim,
       m.nama,
       mk.kode_mk_nk   AS kode_mk,
       mk.nama_mk,
       p.total_pertemuan,
       p.total_alpa,
       p.rasio_alpa,
       p.peringkat
FROM peringkat p
JOIN dim_mahasiswa  m  ON m.mahasiswa_sk = p.mahasiswa_sk
JOIN dim_matakuliah mk ON mk.matakuliah_sk = p.matakuliah_sk
WHERE p.peringkat <= 10
ORDER BY p.peringkat;

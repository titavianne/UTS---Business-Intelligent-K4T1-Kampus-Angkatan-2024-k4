-- ============================================================
-- Metrik: Rasio Kehadiran Mahasiswa (docs/kamus_metrik.md, Metrik 1)
-- ============================================================

-- definisi: rasio kehadiran per (mahasiswa, mata kuliah)
SELECT m.nim_nk        AS nim,
       m.nama,
       mk.kode_mk_nk   AS kode_mk,
       mk.nama_mk,
       count(*)                                     AS total_pertemuan,
       sum(f.is_hadir)                                AS total_hadir,
       round(sum(f.is_hadir)::DOUBLE / count(*), 3)   AS rasio_kehadiran
FROM fact_presensi f
JOIN dim_mahasiswa  m  ON m.mahasiswa_sk = f.mahasiswa_sk AND m.is_current = TRUE
JOIN dim_matakuliah mk ON mk.matakuliah_sk = f.matakuliah_sk
WHERE m.mahasiswa_sk <> -1
GROUP BY 1, 2, 3, 4;

-- guard_test: tangkap gaming lewat "presensi hilang" (bukan kehadiran bagus)
-- Mengembalikan pasangan (mahasiswa, mata kuliah) yang pertemuan tercatatnya < 50% dari
-- jumlah sesi unik yang tercatat untuk mata kuliah itu di seluruh mahasiswa lain.
WITH per_pasangan AS (
    SELECT mahasiswa_sk, matakuliah_sk, count(*) AS n_tercatat
    FROM fact_presensi
    GROUP BY 1, 2
),
per_mk AS (
    SELECT matakuliah_sk, count(DISTINCT date_sk) AS total_sesi_mk
    FROM fact_presensi
    GROUP BY 1
)
SELECT count(*) AS pasangan_dicurigai_presensi_hilang
FROM per_pasangan p
JOIN per_mk s USING (matakuliah_sk)
WHERE p.n_tercatat < 0.5 * s.total_sesi_mk;

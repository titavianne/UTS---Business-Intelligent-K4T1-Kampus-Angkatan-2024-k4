-- ============================================================
-- q03 — Rasio kehadiran per status mahasiswa, Angkatan 2024 (UTS item 4)
-- Wajib: filter yang eksplisit mencerminkan slice tim (Angkatan 2024), supaya jawaban tidak
-- bisa disalin tim lain yang pegang slice angkatan berbeda (k5/k7). Filter ini SENGAJA
-- dituliskan eksplisit meski fact_presensi sudah dibatasi ke slice k4 lewat INNER JOIN di
-- sql/30_fact_presensi.sql — supaya kueri ini tetap benar kalau suatu saat fact digabung lintas
-- angkatan (lihat docs/BATAS_DESAIN.md).
-- Kolom keluaran: status_mahasiswa | jumlah_mahasiswa | total_pertemuan | total_hadir |
--                 rasio_hadir
-- ============================================================

-- Jawaban yang diharapkan (satu kalimat):
--   Kueri ini membandingkan rasio kehadiran mahasiswa aktif vs cuti di angkatan 2024, untuk
--   mengecek apakah ada kebocoran data (mahasiswa berstatus 'cuti' yang masih tercatat hadir
--   di kelas, yang seharusnya nol atau mendekati nol).

SELECT m.status                                          AS status_mahasiswa,
       count(DISTINCT m.mahasiswa_sk)                     AS jumlah_mahasiswa,
       count(*)                                            AS total_pertemuan,
       sum(f.is_hadir)                                     AS total_hadir,
       round(sum(f.is_hadir)::DOUBLE / count(*), 3)        AS rasio_hadir
FROM fact_presensi f
JOIN dim_mahasiswa m ON m.mahasiswa_sk = f.mahasiswa_sk
WHERE m.angkatan = 2024                 -- filter eksplisit slice k4 (Angkatan 2024)
  AND m.mahasiswa_sk <> -1              -- buang anggota Unknown dari perbandingan status
GROUP BY 1
ORDER BY rasio_hadir DESC;

-- ============================================================
-- sql/load.sql — URUTAN EKSEKUSI MILIK TIM (TUGAS D3)
-- Dijalankan lewat: python -m pipeline.load --topic t1 --slice k4 --twice
-- (TIDAK dijalankan pada fase desain UTS ini — lihat catatan DILARANG di README kelompok.
--  Berkas ini ditulis lengkap dan idempoten-secara-konstruksi supaya SIAP dieksekusi orang lain.)
--
-- Urutan: dim_date (diberikan) -> tiga dimensi tim -> fact (terakhir, karena JOIN ke semua dim).
-- Strategi lengkap per tabel + kapan bisa menggandakan baris: pipeline/DESIGN_load.md.
-- Rationale desain tiap DDL (grain, SCD, aditivitas): komentar di masing-masing berkas
-- sql/10_dim_date.sql, sql/20_dim_*.sql, sql/30_fact_presensi.sql — konten di bawah ini adalah
-- salinan definisinya, disatukan dalam urutan eksekusi yang benar untuk pipeline.load.
-- ============================================================

-- 1) dim_date — DIBERIKAN, full reload (generator tanggal, tidak bergantung pada data sumber)
CREATE OR REPLACE TABLE dim_date AS
SELECT CAST(strftime(d, '%Y%m%d') AS INTEGER) AS date_sk,
       d AS full_date,
       CAST(year(d)  AS INTEGER) AS tahun,
       CAST(quarter(d) AS INTEGER) AS triwulan,
       CAST(month(d) AS INTEGER) AS bulan,
       strftime(d, '%B') AS nama_bulan,
       CAST(week(d)  AS INTEGER) AS pekan_iso,
       CAST(day(d)   AS INTEGER) AS hari,
       CAST(dayofweek(d) AS INTEGER) AS hari_ke,
       strftime(d, '%A') AS nama_hari,
       CAST(dayofweek(d) IN (0, 6) AS BOOLEAN) AS akhir_pekan
FROM (SELECT unnest(generate_series(DATE '2024-01-01', DATE '2027-12-31', INTERVAL 1 DAY)) AS d);

INSERT INTO dim_date
SELECT -1, DATE '1900-01-01', 1900, 0, 0, 'TIDAK DIKETAHUI', 0, 0, -1, 'TIDAK DIKETAHUI', FALSE;

-- 2) dim_mahasiswa — TUGAS TIM, SCD Type 2, slice k4 via {SLICE_mahasiswa}
CREATE OR REPLACE TABLE dim_mahasiswa AS
SELECT row_number() OVER (ORDER BY nim)      AS mahasiswa_sk,
       nim                                    AS nim_nk,
       nama,
       CAST(angkatan AS INTEGER)              AS angkatan,
       prodi,
       CASE upper(trim(status))
            WHEN 'AKTIF' THEN 'AKTIF'
            WHEN 'CUTI'  THEN 'CUTI'
            WHEN 'LULUS' THEN 'LULUS'
            WHEN 'DO'    THEN 'DO'
            ELSE 'TIDAK_DIKETAHUI'
       END                                    AS status,
       kota_asal,
       CAST(tanggal_masuk AS DATE)            AS tanggal_masuk,
       CAST(tanggal_masuk AS DATE)            AS valid_from,
       DATE '9999-12-31'                      AS valid_to,
       TRUE                                   AS is_current
FROM read_csv_auto('{D}/mahasiswa.csv', all_varchar=true)
WHERE {SLICE_mahasiswa}
  AND angkatan IS NOT NULL AND angkatan <> ''
UNION ALL
SELECT -1, 'UNKNOWN', 'Tidak diketahui', NULL, 'Tidak diketahui', 'TIDAK_DIKETAHUI',
       'Tidak diketahui', DATE '1900-01-01', DATE '1900-01-01', DATE '9999-12-31', TRUE;

-- 3) dim_matakuliah — TUGAS TIM, SCD Type 1 (overwrite)
CREATE OR REPLACE TABLE dim_matakuliah AS
SELECT row_number() OVER (ORDER BY kode_mk) AS matakuliah_sk,
       kode_mk                               AS kode_mk_nk,
       nama_mk,
       CAST(sks AS INTEGER)                  AS sks,
       CAST(semester AS INTEGER)             AS semester_kurikulum,
       dosen                                 AS dosen_pengampu
FROM read_csv_auto('{D}/matakuliah.csv', all_varchar=true)
UNION ALL
SELECT -1, 'UNKNOWN', 'Tidak diketahui', NULL, NULL, 'Tidak diketahui';

-- 4) dim_status_kehadiran — TUGAS TIM, SCD Type 0 (kamus tetap)
CREATE OR REPLACE TABLE dim_status_kehadiran AS
SELECT * FROM (VALUES
    (1,  'HADIR',           'Hadir',                                  TRUE),
    (2,  'IZIN',            'Izin (dengan keterangan)',                FALSE),
    (3,  'SAKIT',           'Sakit (dengan keterangan)',               FALSE),
    (4,  'ALPA',            'Alpa (tanpa keterangan)',                 FALSE),
    (-1, 'TIDAK_DIKETAHUI', 'Status tidak terbaca dari sumber (mis. "-")', FALSE)
) AS t(status_sk, kode_status, deskripsi, dihitung_hadir);

-- 5) fact_presensi — TUGAS TIM, terakhir karena JOIN ke ketiga dim + dim_date
CREATE OR REPLACE TABLE fact_presensi AS
WITH sumber AS (
    SELECT p.nim,
           p.kode_mk,
           p.pertemuan_ke,
           p.status                                              AS status_raw,
           p.jam_masuk,
           CASE WHEN p.tanggal LIKE '__/__/____'
                    THEN CAST(strptime(p.tanggal, '%d/%m/%Y') AS DATE)
                ELSE TRY_CAST(p.tanggal AS DATE)
           END                                                    AS tanggal
    FROM read_csv_auto('{D}/presensi.csv', all_varchar=true) p
),
dedup AS (
    SELECT *,
           row_number() OVER (
               PARTITION BY nim, kode_mk, tanggal
               ORDER BY (status_raw = '-') ASC, pertemuan_ke ASC
           ) AS rn
    FROM sumber
    WHERE tanggal IS NOT NULL
),
berlabel AS (
    SELECT d.*,
           CASE
               WHEN upper(trim(status_raw)) IN ('HADIR', 'H') THEN 'HADIR'
               WHEN upper(trim(status_raw)) = 'IZIN'          THEN 'IZIN'
               WHEN upper(trim(status_raw)) = 'SAKIT'         THEN 'SAKIT'
               WHEN upper(trim(status_raw)) = 'ALPA'          THEN 'ALPA'
               ELSE 'TIDAK_DIKETAHUI'
           END AS kode_status
    FROM dedup d
    WHERE d.rn = 1
)
SELECT
    row_number() OVER (ORDER BY b.nim, b.kode_mk, b.tanggal)     AS presensi_sk,
    m.mahasiswa_sk,
    coalesce(mk.matakuliah_sk, -1)                                AS matakuliah_sk,
    coalesce(s.status_sk, -1)                                     AS status_sk,
    coalesce(dd.date_sk, -1)                                      AS date_sk,
    CAST(b.pertemuan_ke AS INTEGER)                               AS pertemuan_ke,
    b.jam_masuk                                                   AS jam_masuk_raw,
    CASE WHEN b.kode_status = 'HADIR' THEN 1 ELSE 0 END           AS is_hadir,
    CASE WHEN b.kode_status = 'IZIN'  THEN 1 ELSE 0 END           AS is_izin,
    CASE WHEN b.kode_status = 'SAKIT' THEN 1 ELSE 0 END           AS is_sakit,
    CASE WHEN b.kode_status = 'ALPA'  THEN 1 ELSE 0 END           AS is_alpa,
    CASE WHEN b.jam_masuk IS NOT NULL AND b.jam_masuk <> ''
         THEN CAST(split_part(b.jam_masuk, ':', 1) AS INTEGER) * 60
            + CAST(split_part(b.jam_masuk, ':', 2) AS INTEGER)
         ELSE NULL
    END                                                            AS menit_check_in
FROM berlabel b
JOIN      dim_mahasiswa        m  ON m.nim_nk = b.nim
LEFT JOIN dim_matakuliah       mk ON mk.kode_mk_nk = b.kode_mk
LEFT JOIN dim_status_kehadiran s  ON s.kode_status = b.kode_status
LEFT JOIN dim_date             dd ON dd.full_date = b.tanggal;

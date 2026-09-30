-- ============================================================
-- fact_presensi — fact table (satu-satunya fact) (D2 / UTS item 1.1, 1.2, 1.4)
--
-- GRAIN: Satu baris = satu mahasiswa (angkatan 2024 / slice k4) pada satu pertemuan
--        (sesi kelas, diidentifikasi oleh tanggal) satu mata kuliah.
--        Kunci grain sumber: (nim, kode_mk, tanggal) — persis grain yang diuji oleh test
--        `presensi_duplikat_grain` di tests/test_definitions.yml.
--
-- ALTERNATIF GRAIN YANG DIPERTIMBANGKAN TAPI DITOLAK:
--   "Satu baris = satu nilai akhir mahasiswa per mata kuliah" (grain dari nilai.csv) — ditolak
--   karena tugas ini membatasi desain pada SATU fact table, dan grain presensi (117.936 baris
--   sumber, event operasional harian) memberi pertanyaan analitik yang jauh lebih kaya (tren
--   kehadiran per waktu, window function) dibanding grain nilai (8.265 baris, snapshot akhir
--   semester, dan sendiri sudah punya 158 baris duplikat pada grain nim+kode_mk yang berarti
--   ada percobaan ulang/her yang tidak dimodelkan sebagai versi). nilai.csv karena itu SENGAJA
--   tidak dimasukkan ke fact ini — lihat docs/BATAS_DESAIN.md dan docs/D7_scope_cut.md.
--
-- PENANGANAN KUALITAS DATA (dijelaskan lagi di pipeline/DESIGN_load.md):
--   1. Duplikat grain (4.344 baris di seluruh sumber) -> dedup deterministik: satu baris per
--      (nim, kode_mk, tanggal), pilih baris dengan status bukan '-' bila ada pilihan (ROW_NUMBER).
--   2. Format tanggal dd/mm/yyyy (5.812 baris di seluruh sumber) -> diparse eksplisit dengan
--      strptime, BUKAN dibuang, supaya baris presensi yang sah tidak hilang dari fact.
--   3. 10 varian status mentah -> dipetakan ke dim_status_kehadiran (4 kanonik + 1 Tidak
--      Diketahui untuk '-').
--
-- MEASURE & LABEL ADITIVITAS:
--   is_hadir, is_izin, is_sakit, is_alpa : ADDITIVE
--     -> Tiap baris = satu kejadian pertemuan, nilainya 0/1 dan mutually exclusive. Boleh
--        di-SUM lintas dimensi APA PUN (per mahasiswa, per MK, per tanggal, per angkatan)
--        karena hasilnya selalu berarti "jumlah kejadian" — tidak ada risiko dobel-hitung.
--   menit_check_in : NON-ADDITIVE
--     -> Ini titik waktu (jam masuk dikonversi ke menit sejak 00:00), bukan kuantitas.
--        Menjumlahkan "menit check-in" lintas mahasiswa/pertemuan tidak punya arti bisnis;
--        yang valid hanya MIN/MAX/AVG (mis. rata-rata jam masuk per MK). Selain itu
--        30.303 dari 117.936 baris (≈26%) kosong (jam_masuk tidak diisi), jadi kolom ini juga
--        tidak boleh jadi satu-satunya ukuran kehadiran.
--   (Tidak ada measure semi-additive pada grain ini. Semi-additive biasanya muncul pada grain
--    snapshot/saldo — mis. SKS kumulatif per periode — yang di luar cakupan fact transaksional
--    ini; lihat docs/BATAS_DESAIN.md.)
-- ============================================================

WITH sumber AS (
    SELECT p.nim,
           p.kode_mk,
           p.pertemuan_ke,
           p.status                                              AS status_raw,
           p.jam_masuk,
           CASE WHEN p.tanggal LIKE '__/__/____'
                    THEN CAST(strptime(p.tanggal, '%d/%m/%Y') AS DATE)  -- format alternatif, diparse
                ELSE TRY_CAST(p.tanggal AS DATE)                        -- format ISO, cast langsung
           END                                                    AS tanggal
    FROM read_csv_auto('{D}/presensi.csv', all_varchar=true) p
),
dedup AS (
    -- satu baris per (nim, kode_mk, tanggal): lihat test presensi_duplikat_grain (4.344 baris)
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
               ELSE 'TIDAK_DIKETAHUI'                                    -- menangkap '-' dan varian lain
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
    CAST(b.pertemuan_ke AS INTEGER)                               AS pertemuan_ke,   -- degenerate dimension
    b.jam_masuk                                                   AS jam_masuk_raw,  -- atribut, bukan measure
    CASE WHEN b.kode_status = 'HADIR' THEN 1 ELSE 0 END           AS is_hadir,       -- ADDITIVE
    CASE WHEN b.kode_status = 'IZIN'  THEN 1 ELSE 0 END           AS is_izin,        -- ADDITIVE
    CASE WHEN b.kode_status = 'SAKIT' THEN 1 ELSE 0 END           AS is_sakit,       -- ADDITIVE
    CASE WHEN b.kode_status = 'ALPA'  THEN 1 ELSE 0 END           AS is_alpa,        -- ADDITIVE
    CASE WHEN b.jam_masuk IS NOT NULL AND b.jam_masuk <> ''
         THEN CAST(split_part(b.jam_masuk, ':', 1) AS INTEGER) * 60
            + CAST(split_part(b.jam_masuk, ':', 2) AS INTEGER)
         ELSE NULL
    END                                                            AS menit_check_in -- NON-ADDITIVE
FROM berlabel b
-- INNER JOIN sengaja (bukan LEFT): dim_mahasiswa sudah difilter ke slice k4 (angkatan 2024),
-- jadi join ini sekaligus jadi mekanisme pemotongan fact ke slice k4 tanpa WHERE terpisah.
JOIN      dim_mahasiswa        m  ON m.nim_nk = b.nim
LEFT JOIN dim_matakuliah       mk ON mk.kode_mk_nk = b.kode_mk
LEFT JOIN dim_status_kehadiran s  ON s.kode_status = b.kode_status
LEFT JOIN dim_date             dd ON dd.full_date = b.tanggal;

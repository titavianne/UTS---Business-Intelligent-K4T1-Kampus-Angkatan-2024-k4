# UTS — Business Intelligence Systems (SDA2161)

**Kelompok K4** — Topik **T1 Kampus: Presensi & Kelulusan** — Slice **k4 (Angkatan 2024)**

| # | Nama | NIM |
|---|---|---|
| 1 | Tita Noviana | 24120500011 |
| 2 | Muhamad Helmi Ramadhan | 24120500023 |
| 3 | Ariel Sharon Ferdinandus | 24130500007 |
| 4 | Husni | 24120500026 |

Tag `UTS` menandai commit yang dikumpulkan untuk penilaian desain (checkpoint Sesi 8).

> **Status: DESAIN, bukan implementasi.** Pipeline (`pipeline.load`) dan test runner
> (`tests/run_tests.py`) sengaja belum dijalankan. Yang sudah dijalankan hanya
> `pipeline.profile` (read-only) — angkanya jadi dasar semua keputusan desain di bawah.

## Setup 5 menit

```bash
pip install -r requirements.txt
# atau: python bootstrap.py   (install dependensi + smoke test DuckDB)

python -m pipeline.profile --topic t1 --slice k4      # D1 — profil data sebelum transformasi
python checkpoint.py verify --sesi 8 --topic t1        # DoD UTS (design checkpoint, read-only)
```

Semua perintah di atas **offline dan read-only** — data seed sudah ada di `data/raw/t1_kampus/`.
`checkpoint.py verify --sesi 8` hanya membaca file (tidak menjalankan pipeline atau menyentuh
data) dan harus menunjukkan **14/14 syarat terpenuhi**.

**Belum dijalankan pada fase ini** (di luar cakupan UTS):
```bash
python -m pipeline.load --topic t1 --slice k4 --twice   # D3 — baru masuk cakupan build (UAS)
python tests/run_tests.py --topic t1 --slice k4         # D4 — idem
```

## Dataset

| Topik | Folder | Slice |
|---|---|---|
| **T1** Kampus: Presensi & Kelulusan | `data/raw/t1_kampus/` | `--slice k4` (Angkatan 2024) |

Repo ini hanya menyertakan data seed untuk T1/k4 (bukan seluruh dataset kelas) — sesuai
cakupan tugas kelompok K4.

## Struktur

```
├── data/raw/t1_kampus/         seed (jangan diubah; baca saja) — mahasiswa, matakuliah,
│                                presensi, nilai
├── sql/
│   ├── 00_profiling.sql              diberikan — 6 query profil
│   ├── 10_dim_date.sql               diberikan — generator dimensi tanggal
│   ├── 20_dim_mahasiswa.sql          dim entitas utama — SCD Type 2
│   ├── 20_dim_matakuliah.sql         dim kategori — SCD Type 1
│   ├── 20_dim_status_kehadiran.sql   dim referensi/kamus — SCD Type 0
│   ├── 30_fact_presensi.sql          satu-satunya fact table (grain: per pertemuan)
│   ├── 40_analytics/q01-q03.sql      3 kueri analitik (window function/CTE + filter slice k4)
│   ├── 50_metrics/rasio_kehadiran.sql  1 metrik lengkap di kamus metrik
│   └── load.sql                      urutan eksekusi lengkap (dim_date → 3 dim → fact)
├── pipeline/
│   ├── profile.py             diberikan — D1 + UTS item 3
│   ├── load.py                diberikan — D3, idempoten, `--twice`
│   └── DESIGN_load.md         strategi load per tabel + risiko duplikasi saat rerun
├── tests/
│   ├── test_definitions.yml   6 test kualitas data, angka dari pipeline.profile
│   └── run_tests.py           diberikan — eksekutor, PASS/FAIL + severity
├── docs/
│   ├── profile_t1_k4.md       output asli `pipeline.profile --topic t1 --slice k4`
│   ├── kamus_metrik.md        1 metrik (12 field) + cara digaming + guard test
│   ├── BATAS_DESAIN.md        1 pertanyaan yang tidak bisa dijawab desain ini + syaratnya
│   └── D7_scope_cut.md        AKAN / TIDAK LAGI dibangun, siap ditandatangani dosen
├── bootstrap.py                diberikan — setup dependensi
└── checkpoint.py                diberikan — verifikasi DoD per sesi
```

## Ringkasan desain

- **Grain fact_presensi**: satu baris = satu mahasiswa (angkatan 2024) pada satu pertemuan
  satu mata kuliah.
- **3 dimensi**: `dim_mahasiswa` (SCD Type 2 — status aktif/cuti/lulus/do berubah dan histori-
  nya penting), `dim_matakuliah` (Type 1 — overwrite, sumber tidak punya sinyal perubahan),
  `dim_status_kehadiran` (Type 0 — kamus tetap, menormalkan 10 varian status mentah jadi 5
  anggota kanonik).
- **Measure**: `is_hadir`/`is_izin`/`is_sakit`/`is_alpa` (additive), `menit_check_in`
  (non-additive) — alasan lengkap di komentar `sql/30_fact_presensi.sql`.
- **6 test kualitas data**, angka `perkiraan_baris` dihitung langsung dari
  `pipeline.profile` (4.344 baris duplikat grain presensi, 5.812 format tanggal salah, 62
  mahasiswa tanpa angkatan, 2 nilai di luar rentang, 11.819 status tak terbaca).
- Setiap keputusan desain besar (grain, tipe SCD per dimensi, strategi load per tabel)
  ditulis dengan minimal satu alternatif yang dipertimbangkan lalu ditolak — lihat komentar
  di masing-masing berkas SQL dan `pipeline/DESIGN_load.md`.

Detail lengkap tiap keputusan ada di komentar masing-masing berkas SQL/Markdown di atas —
README ini ringkasan navigasi, bukan pengganti.

## Aturan yang dinilai (dari starter dosen)

- **Idempotensi adalah syarat, bukan bonus** — `--twice` harus mencetak row count yang sama.
- **Test wajib punya severity** — `blocking` menghentikan load; `warning` hanya memberi tahu.
- **`WHERE 1=1` bukan test** — test harus gagal ketika datanya salah, bukan ketika tabel kosong.
- **Desain dulu (UTS), bangun kemudian (UAS)** — `checkpoint.py verify --sesi 8` untuk desain.

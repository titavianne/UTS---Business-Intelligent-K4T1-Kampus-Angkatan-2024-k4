# Batas desain (UTS item 6)

## Pertanyaan yang TIDAK bisa dijawab oleh desain ini

> "Berapa nilai rata-rata (IPK sederhana) mahasiswa angkatan 2024, per mata kuliah atau per
> program studi?"

Desain ini (satu fact table, `fact_presensi`) **tidak bisa** menjawab pertanyaan itu, karena:

1. `nilai.csv` sengaja tidak dimuat ke fact manapun. Batasan tugas ini adalah **satu** fact
   table, dan grain yang dipilih adalah presensi per pertemuan (lihat alternatif yang ditolak
   di `sql/30_fact_presensi.sql`), bukan nilai akhir per mata kuliah. Tidak ada `matakuliah_sk`
   atau `mahasiswa_sk` di `fact_presensi` yang membawa `nilai_angka` — kolom itu tidak ada di
   skema sama sekali.
2. Bahkan kalau `nilai.csv` dipaksa di-JOIN ke `fact_presensi` sebagai atribut tambahan (bukan
   fact terpisah), hasilnya akan salah: grain `fact_presensi` adalah per PERTEMUAN (rata-rata
   belasan baris per nim+kode_mk), sedangkan `nilai_angka` adalah SATU nilai per nim+kode_mk.
   Menempelkannya begitu saja akan menggandakan nilai yang sama di setiap baris pertemuan —
   SUM/AVG di atasnya jadi bias terhadap mata kuliah yang jumlah pertemuannya lebih banyak.
3. `nilai.csv` sendiri punya masalah kualitas data yang belum diberi aturan resolusi: 158
   pasangan (nim, kode_mk) punya lebih dari satu baris nilai (indikasi mengulang/her), dan
   desain ini belum memutuskan apakah nilai yang dipakai adalah nilai pertama, nilai terakhir,
   atau nilai tertinggi. Tanpa keputusan itu, "nilai rata-rata mahasiswa" bisa dihitung dengan
   3 cara berbeda yang hasilnya tidak sama.

## Apa yang dibutuhkan untuk bisa menjawabnya

1. **Fact table kedua**, misalnya `fact_nilai`, dengan grain "satu baris = satu nilai final
   mahasiswa per mata kuliah per semester", terpisah dari `fact_presensi` — di luar cakupan
   satu-fact-table pada desain UTS ini (lihat `docs/D7_scope_cut.md`).
2. **Aturan resolusi baris ganda** untuk 158 pasangan (nim, kode_mk) dengan >1 nilai: keputusan
   bisnis (bukan teknis) dari Kepala Program Studi — apakah nilai yang dipakai untuk IPK adalah
   percobaan terakhir (paling umum di praktik akademik) atau nilai terbaik.
3. **Penanganan 2 baris `nilai_angka` di luar rentang 0-100** (sudah terdeteksi lewat test
   `nilai_di_luar_rentang` di `tests/test_definitions.yml`, tapi belum ada aturan perbaikan/
   karantina) — tanpa ini, dua baris itu akan merusak rata-rata mata kuliah yang memuat mereka.
4. Keputusan apakah `nilai_huruf` (A-E) atau `nilai_angka` (0-100) yang jadi sumber kebenaran
   ketika keduanya ada, karena kombinasi keduanya di seed data tidak selalu konsisten secara
   akademik standar (mis. nilai 83 dengan huruf E pada baris contoh yang terlihat saat
   profiling manual) — perlu dikonfirmasi ke pemilik data (BAAK), bukan diasumsikan salah satu
   yang benar.

GEMA (Gerbang Masinis Virtual) & Blackspot Alert

GEMA & Blackspot Alert adalah sistem peringatan dini (Early Warning System) berbasis Geo-fencing yang dirancang sebagai solusi digital proaktif untuk meningkatkan keselamatan lalu lintas dan angkutan jalan (LLAJ). 
Sistem ini memetakan titik rawan kecelakaan (blackspot) dan perlintasan sebidang kereta api tanpa palang pintu fisik menggunakan pagar virtual berbasis koordinat GPS.  Sebagai alternatif infrastruktur fisik konvensional, proyek ini menawarkan pendekatan berbasis data terpusat yang efisien, responsif, dan rendah biaya untuk menekan angka fatalitas di jalan raya.  

🚀 Fitur Utama Sistem
- Pagar Virtual Otomatis (Geo-fencing): Menetapkan radius zona aman dinamis (100 hingga 200 meter) di sekitar area bahaya yang disesuaikan dengan waktu reaksi manusia (human reaction time) pada kecepatan berkendara normal (40–60 km/jam).
- Mekanisme Peringatan Multi-Sensori (3-in-1 Alert): Saat mendeteksi perangkat masuk ke zona bahaya, sistem langsung memicu tiga jenis stimulan simultan:
  Visual: Layar antarmuka berubah menjadi warna merah terang berkedip disertai pop-up peringatan darurat.
  Audio: Sirene keras dan narasi instruksi suara untuk menembus distraksi pendengaran pengendara.
  Haptik: Getaran intensif pada perangkat sebagai stimulus fisik tambahan.
- Safe Interlocking (Konfirmasi Pengguna): Menyediakan fitur tombol interaktif "OKE, SAYA MENGERTI" yang memaksa pengguna berinteraksi dengan aplikasi untuk mematikan mode darurat, memastikan kesadaran penuh pengendara sebelum kembali ke mode navigasi normal.
- Database Spasial Titik Bahaya: Penyimpanan terstruktur untuk data koordinat presisi (latitude dan longitude) perlintasan sebidang rawan dan lokasi blackspot seperti tikungan tajam atau turunan curam.


🛠️ Arsitektur & Alur Kerja DataSistem beroperasi secara real-time melalui siklus pemantauan lokasi yang kontinu dengan alur sebagai berikut:

[Perangkat Pengguna] 📡 (Kirim Koordinat GPS via Seluler)
         │
         ▼
[Server Side / Logic Engine] 💻 (Komparasi dengan Database Titik Bahaya)
         │
         ├─► [Luar Radius] 🟢 Status: Area Aman -> Pemantauan Berlanjut
         │
         └─► [Masuk Radius] 🔴 Trigger Perintah Mode Darurat
                  │
                  ▼
[Aplikasi Klien] 📱 (Eksekusi Sirene, Layar Merah Berkedip, & Getaran)
                  │
                  ▼
[Terminasi / End] ↩️ (Berhenti Hanya Jika Tombol Ditekan ATAU Pengendara Keluar Zona Bahaya)

- Data Ingest: Perangkat klien mengirimkan koordinat GPS secara berkala melalui jaringan data internet ke server.
- Logic Engine: Server memproses data lokasi tersebut dan membandingkannya secara real-time dengan Database Titik Bahaya.
- Triggering Mechanism: Jika koordinat pengguna berada di dalam radius zona bahaya yang ditentukan, server mengirimkan perintah instruksi ke aplikasi perangkat seluler.
- End-User Alert: Aplikasi klien mengeksekusi peringatan visual, audio, dan haptik secara kontinu hingga pengguna memberikan konfirmasi atau kendaraan telah melewati batas geografis virtual tersebut.  

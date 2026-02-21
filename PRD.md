---

**Product Requirements Document (PRD): NotifyMe**

## **1\. Ringkasan Proyek**

Aplikasi ini bertujuan untuk memantau perubahan konten pada berbagai situs web secara otomatis. Jika ditemukan perubahan, aplikasi akan mengirimkan notifikasi interaktif pada Android maupun Windows.

* **Platform:** Android (Utama) & Windows (Desktop).  
* **Model Bisnis:** 100% Gratis, *Open Source Mindset* (Tanpa biaya langganan API).  
* **Prinsip Kerja:** *Client-side Polling* (Aplikasi melakukan pengecekan langsung dari perangkat user, bukan lewat server perantara).

## ---

**2\. Arsitektur Sistem**

Untuk menjaga efisiensi dan biaya nol rupiah, kita akan menggunakan arsitektur berikut:

* **Framework:** Flutter (Satu kode untuk Android & Windows).  
* **Database:** SQLite (Melalui package sqflite atau drift) untuk menyimpan link dan history.  
* **Background Process:** \* **Android:** WorkManager untuk pengecekan berkala meski aplikasi tertutup.  
  * **Windows:** System Tray \+ Timer yang berjalan di *background*.  
* **Change Detection:** Hash-based comparison atau Text-diffing pada elemen HTML spesifik.

## ---

**3\. Fitur Utama & Spesifikasi Halaman**

### **A. Halaman Utama (Dashboard)**

* **Daftar Web:** List semua website yang dimonitor dengan status (Aktif/Error) dan waktu pengecekan terakhir.  
* **Indikator Update:** Badge merah jika ada update yang belum dibaca.  
* **Floating Action Button (FAB):** Tombol "+" untuk menambah link baru.

### **B. Halaman Settings (Setelan Notifikasi & Sistem)**

* **Konfigurasi Notifikasi:**
  * Pilihan Enable/Disable Push Notifications.
  * *Reminder Interval*: Pengaturan frekuensi pengingat saat notif belum dibaca (5 menit, 15 menit, 30 menit, dll).
  * *Notification Audio*: Pengaturan pemilihan nada dering custom (Chime, Bell, Radar, Mute) yang berbunyi ketika sistem mendeteksi pembaruan konten.
* **Tampilan:**
  * Mode Gelap/Terang Otomatis (Mengikuti Preferensi Sistem).

### **C. Halaman Manajemen Link (Add/Edit)**

* **Kolom Input:**  
  * Nama Label (Contoh: "Update Pengumuman Kampus").  
  * URL Web.  
  * **CSS Selector (Opsional):** Kolom untuk menentukan bagian mana yang dipantau (misal: \#content atau .news-list). Jika kosong, aplikasi memantau seluruh \<body\>.  
  * **Interval Waktu:** Dropdown (15 menit, 1 jam, 6 jam, dll).  
* **Tombol Simpan & Hapus.**

### **C. Halaman Detail & Perbandingan**

* **WebView Integration:** Menampilkan halaman web langsung di dalam aplikasi.  
* **Highlighting:** Menampilkan teks lama vs teks baru (Diffing) untuk menunjukkan bagian mana yang berubah.

### **E. Halaman Dashboard Khusus (Vercel/Mailin)**

* Menu Khusus di Sidebar/BottomNav (bernama "Dashboard" menggantikan History) yang melakukan *embedding* (WebView aman dengan deteksi web fallback) langsung ke: https://mailin-univet.vercel.app/dashboard.

## ---

**4\. Mekanisme Notifikasi Interaktif**

### **Android**

* **Push Notification:** Muncul di status bar.  
* **Action Buttons:** 1\. **Buka:** Membuka aplikasi ke halaman detail web tersebut.  
  2\. **Tandai Dibaca:** Menghilangkan notifikasi dan mengupdate status di database tanpa buka aplikasi.  
  3\. **Tutup:** Menghilangkan notifikasi sementara.  
* **Reminder:** Jika notifikasi tidak diklik dalam X menit, sistem akan memicu ulang (Re-trigger) notifikasi.

### **Windows (High Visibility)**

* **Overlay Notification:** Karena tidak ada speaker, notifikasi akan muncul berupa *Pop-up Window* berukuran besar di pojok kanan bawah atau tengah layar dengan warna kontras.  
* **Sticky Note Style:** Notifikasi tidak akan hilang sampai user menekan salah satu tombol aksi.

## ---

**5\. Workflow (Alur Kerja)**

1. **Input:** User memasukkan URL dan memilih elemen HTML yang ingin dipantau.  
2. **Background Task:** Setiap interval waktu, aplikasi melakukan HTTP GET ke URL tersebut.  
3. **Comparison:** \* Aplikasi mengambil konten HTML.  
   * Mengonversi konten menjadi string/hash.  
   * Membandingkan dengan data lama di SQLite.  
4. **Trigger:** Jika Konten Baru ≠ Konten Lama, kirim notifikasi.  
5. **User Action:** User melihat update, data lama diupdate dengan data baru.

## ---

**6\. Dependensi (Tech Stack)**

| Kebutuhan | Package Flutter (Recommended) |
| :---- | :---- |
| **HTTP Client** | http atau dio |
| **HTML Parser** | html (untuk scraping elemen spesifik) |
| **Database** | sqflite (Android) & sqlite3 (Windows) |
| **Local Notif** | flutter\_local\_notifications |
| **Windows Notif** | local\_notifier atau bot\_toast |
| **Background Task** | workmanager |
| **WebView** | webview\_flutter |

## ---

**7\. Langkah Realisasi Proyek**

1. **Tahap 1: Setup Flutter & UI Dasar.** Buat navigasi dan halaman CRUD untuk link.  
2. **Tahap 2: Implementasi Scraping.** Buat fungsi untuk mengambil HTML dan memisahkan teks berdasarkan CSS Selector.  
3. **Tahap 3: Database Logic.** Simpan data "Snapshot" terakhir dari web untuk bahan perbandingan.  
4. **Tahap 4: Background Service.** \* Konfigurasi WorkManager di Android agar tetap berjalan di *doze mode*.  
   * Konfigurasi aplikasi Windows agar bisa *minimize to tray*.  
5. **Tahap 5: Notification UI.** Desain UI notifikasi besar untuk Windows dan tombol aksi untuk Android.  
6. **Tahap 6: Vercel Integration.** Tambahkan halaman WebView untuk dashboard Vercel Anda.

## ---

**8\. Catatan Penting (Resource Optimization)**

* **Tanpa Gambar:** Agar ringan, aplikasi hanya mengambil data teks/HTML saja (jangan download gambar saat proses pengecekan background).  
* **Efficient Polling:** Batasi minimal interval pengecekan (misal paling cepat 15 menit) agar tidak memakan baterai dan CPU secara berlebihan.

Apakah Anda ingin saya membantu membuatkan **kode dasar (Boilerplate)** untuk fitur pendeteksi perubahan HTML ini sebagai langkah awal?
# 🔔 NotifyMe - Web Monitor & Reminder

NotifyMe adalah aplikasi cerdas berbasis Flutter yang dirancang untuk memantau perubahan konten pada situs web secara otomatis. Jika ada pembaruan pada halaman yang Anda pantau, aplikasi akan segera memberikan notifikasi interaktif langsung ke perangkat Anda.

---

## 🚀 Fitur Utama

- **Pemantauan Latar Belakang (Background Polling):** Aplikasi melakukan pengecekan secara berkala bahkan saat aplikasi tidak dibuka.
- **Notifikasi Interaktif:** Dilengkapi tombol aksi "Baca" (langsung buka web) dan "Baca Nanti" (menunda notifikasi).
- **Visual Element Selector:** Pilih bagian spesifik dari halaman web (CSS Selector) yang ingin dipantau menggunakan browser internal yang canggih.
- **Smart Reminder:** Jika notifikasi belum dibaca, aplikasi akan memberikan pengingat ulang sesuai interval yang Anda tentukan di pengaturan.
- **Pencarian Cerdas:** Temukan monitor Anda dengan cepat berdasarkan Nama atau URL.
- **Smart Sorting:** Website dengan pembaruan terbaru akan otomatis naik ke urutan paling atas.
- **Mode Gelap/Terang:** Tampilan modern yang menyesuaikan dengan preferensi sistem Anda.

---

## 📥 Download & Instalasi

Anda dapat mengunduh versi final aplikasi untuk Android di bawah ini:

### **[📦 Download NotifyMe APK](notifyme.apk)**
*(Setelah diunduh, buka file tersebut di ponsel Android Anda untuk menginstalnya.)*

---

## 🛠️ Cara Penggunaan

1. **Tambah Website:** Klik tombol "+" (FAB) pada halaman utama.
2. **Masukkan URL:** Ketik alamat website yang ingin dipantau.
3. **Pilih Elemen (Opsional):** Gunakan ikon "Visual Selector" untuk menyorot bagian teks tertentu (misal: harga, pengumuman terbaru).
4. **Atur Frekuensi:** Pilih seberapa sering aplikasi harus mengecek pembaruan (mulai dari 1 menit untuk tes hingga harian).
5. **Simpan:** Klik simpan dan biarkan NotifyMe bekerja untuk Anda!

---

## ⚙️ Pengaturan Pengingat (Reminder)

Masuk ke menu **Settings** untuk mengonfigurasi:
- **Enable/Disable Push Notifications.**
- **Reminder Interval:** 5 menit, 15 menit, hingga 1 jam.
- **Notification Audio:** Pilih suara peringatan yang Anda sukai.

---

## 🧑‍💻 Arsitektur & Teknologi

- **Framework:** Flutter
- **Database:** SQLite (Local)
- **Background Service:** WorkManager (Android)
- **Local Storage:** Shared Preferences
- **Web Scraping:** HTML Parser & HTTP Client

---

## 📄 Lisensi

Proyek ini dikembangkan oleh **Mulyo Agung** sebagai solusi pemantauan web mandiri yang efisien dan gratis.

---
*Dibuat dengan ❤️ untuk kemudahan akses informasi.*

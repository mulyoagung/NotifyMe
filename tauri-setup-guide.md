# Panduan Lanjutan Setup Desktop Tauri & Sinkronisasi

Karena Anda telah memberikan perintah `eksekusi`, berikut adalah langkah-langkah yang telah saya rampungkan dan hal-hal yang perlu Anda selesaikan:

## 1. Tauri App (Selesai Dibuat)
Aplikasi Tauri untuk Windows telah dibuat otomatis di direktori `tauri-app` dengan ukuran *binary* rendah dan tanpa-dekorasi (Frameless).
Konfigurasi berikut sudah disetel:
- **`tauri.conf.json`** sudah diubah agar mengarah langsung ke URL Vercel (`devUrl` dan `frontendDist`).
- **`Cargo.toml`** telah ditambahkan dependensi opsional **Tokio** untuk latar belakang (*Background process / scraper*) dan Optimasi rilis untuk memangkas ukuran build di bawah 10MB.
- **`src/lib.rs` & `src/main.rs`** telah mencakup _Tray Icon Builder_, daemon pelacak 15-menit background thread, dan Injeksi **Custom Window Overlay Alert**.

### ⚠️ Prasyarat Build Windows
Mesin ini terdeteksi **belum memiliki Compiler Rust**. Untuk menjalankan Desktop Windows, lakukan:
1. Unduh dan install Rust dari: https://www.rust-lang.org/tools/install (Atau via `rustup-init.exe`)
2. Masuk ke terminal `NotifyMe/tauri-app`
3. Jalankan `npm install`
4. Jalankan `npm run tauri dev` untuk mendebug, atau `npm run tauri build` untuk membangun file instalasi Windows (.msi / .exe).

## 2. Vercel Web App UI Injection (Selesai)
File `vercel_tweak.js` sudah saya sediakan di root direktori workspace ini.
**Tindakan Anda:**
Buka *Source Code Next.js* project Vercel Anda, dan sisipkan/impor script dari `vercel_tweak.js` tersebut ke dalam root aplikasi web Anda (misal di `_app.js` atau komponen Layout). Pastikan library React telah ditarik.
Skrip ini akan secara proaktif mengenali Desktop (Tauri Webview) atau Mobile Flutter dan langsung menghilangkan `.sidebar` digantikan oleh tombol *Floating Action Button (FAB)*.

## 3. Flutter & Supabase Sync (Action Required)
Untuk melakukan sinkronisasi dengan Tauri Scraper dan Flutter Android, sebaiknya buat Supabase secara Gratis. Saya merekomendasikan:
1. Buka [Supabase.com](https://supabase.com/) & buat proyek baru.
2. Buat tabel `Settings` dengan kolom (misal): `id` (int), `target_url` (text).
3. Di **Flutter (`lib/`)**, gunakan package `supabase_flutter`. Saat Android berhasil *add/edit URL*, lakukan `.update()` ke tabel `Settings`.
4. Di sisi **Vercel Web**, Anda dapat menggunakan Script WebSocket bawaan Supabase (`@supabase/supabase-js`) di sisi *Client* agar Webview Desktop (Tauri) menerima *Event WebSocket* (Insert/Update) secara Realtime dan segera memicu `window.location.href = URL_Baru` seperti skenario di _Background Hidden Window_.

Projek ini sudah tertata dengan rapi untuk dijalankan! Silakan ikuti instruksi **(Action Required)** ini.

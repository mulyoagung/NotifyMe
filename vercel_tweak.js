// Cek apakah web dibuka dari dalam Desktop/Mobile Webview (Tauri / Flutter)
useEffect(() => {
    const isWebView = window.__TAURI__ || navigator.userAgent.includes("NotifyMeApp") || window.flutter_inappwebview;

    if (isWebView) {
        // 1. Sembunyikan Sidebar & Sesuaikan Layout
        const style = document.createElement('style');
        style.innerHTML = `
      .sidebar { display: none !important; }
      body { padding-left: 0 !important; } /* Sesuaikan jika ada margin kiri dari sidebar */
      
      /* Optional: Sembunyikan mobile menu toggler khusus webview */
      .mobile-menu-btn { display: none !important; }
    `;
        document.head.appendChild(style);

        // 2. Buat Floating Action Button (FAB) Back Button
        const fab = document.createElement('button');
        fab.innerHTML = `
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <path d="M19 12H5M12 19l-7-7 7-7"/>
      </svg>
    `;
        fab.style.cssText = `
      position: fixed; 
      top: 20px; 
      left: 20px; 
      z-index: 99999;
      width: 45px; 
      height: 45px; 
      border-radius: 50%;
      background: #111; 
      color: #fff;
      border: 2px solid #333; 
      box-shadow: 0 4px 10px rgba(0,0,0,0.5);
      cursor: pointer; 
      display: flex; 
      align-items: center; 
      justify-content: center;
      transition: transform 0.2s ease;
    `;

        // Animasi Hover
        fab.onmouseenter = () => fab.style.transform = 'scale(1.1)';
        fab.onmouseleave = () => fab.style.transform = 'scale(1)';

        // Aksi Navigasi Kembali
        fab.onclick = () => {
            // Ke Homepage Vercel
            window.location.href = '/';

            // Atau jika ingin menutup webview di Flutter InAppWebView (kalau dikonfigurasikan):
            // if (window.flutter_inappwebview) window.flutter_inappwebview.callHandler('goBack');
        };

        document.body.appendChild(fab);
    }
}, []);

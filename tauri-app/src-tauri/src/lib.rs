use std::time::Duration;
use tauri::Manager;

#[tauri::command]
fn tandai_dibaca(window: tauri::Window) {
    let _ = window.close();
}

#[tauri::command]
fn trigger_notif_from_js(app_handle: tauri::AppHandle, data: String) {
    let window_label = format!(
        "notify_{}",
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs()
    );
    let html_content = format!(
        r#"<html><body style="margin:0;"><div style="background:#111;color:#fff;height:100vh;display:flex;flex-direction:column;justify-content:center;align-items:center;font-family:sans-serif;padding:20px;box-sizing:border-box;"><h3 style="margin:0 0 15px 0;">Peringatan Baru!</h3><p style="margin:0 0 20px 0;font-size:14px;text-align:center;">{}</p><div style="display:flex;gap:10px;"><button onclick="window.__TAURI__.core.invoke('tandai_dibaca')" style="background:#4CAF50;color:white;border:none;padding:10px 20px;border-radius:5px;cursor:pointer;font-weight:bold;">Baca</button><button onclick="window.__TAURI__.core.invoke('tandai_dibaca')" style="background:#f44336;color:white;border:none;padding:10px 20px;border-radius:5px;cursor:pointer;font-weight:bold;">Tandai Dibaca</button></div></div></body></html>"#,
        html_escape::encode_text(&data)
    );
    let data_uri = format!(
        "data:text/html;charset=utf-8,{}",
        urlencoding::encode(&html_content)
    );
    let _ = tauri::WebviewWindowBuilder::new(
        &app_handle,
        window_label,
        tauri::WebviewUrl::External(data_uri.parse().unwrap()),
    )
    .inner_size(350.0, 180.0)
    .decorations(false)
    .always_on_top(true)
    .resizable(false)
    .skip_taskbar(true)
    .build();
}

/// Open URL in system default browser
#[tauri::command]
fn open_url_external(url: String, app_handle: tauri::AppHandle) {
    use tauri_plugin_opener::OpenerExt;
    let _ = app_handle.opener().open_url(&url, None::<&str>);
}

/// Open any URL in a new in-app Tauri window
#[tauri::command]
fn open_webview_window(url: String, title: String, app_handle: tauri::AppHandle) {
    let label = format!(
        "webview_{}",
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs()
    );
    if let Ok(parsed) = url.parse() {
        let _ = tauri::WebviewWindowBuilder::new(
            &app_handle,
            label,
            tauri::WebviewUrl::External(parsed),
        )
        .title(title)
        .inner_size(1280.0, 800.0)
        .build();
    }
}

/// Open visual element selector window — injects selector UI into target URL
#[tauri::command]
fn open_selector_window(url: String, app_handle: tauri::AppHandle) {
    let label = format!(
        "selector_{}",
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs()
    );
    if let Ok(parsed) = url.parse() {
        let win_result = tauri::WebviewWindowBuilder::new(
            &app_handle,
            label,
            tauri::WebviewUrl::External(parsed),
        )
        .title("🎯 Pilih Elemen — NotifyMe")
        .inner_size(1280.0, 800.0)
        .initialization_script(SELECTOR_INIT_SCRIPT)
        .build();

        if let Ok(win) = win_result {
            // Keep window alive
            drop(win);
        }
    }
}

// ─── Visual Selector Initialization Script ────────────────────────────────────
// Injected into the target page before content loads.
// Adds a fixed toolbar + hover/click selector UI.
// On confirm, copies CSS selector to clipboard then closes window.
const SELECTOR_INIT_SCRIPT: &str = r#"
(function() {
  function nm_init() {
    if (!document.body) { setTimeout(nm_init, 150); return; }

    // ── Styles ──
    var s = document.createElement('style');
    s.textContent = [
      '#nm-bar{position:fixed!important;top:0!important;left:0!important;right:0!important;z-index:2147483647!important;',
      'background:rgba(4,12,8,.97)!important;border-bottom:2px solid #00F4B1!important;',
      'padding:10px 14px!important;display:flex!important;align-items:center!important;gap:10px!important;',
      'font-family:-apple-system,sans-serif!important;box-shadow:0 4px 20px rgba(0,244,177,.25)!important;}',
      '#nm-sel{flex:1!important;background:rgba(0,244,177,.08)!important;border:1px solid rgba(0,244,177,.4)!important;',
      'border-radius:6px!important;padding:7px 12px!important;color:#00F4B1!important;',
      'font-family:monospace!important;font-size:12px!important;white-space:nowrap!important;overflow:hidden!important;text-overflow:ellipsis!important;}',
      '.nm-btn{border:none!important;padding:8px 14px!important;border-radius:6px!important;cursor:pointer!important;',
      'font-weight:700!important;font-size:13px!important;white-space:nowrap!important;flex-shrink:0!important;}',
      '.nm-ok{background:#00F4B1!important;color:#000!important;}',
      '.nm-exp{background:rgba(0,244,177,.15)!important;color:#00F4B1!important;border:1px solid rgba(0,244,177,.4)!important;}',
      '.nm-cancel{background:rgba(255,60,60,.12)!important;color:#ff6b6b!important;border:1px solid rgba(255,60,60,.35)!important;}'
    ].join('');
    document.head.appendChild(s);

    // ── Toolbar ──
    var bar = document.createElement('div');
    bar.id = 'nm-bar';
    bar.innerHTML =
      '<span style="color:#00F4B1;font-weight:700;font-size:13px;flex-shrink:0">🎯 NotifyMe Selector</span>' +
      '<div id="nm-sel">Hover lalu klik elemen untuk memilih...</div>' +
      '<button class="nm-btn nm-exp" onclick="nm_up()">↑ Perluas</button>' +
      '<button class="nm-btn nm-exp" onclick="nm_dn()">↓ Perkecil</button>' +
      '<button class="nm-btn nm-ok" onclick="nm_ok()">✅ Simpan Selector</button>' +
      '<button class="nm-btn nm-cancel" onclick="window.close()">✕ Batal</button>';
    document.body.insertBefore(bar, document.body.firstChild);
    document.body.style.paddingTop = (bar.offsetHeight + 4) + 'px';

    // ── CSS Selector Generator ──
    function getCSS(el) {
      if (!(el instanceof Element)) return '';
      var path = [];
      while (el.nodeType === 1 && el.tagName.toLowerCase() !== 'html') {
        var sel = el.nodeName.toLowerCase();
        if (el.id && /^[a-zA-Z0-9\-_]+$/.test(el.id)) { path.unshift(sel + '#' + el.id); break; }
        var sib = el.previousElementSibling, nth = 1;
        while (sib) { nth++; sib = sib.previousElementSibling; }
        if (el.className && typeof el.className === 'string') {
          var vc = el.className.trim().split(/\s+/).find(function(c){ return /^[a-zA-Z0-9\-_]+$/.test(c) && c.length < 30; });
          if (vc) sel += '.' + vc;
        }
        if (nth !== 1) sel += ':nth-child(' + nth + ')';
        path.unshift(sel); el = el.parentNode;
      }
      return path.join(' > ');
    }

    var nm_active = null, nm_hover = null, nm_css = '';

    function set_outline(el, o, bg) { el && (el.style.setProperty('outline',o,'important'), el.style.setProperty('background-color',bg,'important')); }
    function clr(el) { el && (el.style.removeProperty('outline'), el.style.removeProperty('background-color')); }

    window.nm_up = function() {
      if (nm_active && nm_active.parentElement && nm_active.parentElement !== document.body) {
        clr(nm_active); nm_active = nm_active.parentElement;
        nm_css = getCSS(nm_active);
        set_outline(nm_active,'3px solid #00F4B1','rgba(0,244,177,.15)');
        document.getElementById('nm-sel').textContent = nm_css;
      }
    };
    window.nm_dn = function() {
      if (nm_active && nm_active.firstElementChild) {
        clr(nm_active); nm_active = nm_active.firstElementChild;
        nm_css = getCSS(nm_active);
        set_outline(nm_active,'3px solid #00F4B1','rgba(0,244,177,.15)');
        document.getElementById('nm-sel').textContent = nm_css;
      }
    };
    window.nm_ok = function() {
      if (!nm_css) { document.getElementById('nm-sel').textContent = 'Pilih elemen dulu!'; return; }
      var box = document.getElementById('nm-sel');
      box.textContent = '⏳ Menyalin ke clipboard...';
      navigator.clipboard.writeText(nm_css).then(function() {
        box.textContent = '✅ Disalin! Tutup window ini, lalu paste di kolom CSS Selector.';
      }).catch(function() {
        box.textContent = nm_css + '  ← Salin teks ini manual (Ctrl+A, Ctrl+C)';
      });
    };

    document.addEventListener('mousemove', function(e) {
      var el = e.target; if (el.closest && el.closest('#nm-bar')) return;
      if (nm_hover && nm_hover !== nm_active) clr(nm_hover);
      nm_hover = el;
      if (el !== nm_active) set_outline(el,'2px dashed #00F4B1','rgba(0,244,177,.06)');
    }, true);

    document.addEventListener('click', function(e) {
      var el = e.target; if (el.closest && el.closest('#nm-bar')) return;
      e.preventDefault(); e.stopPropagation();
      clr(nm_active); nm_active = el;
      nm_css = getCSS(el);
      set_outline(el,'3px solid #00F4B1','rgba(0,244,177,.18)');
      document.getElementById('nm-sel').textContent = nm_css || '(tidak dapat menentukan selector)';
    }, true);
  }
  nm_init();
})();
"#;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .setup(|app| {
            #[cfg(target_os = "windows")]
            {
                use tauri::tray::TrayIconBuilder;
                let _ = TrayIconBuilder::new().tooltip("NotifyMe").build(app);
            }

            let app_handle = app.handle().clone();
            tauri::async_runtime::spawn(async move {
                let mut interval = tokio::time::interval(Duration::from_secs(15 * 60));
                interval.tick().await;
                loop {
                    interval.tick().await;
                    if let Some(scraper_window) = app_handle.get_webview_window("scraper_bg") {
                        let _ = scraper_window.eval(r#"
                            fetch(window.location.href)
                              .then(r=>r.text())
                              .then(html=>{
                                const doc=new DOMParser().parseFromString(html,'text/html');
                                const data=doc.body.innerText.substring(0,100);
                                window.__TAURI__.core.invoke('trigger_notif_from_js',{data});
                              }).catch(console.error);
                        "#);
                    }
                }
            });
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            tandai_dibaca,
            trigger_notif_from_js,
            open_url_external,
            open_webview_window,
            open_selector_window,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

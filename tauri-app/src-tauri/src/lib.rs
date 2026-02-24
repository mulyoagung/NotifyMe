use std::time::Duration;
use tauri::{Manager};

#[tauri::command]
fn tandai_dibaca(window: tauri::Window) {
    let _ = window.close();
}

#[tauri::command]
fn trigger_notif_from_js(app_handle: tauri::AppHandle, data: String) {
    let window_label = format!("notify_{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs());
    
    let html_content = format!(r#"
        <html><body style="margin: 0;">
        <div style="background:#111; color:#fff; height:100vh; display:flex; flex-direction:column; justify-content:center; align-items:center; font-family:sans-serif; margin:0; padding: 20px; box-sizing: border-box;">
            <h3 style="margin:0 0 15px 0;">Peringatan Baru!</h3>
            <p style="margin:0 0 20px 0; font-size:14px; text-align:center;">{}</p>
            <div style="display:flex; gap:10px;">
                <button onclick="window.__TAURI__.core.invoke('tandai_dibaca')" style="background:#4CAF50; color:white; border:none; padding:10px 20px; border-radius:5px; cursor:pointer; font-weight:bold;">Baca</button>
                <button onclick="window.__TAURI__.core.invoke('tandai_dibaca')" style="background:#f44336; color:white; border:none; padding:10px 20px; border-radius:5px; cursor:pointer; font-weight:bold;">Tandai Dibaca</button>
            </div>
        </div>
        </body></html>
    "#, html_escape::encode_text(&data));

    let data_uri = format!("data:text/html;charset=utf-8,{}", urlencoding::encode(&html_content));

    let _notify_window = match tauri::WebviewWindowBuilder::new(
        &app_handle,
        window_label,
        tauri::WebviewUrl::External(data_uri.parse().unwrap())
    )
    .inner_size(350.0, 150.0)
    .decorations(false)
    .always_on_top(true)
    .resizable(false)
    .skip_taskbar(true)
    .build() {
        Ok(w) => w,
        Err(_) => return,
    };
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .setup(|app| {
            #[cfg(target_os = "windows")]
            {
                use tauri::tray::TrayIconBuilder;
                let _ = TrayIconBuilder::new()
                    .tooltip("NotifyMe")
                    .build(app);
            }

            let app_handle = app.handle().clone();
            
            tauri::async_runtime::spawn(async move {
                let mut interval = tokio::time::interval(Duration::from_secs(15 * 60));
                interval.tick().await; // Skip first immediate tick
                
                loop {
                    interval.tick().await; // Will wait 15m before running
                    
                    if let Some(scraper_window) = app_handle.get_webview_window("scraper_bg") {
                        let scrape_script = r#"
                            fetch(window.location.href)
                                .then(res => res.text())
                                .then(html => {
                                    const parser = new DOMParser();
                                    const doc = parser.parseFromString(html, 'text/html');
                                    const data = doc.body.innerText.substring(0, 100);
                                    window.__TAURI__.core.invoke('trigger_notif_from_js', { data: data });
                                }).catch(console.error);
                        "#;
                        let _ = scraper_window.eval(scrape_script);
                    }
                }
            });

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![tandai_dibaca, trigger_notif_from_js])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

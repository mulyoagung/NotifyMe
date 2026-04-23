// Conditional export: web uses dart:html, native uses stubs
export 'tauri_service_native.dart'
    if (dart.library.html) 'tauri_service_web.dart';

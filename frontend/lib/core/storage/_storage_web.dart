// Web-only implementation — compiled only when dart.library.html is present.
// Uses window.localStorage directly: no plugin channel, no Web Crypto API
// dependency, works on plain HTTP from any device on the LAN.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<String?> storageRead(String key) async =>
    html.window.localStorage[key];

Future<void> storageWrite(String key, String value) async =>
    html.window.localStorage[key] = value;

Future<void> storageDelete(String key) async =>
    html.window.localStorage.remove(key);

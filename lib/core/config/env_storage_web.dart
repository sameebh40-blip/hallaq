import 'dart:js_interop';

@JS('window.localStorage')
external Storage get _localStorage;

extension type Storage(JSObject _) {
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}

String? getString(String key) => _localStorage.getItem(key);

void setString(String key, String value) => _localStorage.setItem(key, value);

void remove(String key) => _localStorage.removeItem(key);

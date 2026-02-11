import 'package:flutter/foundation.dart';

const String _prodBaseUrl = "https://backend-gastos-g560.onrender.com";
const String _localBaseUrl = "http://127.0.0.1:8000";

// En web release (GitHub Pages) usa Render. En local, localhost.
String get baseUrl => kReleaseMode ? _prodBaseUrl : _localBaseUrl;

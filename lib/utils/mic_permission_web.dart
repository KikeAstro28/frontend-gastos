// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<void> ensureMicPermission() async {
  final mediaDevices = html.window.navigator.mediaDevices;
  if (mediaDevices == null) return;

  final stream = await mediaDevices.getUserMedia({'audio': true});

  // Cerramos inmediatamente (solo queríamos el permiso)
  for (final track in stream.getTracks()) {
    track.stop();
  }
}

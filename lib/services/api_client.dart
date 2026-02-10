import 'token_storage.dart';

Future<Map<String, String>> authHeaders() async {
  final token = await getToken();

  if (token == null || token.isEmpty) {
    throw Exception('No hay token guardado. El usuario no está logueado.');
  }

  return {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };
}

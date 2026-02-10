import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_service.dart';

class ExpenseService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // ------------------------
  // CATEGORIES
  // ------------------------
  static Future<List<String>> fetchCategories() async {
    final resp = await http.get(
      Uri.parse('$baseUrl/categories'),
      headers: await _headers(),
    );

    if (resp.statusCode != 200) {
      throw Exception('Error categories ${resp.statusCode}: ${resp.body}');
    }

    return (jsonDecode(resp.body) as List).cast<String>();
  }

  static Future<void> addCategory(String name) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/categories'),
      headers: await _headers(),
      body: jsonEncode({'name': name}),
    );

    if (resp.statusCode != 200) {
      throw Exception('Error addCategory ${resp.statusCode}: ${resp.body}');
    }
  }

  static Future<void> hideCategory(String name) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/categories/hide'),
      headers: await _headers(),
      body: jsonEncode({'name': name}),
    );

    if (resp.statusCode != 200) {
      throw Exception('Error hideCategory ${resp.statusCode}: ${resp.body}');
    }
  }

  static Future<void> unhideCategory(String name) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/categories/unhide'),
      headers: await _headers(),
      body: jsonEncode({'name': name}),
    );

    if (resp.statusCode != 200) {
      throw Exception('Error unhideCategory ${resp.statusCode}: ${resp.body}');
    }
  }

  // ------------------------
  // EXPENSES
  // ------------------------
  static Future<List<dynamic>> fetchExpenses() async {
    final resp = await http.get(
      Uri.parse('$baseUrl/expenses'),
      headers: await _headers(),
    );

    if (resp.statusCode != 200) {
      throw Exception('Error expenses ${resp.statusCode}: ${resp.body}');
    }

    return (jsonDecode(resp.body) as List);
  }

  static Future<void> deleteExpense(int id) async {
    final resp = await http.delete(
      Uri.parse('$baseUrl/expenses/$id'),
      headers: await _headers(),
    );

    if (resp.statusCode != 200) {
      throw Exception('Error delete ${resp.statusCode}: ${resp.body}');
    }
  }

  static Future<void> updateExpense(
    int id, {
    required DateTime date,
    required String description,
    required double amount,
    required String category,
    required String extra,
  }) async {
    final body = {
      'date': date.toIso8601String(),
      'description': description,
      'amount': amount,
      'category': category,
      'extra': extra,
    };

    final resp = await http.put(
      Uri.parse('$baseUrl/expenses/$id'),
      headers: await _headers(),
      body: jsonEncode(body),
    );

    if (resp.statusCode != 200) {
      throw Exception('Error update ${resp.statusCode}: ${resp.body}');
    }
  }

  // ✅ Para tu main.dart: pasar Expense.toJson()
  static Future<Map<String, dynamic>> addExpenseMap(Map<String, dynamic> body) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/expenses'),
      headers: await _headers(),
      body: jsonEncode(body),
    );

    if (resp.statusCode != 200) {
      throw Exception('Error addExpense ${resp.statusCode}: ${resp.body}');
    }

    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  // ✅ Para tu main.dart: pasar List<Expense>.map(toJson).toList()
  static Future<List<Map<String, dynamic>>> addExpensesBulk(
    List<Map<String, dynamic>> items,
  ) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/expenses/bulk'),
      headers: await _headers(),
      body: jsonEncode(items),
    );

    if (resp.statusCode != 200) {
      throw Exception('Error addExpensesBulk ${resp.statusCode}: ${resp.body}');
    }

    return (jsonDecode(resp.body) as List).cast<Map<String, dynamic>>();
  }
}

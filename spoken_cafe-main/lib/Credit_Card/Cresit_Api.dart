import 'dart:convert';
import 'package:http/http.dart' as http;

class NestpayPaymentService {
  NestpayPaymentService._();
  static final NestpayPaymentService instance = NestpayPaymentService._();

  // TODO: replace with your actual region & project ID
  final String _functionsBaseUrl = 'https://us-central1-spoken-cafe-456813-b3e6d.cloudfunctions.net/processNestpayPayment';

  /// Public helper for your UI: returns true on approved payment
  Future<bool> makePayment({
    required double amount,
    required String number,
    required String expMonth,
    required String expYear,
    required String cvv,
    required String email,
    required String name,
  }) async {
    try {
      final result = await processNestpayPayment(
        cardNumber: number,
        expMonth: expMonth,
        expYear: expYear,
        cvv: cvv,
        amount: amount,
        email: email,
        name: name,
      );
      return result['success'] == true;
    } catch (e) {
      print('🔴 Payment error: $e',);
      return false;
    }
  }

  /// Calls your Firebase Function and returns its JSON result
  Future<Map<String, dynamic>> processNestpayPayment({
    required String cardNumber,
    required String expMonth,
    required String expYear,
    required String cvv,
    required double amount,
    required String email,
    required String name,
  }) async {
    final orderId = DateTime.now().millisecondsSinceEpoch.toString();

    final payload = {
      'cardNumber': cardNumber,
      'expMonth': expMonth,
      'expYear': expYear,
      'cvv': cvv,
      'amount': amount.toString(),
      'currency': '949',
      'orderId': orderId,
      'email': email,
      'name': name,
    };

    final uri = Uri.parse('$_functionsBaseUrl/processNestpayPayment');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data;
  }
}

// import 'dart:convert';
// import 'package:http/http.dart' as http;

// Future<void> submitPayment(String cardNo, String expMonth, String expYear, String cvv) async {
//   final url = Uri.parse('https://us-central1-spoken-cafe-456813-b3e6d.cloudfunctions.net/processNestpayPayment');
//   final body = jsonEncode({
//     'cardNumber': cardNo,
//     'expMonth': expMonth,
//     'expYear': expYear,
//     'cvv': cvv,
//     'amount': '10.15',    // example amount 
//     'currency': '949',    // TL 
//     'orderId': 'ORDER12345'  // unique order ID
//   });
//   try {
//     final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: body);
//     if (response.statusCode == 200) {
//       final result = jsonDecode(response.body);
//       if (result['success'] == true) {
//         // Payment approved
//         print('Payment successful! AuthCode: ${result['authCode']}');
//         // TODO: update UI to show success (e.g., close modal, show confirmation dialog)
//       } else {
//         // Payment failed
//         print('Payment failed: ${result['message']} (Code: ${result['errorCode']})');
//         // TODO: display error to user
//       }
//     } else {
//       print('Server error: ${response.statusCode}');
//       // Handle server error
//     }
//   } catch (e) {
//     print('Request exception: $e');
//     // Handle network error
//   }
// }

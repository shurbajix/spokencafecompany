import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../Credit_Card/Credit_key.dart'; // Make sure your keys are stored securely

class StripeService {
  StripeService._();
  static final instance = StripeService._();

  Future<void> initialize() async {
    Stripe.publishableKey = stripPublishKey;
    await Stripe.instance.applySettings();
  }

  Future<bool> makePayment(int amount, {String currency = 'try'}) async {
    try {
      final clientSecret = await _createPaymentIntent(amount, currency);
      if (clientSecret == null) {
        return false;
      }

      await _initPaymentSheet(clientSecret);
      await Stripe.instance.presentPaymentSheet();
      return true;
    } on StripeException catch (e) {
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<String?> _createPaymentIntent(int amount, String currency) async {
    try {
      final dio = Dio();
      final response = await dio.post(
        'https://api.stripe.com/v1/payment_intents',
        data: {
          'amount': (amount * 100).toString(),
          'currency': currency,
          'payment_method_types[]': 'card',
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $stripSecritKey',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
      );
      return response.data['client_secret'] as String?;
    } catch (e) {
      print('Stripe payment intent creation failed: $e');
      return null;
    }
  }

  Future<void> _initPaymentSheet(String clientSecret) async {
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'Spoken Cafe',
        style: ThemeMode.light,
      ),
    );
  }
}

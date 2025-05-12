import 'package:flutter/material.dart';
import 'package:flutter_credit_card/flutter_credit_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreditCard extends ConsumerStatefulWidget {
  const CreditCard({
    super.key,
  });

  @override
  ConsumerState<CreditCard> createState() => _CreditCardState();
}

class _CreditCardState extends ConsumerState<CreditCard> {
  List cards = [
    {
      'cardNumber': '1234567891234567',
      'expiryDate': '04/24',
      'cardHolderName': 'Tracer',
      'cvvCode': '124',
      'showBackView': 'false',
    },
    {
      'cardNumber': '1234567891234565',
      'expiryDate': '04/30',
      'cardHolderName': 'Traced',
      'cvvCode': '774',
      'showBackView': 'false',
    },
  ];

  payViaExistingCard(BuildContext context, card) {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 20,
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xff1B1212),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () {},
          child: Text(
            'Add Card',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
            ),
          ),
        ),
      ),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(
            Icons.arrow_back_ios_new,color:Color(0xff1B1212),
          ),
        ),
        title: Text(
          'Credit Card',style:TextStyle(
            color:Color(0xff1B1212),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: cards.length,
        padding: EdgeInsets.zero,
        itemBuilder: (context, index) {
          var card = cards[index];
          return InkWell(
            onTap: () {
              payViaExistingCard(context, card);
            },
            child: CreditCardWidget(
              cardNumber: card['cardNumber'],
              expiryDate: card['expiryDate'],
              cardHolderName: card['cardHolderName'],
              cvvCode: card['cvvCode'],
              showBackView: false, //true when you want to show cvv(back) view
              onCreditCardWidgetChange: (CreditCardBrand
                  brand) {}, // Callback for anytime credit card brand is changed
            ),
          );
        },
      ),
    );
  }
}

class StripeTransactionResponse {
  String message;
  bool success;
  StripeTransactionResponse({required this.message, required this.success});
}

class StripeServer {
  static String apiBase = 'https//api.stripe.com//v1';
  static String secret = '';

  static init() {}

  static StripeTransactionResponse payViaExistingCard(
      {required String amount,
      required String currency,
      required String card}) {
    return StripeTransactionResponse(
        message: 'Transaction successful', success: true);
  }

  static StripeTransactionResponse payWithNewCard(
      {required String amount,
      required String currency,
      required String card}) {
    return StripeTransactionResponse(
        message: 'Transaction successful', success: true);
  }
}

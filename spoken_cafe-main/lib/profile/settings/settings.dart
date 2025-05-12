import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iban/iban.dart';

class Settingsd extends ConsumerStatefulWidget {
  const Settingsd({super.key});

  @override
  ConsumerState<Settingsd> createState() => _SettingsdState();
}

class _SettingsdState extends ConsumerState<Settingsd> {
  final _formKey = GlobalKey<FormState>();

  final _ibanController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _validationResult = '';

  void _validateIBAN() {
    String ibanDigits = _ibanController.text.trim();
    if (ibanDigits.isEmpty) {
      setState(() {
        _validationResult = 'Please enter an IBAN.';
      });
      return;
    }

    // Ensure the length is exactly 24 characters
    if (ibanDigits.length != 24) {
      setState(() {
        _validationResult = 'IBAN must be exactly 24 digits.';
      });
      return;
    }

    // Convert the entered digits back to an IBAN format
    String formattedIBAN = _formatIBAN(ibanDigits);

    if (isValid(formattedIBAN)) {
      setState(() {
        _validationResult = 'Valid IBAN!';
      });
    } else {
      setState(() {
        _validationResult = 'Invalid IBAN!';
      });
    }
  }

  String _formatIBAN(String ibanDigits) {
    // Assuming the IBAN format is known (e.g., GB for the UK)
    // Here we use a placeholder country code and length for demonstration
    String countryCode = 'GB';
    int totalLength =
        22; // Total length of the IBAN including country code and check digits

    // Ensure the length matches the expected IBAN length
    if (ibanDigits.length != totalLength - 2) {
      return '';
    }

    // Insert the country code and check digits
    return '$countryCode${ibanDigits.substring(0, 2)}${ibanDigits.substring(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 30,
        ),
        child: SizedBox(
          height: 44,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xff1B1212),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {},
            child: Text(
              'Send Payemnt',
              style: TextStyle(
                fontSize: 20,
                color: Colors.white,
                
              ),
            ),
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xff1B1212),
          ),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xff1B1212),
            
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Add IBAN',
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
            ),
            ...List.generate(
              3,
              (index) {
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  child: TextFormField(
                    controller: index == 0
                        ? _ibanController
                        : index == 1
                            ? _nameController
                            : _phoneController,
                    decoration: InputDecoration(
                      prefixIcon: index == 0
                          ? IconButton(
                              onPressed: () {},
                              icon: Icon(
                                Icons.check,
                              ),
                            )
                          : null,
                      suffixIcon: index == 0
                          ? IconButton(
                              onPressed: () {},
                              icon: Icon(
                                Icons.edit,
                              ),
                            )
                          : null,
                      counterText: '',
                      hintText: hinttext[index],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          10,
                        ),
                      ),
                    ),
                    keyboardType:
                        index == 0 ? TextInputType.number : TextInputType.text,
                    textInputAction: TextInputAction.done,
                    maxLength: index == 0 ? 24 : null,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter IBAN digits';
                      }
                      if (value.length != 24) {
                        return 'IBAN must be exactly 24 digits';
                      }
                      return null;
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
} //410020500009673983500001
//24

// this is will add this for drawer profile
List<String> profilelist = [
  'Profile',
  'Theme',
  'Settings',
];

List<String> hinttext = [
  'Enter IBAIN',
  'Enter Your Name',
  'Enter Your Phone Number',
];

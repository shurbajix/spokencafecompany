import 'package:flutter/material.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        spacing: 40,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/spken_cafe.png', width: 100, height: 100),
          Column(
            spacing: 20,
            children: [
              Text(
                'Name: Spoken Cafe',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 30),
              ),
              Text(
                'Email: spokencafe@gmail.com',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 30),
              ),
            ],
          ),

          Text(
            'Devleoper By: SUHIB CHARBAJI',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 25),
          ),
        ],
      ),
    );
  }
}

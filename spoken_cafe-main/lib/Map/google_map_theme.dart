// import 'package:flutter/material.dart';

// class GoogleMapTheme extends StatefulWidget {
//   const GoogleMapTheme({super.key});

//   @override
//   State<GoogleMapTheme> createState() => _GoogleMapThemeState();
// }

// class _GoogleMapThemeState extends State<GoogleMapTheme> {
//   String ThemeForMap = '';
//   @override
//   void initState() {
//     // TODO: implement initState
//     super.initState();
//     DefaultAssetBundle.of(context)
//         .loadString('Theme/dark_Theme.json')
//         .then((value) {
//       ThemeForMap = value;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         centerTitle: true,
//         leading: IconButton(
//           onPressed: () {
//             Navigator.pop(context);
//           },
//           icon: Icon(Icons.arrow_back_ios_new),
//         ),
//         title: const Text('Step-by-Step Walking Directions'),
//       ),
//       body: Column(
//         children: [],
//       ),
//     );
//   }
// }

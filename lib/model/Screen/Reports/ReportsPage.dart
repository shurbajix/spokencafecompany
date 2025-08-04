// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:intl/intl.dart';
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:path_provider/path_provider.dart';
// import 'dart:io';
// import 'dart:async';
// import 'package:share_plus/share_plus.dart';

// class ReportsPage extends StatefulWidget {
//   const ReportsPage({super.key});

//   @override
//   State<ReportsPage> createState() => _ReportsPageState();
// }

// class _ReportsPageState extends State<ReportsPage> {
//   String _selectedPeriod = 'Today';
//   DateTime _selectedDate = DateTime.now();
//   bool _isLoading = false;
//   Map<String, dynamic> _reportData = {};
  
//   // Dynamic pricing - can be updated from Firebase
//   double _studentPayment = 190.0;
//   double _teacherEarning = 150.0;
//   double _platformEarning = 40.0;
  
//   final List<String> _periods = ['Today', 'Week', 'Month', 'Year'];
//   final currencyFormatter = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

//   @override
//   void initState() {
//     super.initState();
//     _loadPricingData();
//     _loadReportData();
//     _startPricingListener();
//   }

//   // Load pricing data from Firebase
//   Future<void> _loadPricingData() async {
//     try {
//       final pricingDoc = await FirebaseFirestore.instance
//           .collection('app_settings')
//           .doc('pricing')
//           .get();
      
//       if (pricingDoc.exists) {
//         final data = pricingDoc.data()!;
//         setState(() {
//           _studentPayment = (data['studentPayment'] ?? 190.0).toDouble();
//           _teacherEarning = (data['teacherEarning'] ?? 150.0).toDouble();
//           _platformEarning = (data['platformEarning'] ?? 40.0).toDouble();
//         });
//         print('Pricing updated: Student=$_studentPayment, Teacher=$_teacherEarning, Platform=$_platformEarning');
//       }
//     } catch (e) {
//       print('Error loading pricing data: $e');
//       // Keep default values if loading fails
//     }
//   }

//   Future<void> _loadReportData() async {
//     setState(() {
//       _isLoading = true;
//     });

//     try {
//       // Reload pricing data first to ensure we have latest prices
//       await _loadPricingData();
      
//       final data = await _calculateReportData();
//       setState(() {
//         _reportData = data;
//         _isLoading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _isLoading = false;
//       });
//       print('Error loading report data: $e');
//     }
//   }

//   Future<Map<String, dynamic>> _calculateReportData() async {
//     final DateTime startDate = _getStartDate();
//     final DateTime endDate = _getEndDate();
    
//     print('Calculating report for: ${startDate.toIso8601String()} to ${endDate.toIso8601String()}');

//     try {
//       // Get all takenLessons within the date range
//       final takenLessonsQuery = await FirebaseFirestore.instance
//           .collection('takenLessons')
//           .get();

//       int totalStudents = 0;
//       int normalLessons = 0;
//       int activityLessons = 0;
//       double totalRevenue = 0;
//       double teacherEarnings = 0;
//       double platformEarnings = 0;

//       // Filter lessons by date range
//       for (var doc in takenLessonsQuery.docs) {
//         final data = doc.data();
//         final lessonDateTime = data['dateTime'];
        
//         DateTime lessonDate;
//         if (lessonDateTime is Timestamp) {
//           lessonDate = lessonDateTime.toDate();
//         } else if (lessonDateTime is String) {
//           lessonDate = DateTime.tryParse(lessonDateTime) ?? DateTime.now();
//         } else {
//           continue;
//         }

//         // Check if lesson is within the selected period
//         if (lessonDate.isAfter(startDate) && lessonDate.isBefore(endDate)) {
//           totalStudents++;
          
//           final speakLevel = data['speakLevel'] ?? 'normal';
//           if (speakLevel.toLowerCase() == 'activity') {
//             activityLessons++;
//           } else {
//             normalLessons++;
//           }

//           // Calculate earnings using dynamic pricing
//           totalRevenue += _studentPayment;
//           teacherEarnings += _teacherEarning;
//           platformEarnings += _platformEarning;
//         }
//       }

//       return {
//         'totalStudents': totalStudents,
//         'normalLessons': normalLessons,
//         'activityLessons': activityLessons,
//         'totalRevenue': totalRevenue,
//         'teacherEarnings': teacherEarnings,
//         'platformEarnings': platformEarnings,
//         'startDate': startDate,
//         'endDate': endDate,
//         'period': _selectedPeriod,
//       };
//     } catch (e) {
//       print('Error calculating report data: $e');
//       return {
//         'totalStudents': 0,
//         'normalLessons': 0,
//         'activityLessons': 0,
//         'totalRevenue': 0,
//         'teacherEarnings': 0,
//         'platformEarnings': 0,
//         'startDate': startDate,
//         'endDate': endDate,
//         'period': _selectedPeriod,
//       };
//     }
//   }

//   DateTime _getStartDate() {
//     final now = DateTime.now();
//     switch (_selectedPeriod) {
//       case 'Today':
//         return DateTime(now.year, now.month, now.day);
//       case 'Week':
//         final weekStart = now.subtract(Duration(days: now.weekday - 1));
//         return DateTime(weekStart.year, weekStart.month, weekStart.day);
//       case 'Month':
//         return DateTime(now.year, now.month, 1);
//       case 'Year':
//         return DateTime(now.year, 1, 1);
//       default:
//         return DateTime(now.year, now.month, now.day);
//     }
//   }

//   DateTime _getEndDate() {
//     final now = DateTime.now();
//     switch (_selectedPeriod) {
//       case 'Today':
//         return DateTime(now.year, now.month, now.day, 23, 59, 59);
//       case 'Week':
//         final weekStart = now.subtract(Duration(days: now.weekday - 1));
//         final weekEnd = weekStart.add(const Duration(days: 6));
//         return DateTime(weekEnd.year, weekEnd.month, weekEnd.day, 23, 59, 59);
//       case 'Month':
//         final nextMonth = DateTime(now.year, now.month + 1, 1);
//         return nextMonth.subtract(const Duration(days: 1));
//       case 'Year':
//         return DateTime(now.year, 12, 31, 23, 59, 59);
//       default:
//         return DateTime(now.year, now.month, now.day, 23, 59, 59);
//     }
//   }

//   void _changePeriod(String period) {
//     setState(() {
//       _selectedPeriod = period;
//     });
//     _loadReportData();
//   }

//   StreamSubscription? _pricingSubscription;

//   // Add real-time listener for pricing changes
//   void _startPricingListener() {
//     _pricingSubscription = FirebaseFirestore.instance
//         .collection('app_settings')
//         .doc('pricing')
//         .snapshots()
//         .listen((snapshot) {
//       if (snapshot.exists && mounted) {
//         final data = snapshot.data()!;
//         setState(() {
//           _studentPayment = (data['studentPayment'] ?? 190.0).toDouble();
//           _teacherEarning = (data['teacherEarning'] ?? 150.0).toDouble();
//           _platformEarning = (data['platformEarning'] ?? 40.0).toDouble();
//         });
//         print('Pricing updated in real-time: Student=$_studentPayment, Teacher=$_teacherEarning, Platform=$_platformEarning');
//         // Reload report data with new pricing
//         _loadReportData();
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _pricingSubscription?.cancel();
//     super.dispose();
//   }

//   Future<void> _downloadPDF() async {
//     try {
//       final pdf = pw.Document();
      
//       // Add beautiful header
//       pdf.addPage(
//         pw.Page(
//           pageFormat: PdfPageFormat.a4,
//           build: (pw.Context context) {
//             return pw.Column(
//               crossAxisAlignment: pw.CrossAxisAlignment.start,
//               children: [
//                 // Header with logo and title
//                 pw.Container(
//                   padding: const pw.EdgeInsets.all(20),
//                   decoration: pw.BoxDecoration(
//                     color: PdfColors.blue900,
//                     borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
//                   ),
//                   child: pw.Row(
//                     children: [
//                       pw.Container(
//                         width: 50,
//                         height: 50,
//                         decoration: const pw.BoxDecoration(
//                           color: PdfColors.white,
//                           shape: pw.BoxShape.circle,
//                         ),
//                         child: pw.Center(
//                           child: pw.Text(
//                             'SC',
//                             style: pw.TextStyle(
//                               fontSize: 20,
//                               fontWeight: pw.FontWeight.bold,
//                               color: PdfColors.blue900,
//                             ),
//                           ),
//                         ),
//                       ),
//                       pw.SizedBox(width: 20),
//                       pw.Expanded(
//                         child: pw.Column(
//                           crossAxisAlignment: pw.CrossAxisAlignment.start,
//                           children: [
//                             pw.Text(
//                               'Spoken Cafe',
//                               style: pw.TextStyle(
//                                 fontSize: 24,
//                                 fontWeight: pw.FontWeight.bold,
//                                 color: PdfColors.white,
//                               ),
//                             ),
//                             pw.Text(
//                               'Financial Report - ${_selectedPeriod}',
//                               style: pw.TextStyle(
//                                 fontSize: 16,
//                                 color: PdfColors.white,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       pw.Text(
//                         DateFormat('yyyy/MM/dd').format(DateTime.now()),
//                         style: pw.TextStyle(
//                           fontSize: 14,
//                           color: PdfColors.white,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
                
//                 pw.SizedBox(height: 30),
                
//                 // Period information
//                 pw.Container(
//                   padding: const pw.EdgeInsets.all(15),
//                   decoration: pw.BoxDecoration(
//                     color: PdfColors.grey100,
//                     borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
//                   ),
//                   child: pw.Row(
//                     children: [
//                       pw.Icon(pw.IconData(0xe878), color: PdfColors.blue900, size: 20),
//                       pw.SizedBox(width: 10),
//                       pw.Text(
//                         'Report Period: ${DateFormat('yyyy/MM/dd').format(_reportData['startDate'])} - ${DateFormat('yyyy/MM/dd').format(_reportData['endDate'])}',
//                         style: pw.TextStyle(
//                           fontSize: 16,
//                           fontWeight: pw.FontWeight.bold,
//                           color: PdfColors.blue900,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
                
//                 pw.SizedBox(height: 30),
                
//                 // Financial Summary
//                 pw.Text(
//                   'Financial Summary',
//                   style: pw.TextStyle(
//                     fontSize: 20,
//                     fontWeight: pw.FontWeight.bold,
//                     color: PdfColors.blue900,
//                   ),
//                 ),
                
//                 pw.SizedBox(height: 20),
                
//                 // Revenue breakdown
//                 pw.Container(
//                   padding: const pw.EdgeInsets.all(20),
//                   decoration: pw.BoxDecoration(
//                     color: PdfColors.green50,
//                     borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
//                     border: pw.Border.all(color: PdfColors.green200),
//                   ),
//                   child: pw.Column(
//                     children: [
//                       pw.Row(
//                         mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//                         children: [
//                           pw.Text(
//                             'Total Revenue:',
//                             style: pw.TextStyle(
//                               fontSize: 18,
//                               fontWeight: pw.FontWeight.bold,
//                               color: PdfColors.green900,
//                             ),
//                           ),
//                           pw.Text(
//                             '${_reportData['totalRevenue'].toStringAsFixed(0)} ₺',
//                             style: pw.TextStyle(
//                               fontSize: 24,
//                               fontWeight: pw.FontWeight.bold,
//                               color: PdfColors.green900,
//                             ),
//                           ),
//                         ],
//                       ),
//                       pw.SizedBox(height: 15),
//                       pw.Divider(color: PdfColors.green200),
//                       pw.SizedBox(height: 15),
//                       pw.Row(
//                         mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//                         children: [
//                           pw.Text(
//                             'Teacher Earnings:',
//                             style: pw.TextStyle(
//                               fontSize: 16,
//                               color: PdfColors.green800,
//                             ),
//                           ),
//                           pw.Text(
//                             '${_reportData['teacherEarnings'].toStringAsFixed(0)} ₺',
//                             style: pw.TextStyle(
//                               fontSize: 18,
//                               fontWeight: pw.FontWeight.bold,
//                               color: PdfColors.green800,
//                             ),
//                           ),
//                         ],
//                       ),
//                       pw.SizedBox(height: 10),
//                       pw.Row(
//                         mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//                         children: [
//                           pw.Text(
//                             'Platform Earnings:',
//                             style: pw.TextStyle(
//                               fontSize: 16,
//                               color: PdfColors.green800,
//                             ),
//                           ),
//                           pw.Text(
//                             '${_reportData['platformEarnings'].toStringAsFixed(0)} ₺',
//                             style: pw.TextStyle(
//                               fontSize: 18,
//                               fontWeight: pw.FontWeight.bold,
//                               color: PdfColors.green800,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
                
//                 pw.SizedBox(height: 30),
                
//                 // Lesson Statistics
//                 pw.Text(
//                   'Lesson Statistics',
//                   style: pw.TextStyle(
//                     fontSize: 20,
//                     fontWeight: pw.FontWeight.bold,
//                     color: PdfColors.blue900,
//                   ),
//                 ),
                
//                 pw.SizedBox(height: 20),
                
//                 pw.Row(
//                   children: [
//                     pw.Expanded(
//                       child: pw.Container(
//                         padding: const pw.EdgeInsets.all(15),
//                         decoration: pw.BoxDecoration(
//                           color: PdfColors.blue50,
//                           borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
//                           border: pw.Border.all(color: PdfColors.blue200),
//                         ),
//                         child: pw.Column(
//                           children: [
//                             pw.Text(
//                               '${_reportData['totalStudents']}',
//                               style: pw.TextStyle(
//                                 fontSize: 24,
//                                 fontWeight: pw.FontWeight.bold,
//                                 color: PdfColors.blue900,
//                               ),
//                             ),
//                             pw.Text(
//                               'Total Students',
//                               style: pw.TextStyle(
//                                 fontSize: 14,
//                                 color: PdfColors.blue700,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                     pw.SizedBox(width: 15),
//                     pw.Expanded(
//                       child: pw.Container(
//                         padding: const pw.EdgeInsets.all(15),
//                         decoration: pw.BoxDecoration(
//                           color: PdfColors.orange50,
//                           borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
//                           border: pw.Border.all(color: PdfColors.orange200),
//                         ),
//                         child: pw.Column(
//                           children: [
//                             pw.Text(
//                               '${_reportData['normalLessons']}',
//                               style: pw.TextStyle(
//                                 fontSize: 24,
//                                 fontWeight: pw.FontWeight.bold,
//                                 color: PdfColors.orange900,
//                               ),
//                             ),
//                             pw.Text(
//                               'Normal Lessons',
//                               style: pw.TextStyle(
//                                 fontSize: 14,
//                                 color: PdfColors.orange700,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                     pw.SizedBox(width: 15),
//                     pw.Expanded(
//                       child: pw.Container(
//                         padding: const pw.EdgeInsets.all(15),
//                         decoration: pw.BoxDecoration(
//                           color: PdfColors.green50,
//                           borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
//                           border: pw.Border.all(color: PdfColors.green200),
//                         ),
//                         child: pw.Column(
//                           children: [
//                             pw.Text(
//                               '${_reportData['activityLessons']}',
//                               style: pw.TextStyle(
//                                 fontSize: 24,
//                                 fontWeight: pw.FontWeight.bold,
//                                 color: PdfColors.green900,
//                               ),
//                             ),
//                             pw.Text(
//                               'Activity Lessons',
//                               style: pw.TextStyle(
//                                 fontSize: 14,
//                                 color: PdfColors.green700,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
                
//                 pw.SizedBox(height: 30),
                
//                 // Pricing Breakdown
//                 pw.Container(
//                   padding: const pw.EdgeInsets.all(15),
//                   decoration: pw.BoxDecoration(
//                     color: PdfColors.purple50,
//                     borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
//                     border: pw.Border.all(color: PdfColors.purple200),
//                   ),
//                   child: pw.Column(
//                     crossAxisAlignment: pw.CrossAxisAlignment.start,
//                     children: [
//                       pw.Text(
//                         'Pricing Breakdown',
//                         style: pw.TextStyle(
//                           fontSize: 18,
//                           fontWeight: pw.FontWeight.bold,
//                           color: PdfColors.purple900,
//                         ),
//                       ),
//                       pw.SizedBox(height: 15),
//                       pw.Row(
//                         children: [
//                           pw.Expanded(
//                             child: pw.Column(
//                               crossAxisAlignment: pw.CrossAxisAlignment.start,
//                               children: [
//                                 pw.Text(
//                                   'Student Pays:',
//                                   style: pw.TextStyle(
//                                     fontSize: 14,
//                                     color: PdfColors.grey600,
//                                   ),
//                                 ),
//                                 pw.Text(
//                                   '${_studentPayment.toStringAsFixed(0)} ₺',
//                                   style: pw.TextStyle(
//                                     fontSize: 16,
//                                     fontWeight: pw.FontWeight.bold,
//                                     color: PdfColors.black,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                           pw.Expanded(
//                             child: pw.Column(
//                               crossAxisAlignment: pw.CrossAxisAlignment.start,
//                               children: [
//                                 pw.Text(
//                                   'Teacher Gets:',
//                                   style: pw.TextStyle(
//                                     fontSize: 14,
//                                     color: PdfColors.grey600,
//                                   ),
//                                 ),
//                                 pw.Text(
//                                   '${_teacherEarning.toStringAsFixed(0)} ₺',
//                                   style: pw.TextStyle(
//                                     fontSize: 16,
//                                     fontWeight: pw.FontWeight.bold,
//                                     color: PdfColors.green700,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                           pw.Expanded(
//                             child: pw.Column(
//                               crossAxisAlignment: pw.CrossAxisAlignment.start,
//                               children: [
//                                 pw.Text(
//                                   'Platform Gets:',
//                                   style: pw.TextStyle(
//                                     fontSize: 14,
//                                     color: PdfColors.grey600,
//                                   ),
//                                 ),
//                                 pw.Text(
//                                   '${_platformEarning.toStringAsFixed(0)} ₺',
//                                   style: pw.TextStyle(
//                                     fontSize: 16,
//                                     fontWeight: pw.FontWeight.bold,
//                                     color: PdfColors.orange700,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
                
//                 pw.SizedBox(height: 30),
                
//                 // Footer
//                 pw.Container(
//                   padding: const pw.EdgeInsets.all(15),
//                   decoration: pw.BoxDecoration(
//                     color: PdfColors.grey100,
//                     borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
//                   ),
//                   child: pw.Text(
//                     'Report generated on ${DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now())}',
//                     style: pw.TextStyle(
//                       fontSize: 12,
//                       color: PdfColors.grey600,
//                     ),
//                     textAlign: pw.TextAlign.center,
//                   ),
//                 ),
//               ],
//             );
//           },
//         ),
//       );

//       final pdfBytes = await pdf.save();

//       // Save to temporary directory and share
//       final tempDir = await getTemporaryDirectory();
//       final file = File('${tempDir.path}/spoken_cafe_report_${_selectedPeriod.toLowerCase()}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');
//       await file.writeAsBytes(pdfBytes);

//       if (mounted) {
//         await Share.shareXFiles(
//           [XFile(file.path)],
//           text: 'Spoken Cafe Financial Report - ${_selectedPeriod}',
//         );
        
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('PDF report shared successfully'),
//             backgroundColor: Colors.green,
//             behavior: SnackBarBehavior.floating,
//           ),
//         );
//       }
//     } catch (e) {
//       print('Error generating PDF: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error generating PDF: $e'),
//             backgroundColor: Colors.red,
//             behavior: SnackBarBehavior.floating,
//           ),
//         );
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[50],
//       body: Column(
//         children: [
//           // Header
//           Container(
//             padding: const EdgeInsets.all(20),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.grey.withOpacity(0.1),
//                   spreadRadius: 1,
//                   blurRadius: 5,
//                   offset: const Offset(0, 2),
//                 ),
//               ],
//             ),
//             child: Column(
//               children: [
//                 Row(
//                   children: [
//                     Container(
//                       padding: const EdgeInsets.all(12),
//                       decoration: BoxDecoration(
//                         color: const Color(0xff1B1212),
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: const Icon(
//                         Icons.analytics,
//                         color: Colors.white,
//                         size: 24,
//                       ),
//                     ),
//                     const SizedBox(width: 16),
//                     const Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             'Financial Reports',
//                             style: TextStyle(
//                               fontSize: 24,
//                               fontWeight: FontWeight.bold,
//                               color: Color(0xff1B1212),
//                             ),
//                           ),
//                           Text(
//                             'Track your earnings and performance',
//                             style: TextStyle(
//                               fontSize: 14,
//                               color: Colors.grey,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     IconButton(
//                       onPressed: _downloadPDF,
//                       icon: const Icon(Icons.download),
//                       tooltip: 'Download PDF Report',
//                     ),
//                   ],
//                 ),
                
//                 const SizedBox(height: 20),
                
//                 // Period Selector
//                 Container(
//                   padding: const EdgeInsets.all(4),
//                   decoration: BoxDecoration(
//                     color: Colors.grey[100],
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: Row(
//                     children: _periods.map((period) {
//                       final isSelected = _selectedPeriod == period;
//                       return Expanded(
//                         child: GestureDetector(
//                           onTap: () => _changePeriod(period),
//                           child: Container(
//                             padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
//                             decoration: BoxDecoration(
//                               color: isSelected ? const Color(0xff1B1212) : Colors.transparent,
//                               borderRadius: BorderRadius.circular(8),
//                             ),
//                             child: Text(
//                               period,
//                               textAlign: TextAlign.center,
//                               style: TextStyle(
//                                 fontSize: 14,
//                                 fontWeight: FontWeight.w600,
//                                 color: isSelected ? Colors.white : Colors.grey[600],
//                               ),
//                             ),
//                           ),
//                         ),
//                       );
//                     }).toList(),
//                   ),
//                 ),
//               ],
//             ),
//           ),
          
//           // Content
//           Expanded(
//             child: _isLoading
//                 ? const Center(
//                     child: CircularProgressIndicator(
//                       color: Color(0xff1B1212),
//                       backgroundColor: Colors.white,
//                     ),
//                   )
//                 : RefreshIndicator(
//                     onRefresh: _loadReportData,
//                     child: SingleChildScrollView(
//                       padding: const EdgeInsets.all(20),
//                       child: Column(
//                         children: [
//                           // Financial Summary Card
//                           Container(
//                             width: double.infinity,
//                             padding: const EdgeInsets.all(24),
//                             decoration: BoxDecoration(
//                               gradient: LinearGradient(
//                                 colors: [Colors.blue[600]!, Colors.blue[800]!],
//                                 begin: Alignment.topLeft,
//                                 end: Alignment.bottomRight,
//                               ),
//                               borderRadius: BorderRadius.circular(16),
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: Colors.blue.withOpacity(0.3),
//                                   spreadRadius: 2,
//                                   blurRadius: 10,
//                                   offset: const Offset(0, 4),
//                                 ),
//                               ],
//                             ),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Row(
//                                   children: [
//                                     const Icon(
//                                       Icons.trending_up,
//                                       color: Colors.white,
//                                       size: 24,
//                                     ),
//                                     const SizedBox(width: 12),
//                                     const Text(
//                                       'Financial Summary',
//                                       style: TextStyle(
//                                         fontSize: 20,
//                                         fontWeight: FontWeight.bold,
//                                         color: Colors.white,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                                 const SizedBox(height: 20),
//                                 Row(
//                                   children: [
//                                     Expanded(
//                                       child: Column(
//                                         crossAxisAlignment: CrossAxisAlignment.start,
//                                         children: [
//                                           const Text(
//                                             'Total Revenue',
//                                             style: TextStyle(
//                                               fontSize: 14,
//                                               color: Colors.white70,
//                                             ),
//                                           ),
//                                           const SizedBox(height: 4),
//                                           Text(
//                                             '${_reportData['totalRevenue']?.toStringAsFixed(0) ?? '0'} ₺',
//                                             style: const TextStyle(
//                                               fontSize: 28,
//                                               fontWeight: FontWeight.bold,
//                                               color: Colors.white,
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                     Container(
//                                       width: 1,
//                                       height: 50,
//                                       color: Colors.white24,
//                                     ),
//                                     Expanded(
//                                       child: Column(
//                                         crossAxisAlignment: CrossAxisAlignment.start,
//                                         children: [
//                                           const Text(
//                                             'Period',
//                                             style: TextStyle(
//                                               fontSize: 14,
//                                               color: Colors.white70,
//                                             ),
//                                           ),
//                                           const SizedBox(height: 4),
//                                           Text(
//                                             _selectedPeriod,
//                                             style: const TextStyle(
//                                               fontSize: 18,
//                                               fontWeight: FontWeight.bold,
//                                               color: Colors.white,
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ],
//                             ),
//                           ),
                          
//                           const SizedBox(height: 20),
                          
//                           // Earnings Breakdown
//                           Row(
//                             children: [
//                               Expanded(
//                                 child: Container(
//                                   padding: const EdgeInsets.all(20),
//                                   decoration: BoxDecoration(
//                                     color: Colors.green[50],
//                                     borderRadius: BorderRadius.circular(12),
//                                     border: Border.all(color: Colors.green[200]!),
//                                   ),
//                                   child: Column(
//                                     children: [
//                                       Icon(
//                                         Icons.person,
//                                         color: Colors.green[600],
//                                         size: 32,
//                                       ),
//                                       const SizedBox(height: 12),
//                                       Text(
//                                         '${_reportData['teacherEarnings']?.toStringAsFixed(0) ?? '0'} ₺',
//                                         style: TextStyle(
//                                           fontSize: 20,
//                                           fontWeight: FontWeight.bold,
//                                           color: Colors.green[700],
//                                         ),
//                                       ),
//                                       const SizedBox(height: 4),
//                                       const Text(
//                                         'Teacher Earnings',
//                                         style: TextStyle(
//                                           fontSize: 12,
//                                           color: Colors.grey,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ),
//                               const SizedBox(width: 12),
//                               Expanded(
//                                 child: Container(
//                                   padding: const EdgeInsets.all(20),
//                                   decoration: BoxDecoration(
//                                     color: Colors.orange[50],
//                                     borderRadius: BorderRadius.circular(12),
//                                     border: Border.all(color: Colors.orange[200]!),
//                                   ),
//                                   child: Column(
//                                     children: [
//                                       Icon(
//                                         Icons.business,
//                                         color: Colors.orange[600],
//                                         size: 32,
//                                       ),
//                                       const SizedBox(height: 12),
//                                       Text(
//                                         '${_reportData['platformEarnings']?.toStringAsFixed(0) ?? '0'} ₺',
//                                         style: TextStyle(
//                                           fontSize: 20,
//                                           fontWeight: FontWeight.bold,
//                                           color: Colors.orange[700],
//                                         ),
//                                       ),
//                                       const SizedBox(height: 4),
//                                       const Text(
//                                         'Platform Earnings',
//                                         style: TextStyle(
//                                           fontSize: 12,
//                                           color: Colors.grey,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
                          
//                           const SizedBox(height: 20),
                          
//                           // Lesson Statistics
//                           Container(
//                             width: double.infinity,
//                             padding: const EdgeInsets.all(24),
//                             decoration: BoxDecoration(
//                               color: Colors.white,
//                               borderRadius: BorderRadius.circular(16),
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: Colors.grey.withOpacity(0.1),
//                                   spreadRadius: 1,
//                                   blurRadius: 10,
//                                   offset: const Offset(0, 2),
//                                 ),
//                               ],
//                             ),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Row(
//                                   children: [
//                                     const Icon(
//                                       Icons.school,
//                                       color: Color(0xff1B1212),
//                                       size: 24,
//                                     ),
//                                     const SizedBox(width: 12),
//                                     const Text(
//                                       'Lesson Statistics',
//                                       style: TextStyle(
//                                         fontSize: 20,
//                                         fontWeight: FontWeight.bold,
//                                         color: Color(0xff1B1212),
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                                 const SizedBox(height: 20),
//                                 Row(
//                                   children: [
//                                     Expanded(
//                                       child: _buildStatCard(
//                                         '${_reportData['totalStudents'] ?? 0}',
//                                         'Total Students',
//                                         Colors.blue,
//                                         Icons.people,
//                                       ),
//                                     ),
//                                     const SizedBox(width: 12),
//                                     Expanded(
//                                       child: _buildStatCard(
//                                         '${_reportData['normalLessons'] ?? 0}',
//                                         'Normal Lessons',
//                                         Colors.green,
//                                         Icons.sports,
//                                       ),
//                                     ),
//                                     const SizedBox(width: 12),
//                                     Expanded(
//                                       child: _buildStatCard(
//                                         '${_reportData['activityLessons'] ?? 0}',
//                                         'Activity Lessons',
//                                         Colors.orange,
//                                         Icons.fitness_center,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ],
//                             ),
//                           ),
                          
//                           const SizedBox(height: 20),
                          
//                           // Pricing Information
//                           Container(
//                             width: double.infinity,
//                             padding: const EdgeInsets.all(20),
//                             decoration: BoxDecoration(
//                               color: Colors.purple[50],
//                               borderRadius: BorderRadius.circular(12),
//                               border: Border.all(color: Colors.purple[200]!),
//                             ),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Row(
//                                   children: [
//                                     Icon(
//                                       Icons.info_outline,
//                                       color: Colors.purple[600],
//                                       size: 20,
//                                     ),
//                                     const SizedBox(width: 8),
//                                     Text(
//                                       'Pricing Breakdown',
//                                       style: TextStyle(
//                                         fontSize: 16,
//                                         fontWeight: FontWeight.bold,
//                                         color: Colors.purple[700],
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                                 const SizedBox(height: 12),
//                                 Row(
//                                   children: [
//                                     Expanded(
//                                       child: Column(
//                                         crossAxisAlignment: CrossAxisAlignment.start,
//                                         children: [
//                                           const Text(
//                                             'Student Pays:',
//                                             style: TextStyle(
//                                               fontSize: 14,
//                                               color: Colors.grey,
//                                             ),
//                                           ),
//                                           Text(
//                                             '${_studentPayment.toStringAsFixed(0)} ₺',
//                                             style: const TextStyle(
//                                               fontSize: 16,
//                                               fontWeight: FontWeight.bold,
//                                               color: Colors.black,
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                     Expanded(
//                                       child: Column(
//                                         crossAxisAlignment: CrossAxisAlignment.start,
//                                         children: [
//                                           const Text(
//                                             'Teacher Gets:',
//                                             style: TextStyle(
//                                               fontSize: 14,
//                                               color: Colors.grey,
//                                             ),
//                                           ),
//                                           Text(
//                                             '${_teacherEarning.toStringAsFixed(0)} ₺',
//                                             style: const TextStyle(
//                                               fontSize: 16,
//                                               fontWeight: FontWeight.bold,
//                                               color: Colors.green,
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                     Expanded(
//                                       child: Column(
//                                         crossAxisAlignment: CrossAxisAlignment.start,
//                                         children: [
//                                           const Text(
//                                             'Platform Gets:',
//                                             style: TextStyle(
//                                               fontSize: 14,
//                                               color: Colors.grey,
//                                             ),
//                                           ),
//                                           Text(
//                                             '${_platformEarning.toStringAsFixed(0)} ₺',
//                                             style: const TextStyle(
//                                               fontSize: 16,
//                                               fontWeight: FontWeight.bold,
//                                               color: Colors.orange,
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//         ],
//       ),
//     );
//   }

//   Widget _buildStatCard(String value, String label, Color color, IconData icon) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: color.withOpacity(0.3)),
//       ),
//       child: Column(
//         children: [
//           Icon(icon, color: color, size: 24),
//           const SizedBox(height: 8),
//           Text(
//             value,
//             style: TextStyle(
//               fontSize: 20,
//               fontWeight: FontWeight.bold,
//               color: color,
//             ),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             label,
//             style: const TextStyle(
//               fontSize: 12,
//               color: Colors.grey,
//             ),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }
// } 

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import 'package:share_plus/share_plus.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String _selectedPeriod = 'Today';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  Map<String, dynamic> _reportData = {};

  // Dynamic pricing - can be updated from Firebase
  double _studentPayment = 190.0;
  double _teacherEarning = 150.0;
  double _platformEarning = 40.0;

  final List<String> _periods = ['Today', 'Week', 'Month', 'Year'];
  final currencyFormatter = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

  StreamSubscription? _pricingSubscription;

  @override
  void initState() {
    super.initState();
    _loadPricingData();
    _loadReportData();
    _startPricingListener();
  }

  // Load pricing data from Firebase
  Future<void> _loadPricingData() async {
    try {
      final pricingDoc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('pricing')
          .get();

      if (pricingDoc.exists && mounted) {
        final data = pricingDoc.data()!;
        setState(() {
          _studentPayment = (data['studentPayment'] ?? 190.0).toDouble();
          _teacherEarning = (data['teacherEarning'] ?? 150.0).toDouble();
          _platformEarning = (data['platformEarning'] ?? 40.0).toDouble();
        });
        print(
            'Pricing updated: Student=$_studentPayment, Teacher=$_teacherEarning, Platform=$_platformEarning');
      }
    } catch (e) {
      print('Error loading pricing data: $e');
      // Keep default values if loading fails
    }
  }

  Future<void> _loadReportData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      // Reload pricing data first to ensure we have latest prices
      await _loadPricingData();

      final data = await _calculateReportData();

      if (!mounted) return;
      setState(() {
        _reportData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      print('Error loading report data: $e');
    }
  }

  Future<Map<String, dynamic>> _calculateReportData() async {
    final DateTime startDate = _getStartDate();
    final DateTime endDate = _getEndDate();

    print(
        'Calculating report for: ${startDate.toIso8601String()} to ${endDate.toIso8601String()}');

    try {
      // Get all takenLessons within the date range
      final takenLessonsQuery = await FirebaseFirestore.instance
          .collection('takenLessons')
          .get();

      int totalStudents = 0;
      int normalLessons = 0;
      int activityLessons = 0;
      double totalRevenue = 0;
      double teacherEarnings = 0;
      double platformEarnings = 0;

      // Filter lessons by date range
      for (var doc in takenLessonsQuery.docs) {
        final data = doc.data();
        final lessonDateTime = data['dateTime'];

        DateTime lessonDate;
        if (lessonDateTime is Timestamp) {
          lessonDate = lessonDateTime.toDate();
        } else if (lessonDateTime is String) {
          lessonDate = DateTime.tryParse(lessonDateTime) ?? DateTime.now();
        } else {
          continue;
        }

        // Check if lesson is within the selected period
        if (lessonDate.isAfter(startDate) && lessonDate.isBefore(endDate)) {
          totalStudents++;

          final speakLevel = data['speakLevel'] ?? 'normal';
          if (speakLevel.toLowerCase() == 'activity') {
            activityLessons++;
          } else {
            normalLessons++;
          }

          // Calculate earnings using dynamic pricing
          totalRevenue += _studentPayment;
          teacherEarnings += _teacherEarning;
          platformEarnings += _platformEarning;
        }
      }

      return {
        'totalStudents': totalStudents,
        'normalLessons': normalLessons,
        'activityLessons': activityLessons,
        'totalRevenue': totalRevenue,
        'teacherEarnings': teacherEarnings,
        'platformEarnings': platformEarnings,
        'startDate': startDate,
        'endDate': endDate,
        'period': _selectedPeriod,
      };
    } catch (e) {
      print('Error calculating report data: $e');
      return {
        'totalStudents': 0,
        'normalLessons': 0,
        'activityLessons': 0,
        'totalRevenue': 0,
        'teacherEarnings': 0,
        'platformEarnings': 0,
        'startDate': startDate,
        'endDate': endDate,
        'period': _selectedPeriod,
      };
    }
  }

  DateTime _getStartDate() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'Today':
        return DateTime(now.year, now.month, now.day);
      case 'Week':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(weekStart.year, weekStart.month, weekStart.day);
      case 'Month':
        return DateTime(now.year, now.month, 1);
      case 'Year':
        return DateTime(now.year, 1, 1);
      default:
        return DateTime(now.year, now.month, now.day);
    }
  }

  DateTime _getEndDate() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'Today':
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
      case 'Week':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));
        return DateTime(weekEnd.year, weekEnd.month, weekEnd.day, 23, 59, 59);
      case 'Month':
        final nextMonth = DateTime(now.year, now.month + 1, 1);
        return nextMonth.subtract(const Duration(days: 1));
      case 'Year':
        return DateTime(now.year, 12, 31, 23, 59, 59);
      default:
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
    }
  }

  void _changePeriod(String period) {
    setState(() {
      _selectedPeriod = period;
    });
    _loadReportData();
  }

  // Add real-time listener for pricing changes
  void _startPricingListener() {
    _pricingSubscription = FirebaseFirestore.instance
        .collection('app_settings')
        .doc('pricing')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data()!;
        setState(() {
          _studentPayment = (data['studentPayment'] ?? 190.0).toDouble();
          _teacherEarning = (data['teacherEarning'] ?? 150.0).toDouble();
          _platformEarning = (data['platformEarning'] ?? 40.0).toDouble();
        });
        print(
            'Pricing updated in real-time: Student=$_studentPayment, Teacher=$_teacherEarning, Platform=$_platformEarning');
        // Reload report data with new pricing
        _loadReportData();
      }
    });
  }

  @override
  void dispose() {
    _pricingSubscription?.cancel();
    super.dispose();
  }

  Future<void> _downloadPDF() async {
    try {
      final pdf = pw.Document();

      // Add beautiful header
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header with logo and title
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue900,
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(10)),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 50,
                        height: 50,
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.white,
                          shape: pw.BoxShape.circle,
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            'SC',
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 20),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Spoken Cafe',
                              style: pw.TextStyle(
                                fontSize: 24,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                            pw.Text(
                              'Financial Report - ${_selectedPeriod}',
                              style: pw.TextStyle(
                                fontSize: 16,
                                color: PdfColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.Text(
                        DateFormat('yyyy/MM/dd').format(DateTime.now()),
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 30),

                // Period information
                pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Icon(pw.IconData(0xe878),
                          color: PdfColors.blue900, size: 20),
                      pw.SizedBox(width: 10),
                      pw.Text(
                        'Report Period: ${DateFormat('yyyy/MM/dd').format(_reportData['startDate'])} - ${DateFormat('yyyy/MM/dd').format(_reportData['endDate'])}',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 30),

                // Financial Summary
                pw.Text(
                  'Financial Summary',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),

                pw.SizedBox(height: 20),

                // Revenue breakdown
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                    border: pw.Border.all(color: PdfColors.green200),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Total Revenue:',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green900,
                            ),
                          ),
                          pw.Text(
                            '${_reportData['totalRevenue'].toStringAsFixed(0)} ₺',
                            style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green900,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 15),
                      pw.Divider(color: PdfColors.green200),
                      pw.SizedBox(height: 15),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Teacher Earnings:',
                            style: pw.TextStyle(
                              fontSize: 16,
                              color: PdfColors.green800,
                            ),
                          ),
                          pw.Text(
                            '${_reportData['teacherEarnings'].toStringAsFixed(0)} ₺',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green800,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 10),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Platform Earnings:',
                            style: pw.TextStyle(
                              fontSize: 16,
                              color: PdfColors.green800,
                            ),
                          ),
                          pw.Text(
                            '${_reportData['platformEarnings'].toStringAsFixed(0)} ₺',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 30),

                // Lesson Statistics
                pw.Text(
                  'Lesson Statistics',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),

                pw.SizedBox(height: 20),

                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(15),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue50,
                          borderRadius:
                              const pw.BorderRadius.all(pw.Radius.circular(8)),
                          border: pw.Border.all(color: PdfColors.blue200),
                        ),
                        child: pw.Column(
                          children: [
                            pw.Text(
                              '${_reportData['totalStudents']}',
                              style: pw.TextStyle(
                                fontSize: 24,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue900,
                              ),
                            ),
                            pw.Text(
                              'Total Students',
                              style: pw.TextStyle(
                                fontSize: 14,
                                color: PdfColors.blue700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 15),
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(15),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.orange50,
                          borderRadius:
                              const pw.BorderRadius.all(pw.Radius.circular(8)),
                          border: pw.Border.all(color: PdfColors.orange200),
                        ),
                        child: pw.Column(
                          children: [
                            pw.Text(
                              '${_reportData['normalLessons']}',
                              style: pw.TextStyle(
                                fontSize: 24,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.orange900,
                              ),
                            ),
                            pw.Text(
                              'Normal Lessons',
                              style: pw.TextStyle(
                                fontSize: 14,
                                color: PdfColors.orange700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 15),
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(15),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.green50,
                          borderRadius:
                              const pw.BorderRadius.all(pw.Radius.circular(8)),
                          border: pw.Border.all(color: PdfColors.green200),
                        ),
                        child: pw.Column(
                          children: [
                            pw.Text(
                              '${_reportData['activityLessons']}',
                              style: pw.TextStyle(
                                fontSize: 24,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.green900,
                              ),
                            ),
                            pw.Text(
                              'Activity Lessons',
                              style: pw.TextStyle(
                                fontSize: 14,
                                color: PdfColors.green700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 30),

                // Pricing Breakdown
                pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.purple50,
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: PdfColors.purple200),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Pricing Breakdown',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.purple900,
                        ),
                      ),
                      pw.SizedBox(height: 15),
                      pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'Student Pays:',
                                  style: pw.TextStyle(
                                    fontSize: 14,
                                    color: PdfColors.grey600,
                                  ),
                                ),
                                pw.Text(
                                  '${_studentPayment.toStringAsFixed(0)} ₺',
                                  style: pw.TextStyle(
                                    fontSize: 16,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'Teacher Gets:',
                                  style: pw.TextStyle(
                                    fontSize: 14,
                                    color: PdfColors.grey600,
                                  ),
                                ),
                                pw.Text(
                                  '${_teacherEarning.toStringAsFixed(0)} ₺',
                                  style: pw.TextStyle(
                                    fontSize: 16,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.green700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'Platform Gets:',
                                  style: pw.TextStyle(
                                    fontSize: 14,
                                    color: PdfColors.grey600,
                                  ),
                                ),
                                pw.Text(
                                  '${_platformEarning.toStringAsFixed(0)} ₺',
                                  style: pw.TextStyle(
                                    fontSize: 16,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.orange700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 30),

                // Footer
                pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Text(
                    'Report generated on ${DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey600,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();

      // Save to temporary directory and share
      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/spoken_cafe_report_${_selectedPeriod.toLowerCase()}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');
      await file.writeAsBytes(pdfBytes);

      if (mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Spoken Cafe Financial Report - ${_selectedPeriod}',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF report shared successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error generating PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xff1B1212),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.analytics,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Financial Reports',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff1B1212),
                            ),
                          ),
                          Text(
                            'Track your earnings and performance',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _downloadPDF,
                      icon: const Icon(Icons.download),
                      tooltip: 'Download PDF Report',
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Period Selector
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: _periods.map((period) {
                      final isSelected = _selectedPeriod == period;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _changePeriod(period),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              color:
                                  isSelected ? const Color(0xff1B1212) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              period,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xff1B1212),
                      backgroundColor: Colors.white,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadReportData,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Financial Summary Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue[600]!, Colors.blue[800]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  spreadRadius: 2,
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.trending_up,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Financial Summary',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Total Revenue',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.white70,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${_reportData['totalRevenue']?.toStringAsFixed(0) ?? '0'} ₺',
                                            style: const TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 50,
                                      color: Colors.white24,
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Period',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.white70,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _selectedPeriod,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Earnings Breakdown
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.green[200]!),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.person,
                                        color: Colors.green[600],
                                        size: 32,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        '${_reportData['teacherEarnings']?.toStringAsFixed(0) ?? '0'} ₺',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Teacher Earnings',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.orange[200]!),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.business,
                                        color: Colors.orange[600],
                                        size: 32,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        '${_reportData['platformEarnings']?.toStringAsFixed(0) ?? '0'} ₺',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange[700],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Platform Earnings',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Lesson Statistics
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.school,
                                      color: Color(0xff1B1212),
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Lesson Statistics',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xff1B1212),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatCard(
                                        '${_reportData['totalStudents'] ?? 0}',
                                        'Total Students',
                                        Colors.blue,
                                        Icons.people,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStatCard(
                                        '${_reportData['normalLessons'] ?? 0}',
                                        'Normal Lessons',
                                        Colors.green,
                                        Icons.sports,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStatCard(
                                        '${_reportData['activityLessons'] ?? 0}',
                                        'Activity Lessons',
                                        Colors.orange,
                                        Icons.fitness_center,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Pricing Information
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.purple[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.purple[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.purple[600],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Pricing Breakdown',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.purple[700],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Student Pays:',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          Text(
                                            '${_studentPayment.toStringAsFixed(0)} ₺',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Teacher Gets:',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          Text(
                                            '${_teacherEarning.toStringAsFixed(0)} ₺',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Platform Gets:',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          Text(
                                            '${_platformEarning.toStringAsFixed(0)} ₺',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String value, String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:intl/intl.dart';

// class DetailReportPage extends StatefulWidget {
//   const DetailReportPage({super.key});

//   @override
//   State<DetailReportPage> createState() => _DetailReportPageState();
// }

// class _DetailReportPageState extends State<DetailReportPage> {
//   String _selectedPeriod = 'Week';
//   DateTime _selectedDate = DateTime.now();
//   bool _isLoading = false;
//   List<Map<String, dynamic>> _dailyDetails = [];
//   final List<String> _periods = ['Day', 'Week', 'Month', 'Year'];
//   final currencyFormatter = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
//   DateTime _customStartDate = DateTime.now().subtract(Duration(days: 7));
//   DateTime _customEndDate = DateTime.now();
//   int _rangeTotalEarnings = 0;
//   int _rangeTotalStudents = 0;

//   @override
//   void initState() {
//     super.initState();
//     _loadDetails();
//   }

//   void _changePeriod(String period) {
//     setState(() {
//       _selectedPeriod = period;
//     });
//     _loadDetails();
//   }

//   DateTime _getStartDate() {
//     final now = DateTime.now();
//     switch (_selectedPeriod) {
//       case 'Day':
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
//       case 'Day':
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

//   Future<void> _pickStartDate() async {
//     final picked = await showDatePicker(
//       context: context,
//       initialDate: _customStartDate,
//       firstDate: DateTime(2020),
//       lastDate: DateTime.now(),
//     );
//     if (picked != null) {
//       setState(() {
//         _customStartDate = picked;
//         if (_customEndDate.isBefore(_customStartDate)) {
//           _customEndDate = _customStartDate;
//         }
//       });
//     }
//   }

//   Future<void> _pickEndDate() async {
//     final picked = await showDatePicker(
//       context: context,
//       initialDate: _customEndDate,
//       firstDate: _customStartDate,
//       lastDate: DateTime.now(),
//     );
//     if (picked != null) {
//       setState(() {
//         _customEndDate = picked;
//       });
//     }
//   }

//   void _applyCustomRange() {
//     _loadDetails(customStart: _customStartDate, customEnd: _customEndDate);
//   }

//   Future<void> _loadDetails({DateTime? customStart, DateTime? customEnd}) async {
//     setState(() {
//       _isLoading = true;
//       _dailyDetails = [];
//       _rangeTotalEarnings = 0;
//       _rangeTotalStudents = 0;
//     });
//     try {
//       final startDate = customStart ?? _getStartDate();
//       final endDate = customEnd ?? _getEndDate();
//       final takenLessonsQuery = await FirebaseFirestore.instance
//           .collection('takenLessons')
//           .get();
//       // Group lessons by day
//       Map<String, List<Map<String, dynamic>>> grouped = {};
//       Set<String> allStudents = {};
//       int totalEarnings = 0;
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
//         if (lessonDate.isBefore(startDate) || lessonDate.isAfter(endDate)) continue;
//         final dayKey = DateFormat('yyyy-MM-dd').format(lessonDate);
//         grouped.putIfAbsent(dayKey, () => []).add(data);
//         allStudents.add(data['studentName'] ?? 'Unknown');
//         totalEarnings = totalEarnings + ((data['price'] ?? 0) as num).toInt();
//       }
//       // Build daily details
//       List<Map<String, dynamic>> details = [];
//       grouped.forEach((day, lessons) {
//         final students = lessons.map((e) => e['studentName'] ?? 'Unknown').toSet().toList();
//         final totalAmount = lessons.fold<num>(0, (sum, e) => sum + (e['price'] ?? 0)).toInt();
//         details.add({
//           'date': day,
//           'studentCount': students.length,
//           'students': students,
//           'totalAmount': totalAmount,
//         });
//       });
//       // Sort by date descending
//       details.sort((a, b) => b['date'].compareTo(a['date']));
//       setState(() {
//         _dailyDetails = details;
//         _rangeTotalEarnings = totalEarnings.toInt();
//         _rangeTotalStudents = allStudents.length;
//         _isLoading = false;
//       });
//     } catch (e) {
//       print('Error loading detail report: $e');
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Detail Report'),
//         backgroundColor: Colors.blue[700],
//         foregroundColor: Colors.white,
//       ),
//       backgroundColor: Colors.grey[50],
//       body: Column(
//         children: [
//           // Date Range Picker
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: GestureDetector(
//                     onTap: _pickStartDate,
//                     child: Container(
//                       padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(8),
//                         border: Border.all(color: Colors.blue[100]!),
//                       ),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Icon(Icons.calendar_today, size: 18, color: Colors.blue[700]),
//                           SizedBox(width: 6),
//                           Text('From: ${DateFormat('yyyy-MM-dd').format(_customStartDate)}', style: TextStyle(fontSize: 14)),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//                 SizedBox(width: 10),
//                 Expanded(
//                   child: GestureDetector(
//                     onTap: _pickEndDate,
//                     child: Container(
//                       padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(8),
//                         border: Border.all(color: Colors.blue[100]!),
//                       ),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Icon(Icons.calendar_today, size: 18, color: Colors.blue[700]),
//                           SizedBox(width: 6),
//                           Text('To: ${DateFormat('yyyy-MM-dd').format(_customEndDate)}', style: TextStyle(fontSize: 14)),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//                 SizedBox(width: 10),
//                 ElevatedButton(
//                   onPressed: _applyCustomRange,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.blue[700],
//                     foregroundColor: Colors.white,
//                     padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                   ),
//                   child: Text('Apply'),
//                 ),
//               ],
//             ),
//           ),
//           // Summary
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//             child: Card(
//               color: Colors.blue[50],
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               child: Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                   children: [
//                     Column(
//                       children: [
//                         Text('Total Earnings', style: TextStyle(fontSize: 14, color: Colors.blue[900], fontWeight: FontWeight.bold)),
//                         SizedBox(height: 4),
//                         Text(currencyFormatter.format(_rangeTotalEarnings), style: TextStyle(fontSize: 18, color: Colors.green[700], fontWeight: FontWeight.bold)),
//                       ],
//                     ),
//                     Column(
//                       children: [
//                         Text('Total Students', style: TextStyle(fontSize: 14, color: Colors.blue[900], fontWeight: FontWeight.bold)),
//                         SizedBox(height: 4),
//                         Text('$_rangeTotalStudents', style: TextStyle(fontSize: 18, color: Colors.blue[700], fontWeight: FontWeight.bold)),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//           // Period Selector
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: _periods.map((period) {
//                 final selected = _selectedPeriod == period;
//                 return Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 6.0),
//                   child: ChoiceChip(
//                     label: Text(period),
//                     selected: selected,
//                     onSelected: (_) => _changePeriod(period),
//                     selectedColor: Colors.blue[700],
//                     labelStyle: TextStyle(
//                       color: selected ? Colors.white : Colors.blue[700],
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 );
//               }).toList(),
//             ),
//           ),
//           Expanded(
//             child: _isLoading
//                 ? Center(child: CircularProgressIndicator())
//                 : _dailyDetails.isEmpty
//                     ? Center(child: Text('No data for this period.'))
//                     : ListView.builder(
//                         padding: EdgeInsets.all(16),
//                         itemCount: _dailyDetails.length,
//                         itemBuilder: (context, idx) {
//                           final day = _dailyDetails[idx];
//                           return Card(
//                             margin: EdgeInsets.only(bottom: 16),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                             elevation: 2,
//                             child: Padding(
//                               padding: const EdgeInsets.all(20.0),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Row(
//                                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                     children: [
//                                       Text(
//                                         DateFormat('yyyy-MM-dd').format(DateTime.parse(day['date'])),
//                                         style: TextStyle(
//                                           fontSize: 18,
//                                           fontWeight: FontWeight.bold,
//                                           color: Colors.blue[700],
//                                         ),
//                                       ),
//                                       Text(
//                                         '${currencyFormatter.format(day['totalAmount'])}',
//                                         style: TextStyle(
//                                           fontSize: 18,
//                                           fontWeight: FontWeight.bold,
//                                           color: Colors.green[700],
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                   SizedBox(height: 10),
//                                   Text(
//                                     'Students: ${day['studentCount']}',
//                                     style: TextStyle(fontSize: 16, color: Colors.black87),
//                                   ),
//                                   SizedBox(height: 6),
//                                   Wrap(
//                                     spacing: 8,
//                                     children: [
//                                       for (final name in day['students'])
//                                         Chip(
//                                           label: Text(name),
//                                           backgroundColor: Colors.blue[50],
//                                         ),
//                                     ],
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//           ),
//         ],
//       ),
//     );
//   }
// } 

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DetailReportPage extends StatefulWidget {
  const DetailReportPage({super.key});

  @override
  State<DetailReportPage> createState() => _DetailReportPageState();
}

class _DetailReportPageState extends State<DetailReportPage> {
  String _selectedPeriod = 'Week';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  List<Map<String, dynamic>> _dailyDetails = [];
  final List<String> _periods = ['Day', 'Week', 'Month', 'Year'];
  final currencyFormatter = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
  DateTime _customStartDate = DateTime.now().subtract(Duration(days: 7));
  DateTime _customEndDate = DateTime.now();
  int _rangeTotalEarnings = 0;
  int _rangeTotalStudents = 0;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  void _changePeriod(String period) {
    if (!mounted) return;
    setState(() {
      _selectedPeriod = period;
    });
    _loadDetails();
  }

  DateTime _getStartDate() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'Day':
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
      case 'Day':
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

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customStartDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _customStartDate = picked;
        if (_customEndDate.isBefore(_customStartDate)) {
          _customEndDate = _customStartDate;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customEndDate,
      firstDate: _customStartDate,
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _customEndDate = picked;
      });
    }
  }

  void _applyCustomRange() {
    _loadDetails(customStart: _customStartDate, customEnd: _customEndDate);
  }

  Future<void> _loadDetails({DateTime? customStart, DateTime? customEnd}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _dailyDetails = [];
      _rangeTotalEarnings = 0;
      _rangeTotalStudents = 0;
    });

    try {
      final startDate = customStart ?? _getStartDate();
      final endDate = customEnd ?? _getEndDate();

      final takenLessonsQuery = await FirebaseFirestore.instance
          .collection('takenLessons')
          .get();

      // Group lessons by day
      Map<String, List<Map<String, dynamic>>> grouped = {};
      Set<String> allStudents = {};
      int totalEarnings = 0;

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
        if (lessonDate.isBefore(startDate) || lessonDate.isAfter(endDate)) continue;
        final dayKey = DateFormat('yyyy-MM-dd').format(lessonDate);
        grouped.putIfAbsent(dayKey, () => []).add(data);
        allStudents.add(data['studentName'] ?? 'Unknown');
        totalEarnings += ((data['price'] ?? 0) as num).toInt();
      }

      // Build daily details
      List<Map<String, dynamic>> details = [];
      grouped.forEach((day, lessons) {
        final students = lessons.map((e) => e['studentName'] ?? 'Unknown').toSet().toList();
        final totalAmount = lessons.fold<num>(0, (sum, e) => sum + (e['price'] ?? 0)).toInt();
        details.add({
          'date': day,
          'studentCount': students.length,
          'students': students,
          'totalAmount': totalAmount,
        });
      });

      // Sort by date descending
      details.sort((a, b) => b['date'].compareTo(a['date']));

      if (!mounted) return;
      setState(() {
        _dailyDetails = details;
        _rangeTotalEarnings = totalEarnings.toInt();
        _rangeTotalStudents = allStudents.length;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading detail report: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Report'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Date Range Picker
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickStartDate,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[100]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today, size: 18, color: Colors.blue[700]),
                          SizedBox(width: 6),
                          Text('From: ${DateFormat('yyyy-MM-dd').format(_customStartDate)}', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickEndDate,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[100]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today, size: 18, color: Colors.blue[700]),
                          SizedBox(width: 6),
                          Text('To: ${DateFormat('yyyy-MM-dd').format(_customEndDate)}', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _applyCustomRange,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Apply'),
                ),
              ],
            ),
          ),
          // Summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              color: Colors.blue[50],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Text('Total Earnings', style: TextStyle(fontSize: 14, color: Colors.blue[900], fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text(currencyFormatter.format(_rangeTotalEarnings), style: TextStyle(fontSize: 18, color: Colors.green[700], fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      children: [
                        Text('Total Students', style: TextStyle(fontSize: 14, color: Colors.blue[900], fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('$_rangeTotalStudents', style: TextStyle(fontSize: 18, color: Colors.blue[700], fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Period Selector
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _periods.map((period) {
                final selected = _selectedPeriod == period;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                  child: ChoiceChip(
                    label: Text(period),
                    selected: selected,
                    onSelected: (_) => _changePeriod(period),
                    selectedColor: Colors.blue[700],
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.blue[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _dailyDetails.isEmpty
                    ? Center(child: Text('No data for this period.'))
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _dailyDetails.length,
                        itemBuilder: (context, idx) {
                          final day = _dailyDetails[idx];
                          return Card(
                            margin: EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        DateFormat('yyyy-MM-dd').format(DateTime.parse(day['date'])),
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                      Text(
                                        '${currencyFormatter.format(day['totalAmount'])}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'Students: ${day['studentCount']}',
                                    style: TextStyle(fontSize: 16, color: Colors.black87),
                                  ),
                                  SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      for (final name in day['students'])
                                        Chip(
                                          label: Text(name),
                                          backgroundColor: Colors.blue[50],
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

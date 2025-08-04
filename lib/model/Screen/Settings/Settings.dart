import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  // Pricing controllers
  final TextEditingController _studentPaymentController = TextEditingController();
  final TextEditingController _teacherEarningController = TextEditingController();
  final TextEditingController _platformEarningController = TextEditingController();
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPricingData();
  }

  @override
  void dispose() {
    _studentPaymentController.dispose();
    _teacherEarningController.dispose();
    _platformEarningController.dispose();
    super.dispose();
  }

  Future<void> _loadPricingData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final pricingDoc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('pricing')
          .get();
      
      if (pricingDoc.exists) {
        final data = pricingDoc.data()!;
        _studentPaymentController.text = (data['studentPayment'] ?? 190.0).toString();
        _teacherEarningController.text = (data['teacherEarning'] ?? 150.0).toString();
        _platformEarningController.text = (data['platformEarning'] ?? 40.0).toString();
      } else {
        // Set default values
        _studentPaymentController.text = '190.0';
        _teacherEarningController.text = '150.0';
        _platformEarningController.text = '40.0';
      }
    } catch (e) {
      print('Error loading pricing data: $e');
      // Set default values on error
      _studentPaymentController.text = '190.0';
      _teacherEarningController.text = '150.0';
      _platformEarningController.text = '40.0';
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _savePricingData() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final studentPayment = double.tryParse(_studentPaymentController.text) ?? 190.0;
      final teacherEarning = double.tryParse(_teacherEarningController.text) ?? 150.0;
      final platformEarning = double.tryParse(_platformEarningController.text) ?? 40.0;

      // Validate that the sum equals student payment
      if ((teacherEarning + platformEarning).roundToDouble() != studentPayment.roundToDouble()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Teacher + Platform earnings must equal Student payment'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isSaving = false;
        });
        return;
      }

      await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('pricing')
          .set({
        'studentPayment': studentPayment,
        'teacherEarning': teacherEarning,
        'platformEarning': platformEarning,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pricing updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error saving pricing data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving pricing: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() {
      _isSaving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Settings'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      
      body: _isLoading 
        ? Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                // App Info Section
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
            children: [
                      Image.asset('assets/images/spken_cafe_control.png', width: 80, height: 80),
                      SizedBox(height: 20),
                      Text(
                        'Spoken Cafe',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
              Text(
                        'spokencafe@gmail.com',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
                      SizedBox(height: 20),
              Text(
                        'Developer: SUHIB CHARBAJI',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ),
                ),

                SizedBox(height: 30),

                // Pricing Settings Section
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.attach_money, color: Colors.green[600], size: 24),
                          SizedBox(width: 10),
          Text(
                            'Pricing Settings',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      
                      // Student Payment
                      TextField(
                        controller: _studentPaymentController,
                        decoration: InputDecoration(
                          labelText: 'Student Payment (₺)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.payment),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      
                      SizedBox(height: 15),
                      
                      // Teacher Earning
                      TextField(
                        controller: _teacherEarningController,
                        decoration: InputDecoration(
                          labelText: 'Teacher Earning (₺)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.school),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      
                      SizedBox(height: 15),
                      
                      // Platform Earning
                      TextField(
                        controller: _platformEarningController,
                        decoration: InputDecoration(
                          labelText: 'Platform Earning (₺)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.business),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      
                      SizedBox(height: 20),
                      
                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _savePricingData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isSaving 
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Saving...'),
                                ],
                              )
                            : Text('Save Pricing Settings'),
                        ),
                      ),
                      
                      SizedBox(height: 15),
                      
                      // Info Text
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Note: Teacher + Platform earnings must equal Student payment. Changes will automatically update all reports.',
                                style: TextStyle(fontSize: 14, color: Colors.blue[700]),
                              ),
          ),
        ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Static profile data
  final Map<String, dynamic> profileData = {
    'First_Name__c': 'John',
    'Last_Name__c': 'Doe',
    'Employee_Code__c': 'EMP12345',
    'Performance_Flag__c': 'Excellent',
    'Phone__c': '+1-555-123-4567',
    'Email__c': 'john.doe@example.com',
    'Bank_Name__c': 'National Bank',
    'IFSC_Code__c': 'NBIN0001234',
    'Bank_Account_Number__c': '123456789012',
    'Aadhar_Number__c': '1234-5678-9012',
    'PAN_Card__c': 'ABCDE1234F',
    'Date_of_Birth__c': '1990-05-15',
    'Work_Location__c': 'New York',
    'Joining_Date__c': '2020-01-10',
    'Reporting_Manager__c': 'Jane Smith',
    'Annual_Review_Date__c': '2025-01-10',
    'Department__c': 'Engineering',
  };

  String _formatDate(dynamic dateValue) {
    if (dateValue == null || dateValue.toString().isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateValue.toString());
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateValue.toString();
    }
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'N/A';
    return value.toString();
  }

  void _onBottomNavTap(BuildContext context, int index) {
    // Mock navigation actions
    if (index == 3) return; // Already on Profile page

    switch (index) {
      case 0:
      // Navigate to Dashboard
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Navigating to Dashboard')),
        );
        break;
      case 1:
      // Navigate to Leave Dashboard
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Navigating to Leave Dashboard')),
        );
        break;
      case 2:
      // Navigate to Attendance History
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Navigating to Attendance History')),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF2D3748);
    final subtitleColor = isDarkMode ? Colors.white70 : Colors.grey[600];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: cardColor,
        title: Text(
          'Profile',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline, color: textColor),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Help feature not implemented')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF667EEA).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Profile Photo
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Employee Name
                  Text(
                    '${_formatValue(profileData['First_Name__c'])} ${_formatValue(profileData['Last_Name__c'])}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  // Employee Code
                  Text(
                    'ID: ${_formatValue(profileData['Employee_Code__c'])}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Performance Flag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formatValue(profileData['Performance_Flag__c']),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Contact Information Section
            _buildSectionCard(
              'Contact Information',
              [
                _buildInfoRow('Phone', _formatValue(profileData['Phone__c']), Icons.phone),
                _buildDivider(),
                _buildInfoRow('Email', _formatValue(profileData['Email__c']), Icons.email),
              ],
              cardColor,
              textColor,
              subtitleColor,
              isDarkMode,
            ),

            const SizedBox(height: 16),

            // Banking Information Section
            _buildSectionCard(
              'Banking Information',
              [
                _buildInfoRow('Bank Name', _formatValue(profileData['Bank_Name__c']), Icons.account_balance),
                _buildDivider(),
                _buildInfoRow('IFSC Code', _formatValue(profileData['IFSC_Code__c']), Icons.code),
                _buildDivider(),
                _buildInfoRow('Account Number', _formatValue(profileData['Bank_Account_Number__c']), Icons.credit_card),
              ],
              cardColor,
              textColor,
              subtitleColor,
              isDarkMode,
            ),

            const SizedBox(height: 16),

            // Personal Information Section
            _buildSectionCard(
              'Personal Information',
              [
                _buildInfoRow('Aadhar Number', _formatValue(profileData['Aadhar_Number__c']), Icons.badge),
                _buildDivider(),
                _buildInfoRow('PAN Card', _formatValue(profileData['PAN_Card__c']), Icons.credit_card_outlined),
                _buildDivider(),
                _buildInfoRow('Date of Birth', _formatDate(profileData['Date_of_Birth__c']), Icons.cake),
                _buildDivider(),
                _buildInfoRow('Work Location', _formatValue(profileData['Work_Location__c']), Icons.location_on),
              ],
              cardColor,
              textColor,
              subtitleColor,
              isDarkMode,
            ),

            const SizedBox(height: 16),

            // Employment Information Section
            _buildSectionCard(
              'Employment Information',
              [
                _buildInfoRow('Joining Date', _formatDate(profileData['Joining_Date__c']), Icons.date_range),
                _buildDivider(),
                _buildInfoRow('Reporting Manager', _formatValue(profileData['Reporting_Manager__c']), Icons.supervisor_account),
                _buildDivider(),
                _buildInfoRow('Annual Review Date', _formatDate(profileData['Annual_Review_Date__c']), Icons.event_note),
                _buildDivider(),
                _buildInfoRow('Department', _formatValue(profileData['Department__c']), Icons.business),
              ],
              cardColor,
              textColor,
              subtitleColor,
              isDarkMode,
            ),

            const SizedBox(height: 24),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logout action triggered')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: cardColor,
        selectedItemColor: const Color(0xFF667EEA),
        unselectedItemColor: isDarkMode ? Colors.grey[500] : Colors.grey[400],
        currentIndex: 3, // Profile tab selected
        elevation: 10,
        onTap: (index) => _onBottomNavTap(context, index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            activeIcon: Icon(Icons.home_filled),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_available_outlined),
            activeIcon: Icon(Icons.event_available),
            label: 'Leave',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline),
            activeIcon: Icon(Icons.work),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
      String title,
      List<Widget> children,
      Color cardColor,
      Color textColor,
      Color? subtitleColor,
      bool isDarkMode,
      ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: isDarkMode ? Colors.black.withOpacity(0.1) : Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF2D3748);
    final subtitleColor = isDarkMode ? Colors.white70 : Colors.grey[600];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF667EEA).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF667EEA),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: subtitleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
        thickness: 1,
        height: 1,
      ),
    );
  }
}
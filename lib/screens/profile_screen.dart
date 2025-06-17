import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:codmgo2/utils/profile_logic.dart';
import 'package:codmgo2/screens/dashboard_page.dart';
import 'package:codmgo2/screens/leave_dashboard.dart';
import 'package:codmgo2/screens/attendence_history.dart';

class ProfilePage extends StatefulWidget {
  final String? employeeId;

  const ProfilePage({Key? key, this.employeeId}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late ProfileLogic profileLogic;

  @override
  void initState() {
    super.initState();
    // Initialize the ProfileLogic if not already provided
    profileLogic = context.read<ProfileLogic>();

    // Load profile data when the page initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileData();
    });
  }

  Future<void> _loadProfileData() async {
    try {
      // If employeeId is provided, we might need to initialize it
      if (widget.employeeId != null && widget.employeeId!.isNotEmpty) {
        // Check if we need to validate or set the employee ID
        final isValid = await profileLogic.validateEmployeeExists(widget.employeeId!);
        if (!isValid) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Invalid employee ID: ${widget.employeeId}'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      // Load the profile data
      await profileLogic.loadProfile();
    } catch (e) {
      debugPrint('Error in _loadProfileData: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshProfile() async {
    await profileLogic.loadProfile();
  }

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
    if (value == null || value.toString().isEmpty) return 'N/A';
    return value.toString();
  }

  Color _getPerformanceFlagColor(String? flag) {
    if (flag == null || flag.isEmpty) return Colors.grey;
    switch (flag.toLowerCase()) {
      case 'excellent':
        return Colors.green;
      case 'good':
        return Colors.blue;
      case 'average':
        return Colors.orange;
      case 'poor':
        return Colors.red;
      default:
        return Colors.yellow;
    }
  }

  void _onBottomNavTap(BuildContext context, int index) {
    if (index == 3) return; // Already on Profile page

    final profileData = context.read<ProfileLogic>().profileData;
    final employeeId = widget.employeeId ?? profileLogic.employeeId ?? '';

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardPage(
              employeeId: employeeId,
              firstName: _formatValue(profileData?['First_Name__c']),
              lastName: _formatValue(profileData?['Last_Name__c']),
            ),
          ),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LeaveDashboardPage(employeeId: employeeId),
          ),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AttendanceHistoryPage(employeeId: employeeId),
          ),
        );
        break;
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Clear profile data
                profileLogic.clearProfile();

                // Navigate to login screen
                Navigator.pop(context); // Close dialog
                Navigator.pushReplacementNamed(context, '/login'); // Adjust route as needed
              },
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileLogic>(
      builder: (context, profileLogic, child) {
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
                icon: Icon(Icons.refresh, color: textColor),
                onPressed: profileLogic.isLoading ? null : _refreshProfile,
              ),
              IconButton(
                icon: Icon(Icons.notifications_outlined, color: textColor),
                onPressed: () {
                  // Navigate to notifications page
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notifications feature coming soon')),
                  );
                },
              ),
            ],
          ),
          body: profileLogic.isLoading
              ? const Center(
            child: CircularProgressIndicator(),
          )
              : profileLogic.errorMessage != null
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error Loading Profile',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    profileLogic.errorMessage!,
                    style: TextStyle(
                      fontSize: 14,
                      color: subtitleColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Employee ID: ${widget.employeeId ?? profileLogic.employeeId ?? 'Not available'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: subtitleColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshProfile,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
              : profileLogic.profileData == null
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_off,
                  size: 64,
                  color: subtitleColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Profile Data',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Unable to load profile information',
                  style: TextStyle(
                    fontSize: 14,
                    color: subtitleColor,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _refreshProfile,
                  child: const Text('Reload'),
                ),
              ],
            ),
          )
              : RefreshIndicator(
            onRefresh: _refreshProfile,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
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
                            color: const Color(0xFF667EEA).withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color:Colors.white70, width: 3),
                          ),
                          child: Icon(
                            Icons.person,
                            size: 50,
                            color:Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Employee Name
                        Text(
                          '${_formatValue(profileLogic.profileData?['First_Name__c'])} ${_formatValue(profileLogic.profileData?['Last_Name__c'])}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        // Employee Code
                        Text(
                          'ID: ${_formatValue(profileLogic.profileData?['Employee_Code__c'])}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Performance Flag Section
                  if (profileLogic.profileData?['Performance_Flag__c'] != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: _getPerformanceFlagColor(profileLogic.profileData?['Performance_Flag__c']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getPerformanceFlagColor(profileLogic.profileData?['Performance_Flag__c']),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.flag,
                            color: _getPerformanceFlagColor(profileLogic.profileData?['Performance_Flag__c']),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Performance Flag : ${_formatValue(profileLogic.profileData?['Performance_Flag__c'])}',
                            style: TextStyle(
                              color: _getPerformanceFlagColor(profileLogic.profileData?['Performance_Flag__c']),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Contact Information Section
                  _buildSection(
                    'Contact Information',
                    [
                      _buildInfoRow('Phone', _formatValue(profileLogic.profileData?['Phone__c']), Icons.phone, textColor, subtitleColor),
                      _buildInfoRow('Email', _formatValue(profileLogic.profileData?['Email__c']), Icons.email, textColor, subtitleColor),
                    ],
                    cardColor,
                    isDarkMode,
                    textColor,
                  ),

                  const SizedBox(height: 18),

                  // Banking Information Section
                  _buildSection(
                    'Banking Information',
                    [
                      _buildInfoRow('Bank Name', _formatValue(profileLogic.profileData?['Bank_Name__c']), Icons.account_balance, textColor, subtitleColor),
                      _buildInfoRow('IFSC Code', _formatValue(profileLogic.profileData?['IFSC_Code__c']), Icons.code, textColor, subtitleColor),
                      _buildInfoRow('Account Number', _formatValue(profileLogic.profileData?['Bank_Account_Number__c']), Icons.credit_card, textColor, subtitleColor),
                    ],
                    cardColor,
                    isDarkMode,
                    textColor,
                  ),

                  const SizedBox(height: 18),

                  // Personal Information Section
                  _buildSection(
                    'Personal Information',
                    [
                      _buildInfoRow('Aadhar Number', _formatValue(profileLogic.profileData?['Aadhar_Number__c']), Icons.badge, textColor, subtitleColor),
                      _buildInfoRow('PAN Card', _formatValue(profileLogic.profileData?['PAN_Card__c']), Icons.credit_card_outlined, textColor, subtitleColor),
                      _buildInfoRow('Date of Birth', _formatDate(profileLogic.profileData?['Date_of_Birth__c']), Icons.cake, textColor, subtitleColor),
                      _buildInfoRow('Work Location', _formatValue(profileLogic.profileData?['Work_Location__c']), Icons.location_on, textColor, subtitleColor),
                    ],
                    cardColor,
                    isDarkMode,
                    textColor,
                  ),

                  const SizedBox(height: 18),

                  // Employment Information Section
                  _buildSection(
                    'Employment Information',
                    [
                      _buildInfoRow('Joining Date', _formatDate(profileLogic.profileData?['Joining_Date__c']), Icons.date_range, textColor, subtitleColor),
                      _buildInfoRow('Reporting Manager', _formatValue(profileLogic.profileData?['Reporting_Manager_Formula__c']), Icons.supervisor_account, textColor, subtitleColor),
                      _buildInfoRow('Annual Review Date', _formatDate(profileLogic.profileData?['Annual_Review_Date__c']), Icons.event_note, textColor, subtitleColor),
                      _buildInfoRow('Department', _formatValue(profileLogic.profileData?['Department__c']), Icons.business, textColor, subtitleColor),
                    ],
                    cardColor,
                    isDarkMode,
                    textColor,
                  ),

                  const SizedBox(height: 24),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _showLogoutDialog,
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
      },
    );
  }

  Widget _buildSection(String title, List<Widget> rows, Color cardColor, bool isDarkMode, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: _buildRowsWithDividers(rows, isDarkMode),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildRowsWithDividers(List<Widget> rows, bool isDarkMode) {
    List<Widget> widgets = [];
    for (int i = 0; i < rows.length; i++) {
      widgets.add(rows[i]);
      if (i < rows.length - 1) {
        widgets.add(const SizedBox(height: 16));
        widgets.add(_buildDivider(isDarkMode));
        widgets.add(const SizedBox(height: 16));
      }
    }
    return widgets;
  }

  Widget _buildInfoRow(String label, String value, IconData icon, Color textColor, Color? subtitleColor) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF667EEA).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF667EEA),
            size: 30,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: subtitleColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(bool isDarkMode) {
    return Divider(
      color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
      thickness: 1,
      height: 1,
    );
  }
}
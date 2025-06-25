import 'package:codmgo2/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:codmgo2/screens/apply_leave.dart';
import 'package:codmgo2/screens/leave_history.dart';
import 'package:codmgo2/screens/dashboard_page.dart';
import 'package:codmgo2/screens/attendence_history.dart';
import 'package:codmgo2/services/profile_service.dart';
import 'package:codmgo2/services/leave_api_service.dart';
import 'package:codmgo2/utils/upcoming_leaves.dart';
import 'package:codmgo2/utils/shared_prefs_utils.dart';

class LeaveDashboardPage extends StatefulWidget {
  final String employeeId;

  const LeaveDashboardPage({Key? key, required this.employeeId}) : super(key: key);

  @override
  State<LeaveDashboardPage> createState() => _LeaveDashboardPageState();
}

class _LeaveDashboardPageState extends State<LeaveDashboardPage> with TickerProviderStateMixin {
  String? accessToken;
  String? instanceUrl;
  String? employeeId;
  String? firstName;
  String? lastName;
  String? email;
  bool isLoadingAuth = true;
  bool isLoadingLeaveData = true;
  String? errorMessage;
  final ScrollController _scrollController = ScrollController();

  // Leave data
  Map<String, dynamic>? leaveStatistics;
  Map<String, dynamic>? todayLeaveStatus;
  int leavesTaken = 0;
  int leaveBalance = 0;

  // Animation controllers
  late AnimationController scaleAnimationController;
  late Animation<double> scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserDataAndAuth();
  }

  void _initializeAnimations() {
    scaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: scaleAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    scaleAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserDataAndAuth() async {
    setState(() {
      isLoadingAuth = true;
      errorMessage = null;
    });

    try {
      // Get user data from SharedPrefs (remember me or current session)
      final rememberedData = await SharedPrefsUtils.checkRememberMeStatus();

      if (rememberedData != null) {
        // Use remembered data
        setState(() {
          employeeId = rememberedData['employee_id'];
          firstName = rememberedData['first_name'];
          lastName = rememberedData['last_name'];
          email = rememberedData['email'];
        });
      } else {
        // Fallback to passed employeeId
        setState(() {
          employeeId = widget.employeeId;
          firstName = '';
          lastName = '';
        });
      }

      // Get valid credentials (will refresh if needed)
      final credentials = await SharedPrefsUtils.getSalesforceCredentials();

      if (credentials != null) {
        setState(() {
          accessToken = credentials['access_token'];
          instanceUrl = credentials['instance_url'];
          isLoadingAuth = false;
        });
        await _loadLeaveData();
      } else {
        setState(() {
          isLoadingAuth = false;
          errorMessage = 'Failed to retrieve authentication credentials. Please login again.';
        });
      }
    } catch (e) {
      setState(() {
        isLoadingAuth = false;
        errorMessage = 'Error loading user data: $e';
      });
    }
  }

  Future<void> _loadLeaveData() async {
    setState(() {
      isLoadingLeaveData = true;
      errorMessage = null;
    });

    try {
      // Load leave statistics and today's status in parallel
      final results = await Future.wait([
        LeaveApiService.getLeaveStatistics(),
        LeaveApiService.getTodayLeaveStatus(),
        LeaveApiService.getEmployeeLeaves(),
      ]);

      final statistics = results[0] as Map<String, dynamic>?;
      final todayStatus = results[1] as Map<String, dynamic>?;
      final allLeaves = results[2] as List<Map<String, dynamic>>?;

      if (statistics != null) {
        // Calculate leaves taken (sum of days for approved leaves)
        int totalDaysTaken = 0;
        if (allLeaves != null) {
          for (var leave in allLeaves) {
            if (leave['Status__c'] == 'Approved') {
              final startDate = DateTime.tryParse(leave['Start_Date__c'] ?? '');
              final endDate = DateTime.tryParse(leave['End_Date__c'] ?? '');
              if (startDate != null && endDate != null) {
                // Add 1 to include both start and end dates
                totalDaysTaken += endDate.difference(startDate).inDays + 1;
              }
            }
          }
        }

        // Handle different data types from backend (double/int/string)
        final totalLeaveBalance = _parseToInt(statistics['total_leave_balance']);

        setState(() {
          leaveStatistics = statistics;
          todayLeaveStatus = todayStatus;
          leavesTaken = totalDaysTaken;
          leaveBalance = totalLeaveBalance;
          isLoadingLeaveData = false;
        });
      } else {
        setState(() {
          isLoadingLeaveData = false;
          errorMessage = 'Failed to load leave data. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        isLoadingLeaveData = false;
        errorMessage = 'Error loading leave data: $e';
      });
    }
  }

  // Helper method to safely parse various numeric types to int
  int _parseToInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed?.round() ?? 0;
    }

    return 0;
  }

  void _onBottomNavTap(BuildContext context, int index) {
    if (index == 1) return; // Already on Leave page

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardPage(
              employeeId: employeeId ?? widget.employeeId,
              firstName: firstName ?? '',
              lastName: lastName ?? '',
            ),
          ),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AttendanceHistoryPage(employeeId: employeeId ?? widget.employeeId),
          ),
        );
        break;
      case 3:
        if (accessToken == null || instanceUrl == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Authentication data not available. Please try again.')),
          );
          _loadUserDataAndAuth(); // Retry loading auth data
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfilePage(),
          ),
        );
        break;
    }
  }

  Future<void> _handleRefresh() async {
    await _loadUserDataAndAuth();
  }

  String _getWelcomeMessage() {
    if (firstName != null && firstName!.isNotEmpty) {
      return 'Welcome Back, $firstName!';
    } else if (employeeId != null) {
      return 'Welcome Back!';
    }
    return 'Welcome!';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF2D3748);
    final subtitleColor = isDarkMode ? Colors.white70 : Colors.grey[600];

    if (isLoadingAuth || isLoadingLeaveData) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                isLoadingAuth ? 'Loading user data...' : 'Loading leave information...',
                style: TextStyle(color: textColor),
              ),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  errorMessage!,
                  style: TextStyle(color: textColor),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _handleRefresh,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: cardColor,
        title: Text(
          'Leave Management',
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
            icon: Icon(Icons.help_outline, color: Colors.green),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getWelcomeMessage(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Manage your leaves efficiently',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildClockStatCard('Leaves Taken', leavesTaken.toString(), Icons.check_circle),
                        const SizedBox(width: 16),
                        _buildClockStatCard('Leave Balance', leaveBalance.toString(), Icons.access_time),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Today's Status Section
              Text(
                'Today\'s Status',
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
                    BoxShadow(
                      color: isDarkMode ? Colors.black.withOpacity(0.1) : Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: (todayLeaveStatus?['is_on_leave'] == true)
                            ? Colors.orange.withOpacity(0.1)
                            : const Color(0xFF667EEA).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        (todayLeaveStatus?['is_on_leave'] == true) ? Icons.event_busy : Icons.today,
                        color: (todayLeaveStatus?['is_on_leave'] == true)
                            ? Colors.orange
                            : const Color(0xFF667EEA),
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Leave Status',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (todayLeaveStatus?['is_on_leave'] == true)
                                ? 'You are on ${todayLeaveStatus?['leave_details']?['Leave_Type__c'] ?? 'leave'} today'
                                : 'You are not on leave today',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Quick Actions Section
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),

              // First Row
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      context,
                      'Apply Leave',
                      Icons.add_circle_outline,
                      const Color(0xFF667EEA),
                      isDarkMode,
                          () {
                        // Add haptic feedback
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ApplyLeavePage(employeeId: employeeId ?? widget.employeeId),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionCard(
                      context,
                      'Leave History',
                      Icons.history,
                      const Color(0xFF9F7AEA),
                      isDarkMode,
                          () {
                        // Add haptic feedback
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LeaveHistoryPage(employeeId: employeeId ?? widget.employeeId),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Upcoming Leaves Section
              UpcomingLeaves(
                textColor: textColor,
                cardColor: cardColor,
                isDarkMode: isDarkMode,
                scaleAnimation: scaleAnimation,
                scaleAnimationController: scaleAnimationController,
                employeeId: employeeId ?? widget.employeeId,
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
        currentIndex: 1, // Leave tab selected
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
            icon: Icon(Icons.calendar_month),
            activeIcon: Icon(Icons.calendar_month),
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

  Widget _buildClockStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
      BuildContext context, String title, IconData icon, Color color, bool isDarkMode, VoidCallback onTap) {
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF2D3748);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
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
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
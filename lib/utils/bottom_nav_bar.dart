import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:codmgo2/screens/dashboard_page.dart';
import 'package:codmgo2/screens/attendence_history.dart';
// import 'package:codmgo2/screens/search_page.dart'; // Uncomment when search page is ready
import 'package:codmgo2/screens/profile_screen.dart';
import 'package:codmgo2/screens/leave_dashboard.dart';
import 'package:codmgo2/screens/leave_history.dart';

class CustomBottomNavBar extends StatefulWidget {
  final String employeeId;
  final String firstName;
  final String lastName;
  final int initialIndex;

  const CustomBottomNavBar({
    super.key,
    required this.employeeId,
    required this.firstName,
    required this.lastName,
    this.initialIndex = 0,
  });

  @override
  State<CustomBottomNavBar> createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar> {
  late int _currentIndex;

  // Cache for pages to prevent rebuilding
  final Map<int, Widget> _pageCache = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _buildAndCachePage(_currentIndex);
  }

  void _buildAndCachePage(int index) {
    if (!_pageCache.containsKey(index)) {
      _pageCache[index] = _buildPage(index);
    }
  }

  void _onBottomNavTap(int index) {
    if (_currentIndex == index) return;
    HapticFeedback.selectionClick();
    _buildAndCachePage(index);
    setState(() {
      _currentIndex = index;
    });
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return DashboardPage(
          firstName: widget.firstName,
          lastName: widget.lastName,
          employeeId: widget.employeeId,
        );
      case 1:
        return LeaveDashboardPage(employeeId: widget.employeeId);
      // case 2:
      //   return _buildSearchPlaceholder();
      case 3:
        return AttendanceHistoryPage(employeeId: widget.employeeId);
      case 4:
        return const ProfilePage();
      default:
        return DashboardPage(
          firstName: widget.firstName,
          lastName: widget.lastName,
          employeeId: widget.employeeId,
        );
    }
  }

  Widget _buildSearchPlaceholder() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 80,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Search Page',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Coming Soon!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required bool isSelected,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _onBottomNavTap(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    key: ValueKey('${index}_${isSelected}'),
                    size: 24,
                    color: isSelected ? activeColor : inactiveColor,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  color: isSelected ? activeColor : inactiveColor,
                  letterSpacing: 0.5,
                  height: 1.33,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final backgroundColor = isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF);
    final activeColor = const Color(0xFF1A73E8);
    final inactiveColor = isDarkMode ? const Color(0xFF9E9E9E) : const Color(0xFF616161);
    final shadowColor = isDarkMode
        ? Colors.black.withOpacity(0.3)
        : Colors.black.withOpacity(0.08);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(6, (index) {
          return _pageCache[index] ?? _buildPage(index);
        }),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 8,
              offset: const Offset(0, -2),
              spreadRadius: 0,
            ),
          ],
          border: isDarkMode ? null : Border(
            top: BorderSide(
              color: const Color(0xFFE0E0E0),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                index: 0,
                isSelected: _currentIndex == 0,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
              _buildNavItem(
                icon: Icons.event_available_outlined,
                activeIcon: Icons.event_available,
                label: 'Leave',
                index: 1,
                isSelected: _currentIndex == 1,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
              // _buildNavItem(
              //   icon: Icons.search_outlined,
              //   activeIcon: Icons.search,
              //   label: 'Search',
              //   index: 2,
              //   isSelected: _currentIndex == 2,
              //   activeColor: activeColor,
              //   inactiveColor: inactiveColor,
              // ),
              _buildNavItem(
                icon: Icons.calendar_month_outlined,
                activeIcon: Icons.calendar_month,
                label: 'Attendance',
                index: 3,
                isSelected: _currentIndex == 3,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
              _buildNavItem(
                icon: Icons.notifications_outlined,
                activeIcon: Icons.notifications,
                label: 'Alerts',
                index: 4,
                isSelected: _currentIndex == 4,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

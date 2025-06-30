import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool isDarkMode;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home,
                activeIcon: Icons.home,
                label: 'Home',
                index: 0,
                isActive: currentIndex == 0,
              ),
              _buildNavItem(
                icon: Icons.event_available_outlined,
                activeIcon: Icons.event_available,
                label: 'Leave',
                index: 1,
                isActive: currentIndex == 1,
              ),
              _buildNavItem(
                icon: Icons.calendar_month,
                activeIcon: Icons.calendar_month,
                label: 'Attendance',
                index: 2,
                isActive: currentIndex == 2,
              ),
              _buildNavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                index: 3,
                isActive: currentIndex == 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF667EEA).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? activeIcon : icon,
                key: ValueKey('$index-$isActive'),
                size: 24,
                color: isActive
                    ? const Color(0xFF667EEA)
                    : isDarkMode
                    ? Colors.grey[500]
                    : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive
                    ? const Color(0xFF667EEA)
                    : isDarkMode
                    ? Colors.grey[500]
                    : Colors.grey[400],
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
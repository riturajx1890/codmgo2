import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

class CustomBottomNavigationBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool isDarkMode;

  const CustomBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.isDarkMode,
  });

  @override
  State<CustomBottomNavigationBar> createState() => _CustomBottomNavigationBarState();
}

class _CustomBottomNavigationBarState extends State<CustomBottomNavigationBar>
    with TickerProviderStateMixin {
  late List<AnimationController> _animationControllers;
  late List<Animation<double>> _scaleAnimations;
  late List<Animation<double>> _bounceAnimations;
  late AnimationController _popupController;
  late Animation<double> _popupAnimation;
  late Animation<double> _popupScaleAnimation;

  final List<NavigationItem> _navigationItems = [
    NavigationItem(icon: Icons.home_rounded, activeIcon: Icons.home, label: 'Home', color: Colors.blueAccent),
    NavigationItem(icon: Icons.beach_access_outlined, activeIcon: Icons.beach_access, label: 'Leave', color: Colors.orange),
    NavigationItem(icon: Icons.history_outlined, activeIcon: Icons.history, label: 'Attendance', color: Colors.green),
    NavigationItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person, label: 'Profile', color: Colors.blueAccent),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationControllers = List.generate(_navigationItems.length, (index) {
      return AnimationController(duration: const Duration(milliseconds: 120), vsync: this);
    });

    _scaleAnimations = _animationControllers.map((controller) {
      return Tween<double>(begin: 1.0, end: 0.9).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    }).toList();

    _bounceAnimations = _animationControllers.map((controller) {
      return Tween<double>(begin: 1.0, end: 1.1).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));
    }).toList();

    _popupController = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);
    _popupAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _popupController, curve: Curves.easeOut));
    _popupScaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: _popupController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    for (var controller in _animationControllers) {
      controller.dispose();
    }
    _popupController.dispose();
    super.dispose();
  }

  Future<void> _handleTap(int index) async {
    if (index == widget.currentIndex) return;

    HapticFeedback.selectionClick();
    _animationControllers[index].forward().then((_) => _animationControllers[index].reverse());
    widget.onTap(index);

    _popupController.forward(from: 0.0);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _popupController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = widget.isDarkMode
        ? Colors.grey[900]!.withOpacity(0.95)
        : Colors.white.withOpacity(0.95);

    final Color shadowColor = widget.isDarkMode
        ? Colors.black.withOpacity(0.3)
        : Colors.grey.withOpacity(0.2);

    return Stack(
      children: [
        Container(
          height: 85,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: widget.isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: List.generate(_navigationItems.length, _buildNavigationItem),
                ),
              ),
            ),
          ),
        ),
        _buildPopupOverlay(),
      ],
    );
  }

  Widget _buildNavigationItem(int index) {
    final item = _navigationItems[index];
    final isSelected = index == widget.currentIndex;

    return Expanded(
      child: AnimatedBuilder(
        animation: Listenable.merge([_scaleAnimations[index], _bounceAnimations[index]]),
        builder: (context, _) {
          return Transform.scale(
            scale: isSelected ? _bounceAnimations[index].value : _scaleAnimations[index].value,
            child: GestureDetector(
              onTap: () => _handleTap(index),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected ? item.color.withOpacity(0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 150),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: Icon(
                            isSelected ? item.activeIcon : item.icon,
                            key: ValueKey(isSelected),
                            size: 24,
                            color: isSelected
                                ? item.color
                                : (widget.isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 150),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? item.color
                          : (widget.isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    child: Text(item.label),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPopupOverlay() {
    return AnimatedBuilder(
      animation: _popupAnimation,
      builder: (context, _) {
        if (_popupAnimation.value == 0) return const SizedBox.shrink();

        final currentItem = _navigationItems[widget.currentIndex];

        return Positioned(
          bottom: 120,
          left: 0,
          right: 0,
          child: Center(
            child: Transform.scale(
              scale: _popupScaleAnimation.value,
              child: Opacity(
                opacity: _popupAnimation.value,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: widget.isDarkMode
                        ? Colors.grey[800]!.withOpacity(0.9)
                        : Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(currentItem.activeIcon, size: 20, color: currentItem.color),
                      const SizedBox(width: 8),
                      Text(
                        currentItem.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;

  NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.color,
  });
}

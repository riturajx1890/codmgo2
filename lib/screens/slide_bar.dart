import 'package:flutter/material.dart';

class SlideBar extends StatelessWidget {
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String? profileImageUrl;
  final VoidCallback? onThemeToggle;
  final bool isDarkMode;

  const SlideBar({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    this.profileImageUrl,
    this.onThemeToggle,
    this.isDarkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final drawerWidth = MediaQuery.of(context).size.width * 0.63;

    return Container(
      width: drawerWidth.clamp(280.0, 320.0),
      height: double.infinity,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Add top padding to account for status bar
            SizedBox(height: MediaQuery.of(context).padding.top),
            _buildHeader(context),
            _buildNavigationItems(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Profile Picture
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  color: const Color(0xFF667EEA).withOpacity(0.2),
                ),
                child: profileImageUrl != null
                    ? ClipOval(
                  child: Image.network(
                    profileImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.person, size: 32, color: Color(0xFF667EEA)),
                  ),
                )
                    : const Icon(Icons.person, size: 32, color: Color(0xFF667EEA)),
              ),
              // Theme Toggle
              GestureDetector(
                onTap: onThemeToggle,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isDarkMode ? Icons.wb_sunny : Icons.nightlight_round,
                    size: 24,
                    color: isDarkMode ? Colors.white : const Color(0xFF333333),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$firstName $lastName',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : const Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            phoneNumber,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: isDarkMode ? Colors.white.withOpacity(0.7) : const Color(0xFF616161),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationItems(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(), // Prevent nested scrolling
      shrinkWrap: true,
      children: [
        const Divider(height: 16),
        _buildNavigationItem(context, icon: Icons.person_outline, title: 'My Profile', onTap: () => _handleNavigation(context, 'profile')),
        _buildNavigationItem(context, icon: Icons.group_add_outlined, title: 'New Group', onTap: () => _handleNavigation(context, 'new_group')),
        _buildNavigationItem(context, icon: Icons.contacts_outlined, title: 'Contacts', onTap: () => _handleNavigation(context, 'contacts')),
        _buildNavigationItem(context, icon: Icons.call_outlined, title: 'Calls', onTap: () => _handleNavigation(context, 'calls')),
        _buildNavigationItem(context, icon: Icons.bookmark_outline, title: 'Saved Messages', onTap: () => _handleNavigation(context, 'saved_messages')),
        _buildNavigationItem(context, icon: Icons.settings_outlined, title: 'Settings', onTap: () => _handleNavigation(context, 'settings'), hasIndicator: true),

        //   const Divider(height: 16),
        //
        //   _buildNavigationItem(context, icon: Icons.group_outlined, title: 'Invite Friends', onTap: () => _handleNavigation(context, 'invite_friends')),
        //   _buildNavigationItem(context, icon: Icons.help_outline, title: 'Telegram Features', onTap: () => _handleNavigation(context, 'telegram_features')),
      ],
    );
  }

  Widget _buildNavigationItem(
      BuildContext context, {
        required IconData icon,
        required String title,
        required VoidCallback onTap,
        bool hasIndicator = false,
      }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.1),
        highlightColor: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.05),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: isDarkMode ? Colors.white.withOpacity(0.7) : const Color(0xFF616161),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: isDarkMode ? Colors.white : const Color(0xFF333333),
                  ),
                ),
              ),
              if (hasIndicator)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleNavigation(BuildContext context, String route) {
    Navigator.of(context).pop(); // Close drawer
    debugPrint('Navigate to $route');
    // Actual navigation logic goes here
  }
}
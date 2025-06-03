import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DashboardPage extends StatelessWidget {
  final String firstName;
  final String lastName;

  const DashboardPage({
    super.key,
    required this.firstName,
    required this.lastName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final Color boxColor = isDarkMode ? Colors.grey[850]! : const Color(0xFFF8F8FF);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.zero,
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
          ),
        ),
      ),
      body: Container(
        color: isDarkMode ? Colors.black : Colors.white,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          children: [
            Text(
              'Hello',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Test Man'
              '$firstName $lastName',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 20),

            // Attendance Box with 3 lines
            _buildDetailedInfoBox(
              color: boxColor,
              textColor: textColor,
              icon: Icons.calendar_today,
              lines: const [
                "Today's Attendance",

                "Clocked In",
                "09:30 AM",
              ],
              height: 150,
            ),

            // Leave Box (single title)
            _buildTopAlignedInfoBox(
              title: 'Upcoming Leave',
              icon: Icons.beach_access,
              color: boxColor,
              textColor: textColor,
              height: 120,
            ),

            // Clock In and Clock Out buttons
            Row(
              children: [
                Expanded(
                  child: _buildCenteredButtonBox(
                    title: 'Clock In',
                    icon: Icons.login,
                    backgroundColor: Colors.blue,
                    height: 130,
                    onTap: () {
                      // Handle Clock In
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildCenteredButtonBox(
                    title: 'Clock Out',
                    icon: Icons.logout,
                    backgroundColor: Colors.blue,
                    height: 130,
                    onTap: () {
                      // Handle Clock Out
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text(
              'More Options',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),

            // Apply Leave Box
            _buildOptionBox(
              title: 'Apply Leave',
              icon: Icons.edit_calendar,
              color: boxColor,
              textColor: textColor,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => Placeholder()));
              },
            ),

            // Attendance History Box
            _buildOptionBox(
              title: 'Attendance History',
              icon: Icons.history,
              color: boxColor,
              textColor: textColor,
              onTap: () {
                // Handle tap
              },
            ),

            // Logout Box
            _buildOptionBox(
              title: 'Logout',
              icon: Icons.exit_to_app,
              color: boxColor,
              textColor: textColor,
              onTap: () {
                // Handle logout
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedInfoBox({
    required IconData icon,
    required List<String> lines,
    required Color color,
    required Color textColor,
    required double height,
  }) {
    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: textColor),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(lines.length, (index) {
                  double fontSize;
                  FontWeight fontWeight;

                  double bottomSpacing;

                  // Customize style based on index
                  switch (index) {
                    case 0:

                      fontSize = 20;
                      fontWeight = FontWeight.bold;
                      bottomSpacing = 8;
                      break;
                    case 1:
                      fontSize = 16;
                      fontWeight = FontWeight.w500;
                      bottomSpacing = 6;
                      break;
                    case 2:
                    default:
                      fontSize = 32;
                      fontWeight = FontWeight.bold;
                      bottomSpacing = 0;
                      break;
                  }

                  return Padding(
                    padding: EdgeInsets.only(bottom: bottomSpacing),
                    child: Text(
                      lines[index],
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: fontWeight,
                        color: textColor,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopAlignedInfoBox({
    required String title,
    required IconData icon,
    required Color color,
    required Color textColor,
    required double height,
  }) {
    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: textColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '04 Jun - 07 Jun',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCenteredButtonBox({
    required String title,
    required IconData icon,
    required Color backgroundColor,
    required double height,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: Colors.white),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionBox({
    required String title,
    required IconData icon,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: textColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: textColor),
          ],
        ),
      ),
    );
  }
}

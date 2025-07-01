import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final textColor = isDarkMode ? Colors.white70 : Colors.grey[800];
    final spinnerColor = isDarkMode ? Colors.white : Colors.blue;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/codm_logo.png', // corrected logo path
              height: 100,
            ),
            const SizedBox(height: 20),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
            ),
            const SizedBox(height: 12),
            Text(
              'Loading, please wait...',
              style: TextStyle(
                fontSize: 16,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

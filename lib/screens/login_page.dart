import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/permission_service.dart';
import '../services/salesforce_api_service.dart';
import '../services/salesforce_auth_service.dart';
import '../styles/spacing_style.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  static final Logger _logger = Logger();

  bool _rememberMe = false;
  bool _isPasswordVisible = false;
  bool _isFormFocused = false;
  bool _hasValidationError = false;
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Timer? _loginTimeoutTimer;

  @override
  void initState() {
    super.initState();
    _logger.i('LoginPage initialized');

    Future.microtask(() async {
      await PermissionService.requestInitialPermissions();
    });

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: -145.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _emailFocusNode.addListener(_onFocusChange);
    _passwordFocusNode.addListener(_onFocusChange);
    _checkRememberMeStatus();
  }

  void _onFocusChange() {
    bool shouldFocus = _emailFocusNode.hasFocus || _passwordFocusNode.hasFocus;

    if (shouldFocus != _isFormFocused) {
      setState(() {
        _isFormFocused = shouldFocus;
      });

      if (_isFormFocused) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  Future<void> _checkRememberMeStatus() async {
    _logger.i('Checking remember me status');

    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMeTimestamp = prefs.getInt('remember_me_timestamp');

      if (rememberMeTimestamp != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final daysPassed = (now - rememberMeTimestamp) / (1000 * 60 * 60 * 24);

        _logger.i('Remember me found, days passed: $daysPassed');

        if (daysPassed < 45) {
          // Get stored employee data
          final employeeId = prefs.getString('employee_id') ?? '';
          final firstName = prefs.getString('first_name') ?? '';
          final lastName = prefs.getString('last_name') ?? '';

          _logger.i('Auto-login with stored data: employeeId=$employeeId, firstName=$firstName, lastName=$lastName');

          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => DashboardPage(
                firstName: firstName,
                lastName: lastName,
                employeeId: employeeId,
              )),
            );
          });
        } else {
          _logger.i('Remember me expired, clearing stored data');
          await prefs.remove('remember_me_timestamp');
          await prefs.remove('employee_id');
          await prefs.remove('first_name');
          await prefs.remove('last_name');
        }
      } else {
        _logger.i('No remember me data found');
      }
    } catch (e, stackTrace) {
      _logger.e('Error checking remember me status: $e', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _saveRememberMeStatus(String employeeId, String firstName, String lastName) async {
    _logger.i('Saving remember me status: employeeId=$employeeId');

    if (_rememberMe) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final currentTimestamp = DateTime.now().millisecondsSinceEpoch;

        await prefs.setInt('remember_me_timestamp', currentTimestamp);
        await prefs.setString('employee_id', employeeId);
        await prefs.setString('first_name', firstName);
        await prefs.setString('last_name', lastName);

        _logger.i('Remember me data saved successfully');
      } catch (e, stackTrace) {
        _logger.e('Error saving remember me data: $e', error: e, stackTrace: stackTrace);
      }
    }
  }

  Future<Map<String, dynamic>?> _checkEmailFromSalesforce(String email) async {
    _logger.i('Starting Salesforce email check for: $email');

    try {
      _logger.i('Authenticating with Salesforce...');
      final authData = await SalesforceAuthService.authenticate();
      if (authData == null) {
        _logger.e('Salesforce authentication failed');
        return null;
      }

      final accessToken = authData['access_token'];
      final instanceUrl = authData['instance_url'];

      _logger.i('Authentication successful, querying employee...');
      final employee = await SalesforceApiService.getEmployeeByEmail(
        accessToken,
        instanceUrl,
        email,
      );

      if (employee != null) {
        _logger.i('Employee found: ${employee['Name']} with ID: ${employee['Id']}');

        // Save employee data immediately to SharedPreferences
        await _saveEmployeeDataToPrefs(employee, accessToken, instanceUrl);

        return {
          'employee': employee,
          'access_token': accessToken,
          'instance_url': instanceUrl,
        };
      } else {
        _logger.w('No employee found with email: $email');
      }
      return null;
    } catch (e, stackTrace) {
      _logger.e('Salesforce login error: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> _saveEmployeeDataToPrefs(Map<String, dynamic> employee, String accessToken, String instanceUrl) async {
    _logger.i('Saving employee data to SharedPreferences');

    try {
      final prefs = await SharedPreferences.getInstance();
      final employeeId = employee['Id']?.toString() ?? '';
      final firstName = employee['First_Name__c']?.toString() ?? '';
      final lastName = employee['Last_Name__c']?.toString() ?? '';
      final email = employee['Email__c']?.toString() ?? '';

      // Save all employee and session data
      await prefs.setString('employee_id', employeeId);
      await prefs.setString('current_employee_id', employeeId); // Also save as current_employee_id
      await prefs.setString('first_name', firstName);
      await prefs.setString('last_name', lastName);
      await prefs.setString('user_email', email);
      await prefs.setString('access_token', accessToken);
      await prefs.setString('instance_url', instanceUrl);

      _logger.i('Employee data saved: employeeId=$employeeId, firstName=$firstName, lastName=$lastName, email=$email');
    } catch (e, stackTrace) {
      _logger.e('Error saving employee data: $e', error: e, stackTrace: stackTrace);
    }
  }

  void _handleLogin() async {
    _logger.i('Starting login process');

    setState(() {
      _hasValidationError = false;
      _isLoading = true;
    });

    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    _logger.i('Login attempt for email: $email');

    if (email.isEmpty || password.isEmpty) {
      _logger.w('Login validation failed: empty fields');
      setState(() {
        _hasValidationError = true;
        _isLoading = false;
      });
      _showSnackBar("Please fill in all fields", isError: true);
      return;
    }

    // Start the timeout timer for 100 seconds
    _loginTimeoutTimer = Timer(const Duration(seconds: 100), () {
      if (_isLoading) {
        _logger.w('Login timeout occurred');
        setState(() {
          _hasValidationError = true;
          _isLoading = false;
        });
        _showSnackBar(
          "Login timeout: Unable to connect to server. Please check your internet connection and try again.",
          isError: true,
        );
      }
    });

    try {
      // Add a small delay for UX
      await Future.delayed(const Duration(milliseconds: 500));

      _logger.i('Checking email with Salesforce...');
      final salesforceData = await _checkEmailFromSalesforce(email);
      bool passwordIsValid = _checkPassword(password);
      bool isValid = salesforceData != null && passwordIsValid;

      _logger.i('Login validation result: isValid=$isValid, salesforceData=${salesforceData != null}, passwordValid=$passwordIsValid');

      // Cancel the timeout timer if we got a response
      _loginTimeoutTimer?.cancel();

      if (!mounted) return;

      setState(() {
        _hasValidationError = !isValid;
        _isLoading = false;
      });

      if (isValid) {
        final employee = salesforceData!['employee'];
        final employeeId = employee['Id']?.toString() ?? '';
        final firstName = employee['First_Name__c']?.toString() ?? '';
        final lastName = employee['Last_Name__c']?.toString() ?? '';

        _logger.i('Login successful for employee: $employeeId');

        // Check if we have a valid employee ID
        if (employeeId.isEmpty) {
          _logger.e('Employee ID is empty');
          setState(() {
            _hasValidationError = true;
          });
          _showSnackBar("Employee record is incomplete. Please contact admin.", isError: true);
          return;
        }

        // Save employee data for remember me
        if (_rememberMe) {
          await _saveRememberMeStatus(employeeId, firstName, lastName);
        }

        _logger.i('Navigating to dashboard...');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardPage(
            firstName: firstName,
            lastName: lastName,
            employeeId: employeeId,
          )),
        );
      } else {
        String errorMessage;
        if (salesforceData == null) {
          errorMessage = "Email not found in system. Please check your email address.";
        } else if (!passwordIsValid) {
          errorMessage = "Invalid password. Please try again.";
        } else {
          errorMessage = "Invalid credentials. Please try again.";
        }

        _logger.w('Login failed: $errorMessage');
        _showSnackBar(errorMessage, isError: true);
      }
    } catch (e, stackTrace) {
      // Cancel the timeout timer
      _loginTimeoutTimer?.cancel();

      if (!mounted) return;

      setState(() {
        _hasValidationError = true;
        _isLoading = false;
      });

      _logger.e('Login error: $e', error: e, stackTrace: stackTrace);
      String errorMessage = "Login failed: ";
      if (e.toString().contains('timeout') || e.toString().contains('TimeoutException')) {
        errorMessage += "Connection timeout. Please check your internet connection.";
      } else if (e.toString().contains('SocketException')) {
        errorMessage += "Network error. Please check your internet connection.";
      } else {
        errorMessage += "Unknown error occurred. Please try again.";
      }

      _showSnackBar(errorMessage, isError: true);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    _logger.d('Showing snackbar: $message (isError: $isError)');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  @override
  void dispose() {
    _logger.i('LoginPage disposing');
    _loginTimeoutTimer?.cancel();
    _animationController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.zero,
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Theme.of(context).brightness == Brightness.light
                ? Brightness.dark
                : Brightness.light,
            statusBarBrightness: Theme.of(context).brightness,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: Padding(
                  padding: CSpacingStyle.paddingWithAppBarHeight,
                  child: Column(
                    children: [
                      const SizedBox(height: 65),
                      Center(
                        child: Image.asset(
                          CImages.appLogo,
                          height: 180,
                          width: 180,
                        ),
                      ),
                      const SizedBox(height: 0),
                      const Text(
                        'Login',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 14),
                      Form(
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailController,
                              focusNode: _emailFocusNode,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.email),
                                hintText: 'Email',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _hasValidationError ? Colors.red : Colors.grey,
                                    width: _hasValidationError ? 2 : 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _hasValidationError
                                        ? Colors.red
                                        : Theme.of(context).primaryColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              focusNode: _passwordFocusNode,
                              obscureText: !_isPasswordVisible,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.lock),
                                hintText: 'Password',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isPasswordVisible = !_isPasswordVisible;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _hasValidationError ? Colors.red : Colors.grey,
                                    width: _hasValidationError ? 2 : 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _hasValidationError
                                        ? Colors.red
                                        : Theme.of(context).primaryColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _rememberMe,
                                      onChanged: (value) {
                                        HapticFeedback.mediumImpact();
                                        setState(() {
                                          _rememberMe = value ?? false;
                                        });
                                      },
                                    ),
                                    const Text('Remember Me'),
                                  ],
                                ),
                                TextButton(
                                  onPressed: () async {
                                    const url = 'https://test.salesforce.com/';
                                    try {
                                      if (await canLaunchUrl(Uri.parse(url))) {
                                        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                      } else {
                                        _showSnackBar(
                                          'Could not open the password reset page.',
                                          isError: true,
                                        );
                                      }
                                    } catch (e) {
                                      _showSnackBar(
                                        'Error opening password reset page: $e',
                                        isError: true,
                                      );
                                    }
                                  },
                                  child: const Text(
                                    'Forget Password?',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                  HapticFeedback.heavyImpact();
                                  _handleLogin();
                                },
                                style: ButtonStyle(
                                  backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                    if (states.contains(WidgetState.disabled)) {
                                      return Colors.blue;
                                    }
                                    return Colors.blue;
                                  }),
                                  foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                    return Colors.white;
                                  }),
                                ),
                                child: _isLoading
                                    ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Logging in...'),
                                  ],
                                )
                                    : const Text('Log In'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

bool _checkPassword(String password) {
  return password == "12345"; // Replace with actual logic later
}

class CImages {
  static const String appLogo = "assets/codm_logo.png";
}
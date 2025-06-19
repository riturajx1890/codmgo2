import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/permission_service.dart';
import '../services/salesforce_api_service.dart';
import '../services/salesforce_auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../utils/shared_prefs_utils.dart';
import 'package:codmgo2/screens/dashboard_page.dart';

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
    try {
      final rememberedData = await SharedPrefsUtils.checkRememberMeStatus();

      if (rememberedData != null) {
        final employeeId = rememberedData['employee_id'] ?? '';
        final firstName = rememberedData['first_name'] ?? '';
        final lastName = rememberedData['last_name'] ?? '';

        _logger.i('Auto-login with remembered data: employeeId=$employeeId, firstName=$firstName, lastName=$lastName');

        if (mounted) {
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
        }
      }
    } catch (e, stackTrace) {
      _logger.e('Error checking remember me status: $e', error: e, stackTrace: stackTrace);
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

        await SharedPrefsUtils.saveEmployeeDataToPrefs(employee, accessToken, instanceUrl);

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
      await Future.delayed(const Duration(milliseconds: 500));

      _logger.i('Checking email with Salesforce...');
      final salesforceData = await _checkEmailFromSalesforce(email);
      bool passwordIsValid = _checkPassword(password);
      bool isValid = salesforceData != null && passwordIsValid;

      _logger.i('Login validation result: isValid=$isValid, salesforceData=${salesforceData != null}, passwordValid=$passwordIsValid');

      _loginTimeoutTimer?.cancel();

      if (!mounted) return;

      setState(() {
        _hasValidationError = !isValid;
        _isLoading = false;
      });

      if (isValid) {
        final employee = salesforceData['employee'];
        final employeeId = employee['Id']?.toString() ?? '';
        final firstName = employee['First_Name__c']?.toString() ?? '';
        final lastName = employee['Last_Name__c']?.toString() ?? '';

        _logger.i('Login successful for employee: $employeeId');

        if (employeeId.isEmpty) {
          _logger.e('Employee ID is empty');
          setState(() {
            _hasValidationError = true;
          });
          _showSnackBar("Employee record is incomplete. Please contact admin.", isError: true);
          return;
        }

        // Save remember me status if enabled using SharedPrefsUtils
        if (_rememberMe) {
          final saveSuccess = await SharedPrefsUtils.saveRememberMeStatus(employeeId, firstName, lastName);
          if (saveSuccess) {
            _logger.i('Remember me status saved successfully');
          } else {
            _logger.w('Failed to save remember me status');
          }
        } else {
          // Clear remember me data if checkbox is unchecked
          await SharedPrefsUtils.clearRememberMeData();
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

  bool _checkPassword(String password) {
    return password == "12345"; // Replace with actual logic later
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF2D3748);
    final subtitleColor = isDarkMode ? Colors.white70 : Colors.grey[600];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: PreferredSize(
        preferredSize: Size.zero,
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
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
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 120),
                      const SizedBox(height: 24),
                      Center(
                        child: Image.asset(
                          'assets/codm_logo.png',
                          height: 125,
                          width: 200,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Log in',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      Form(
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailController,
                              focusNode: _emailFocusNode,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.email, color: subtitleColor),
                                hintText: 'Email',
                                hintStyle: TextStyle(color: subtitleColor),
                                filled: true,
                                fillColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _hasValidationError ? Colors.red : (isDarkMode ? Colors.transparent : Colors.grey[300]!),
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _hasValidationError ? Colors.red : const Color(0xFF667EEA),
                                    width: 1,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.red,
                                    width: 1,
                                  ),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.red,
                                    width: 1,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                              ),
                              style: TextStyle(color: textColor),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              focusNode: _passwordFocusNode,
                              obscureText: !_isPasswordVisible,
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.lock, color: subtitleColor),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                    color: subtitleColor,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isPasswordVisible = !_isPasswordVisible;
                                    });
                                  },
                                ),
                                hintText: 'Password',
                                hintStyle: TextStyle(color: subtitleColor),
                                filled: true,
                                fillColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _hasValidationError ? Colors.red : (isDarkMode ? Colors.transparent : Colors.grey[300]!),
                                    width: 2,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _hasValidationError ? Colors.red : const Color(0xFF667EEA),
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                              ),
                              style: TextStyle(color: textColor),
                            ),
                            const SizedBox(height: 12),
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
                                        _logger.i('Remember me checkbox changed to: $_rememberMe');
                                      },
                                      activeColor: const Color(0xFF667EEA),
                                      checkColor: Colors.white,
                                    ),
                                    Text(
                                      'Remember Me',
                                      style: TextStyle(color: textColor, fontSize: 14),
                                    ),
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
                                  child: Text(
                                    'Forget Password?',
                                    style: TextStyle(
                                      color: const Color(0xFF667EEA),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                  HapticFeedback.heavyImpact();
                                  _handleLogin();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF667EEA),
                                  disabledBackgroundColor: const Color(0xFF667EEA), // Keep same color when disabled
                                  foregroundColor: Colors.white,
                                  disabledForegroundColor: Colors.white, // Keep white text when disabled
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                  side: BorderSide(
                                    color: const Color(0xFF667EEA), // Border same as button color
                                    width: 1,
                                  ),
                                ),
                                child: _isLoading
                                    ? Row(
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
                                    const SizedBox(width: 8),
                                    Text(
                                      'Logging in...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                )
                                    : Text(
                                  'Log In',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
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
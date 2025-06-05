import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/permission_service.dart';
import '../services/salesforce_api_service.dart';
import '../services/salesforce_auth_service.dart';
import '../styles/spacing_style.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
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

  @override
  void initState() {
    super.initState();

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
    final prefs = await SharedPreferences.getInstance();
    final rememberMeTimestamp = prefs.getInt('remember_me_timestamp');

    if (rememberMeTimestamp != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final daysPassed = (now - rememberMeTimestamp) / (1000 * 60 * 60 * 24);

      if (daysPassed < 45) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardPage(firstName: '', lastName: '',)),
          );
        });
      } else {
        await prefs.remove('remember_me_timestamp');
      }
    }
  }

  Future<void> _saveRememberMeStatus() async {
    if (_rememberMe) {
      final prefs = await SharedPreferences.getInstance();
      final currentTimestamp = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt('remember_me_timestamp', currentTimestamp);
    }
  }

  Future<bool> _checkEmailFromSalesforce(String email) async {
    try {
      final authData = await SalesforceAuthService.authenticate();
      if (authData == null) return false;

      final accessToken = authData['access_token'];
      final instanceUrl = authData['instance_url'];

      final employee = await SalesforceApiService.getEmployeeByEmail(
        accessToken,
        instanceUrl,
        email,
      );

      return employee != null;
    } catch (e) {
      debugPrint('Salesforce login error: $e');
      return false;
    }
  }

  void _handleLogin() async {
    setState(() {
      _hasValidationError = false;
      _isLoading = true;
    });

    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _hasValidationError = true;
        _isLoading = false;
      });
      _showSnackBar("Please fill in all fields", isError: true);
      return;
    }

    await Future.delayed(const Duration(milliseconds: 1500));

    bool emailIsValid = await _checkEmailFromSalesforce(email);
    bool passwordIsValid = _checkPassword(password);
    bool isValid = emailIsValid && passwordIsValid;

    setState(() {
      _hasValidationError = !isValid;
      _isLoading = false;
    });

    if (isValid) {
      if (_rememberMe) {
        await _saveRememberMeStatus();
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardPage(firstName: '', lastName: '',)),
      );
    } else {
      _showSnackBar("Invalid credentials. Please try again.", isError: true);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 2),
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
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
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
                                      return Colors.blue; // Keep blue when disabled
                                    }
                                    return Colors.blue; // Normal state
                                  }),
                                  foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                    if (states.contains(WidgetState.disabled)) {
                                      return Colors.white; // Keep text white when disabled
                                    }
                                    return Colors.white; // Normal state
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
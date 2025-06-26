import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum IssueType { attendance, leave, complaint, other }

class HelpScreen extends StatefulWidget {
  final String employeeId;

  const HelpScreen({Key? key, required this.employeeId}) : super(key: key);

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> with SingleTickerProviderStateMixin {
  // Form and validation
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  // Scroll controller for smooth scrolling
  final ScrollController _scrollController = ScrollController();

  // Animation controller and animation
  late AnimationController _animationController;
  late Animation<double> _keyboardAnimation;
  bool _isKeyboardVisible = false;

  // Focus node for description field
  final FocusNode _descriptionFocusNode = FocusNode();

  // Issue form state
  IssueType? _selectedIssueType;
  bool _isLoading = false;

  // Static configurations
  static const Map<IssueType, String> _issueTypeDisplayNames = {
    IssueType.attendance: 'Attendance Issue',
    IssueType.leave: 'Leave Issue',
    IssueType.complaint: 'Make Complaint',
    IssueType.other: 'Other Issue',
  };

  static const Map<IssueType, IconData> _issueTypeIcons = {
    IssueType.attendance: Icons.access_time,
    IssueType.leave: Icons.beach_access,
    IssueType.complaint: Icons.report,
    IssueType.other: Icons.help_outline,
  };

  static const Map<IssueType, Color> _issueTypeColors = {
    IssueType.attendance: Color(0xFF667EEA),
    IssueType.leave: Color(0xFF48BB78),
    IssueType.complaint: Color(0xFFED8936),
    IssueType.other: Color(0xFF9F7AEA),
  };

  static const Map<IssueType, String> _issueTypeDescriptions = {
    IssueType.attendance: 'Attendance concerns',
    IssueType.leave: 'Leave-related concerns',
    IssueType.complaint: 'File a formal complaint',
    IssueType.other: 'Other concerns',
  };

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupFocusListeners();
    _setupKeyboardListener();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _keyboardAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  void _setupFocusListeners() {
    _descriptionFocusNode.addListener(_onFocusChange);
  }

  void _setupKeyboardListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkKeyboardVisibility();
    });
  }

  void _checkKeyboardVisibility() {
    final mediaQuery = MediaQuery.of(context);
    final isKeyboardVisible = mediaQuery.viewInsets.bottom > 0;

    if (isKeyboardVisible != _isKeyboardVisible) {
      setState(() {
        _isKeyboardVisible = isKeyboardVisible;
      });

      if (_isKeyboardVisible) {
        _animationController.forward();
        _scrollToDescription();
      } else {
        _animationController.reverse();
      }
    }
  }

  void _onFocusChange() {
    if (_descriptionFocusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _scrollToDescription();
      });
    }
  }

  Future<void> _scrollToDescription() async {
    if (_scrollController.hasClients) {
      const double descriptionFieldOffset = 200.0; // Approximate offset

      await _scrollController.animateTo(
        descriptionFieldOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkKeyboardVisibility();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _descriptionFocusNode.dispose();
    _descriptionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // UI Helper methods
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  void _showResultDialog({required bool success}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: !success,
      builder: (context) => _buildResultDialog(success, isDarkMode),
    );
  }

  Widget _buildResultDialog(bool success, bool isDarkMode) {
    return GestureDetector(
      onTap: success
          ? () {
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      }
          : null,
      child: AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogIcon(success),
            const SizedBox(height: 16),
            _buildDialogTitle(success, isDarkMode),
            const SizedBox(height: 8),
            _buildDialogMessage(success, isDarkMode),
            const SizedBox(height: 20),
            _buildDialogButton(success),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogIcon(bool success) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: (success ? const Color(0xFF48BB78) : Colors.red).withOpacity(0.1),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Icon(
        success ? Icons.check_circle : Icons.error_outline,
        color: success ? const Color(0xFF48BB78) : Colors.red,
        size: 40,
      ),
    );
  }

  Widget _buildDialogTitle(bool success, bool isDarkMode) {
    return Text(
      success ? 'Success!' : 'Error',
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: isDarkMode ? Colors.white : const Color(0xFF2D3748),
      ),
    );
  }

  Widget _buildDialogMessage(bool success, bool isDarkMode) {
    return Text(
      success
          ? 'Your ${_issueTypeDisplayNames[_selectedIssueType!]} request has been submitted successfully. HR has been notified.'
          : 'Failed to submit help request. Please try again.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 14,
        color: isDarkMode ? Colors.white70 : Colors.grey[600],
      ),
    );
  }

  Widget _buildDialogButton(bool success) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.of(context).pop();
          if (success) Navigator.of(context).pop();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: success ? const Color(0xFF667EEA) : Colors.blueAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          shadowColor: Colors.transparent,
          side: BorderSide(
            color: success ? const Color(0xFF667EEA) : Colors.blueAccent,
            width: 1,
          ),
        ),
        child: Text(success ? 'Done' : 'Try Again'),
      ),
    );
  }

  // Form submission
  Future<void> _submitHelpRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedIssueType == null) {
      _showSnackBar('Please select an issue type');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // TODO: Implement actual submission logic
      // For now, we'll simulate a successful submission
      await Future.delayed(const Duration(seconds: 1));
      setState(() => _isLoading = false);
      _showResultDialog(success: true);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('An error occurred: ${e.toString()}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = _AppTheme(isDarkMode);

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: _buildAppBar(theme),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: AnimatedBuilder(
            animation: _keyboardAnimation,
            builder: (context, child) {
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  20.0,
                  20.0,
                  20.0,
                  20.0 + (_keyboardAnimation.value * 50),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildIssueTypeSection(theme),
                      const SizedBox(height: 32),
                      _buildDescriptionSection(theme),
                      const SizedBox(height: 24),
                      _buildSubmitButton(),
                      const SizedBox(height: 12),
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

  PreferredSizeWidget _buildAppBar(_AppTheme theme) {
    return AppBar(
      elevation: 0,
      backgroundColor: theme.cardColor,
      title: Text(
        'Help & Support',
        style: TextStyle(
          color: theme.textColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios, color: theme.textColor),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildIssueTypeSection(_AppTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Issue',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: theme.textColor,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildIssueTypeCard(IssueType.attendance, theme)),
            const SizedBox(width: 16),
            Expanded(child: _buildIssueTypeCard(IssueType.leave, theme)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildIssueTypeCard(IssueType.complaint, theme)),
            const SizedBox(width: 16),
            Expanded(child: _buildIssueTypeCard(IssueType.other, theme)),
          ],
        ),
      ],
    );
  }

  Widget _buildDescriptionSection(_AppTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Description',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.textColor,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              '*',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: _descriptionController,
            focusNode: _descriptionFocusNode,
            maxLines: 4,
            style: TextStyle(color: theme.textColor),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return '';
              if (value.trim().length < 5) return '';
              return null;
            },
            decoration: InputDecoration(
              hintText: 'Please provide a detailed description of your issue',
              hintStyle: TextStyle(color: theme.subtitleColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 1),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              filled: true,
              fillColor: theme.cardColor,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitHelpRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF667EEA),
          disabledBackgroundColor: const Color(0xFF667EEA),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          shadowColor: Colors.transparent,
          side: const BorderSide(color: Color(0xFF667EEA), width: 1),
        ),
        child: _isLoading
            ? const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Submitting...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        )
            : const Text(
          'Submit Help Request',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildIssueTypeCard(IssueType type, _AppTheme theme) {
    final isSelected = _selectedIssueType == type;
    final color = _issueTypeColors[type]!;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIssueType = isSelected ? null : type;
        });
      },
      child: Container(
        height: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? color.withOpacity(0.2) : theme.shadowColor,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_issueTypeIcons[type], color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              _issueTypeDisplayNames[type]!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : theme.textColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _issueTypeDescriptions[type]!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: theme.subtitleColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// Theme helper class for better organization
class _AppTheme {
  final bool isDarkMode;

  _AppTheme(this.isDarkMode);

  Color get backgroundColor => isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
  Color get cardColor => isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  Color get textColor => isDarkMode ? Colors.white : const Color(0xFF2D3748);
  Color? get subtitleColor => isDarkMode ? Colors.white70 : Colors.grey[600];
  Color get shadowColor => isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05);
}
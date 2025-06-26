import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:codmgo2/utils/apply_leave_logic.dart';

class ApplyLeavePage extends StatefulWidget {
  final String employeeId;

  const ApplyLeavePage({Key? key, required this.employeeId}) : super(key: key);

  @override
  State<ApplyLeavePage> createState() => _ApplyLeavePageState();
}

class _ApplyLeavePageState extends State<ApplyLeavePage>
    with SingleTickerProviderStateMixin {
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

  // Leave form state
  LeaveType? _selectedLeaveType;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  // Static configurations
  static const Map<LeaveType, String> _leaveTypeDisplayNames = {
    LeaveType.casual: 'Casual Leave',
    LeaveType.halfDay: 'Half-Day Leave',
    LeaveType.oneDay: 'One Day Leave',
    LeaveType.sick: 'Medical Leave',
  };

  static const Map<LeaveType, IconData> _leaveTypeIcons = {
    LeaveType.casual: Icons.beach_access,
    LeaveType.halfDay: Icons.schedule,
    LeaveType.oneDay: Icons.today,
    LeaveType.sick: Icons.local_hospital,
  };

  static const Map<LeaveType, Color> _leaveTypeColors = {
    LeaveType.casual: Color(0xFF667EEA),
    LeaveType.halfDay: Color(0xFF48BB78),
    LeaveType.oneDay: Color(0xFF9F7AEA),
    LeaveType.sick: Color(0xFFED8936),
  };

  static const Map<LeaveType, String> _leaveTypeDescriptions = {
    LeaveType.casual: 'Personal & recreational',
    LeaveType.halfDay: 'Half day (4 hours)',
    LeaveType.oneDay: 'Single day absence',
    LeaveType.sick: 'Medical (backdated)',
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
    // Listen to media query changes for keyboard detection
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
      // Delay to allow keyboard to appear
      Future.delayed(const Duration(milliseconds: 300), () {
        _scrollToDescription();
      });
    }
  }

  Future<void> _scrollToDescription() async {
    if (_scrollController.hasClients) {
      // Calculate the position to scroll to the description field
      const double descriptionFieldOffset = 400.0; // Approximate offset

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

  // Utility methods
  bool _canBackdate(LeaveType type) => type == LeaveType.sick;
  bool _isSingleDayLeave(LeaveType type) =>
      type == LeaveType.halfDay || type == LeaveType.oneDay;

  // Date selection methods
  Future<void> _selectStartDate() async {
    final picked = await _showDatePicker(
      initialDate: _startDate ?? DateTime.now(),
      firstDate: _selectedLeaveType != null && _canBackdate(_selectedLeaveType!)
          ? DateTime.now().subtract(const Duration(days: 30))
          : DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_selectedLeaveType != null && _isSingleDayLeave(_selectedLeaveType!)) {
          _endDate = picked;
        } else if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    if (_startDate == null) {
      _showSnackBar('Please select start date first');
      return;
    }

    final picked = await _showDatePicker(
      initialDate: _endDate ?? _startDate!,
      firstDate: _startDate!,
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<DateTime?> _showDatePicker({
    required DateTime initialDate,
    required DateTime firstDate,
  }) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF667EEA),
              onPrimary: Colors.white,
              surface: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              onSurface: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
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
      onTap: success ? () {
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      } : null,
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
          ? 'Your ${_leaveTypeDisplayNames[_selectedLeaveType!]} request has been submitted successfully. HR and your manager have been notified.'
          : 'Failed to submit leave request. Please try again.',
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
  Future<void> _submitLeaveRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedLeaveType == null) {
      _showSnackBar('Please select a leave type');
      return;
    }

    if (_startDate == null) {
      _showSnackBar('Please select start date');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await ApplyLeaveLogic.submitLeaveRequest(
        leaveType: _selectedLeaveType!,
        startDate: _startDate!,
        endDate: _endDate ?? _startDate!,
        description: _descriptionController.text.trim(),
      );

      setState(() => _isLoading = false);
      _showResultDialog(success: success);
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
                  20.0 + (_keyboardAnimation.value * 50), // Add padding when keyboard is visible
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLeaveTypeSection(theme),
                      const SizedBox(height: 32),
                      _buildDateSection(theme),
                      const SizedBox(height: 32),
                      _buildDescriptionSection(theme),
                      const SizedBox(height: 24),
                      _buildSubmitButton(),
                      const SizedBox(height: 12), // Extra space for better scrolling
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
        'Apply for Leave',
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

  Widget _buildLeaveTypeSection(_AppTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Leave Type',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: theme.textColor,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildLeaveTypeCard(LeaveType.casual, theme)),
            const SizedBox(width: 16),
            Expanded(child: _buildLeaveTypeCard(LeaveType.halfDay, theme)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildLeaveTypeCard(LeaveType.oneDay, theme)),
            const SizedBox(width: 16),
            Expanded(child: _buildLeaveTypeCard(LeaveType.sick, theme)),
          ],
        ),
      ],
    );
  }

  Widget _buildDateSection(_AppTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Dates',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: theme.textColor,
          ),
        ),
        const SizedBox(height: 16),
        _buildDateSelector(
          'Start Date',
          _startDate,
          Icons.calendar_today,
          _selectStartDate,
          theme,
        ),
        const SizedBox(height: 16),
        if (_selectedLeaveType == null || !_isSingleDayLeave(_selectedLeaveType!))
          _buildDateSelector(
            'End Date (Optional)',
            _endDate,
            Icons.event,
            _selectEndDate,
            theme,
          ),
        ..._buildDateInfoCards(),
      ],
    );
  }

  List<Widget> _buildDateInfoCards() {
    final List<Widget> cards = [];

    if (_selectedLeaveType != null && _isSingleDayLeave(_selectedLeaveType!)) {
      cards.addAll([
        const SizedBox(height: 16),
        _buildInfoCard(
          '${_leaveTypeDisplayNames[_selectedLeaveType!]} is only applicable for a single day.',
          Icons.info_outline,
          Colors.blue,
        ),
      ]);
    }

    if (_selectedLeaveType != null && _canBackdate(_selectedLeaveType!)) {
      cards.addAll([
        const SizedBox(height: 16),
        _buildInfoCard(
          'Sick/Medical Leave can be backdated up to 30 days.',
          Icons.schedule,
          Colors.orange,
        ),
      ]);
    }

    return cards;
  }

  Widget _buildInfoCard(String text, IconData icon, Color color) {
    // Create a darker shade of the color
    final darkColor = Color.fromRGBO(
      (color.red * 0.7).round(),
      (color.green * 0.7).round(),
      (color.blue * 0.7).round(),
      1.0,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: darkColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: darkColor, fontSize: 14),
            ),
          ),
        ],
      ),
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
              hintText: 'Please provide a detailed reason for your leave request',
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
        onPressed: _isLoading ? null : _submitLeaveRequest,
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
          'Submit Leave Request',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildLeaveTypeCard(LeaveType type, _AppTheme theme) {
    final isSelected = _selectedLeaveType == type;
    final color = _leaveTypeColors[type]!;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_selectedLeaveType == type) {
            _selectedLeaveType = null;
            _startDate = null;
            _endDate = null;
          } else {
            _selectedLeaveType = type;
            _startDate = DateTime.now();
            if (_isSingleDayLeave(type)) {
              _endDate = DateTime.now();
            } else {
              _endDate = null;
            }
          }
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
              child: Icon(_leaveTypeIcons[type], color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              _leaveTypeDisplayNames[type]!,
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
              _leaveTypeDescriptions[type]!,
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

  Widget _buildDateSelector(
      String label,
      DateTime? date,
      IconData icon,
      VoidCallback onTap,
      _AppTheme theme,
      ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF667EEA).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF667EEA), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date != null
                        ? DateFormat('EEEE, MMM dd, yyyy').format(date)
                        : 'Select date',
                    style: TextStyle(
                      fontSize: 16,
                      color: date != null ? theme.textColor : theme.subtitleColor,
                      fontWeight: date != null ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.calendar_today, color: theme.subtitleColor, size: 20),
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
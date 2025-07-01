import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:codmgo2/utils/apply_leave_logic.dart';

class ApplyLeavePage extends StatefulWidget {
  final String employeeId;
  const ApplyLeavePage({Key? key, required this.employeeId}) : super(key: key);

  @override
  State<ApplyLeavePage> createState() => _ApplyLeavePageState();
}

class _ApplyLeavePageState extends State<ApplyLeavePage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _scrollController = ScrollController();
  final _descriptionFocusNode = FocusNode();

  LeaveType? _selectedLeaveType;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  double _originalScrollPosition = 0.0;

  static const _leaveTypeData = {
    LeaveType.casual: {'name': 'Casual Leave', 'icon': Icons.beach_access, 'color': Color(0xFF667EEA), 'desc': 'Personal & recreational'},
    LeaveType.halfDay: {'name': 'Half-Day Leave', 'icon': Icons.schedule, 'color': Color(0xFF48BB78), 'desc': 'Half day (4 hours)'},
    LeaveType.oneDay: {'name': 'One Day Leave', 'icon': Icons.today, 'color': Color(0xFF9F7AEA), 'desc': 'Single day absence'},
    LeaveType.sick: {'name': 'Medical Leave', 'icon': Icons.local_hospital, 'color': Color(0xFFED8936), 'desc': 'Medical (backdated)'},
  };

  @override
  void initState() {
    super.initState();
    _descriptionFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _descriptionFocusNode.dispose();
    _descriptionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_descriptionFocusNode.hasFocus) {
      // Store the current scroll position
      _originalScrollPosition = _scrollController.position.pixels;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Scroll down by exactly 480 pixels from current position
        _scrollController.animateTo(
          _originalScrollPosition + 480,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    } else {
      // Return to original position when focus is lost
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _originalScrollPosition,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  bool _canBackdate(LeaveType type) => type == LeaveType.sick;
  bool _isSingleDayLeave(LeaveType type) => type == LeaveType.halfDay || type == LeaveType.oneDay;

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

  Future<DateTime?> _showDatePicker({required DateTime initialDate, required DateTime firstDate}) async {
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
      builder: (context) => GestureDetector(
        onTap: success ? () => Navigator.of(context)..pop()..pop() : null,
        child: AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
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
              ),
              const SizedBox(height: 16),
              Text(
                success ? 'Success!' : 'Error',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : const Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                success
                    ? 'Your ${_leaveTypeData[_selectedLeaveType!]!['name']} request has been submitted successfully. HR and your manager have been notified.'
                    : 'Failed to submit leave request. Please try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white70 : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
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
                    ),
                  ),
                  child: Text(success ? 'Done' : 'Try Again'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
      appBar: AppBar(
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
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
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
                SizedBox(height: 8),
              ],
            ),
          ),
        ),
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
        Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildLeaveTypeOption(LeaveType.casual, theme)),
                const SizedBox(width: 12),
                Expanded(child: _buildLeaveTypeOption(LeaveType.halfDay, theme)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildLeaveTypeOption(LeaveType.oneDay, theme)),
                const SizedBox(width: 12),
                Expanded(child: _buildLeaveTypeOption(LeaveType.sick, theme)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLeaveTypeOption(LeaveType type, _AppTheme theme) {
    final isSelected = _selectedLeaveType == type;
    final data = _leaveTypeData[type]!;
    final color = data['color'] as Color;

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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : (theme.isDarkMode ? const Color(0xFF424242) : const Color(0xFFE0E0E0)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              data['icon'] as IconData,
              color: color, // Always use the leave type's color
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              data['name'] as String,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : theme.textColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
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
        _buildDateSelector('Start Date', _startDate, Icons.calendar_today, _selectStartDate, theme),
        const SizedBox(height: 16),
        if (_selectedLeaveType == null || !_isSingleDayLeave(_selectedLeaveType!))
          _buildDateSelector('End Date (Optional)', _endDate, Icons.event, _selectEndDate, theme),
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
          '${_leaveTypeData[_selectedLeaveType!]!['name']} is only applicable for a single day.',
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
            child: Text(text, style: TextStyle(color: darkColor, fontSize: 14)),
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
            const Text(' *', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.red)),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120, // Fixed height for the text field
          child: TextFormField(
            controller: _descriptionController,
            focusNode: _descriptionFocusNode,
            maxLines: 4,
            style: TextStyle(color: theme.textColor),
            validator: (value) {
              if (value == null || value.trim().isEmpty || value.trim().length < 5) return '';
              return null;
            },
            decoration: InputDecoration(
              hintText: 'Please provide a detailed reason for your leave request',
              hintStyle: TextStyle(color: theme.subtitleColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              filled: true,
              fillColor: theme.cardColor,
              contentPadding: const EdgeInsets.all(16),
              errorStyle: const TextStyle(height: 0, fontSize: 0),
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
          side: const BorderSide(color: Color(0xFF667EEA)),
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
            Text('Submitting...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        )
            : const Text('Submit Leave Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildDateSelector(String label, DateTime? date, IconData icon, VoidCallback onTap, _AppTheme theme) {
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
                    date != null ? DateFormat('EEEE, MMM dd, yyyy').format(date) : 'Select date',
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

class _AppTheme {
  final bool isDarkMode;
  _AppTheme(this.isDarkMode);

  Color get backgroundColor => isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
  Color get cardColor => isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  Color get textColor => isDarkMode ? Colors.white : const Color(0xFF2D3748);
  Color? get subtitleColor => isDarkMode ? Colors.white70 : Colors.grey[600];
  Color get shadowColor => isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05);
}
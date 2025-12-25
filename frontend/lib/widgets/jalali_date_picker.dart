/// Custom Jalali Date Picker Widget
/// A Material Design-styled date picker for Jalali/Shamsi calendar

import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../utils/jalali_date.dart';
import '../utils/persian_number.dart';
import '../utils/app_colors.dart';

/// Shows a Jalali date picker dialog
/// Returns the selected JalaliDate or null if cancelled
Future<JalaliDate?> showJalaliDatePicker({
  required BuildContext context,
  JalaliDate? initialDate,
  JalaliDate? firstDate,
  JalaliDate? lastDate,
  String? helpText,
  String? cancelText,
  String? confirmText,
}) async {
  final now = JalaliDate.now();

  // Set sensible defaults - narrow range for best performance
  // 5 years back, 10 years forward = max ~180 months
  initialDate ??= now;
  firstDate ??= JalaliDate(now.year - 5, 1, 1);
  lastDate ??= JalaliDate(now.year + 10, 12, 29);

  // Ensure initialDate is within range
  if (initialDate.isBefore(firstDate)) {
    initialDate = firstDate;
  } else if (initialDate.isAfter(lastDate)) {
    initialDate = lastDate;
  }

  return showDialog<JalaliDate>(
    context: context,
    builder: (context) => JalaliDatePickerDialog(
      initialDate: initialDate!,
      firstDate: firstDate!,
      lastDate: lastDate!,
      helpText: helpText ?? 'انتخاب تاریخ',
      cancelText: cancelText ?? 'لغو',
      confirmText: confirmText ?? 'تایید',
    ),
  );
}

/// The main date picker dialog
class JalaliDatePickerDialog extends StatefulWidget {
  final JalaliDate initialDate;
  final JalaliDate firstDate;
  final JalaliDate lastDate;
  final String helpText;
  final String cancelText;
  final String confirmText;

  const JalaliDatePickerDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.helpText,
    required this.cancelText,
    required this.confirmText,
  });

  @override
  State<JalaliDatePickerDialog> createState() => _JalaliDatePickerDialogState();
}

class _JalaliDatePickerDialogState extends State<JalaliDatePickerDialog> {
  late JalaliDate _selectedDate;
  late JalaliDate _displayedMonth;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    // Validate and clamp the initial date to prevent range errors
    final initialYear = widget.initialDate.year.clamp(
      widget.firstDate.year,
      widget.lastDate.year,
    );
    final initialMonth = widget.initialDate.month.clamp(1, 12);

    // Clamp day to valid range for the month
    final tempDate = JalaliDate(initialYear, initialMonth, 1);
    final maxDay = tempDate.daysInMonth;
    final initialDay = widget.initialDate.day.clamp(1, maxDay);

    _selectedDate = JalaliDate(initialYear, initialMonth, initialDay);
    _displayedMonth = JalaliDate(initialYear, initialMonth, 1);

    // Calculate initial page with safety bounds
    final totalMonthsCount = _totalMonths;
    final initialPage = totalMonthsCount > 0
        ? _getMonthIndex(_displayedMonth).clamp(0, totalMonthsCount - 1)
        : 0;
    _pageController = PageController(initialPage: initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _getMonthIndex(JalaliDate date) {
    // Ensure the date is within valid range
    final clampedYear = date.year.clamp(
      widget.firstDate.year,
      widget.lastDate.year,
    );
    final clampedMonth = date.month.clamp(1, 12);
    return (clampedYear - widget.firstDate.year) * 12 +
        (clampedMonth - widget.firstDate.month);
  }

  JalaliDate _getDateFromMonthIndex(int index) {
    // Clamp index to valid range
    final clampedIndex = index.clamp(0, _totalMonths - 1);
    final totalMonths = widget.firstDate.month - 1 + clampedIndex;
    final year = widget.firstDate.year + totalMonths ~/ 12;
    final month = (totalMonths % 12 + 1).clamp(1, 12);
    return JalaliDate(year, month, 1);
  }

  int get _totalMonths {
    return (widget.lastDate.year - widget.firstDate.year) * 12 +
        (widget.lastDate.month - widget.firstDate.month) +
        1;
  }

  void _goToPreviousMonth() {
    final currentIndex = _getMonthIndex(_displayedMonth);
    if (currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNextMonth() {
    final currentIndex = _getMonthIndex(_displayedMonth);
    if (currentIndex < _totalMonths - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _selectDate(JalaliDate date) {
    if (date.isBefore(widget.firstDate) || date.isAfter(widget.lastDate)) {
      return;
    }
    setState(() {
      _selectedDate = date;
    });
  }

  void _showYearPicker() async {
    final selectedYear = await showDialog<int>(
      context: context,
      builder: (context) => _YearPickerDialog(
        selectedYear: _displayedMonth.year,
        firstYear: widget.firstDate.year,
        lastYear: widget.lastDate.year,
      ),
    );

    if (selectedYear != null && selectedYear != _displayedMonth.year) {
      final newDate = JalaliDate(selectedYear, _displayedMonth.month, 1);
      setState(() {
        _displayedMonth = newDate;
      });
      _pageController.jumpToPage(_getMonthIndex(newDate));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 340,
          constraints: const BoxConstraints(maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              _buildHeader(),
              // Calendar
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Month navigation
                    _buildMonthNavigation(),
                    // Day of week headers
                    _buildDayOfWeekHeaders(),
                    // Calendar grid
                    SizedBox(
                      height: 240,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _totalMonths,
                        onPageChanged: (index) {
                          setState(() {
                            _displayedMonth = _getDateFromMonthIndex(index);
                          });
                        },
                        itemBuilder: (context, index) {
                          final monthDate = _getDateFromMonthIndex(index);
                          return _buildMonthGrid(monthDate);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Actions
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.helpText,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedDate.formatFullPersian(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthNavigation() {
    // Safely get month name with bounds checking
    final monthIndex = _displayedMonth.month.clamp(1, 12);
    final monthName = JalaliDate.monthNames[monthIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _goToPreviousMonth,
            tooltip: 'ماه قبل',
          ),
          GestureDetector(
            onTap: _showYearPicker,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$monthName ${PersianNumber.toPersian(_displayedMonth.year.toString())}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 20),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _goToNextMonth,
            tooltip: 'ماه بعد',
          ),
        ],
      ),
    );
  }

  Widget _buildDayOfWeekHeaders() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: JalaliDate.shortDayOfWeekNames.map((name) {
          final isHoliday = name == 'ج';
          return Expanded(
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isHoliday ? Colors.red : Colors.grey[600],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMonthGrid(JalaliDate monthDate) {
    final firstDayOfMonth = JalaliDate(monthDate.year, monthDate.month, 1);
    final daysInMonth = firstDayOfMonth.daysInMonth;
    final firstWeekday = firstDayOfMonth.weekDay;

    // Build the grid
    final List<Widget> dayWidgets = [];

    // Add empty cells for days before the first day of month
    for (int i = 0; i < firstWeekday; i++) {
      dayWidgets.add(const SizedBox(width: 40, height: 40));
    }

    // Add day cells
    for (int day = 1; day <= daysInMonth; day++) {
      final date = JalaliDate(monthDate.year, monthDate.month, day);
      dayWidgets.add(_buildDayCell(date));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: dayWidgets,
      ),
    );
  }

  Widget _buildDayCell(JalaliDate date) {
    final isSelected = date.isSameDay(_selectedDate);
    final isToday = date.isToday;
    final isDisabled =
        date.isBefore(widget.firstDate) || date.isAfter(widget.lastDate);
    final isFriday = date.weekDay == 6;

    Color? backgroundColor;
    Color textColor = Colors.black87;

    if (isSelected) {
      backgroundColor = AppColors.primaryBlue;
      textColor = Colors.white;
    } else if (isToday) {
      backgroundColor = AppColors.primaryBlue.withValues(alpha: 0.1);
      textColor = AppColors.primaryBlue;
    }

    if (isDisabled) {
      textColor = Colors.grey[300]!;
    } else if (isFriday && !isSelected) {
      textColor = Colors.red;
    }

    return GestureDetector(
      onTap: isDisabled ? null : () => _selectDate(date),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: isToday && !isSelected
              ? Border.all(color: AppColors.primaryBlue, width: 1)
              : null,
        ),
        child: Center(
          child: Text(
            PersianNumber.toPersian(date.day.toString()),
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: isSelected || isToday
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(widget.cancelText),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(_selectedDate),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: Text(widget.confirmText),
          ),
        ],
      ),
    );
  }
}

/// Year picker dialog
class _YearPickerDialog extends StatelessWidget {
  final int selectedYear;
  final int firstYear;
  final int lastYear;

  const _YearPickerDialog({
    required this.selectedYear,
    required this.firstYear,
    required this.lastYear,
  });

  @override
  Widget build(BuildContext context) {
    final years = List.generate(
      lastYear - firstYear + 1,
      (index) => firstYear + index,
    );

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 300,
          height: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'انتخاب سال',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: years.length,
                  itemBuilder: (context, index) {
                    final year = years[index];
                    final isSelected = year == selectedYear;

                    return GestureDetector(
                      onTap: () => Navigator.of(context).pop(year),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryBlue
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            PersianNumber.toPersian(year.toString()),
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('لغو'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline Jalali Date Picker (for embedding in forms)
class JalaliDatePickerFormField extends StatefulWidget {
  final JalaliDate? initialDate;
  final JalaliDate? firstDate;
  final JalaliDate? lastDate;
  final String? labelText;
  final String? hintText;
  final ValueChanged<JalaliDate?>? onChanged;
  final FormFieldValidator<JalaliDate>? validator;
  final InputDecoration? decoration;

  const JalaliDatePickerFormField({
    super.key,
    this.initialDate,
    this.firstDate,
    this.lastDate,
    this.labelText,
    this.hintText,
    this.onChanged,
    this.validator,
    this.decoration,
  });

  @override
  State<JalaliDatePickerFormField> createState() =>
      _JalaliDatePickerFormFieldState();
}

class _JalaliDatePickerFormFieldState extends State<JalaliDatePickerFormField> {
  JalaliDate? _selectedDate;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Always initialize with today's date if initialDate is not provided
    _selectedDate = widget.initialDate ?? JalaliDate.now();
    _controller.text = _selectedDate!.formatPersian();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _showPicker() async {
    final result = await showJalaliDatePicker(
      context: context,
      initialDate: _selectedDate ?? JalaliDate.now(),
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
    );

    if (result != null) {
      setState(() {
        _selectedDate = result;
        _controller.text = result.formatPersian();
      });
      widget.onChanged?.call(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      readOnly: true,
      onTap: _showPicker,
      decoration:
          widget.decoration ??
          InputDecoration(
            labelText: widget.labelText ?? 'تاریخ',
            hintText: widget.hintText ?? 'انتخاب تاریخ',
            border: const OutlineInputBorder(),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_selectedDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      setState(() {
                        _selectedDate = null;
                        _controller.clear();
                      });
                      widget.onChanged?.call(null);
                    },
                  ),
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.calendar_today),
                ),
              ],
            ),
          ),
      validator: widget.validator != null
          ? (value) => widget.validator!(_selectedDate)
          : null,
    );
  }
}

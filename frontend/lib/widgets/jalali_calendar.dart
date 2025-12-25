/// Custom Jalali Calendar Widget for displaying installations
/// Similar to TableCalendar but uses Jalali dates

import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../utils/jalali_date.dart';
import '../utils/persian_number.dart';
import '../utils/app_colors.dart';

class JalaliCalendar<T> extends StatefulWidget {
  final JalaliDate focusedDay;
  final JalaliDate selectedDay;
  final Function(JalaliDate) onDaySelected;
  final Function(JalaliDate) onPageChanged;
  final List<T> Function(JalaliDate) eventLoader;
  final Color Function(T)? eventColorBuilder;
  final JalaliDate firstDay;
  final JalaliDate lastDay;
  final String? helpText;

  const JalaliCalendar({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.onDaySelected,
    required this.onPageChanged,
    required this.eventLoader,
    this.eventColorBuilder,
    required this.firstDay,
    required this.lastDay,
    this.helpText,
  });

  @override
  State<JalaliCalendar<T>> createState() => _JalaliCalendarState<T>();
}

class _JalaliCalendarState<T> extends State<JalaliCalendar<T>> {
  late JalaliDate _focusedMonth;
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _focusedMonth = JalaliDate(widget.focusedDay.year, widget.focusedDay.month, 1);
    _currentPage = _getMonthIndex(_focusedMonth);
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _getMonthIndex(JalaliDate date) {
    return (date.year - widget.firstDay.year) * 12 + (date.month - widget.firstDay.month);
  }

  JalaliDate _getDateFromMonthIndex(int index) {
    final totalMonths = index + widget.firstDay.month;
    final year = widget.firstDay.year + (totalMonths ~/ 12);
    final month = (totalMonths % 12);
    return JalaliDate(year, month == 0 ? 12 : month, 1);
  }

  int get _totalMonths {
    final start = _getMonthIndex(widget.firstDay);
    final end = _getMonthIndex(widget.lastDay);
    return end - start + 1;
  }

  void _previousMonth() {
    if (_currentPage > 0) {
      _currentPage--;
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _updateFocusedMonth();
    }
  }

  void _nextMonth() {
    if (_currentPage < _totalMonths - 1) {
      _currentPage++;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _updateFocusedMonth();
    }
  }

  void _updateFocusedMonth() {
    final newMonth = _getDateFromMonthIndex(_currentPage);
    setState(() {
      _focusedMonth = newMonth;
    });
    widget.onPageChanged(newMonth);
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: _previousMonth,
            tooltip: 'ماه قبل',
          ),
          Text(
            '${JalaliDate.monthNames[_focusedMonth.month]} ${PersianNumber.toPersian(_focusedMonth.year.toString())}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: _nextMonth,
            tooltip: 'ماه بعد',
          ),
        ],
      ),
    );
  }

  Widget _buildDayOfWeekHeaders() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: JalaliDate.shortDayOfWeekNames.map((name) {
          final isHoliday = name == 'ج'; // Friday
          return Expanded(
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isHoliday ? Colors.red : Colors.grey[700],
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        children: dayWidgets,
      ),
    );
  }

  Widget _buildDayCell(JalaliDate date) {
    final isSelected = date.year == widget.selectedDay.year &&
        date.month == widget.selectedDay.month &&
        date.day == widget.selectedDay.day;
    final isToday = date.isToday;
    final isDisabled = date.isBefore(widget.firstDay) || date.isAfter(widget.lastDay);
    final isFriday = date.weekDay == 6;

    final events = widget.eventLoader(date);
    final hasEvents = events.isNotEmpty;

    Color? backgroundColor;
    Color textColor = Colors.black87;
    Color? eventColor;

    if (isSelected) {
      backgroundColor = AppColors.primaryBlue;
      textColor = Colors.white;
    } else if (isToday) {
      backgroundColor = AppColors.primaryBlue.withValues(alpha: 0.2);
      textColor = AppColors.primaryBlue;
    }

    if (isDisabled) {
      textColor = Colors.grey[300]!;
    } else if (isFriday && !isSelected) {
      textColor = Colors.red;
    }

    if (hasEvents && widget.eventColorBuilder != null) {
      eventColor = widget.eventColorBuilder!(events.first);
    } else if (hasEvents) {
      eventColor = AppColors.primaryBlue;
    }

    return GestureDetector(
      onTap: isDisabled ? null : () => widget.onDaySelected(date),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: isToday && !isSelected
              ? Border.all(color: AppColors.primaryBlue, width: 2)
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Day number
            Text(
              PersianNumber.toPersian(date.day.toString()),
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            // Event marker
            if (hasEvents && eventColor != null)
              Positioned(
                bottom: 2,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: eventColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildDayOfWeekHeaders(),
            SizedBox(
              height: 280,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _totalMonths,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                  _updateFocusedMonth();
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
    );
  }
}


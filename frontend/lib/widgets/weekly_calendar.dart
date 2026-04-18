import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';

class WeeklyCalendar extends StatefulWidget {
  final List<DateTime> weekDates;
  final DateTime today;
  final DateTime? selectedDate;
  final ScrollController scrollController;
  final Map<DateTime, Map<String, dynamic>>? historicalData;
  final Function(DateTime) onDateTapped;

  const WeeklyCalendar({
    super.key,
    required this.weekDates,
    required this.today,
    this.selectedDate,
    required this.scrollController,
    this.historicalData,
    required this.onDateTapped,
  });

  @override
  State<WeeklyCalendar> createState() => _WeeklyCalendarState();
}

class _WeeklyCalendarState extends State<WeeklyCalendar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardFill,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              controller: widget.scrollController,
              itemCount: widget.weekDates.length,
              itemBuilder: (context, index) {
                final date = widget.weekDates[index];
                final isToday = _isSameDay(date, widget.today);
                final isSelected = widget.selectedDate != null && _isSameDay(date, widget.selectedDate!);
                final isPast = date.isBefore(widget.today) && !_isSameDay(date, widget.today);
                final isFuture = date.isAfter(widget.today);
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildDayCard(date, isToday, isSelected, isPast, isFuture),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard(DateTime date, bool isToday, bool isSelected, bool isPast, bool isFuture) {
    final dayName = _getDayName(date.weekday);
    final dayNumber = date.day.toString();
    
    Color backgroundColor;
    Color borderColor;
    Color textColor;
    
    if (isSelected) {
      backgroundColor = AppColors.primaryGreen;
      borderColor = Colors.transparent;
      textColor = Colors.white;
    } else if (isToday) {
      backgroundColor = AppColors.lightGreen;
      borderColor = Colors.transparent;
      textColor = Colors.white;
    } else {
      backgroundColor = Colors.transparent;
      borderColor = isFuture ? AppColors.inputBorder.withOpacity(0.5) : AppColors.inputBorder;
      textColor = isFuture ? AppColors.textSecondary.withOpacity(0.5) : AppColors.textPrimary;
    }
    
    return GestureDetector(
      onTap: isFuture ? null : () => widget.onDateTapped(date),
      child: Container(
        width: 50,
        height: 70,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dayName,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              dayNumber,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            if (isPast && widget.historicalData != null && widget.historicalData!.containsKey(date))
              Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.only(top: 2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }
}

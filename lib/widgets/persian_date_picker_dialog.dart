import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';

import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/adaptive_dialog_action.dart';

enum DateTimePickerMode { date, time, datetime }

class PersianDatePickerDialog extends StatefulWidget {
  final DateTimePickerMode mode;
  final Function(String?)? onFinished;

  const PersianDatePickerDialog({
    super.key,
    this.mode = DateTimePickerMode.date,
    this.onFinished,
  });

  @override
  State<PersianDatePickerDialog> createState() => _PersianDatePickerDialogState();
}

class _PersianDatePickerDialogState extends State<PersianDatePickerDialog> {
  Jalali? selectedDate;
  TimeOfDay? selectedTime;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    
    String title;
    switch (widget.mode) {
      case DateTimePickerMode.date:
        title = l10n.datePickerTitle;
      case DateTimePickerMode.time:
        title = l10n.timePickerTitle;
      case DateTimePickerMode.datetime:
        title = l10n.dateTimePickerTitle;
    }

    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.mode != DateTimePickerMode.time)
            ElevatedButton(
              onPressed: () => _showPersianDatePicker(context),
              child: Text(
                selectedDate != null 
                  ? selectedDate!.formatFullDate()
                  : l10n.selectDate,
              ),
            ),
          if (widget.mode != DateTimePickerMode.date) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _showPersianTimePicker(context),
              child: Text(
                selectedTime != null 
                  ? _formatTime(selectedTime!)
                  : l10n.selectTime,
              ),
            ),
          ],
          if (selectedDate != null || selectedTime != null) ...[
            const SizedBox(height: 16),
            Text(
              l10n.selectedValue(': ${_getDisplayFormattedResult()}'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
      actions: [
        AdaptiveDialogAction(
          onPressed: () => widget.onFinished?.call(null),
          child: Text(l10n.cancel),
        ),
        AdaptiveDialogAction(
          onPressed: _canConfirm() 
            ? () => widget.onFinished?.call(_getFormattedResult())
            : null,
          child: Text(l10n.ok),
        ),
      ],
    );
  }

  Future<void> _showPersianDatePicker(BuildContext context) async {
    final picked = await showPersianDatePicker(
      context: context,
      initialDate: selectedDate ?? Jalali.now(),
      firstDate: Jalali(1300),
      lastDate: Jalali(1450),
      initialEntryMode: PersianDatePickerEntryMode.calendarOnly,
      initialDatePickerMode: PersianDatePickerMode.day,
      helpText: 'انتخاب تاریخ',
      cancelText: 'لغو',
      confirmText: 'تایید',
      fieldLabelText: 'تاریخ را وارد کنید',
      fieldHintText: 'سال/ماه/روز',
      useRootNavigator: false,
             builder: (context, child) {
         return Localizations.override(
           context: context,
           locale: const Locale('fa', 'IR'),
           delegates: [
             PersianMaterialLocalizations.delegate,
             PersianCupertinoLocalizations.delegate,
             GlobalMaterialLocalizations.delegate,
             GlobalWidgetsLocalizations.delegate,
             GlobalCupertinoLocalizations.delegate,
           ],
                       child: Theme(
              data: Theme.of(context).copyWith(
                // Keep Material 3 for modern styling
                visualDensity: VisualDensity.adaptivePlatformDensity,
              ),
             child: Directionality(
               textDirection: TextDirection.rtl,
               child: child!,
             ),
           ),
         );
       },
    );
    
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _showPersianTimePicker(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
      helpText: 'انتخاب زمان',
      cancelText: 'لغو',
      confirmText: 'تایید',
      hourLabelText: 'ساعت',
      minuteLabelText: 'دقیقه',
      builder: (BuildContext context, Widget? child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  bool _canConfirm() {
    switch (widget.mode) {
      case DateTimePickerMode.date:
        return selectedDate != null;
      case DateTimePickerMode.time:
        return selectedTime != null;
      case DateTimePickerMode.datetime:
        return selectedDate != null && selectedTime != null;
    }
  }

  String _getFormattedResult() {
    switch (widget.mode) {
      case DateTimePickerMode.date:
        return selectedDate != null ? _formatDateForSending(selectedDate!) : '';
      case DateTimePickerMode.time:
        return selectedTime != null ? _formatTimeForSending(selectedTime!) : '';
      case DateTimePickerMode.datetime:
        if (selectedDate != null && selectedTime != null) {
          return '${_formatDateForSending(selectedDate!)} ${_formatTimeForSending(selectedTime!)}';
        }
        return '';
    }
  }

  String _getDisplayFormattedResult() {
    switch (widget.mode) {
      case DateTimePickerMode.date:
        return selectedDate?.formatFullDate() ?? '';
      case DateTimePickerMode.time:
        return selectedTime != null ? _formatTime(selectedTime!) : '';
      case DateTimePickerMode.datetime:
        if (selectedDate != null && selectedTime != null) {
          return '${selectedDate!.formatFullDate()} ${_formatTime(selectedTime!)}';
        }
        return '';
    }
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Format date for sending in message (Persian numbers: ۱۴۰۳/۰۴/۱۵)
  String _formatDateForSending(Jalali date) {
    final year = _toPersianNumbers(date.year.toString());
    final month = _toPersianNumbers(date.month.toString().padLeft(2, '0'));
    final day = _toPersianNumbers(date.day.toString().padLeft(2, '0'));
    return '$year/$month/$day';
  }

  /// Format time for sending in message (Persian numbers: ۱۵:۳۰)
  String _formatTimeForSending(TimeOfDay time) {
    final hour = _toPersianNumbers(time.hour.toString().padLeft(2, '0'));
    final minute = _toPersianNumbers(time.minute.toString().padLeft(2, '0'));
    return '$hour:$minute';
  }

  /// Convert English numbers to Persian numbers
  String _toPersianNumbers(String input) {
    const englishNumbers = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persianNumbers = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    
    String result = input;
    for (int i = 0; i < englishNumbers.length; i++) {
      result = result.replaceAll(englishNumbers[i], persianNumbers[i]);
    }
    return result;
  }
}

// Extension to add missing localization keys
extension L10nExtensions on L10n {
  String get datePickerTitle => 'انتخاب تاریخ';
  String get timePickerTitle => 'انتخاب زمان'; 
  String get dateTimePickerTitle => 'انتخاب تاریخ و زمان';
  String get selectDate => 'انتخاب تاریخ';
  String get selectTime => 'انتخاب زمان';
  String selectedValue(String value) => 'انتخاب شده$value';
} 
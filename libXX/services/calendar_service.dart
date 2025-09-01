import 'package:vendor_app/models/booking.dart';
import 'package:vendor_app/config/constants.dart';

class CalendarService {
  final String businessLocation;

  CalendarService({String? businessLocation})
      : businessLocation =
            businessLocation ?? AppConstants.defaultBusinessLocation;

  String? generateCalendarLink({
    required Booking booking,
    required String calendarType,
  }) {
    final startTime = booking.bookingDate;
    final endTime =
        startTime.add(const Duration(hours: 1)); // Default 1-hour duration

    final title = Uri.encodeComponent('Booking: ${booking.customerName}');
    final details = Uri.encodeComponent(
        'Booking for ${booking.items.map((item) => item.productName).join(", ")}');
    final location = Uri.encodeComponent(
        businessLocation.isNotEmpty ? businessLocation : 'Online Meeting');

    switch (calendarType.toLowerCase()) {
      case 'google':
        return _generateGoogleCalendarLink(
          title: title,
          details: details,
          location: location,
          startTime: startTime,
          endTime: endTime,
        );
      case 'apple':
        return _generateAppleCalendarLink(
          title: title,
          details: details,
          location: location,
          startTime: startTime,
          endTime: endTime,
        );
      case 'outlook':
        return _generateOutlookCalendarLink(
          title: title,
          details: details,
          location: location,
          startTime: startTime,
          endTime: endTime,
        );
      default:
        return null;
    }
  }

  String _generateGoogleCalendarLink({
    required String title,
    required String details,
    required String location,
    required DateTime startTime,
    required DateTime endTime,
  }) {
    final start = startTime
            .toUtc()
            .toIso8601String()
            .replaceAll('-', '')
            .replaceAll(':', '')
            .split('.')[0] +
        'Z';
    final end = endTime
            .toUtc()
            .toIso8601String()
            .replaceAll('-', '')
            .replaceAll(':', '')
            .split('.')[0] +
        'Z';

    return 'https://calendar.google.com/calendar/render?action=TEMPLATE'
        '&text=$title'
        '&details=$details'
        '&location=$location'
        '&dates=$start/$end';
  }

  String _generateAppleCalendarLink({
    required String title,
    required String details,
    required String location,
    required DateTime startTime,
    required DateTime endTime,
  }) {
    final start = startTime.toUtc().toIso8601String();
    final end = endTime.toUtc().toIso8601String();

    return 'data:text/calendar;charset=utf-8,'
        'BEGIN:VCALENDAR\n'
        'VERSION:2.0\n'
        'BEGIN:VEVENT\n'
        'SUMMARY:$title\n'
        'DESCRIPTION:$details\n'
        'LOCATION:$location\n'
        'DTSTART:$start\n'
        'DTEND:$end\n'
        'END:VEVENT\n'
        'END:VCALENDAR';
  }

  String _generateOutlookCalendarLink({
    required String title,
    required String details,
    required String location,
    required DateTime startTime,
    required DateTime endTime,
  }) {
    final start = startTime.toUtc().toIso8601String();
    final end = endTime.toUtc().toIso8601String();

    return 'https://outlook.live.com/calendar/0/deeplink/compose?'
        'subject=$title'
        '&body=$details'
        '&location=$location'
        '&startdt=$start'
        '&enddt=$end'
        '&path=/calendar/action/compose'
        '&rru=addevent';
  }
}

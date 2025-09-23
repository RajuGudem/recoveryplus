import 'package:flutter/material.dart';

class FrequencyToTimeMapper {
  static List<TimeOfDay> mapFrequencyToTimes(String frequency) {
    final lowerCaseFrequency = frequency.toLowerCase();

    switch (lowerCaseFrequency) {
      case 'once daily':
      case 'qd': // Quaque Die (every day)
        return [const TimeOfDay(hour: 8, minute: 0)]; // 8:00 AM

      case 'twice daily':
      case 'bid': // Bis in Die (twice a day)
        return [
          const TimeOfDay(hour: 8, minute: 0), // 8:00 AM
          const TimeOfDay(hour: 20, minute: 0), // 8:00 PM
        ];

      case 'thrice daily':
      case 'tid': // Ter in Die (three times a day)
        return [
          const TimeOfDay(hour: 8, minute: 0), // 8:00 AM
          const TimeOfDay(hour: 14, minute: 0), // 2:00 PM
          const TimeOfDay(hour: 20, minute: 0), // 8:00 PM
        ];

      case 'four times a day':
      case 'qid': // Quater in Die (four times a day)
        return [
          const TimeOfDay(hour: 8, minute: 0), // 8:00 AM
          const TimeOfDay(hour: 12, minute: 0), // 12:00 PM
          const TimeOfDay(hour: 17, minute: 0), // 5:00 PM
          const TimeOfDay(hour: 22, minute: 0), // 10:00 PM
        ];

      case 'as needed':
      case 'prn': // Pro Re Nata (as needed)
        return []; // No specific schedule, user will take as needed

      // Add more cases for other common frequencies or abbreviations
      // e.g., 'every 4 hours', 'every 6 hours', 'every 8 hours', 'every other day', etc.
      // For now, we'll keep it simple.

      default:
        // For unhandled frequencies, return an empty list or a default time
        // For now, we'll return an empty list, meaning no automatic scheduling
        return [];
    }
  }
}

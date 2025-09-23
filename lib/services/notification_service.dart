// services/notification_service.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:recoveryplus/utils/frequency_mapper.dart'; // Import FrequencyToTimeMapper

/// Top-level background notification tap handler for flutter_local_notifications
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  debugPrint("🔔 [BG HANDLER] Notification tapped in background!");
  debugPrint("🔔 [BG HANDLER] Notification ID: ${response.id}");
  debugPrint("🔔 [BG HANDLER] Notification payload: ${response.payload}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final Set<int> _scheduledNotificationIds = {};

  // Vibration pattern
  final Int64List vibrationPattern = Int64List.fromList([0, 1000, 500, 1000]);

  // Channel IDs and names
  static const String _medicationChannelId = 'medication_channel';
  static const String _medicationChannelName = 'Medication Reminders';
  static const String _appointmentChannelId = 'appointment_channel';
  static const String _appointmentChannelName = 'Appointment Reminders';
  static const String _appointmentChannelDescription =
      'Reminders for upcoming appointments';

  Future<void> initialize() async {
    try {
      // Initialize timezone with device's local timezone
      tz.initializeTimeZones();
      try {
        final String localTimezone = await FlutterTimezone.getLocalTimezone();
        String finalTimezone = localTimezone;

        // Handle known timezone aliases
        if (localTimezone == 'Asia/Calcutta') {
          finalTimezone = 'Asia/Kolkata';
        }

        tz.setLocalLocation(tz.getLocation(finalTimezone));
        debugPrint('ℹ️ Timezone successfully initialized to: $finalTimezone');
      } catch (e) {
        debugPrint('❌ Could not get local timezone, defaulting to UTC. Error: $e');
        // Fallback to UTC if getting local timezone fails
        tz.setLocalLocation(tz.getLocation('UTC'));
      }

      final AndroidInitializationSettings initializationSettingsAndroid =
          const AndroidInitializationSettings('@mipmap/ic_launcher');
      final DarwinInitializationSettings initializationSettingsIOS =
          const DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      final InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint("Notification clicked with payload: ${response.payload}");
          debugPrint(
            "Notification received in app (foreground): ID: ${response.id}, Payload: ${response.payload}",
          );
        },
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      await requestPermissions();
      debugPrint('✅ Notification permissions requested.');
      debugPrint('✅ Android notification and exact alarm permissions granted');
      await _createNotificationChannels();
      debugPrint('✅ Notification channels created.');
    } catch (e, stack) {
      debugPrint('Error initializing notifications: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  Future<void> requestPermissions() async {
    debugPrint('ℹ️ Requesting notification permissions...');
    final notificationStatus = await Permission.notification.request();
    debugPrint('ℹ️ Notification permission status: $notificationStatus');

    if (Platform.isAndroid) {
      debugPrint('ℹ️ Requesting exact alarm permission for Android...');
      final status = await Permission.scheduleExactAlarm.request();
      debugPrint('ℹ️ Exact alarm permission status: $status');
      if (status.isGranted) {
        debugPrint('✅ SCHEDULE_EXACT_ALARM permission granted');
      } else if (status.isDenied) {
        debugPrint('❌ SCHEDULE_EXACT_ALARM permission denied. Reminders may be delayed.');
      } else if (status.isPermanentlyDenied) {
        debugPrint('❌ SCHEDULE_EXACT_ALARM permission permanently denied. Opening app settings.');
        openAppSettings();
      }
    }
  }

  Future<void> _createNotificationChannels() async {
    // Do not use const for dynamic fields
    final AndroidNotificationChannel medicationChannel = AndroidNotificationChannel(
      _medicationChannelId,
      _medicationChannelName,
      description: 'Reminders for taking medications',
      importance: Importance.max,
      playSound: true,
    );
    debugPrint('Creating medication notification channel with max importance...');
    final AndroidNotificationChannel appointmentChannel = AndroidNotificationChannel(
      _appointmentChannelId,
      _appointmentChannelName,
      description: _appointmentChannelDescription,
      importance: Importance.max,
      playSound: true,
    );
    debugPrint('Creating appointment notification channel with max importance...');
    final androidPlugin = notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(medicationChannel);
    debugPrint('✅ Medication channel created.');
    await androidPlugin?.createNotificationChannel(appointmentChannel);
    debugPrint('✅ Appointment channel created.');
  }

  // MEDICATION REMINDER METHODS
  Future<void> scheduleMedicationReminder({
    required String medicationName,
    required String dosage,
    required TimeOfDay time,
    required int id,
  }) async {
    try {
      final scheduledDate = _nextInstanceOfTime(time.hour, time.minute);
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        _medicationChannelId,
        _medicationChannelName,
        channelDescription: 'Reminders for taking medications',
        importance: Importance.max,
        priority: Priority.high,
      );
      final DarwinNotificationDetails iosDetails = const DarwinNotificationDetails(
        sound: 'default',
      );
      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      try {
        await notificationsPlugin.zonedSchedule(
          id,
          '💊 Medication Reminder',
          'Time to take $medicationName ($dosage)',
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
        _scheduledNotificationIds.add(id);
        debugPrint('✅ Scheduled medication notification with details:');
        debugPrint('  - ID: $id');
        debugPrint('  - Title: 💊 Medication Reminder');
        debugPrint('  - Body: Time to take $medicationName ($dosage)');
        debugPrint('  - Scheduled Date: $scheduledDate');
        debugPrint('  - Android Mode: ${AndroidScheduleMode.exactAllowWhileIdle}');
      } catch (e, stack) {
        debugPrint('❌ Error in zonedSchedule for medication notification: $e');
        debugPrint('Stack trace: $stack');
      }
    } catch (e, stack) {
      debugPrint('❌ Error scheduling medication notification: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  Future<void> scheduleMedicationsNotifications(List<Map<String, dynamic>> medications) async {
    debugPrint('🔄 Scheduling notifications for ${medications.length} medications...');
    int notificationIdCounter = 0; // Simple counter for unique IDs

    for (var medData in medications) {
      final String name = medData['name'] ?? 'Unknown Medication';
      final String dosage = medData['dosage'] ?? '';
      final String frequency = medData['frequency'] ?? '';

      if (frequency.isNotEmpty) {
        final List<TimeOfDay> times = FrequencyToTimeMapper.mapFrequencyToTimes(frequency);

        if (times.isNotEmpty) {
          for (var time in times) {
            // Generate a unique ID for each notification
            // Combine a base ID (e.g., hash of medication name) with a time-based component
            // For simplicity, using a counter for now, but a more robust ID generation
            // might be needed for persistent notifications across app restarts.
            final int id = name.hashCode + time.hour * 100 + time.minute + notificationIdCounter++;

            await scheduleMedicationReminder(
              medicationName: name,
              dosage: dosage,
              time: time,
              id: id,
            );
          }
        } else {
          debugPrint('⏭️ No specific times mapped for frequency: $frequency for $name');
        }
      } else {
        debugPrint('⏭️ No frequency provided for medication: $name');
      }
    }
    debugPrint('✅ Finished scheduling medication notifications.');
  }

  // APPOINTMENT REMINDER METHODS - DAILY AT FIXED TIME
  Future<void> scheduleAppointmentReminder({
    required int id,
    required String title,
    required String doctorName,
    required String location,
    required DateTime scheduledDate,
    TimeOfDay reminderTime = const TimeOfDay(hour: 9, minute: 0),
  }) async {
    try {
      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
      final tz.TZDateTime appointmentDate = tz.TZDateTime.from(
        scheduledDate,
        tz.local,
      );
      if (appointmentDate.isAfter(now)) {
        final daysUntilAppointment = appointmentDate.difference(now).inDays;
        for (int i = 0; i <= daysUntilAppointment; i++) {
          final reminderDate = tz.TZDateTime(tz.local, now.year, now.month, now.day).add(Duration(days: i));
          final reminderDateTime = tz.TZDateTime(
            tz.local,
            reminderDate.year,
            reminderDate.month,
            reminderDate.day,
            reminderTime.hour,
            reminderTime.minute,
          );
          if (reminderDateTime.isAfter(now)) {
            try {
              await _scheduleDailyAppointmentNotification(
                id: id + i,
                title: title,
                doctorName: doctorName,
                location: location,
                scheduledDate: scheduledDate,
                reminderDate: reminderDateTime,
                daysUntil: daysUntilAppointment - i,
              );
            } catch (e, stack) {
              debugPrint('❌ Error scheduling daily appointment notification (ID: ${id + i}): $e');
              debugPrint('Stack trace: $stack');
            }
          } else {
            debugPrint('⏭️ Skipping daily appointment reminder for "$title" on $reminderDateTime because it is in the past.');
          }
        }
      } else {
        debugPrint('⏭️ Skipping appointment reminder for "$title" because the appointment date $appointmentDate is in the past.');
      }
      debugPrint(
          '✅ Scheduled daily appointment reminders for: $title on ${DateFormat('MMM dd, yyyy').format(scheduledDate)}');
    } catch (e, stack) {
      debugPrint('❌ Error scheduling appointment reminders: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  Future<void> _scheduleDailyAppointmentNotification({
    required int id,
    required String title,
    required String doctorName,
    required String location,
    required DateTime scheduledDate,
    required tz.TZDateTime reminderDate,
    required int daysUntil,
  }) async {
    try {
      final String notificationTitle = '📅 Appointment Reminder';
      String notificationBody;
      if (daysUntil == 0) {
        notificationBody =
            'Your appointment "$title" with Dr. $doctorName is today at $location';
      } else if (daysUntil == 1) {
        notificationBody =
            'Your appointment "$title" with Dr. $doctorName is tomorrow at $location';
      } else {
        notificationBody =
            'Your appointment "$title" with Dr. $doctorName is in $daysUntil days at $location';
      }
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        _appointmentChannelId,
        _appointmentChannelName,
        channelDescription: 'Reminders for upcoming appointments',
        importance: Importance.high,
        priority: Priority.high,
      );
      final DarwinNotificationDetails iosDetails = const DarwinNotificationDetails(
        sound: 'default',
      );
      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      await notificationsPlugin.zonedSchedule(
        id,
        notificationTitle,
        notificationBody,
        reminderDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exact,
        payload: 'appointment_$id',
      );
      _scheduledNotificationIds.add(id);
      debugPrint('✅ Scheduled daily appointment notification with details:');
      debugPrint('  - ID: $id');
      debugPrint('  - Title: $notificationTitle');
      debugPrint('  - Body: $notificationBody');
      debugPrint('  - Reminder Date: $reminderDate');
      debugPrint('  - Android Mode: ${AndroidScheduleMode.exact}');
    } catch (e, stack) {
      debugPrint('❌ Error scheduling daily appointment notification: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  // Alternative: Single daily reminder (only on the day of appointment)
  Future<void> scheduleAppointmentReminderSingle({
    required int id,
    required String title,
    required String doctorName,
    required String location,
    required DateTime scheduledDate,
    TimeOfDay reminderTime = const TimeOfDay(hour: 9, minute: 0),
  }) async {
    try {
      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
      final tz.TZDateTime appointmentDate = tz.TZDateTime.from(
        scheduledDate,
        tz.local,
      );
      if (appointmentDate.isAfter(now)) {
        final reminderDateTime = tz.TZDateTime(
          tz.local,
          appointmentDate.year,
          appointmentDate.month,
          appointmentDate.day,
          reminderTime.hour,
          reminderTime.minute,
        );
        if (reminderDateTime.isAfter(now)) {
          final AndroidNotificationDetails androidDetails =
              AndroidNotificationDetails(
            _appointmentChannelId,
            _appointmentChannelName,
            channelDescription: _appointmentChannelDescription,
            importance: Importance.max,
            priority: Priority.high,
          );
          final DarwinNotificationDetails iosDetails =
              const DarwinNotificationDetails(sound: 'default');
          final NotificationDetails details = NotificationDetails(
            android: androidDetails,
            iOS: iosDetails,
          );
          try {
            await notificationsPlugin.zonedSchedule(
              id,
              '📅 Appointment Today',
              'Your appointment "$title" with Dr. $doctorName is today at $location',
              reminderDateTime,
              details,
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              matchDateTimeComponents: DateTimeComponents.dateAndTime,
              payload: 'appointment_$id',
            );
            _scheduledNotificationIds.add(id);
            debugPrint('✅ Scheduled single appointment reminder with details:');
            debugPrint('  - ID: $id');
            debugPrint('  - Title: 📅 Appointment Today');
            debugPrint('  - Body: Your appointment "$title" with Dr. $doctorName is today at $location');
            debugPrint('  - Reminder Date: $reminderDateTime');
            debugPrint('  - Android Mode: ${AndroidScheduleMode.exactAllowWhileIdle}');
          } catch (e, stack) {
            debugPrint('❌ Error in zonedSchedule for single appointment reminder: $e');
            debugPrint('Stack trace: $stack');
          }
        } else {
          debugPrint('⏭️ Skipping single appointment reminder for "$title" because the reminder time $reminderDateTime is in the past.');
        }
      } else {
        debugPrint('⏭️ Skipping single appointment reminder for "$title" because the appointment date $appointmentDate is in the past.');
      }
      } catch (e, stack) {
      debugPrint('❌ Error scheduling appointment reminder: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  Future<void> cancelAppointmentNotifications(int appointmentId) async {
    try {
      // Remove all scheduled appointment notifications related to this appointmentId
      // (including daily reminders with incremented IDs)
      final idsToCancel = _scheduledNotificationIds
          .where((id) => id == appointmentId || id.toString().startsWith(appointmentId.toString()))
          .toList();
      for (final id in idsToCancel) {
        await cancelNotification(id);
      }
      debugPrint(
        '✅ Cancelled appointment notifications for ID: $appointmentId (Cancelled IDs: $idsToCancel)',
      );
    } catch (e) {
      debugPrint('❌ Error cancelling appointment notifications: $e');
    }
  }

  Future<void> scheduleBackgroundCompatibleReminder({
    required String docId,
    required String medicationName,
    required String dosage,
    required TimeOfDay time,
  }) async {
    try {
      final timeString = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      final id = '$docId-$timeString'.hashCode;
      final scheduledDate = _nextInstanceOfTime(time.hour, time.minute);
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        _medicationChannelId,
        _medicationChannelName,
        channelDescription: 'Reminders for taking medications',
        importance: Importance.high,
        priority: Priority.high,
      );
      final DarwinNotificationDetails iosDetails = const DarwinNotificationDetails(
        sound: 'default',
        threadIdentifier: 'medication-reminders',
      );
      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      await notificationsPlugin.zonedSchedule(
        id,
        '💊 Medication Reminder',
        'Time to take $medicationName ($dosage)',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'medication_$id',
      );
      _scheduledNotificationIds.add(id);
      debugPrint('✅ Scheduled background-compatible medication notification with details:');
      debugPrint('  - ID: $id');
      debugPrint('  - Title: 💊 Medication Reminder');
      debugPrint('  - Body: Time to take $medicationName ($dosage)');
      debugPrint('  - Scheduled Date: $scheduledDate');
      debugPrint('  - Android Mode: ${AndroidScheduleMode.exactAllowWhileIdle}');
    } catch (e, stack) {
      debugPrint('❌ Error scheduling background-compatible medication reminder: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  Future<void> rescheduleAllMedications(
    List<Map<String, dynamic>> medications, {
    String? currentUserId,
  }) async {
    // Only reschedule if user is logged in (currentUserId is not null)
    if (currentUserId == null) {
      debugPrint('⏭️ Skipping rescheduling medications: no user logged in');
      return;
    }
    try {
      await cancelAllNotifications();
      debugPrint('🔄 Rescheduling ${medications.length} medications');
      for (final medication in medications) {
        final timeString = medication['time'] as String?;
        final docId = medication['id'] as String?;
        if (timeString != null && docId != null) {
          final timeParts = timeString.split(':');
          if (timeParts.length == 2) {
            try {
              final hour = int.parse(timeParts[0]);
              final minute = int.parse(timeParts[1]);
              final notificationId = '$docId-$timeString'.hashCode;
              await scheduleBackgroundCompatibleReminder(
                docId: docId,
                medicationName: medication['medication'] ?? 'Unknown Medication',
                dosage: medication['dosage'] ?? '',
                time: TimeOfDay(hour: hour, minute: minute),
              );
              debugPrint(
                '✅ Rescheduled medication: ${medication['medication']} at $timeString (ID: $notificationId)',
              );
            } catch (e, stack) {
              debugPrint(
                '❌ Error rescheduling medication ${medication['medication']}: $e',
              );
              debugPrint('Stack trace: $stack');
            }
          }
        }
      }
    } catch (e, stack) {
      debugPrint('❌ Error in rescheduleAllMedications: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  Future<void> printPendingNotifications() async {
    try {
      debugPrint('🕒 Checking for pending notifications...');
      final pendingRequests = await notificationsPlugin.pendingNotificationRequests();
      if (pendingRequests.isEmpty) {
        debugPrint('✅ No pending notifications found.');
        return;
      }
      debugPrint('🕒 Found ${pendingRequests.length} pending notifications:');
      for (final request in pendingRequests) {
        debugPrint(
            '  - ID: ${request.id}, Title: "${request.title}", Body: "${request.body}", Payload: "${request.payload}"'
        );
      }
    } catch (e, stack) {
      debugPrint('❌ Error fetching pending notifications: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  Future<void> cancelNotification(int id) async {
    await notificationsPlugin.cancel(id);
    _scheduledNotificationIds.remove(id);
  }

  Future<void> cancelAllNotifications() async {
    await notificationsPlugin.cancelAll();
    _scheduledNotificationIds.clear();
  }

  Set<int> get scheduledNotificationIds => _scheduledNotificationIds;

  bool isNotificationScheduled(int id) =>
      _scheduledNotificationIds.contains(id);

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    debugPrint('Calculated scheduledDate: $scheduledDate in timezone ${scheduledDate.location.name}');
    debugPrint('🕑 Next instance of time will schedule at: $scheduledDate');
    return scheduledDate;
  }
}

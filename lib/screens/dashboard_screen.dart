import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:recoveryplus/screens/exercise_screen.dart';
import 'package:recoveryplus/screens/medication_screen.dart';
import 'package:recoveryplus/screens/profile_screen.dart';
import 'package:recoveryplus/screens/appointments_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http; // Import http package
import 'dart:convert'; // Import dart:convert for json operations
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv for backend URL
import 'package:recoveryplus/services/database_service.dart';
import 'package:recoveryplus/widgets/pain_tracker.dart';
import 'package:recoveryplus/services/notification_service.dart';
import 'package:recoveryplus/widgets/recovery_progress.dart';
import 'package:image/image.dart' as img; // Import image package
import 'dart:io'; // Import dart:io for File operations
import 'package:path_provider/path_provider.dart'; // Import path_provider for temporary directory

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DatabaseService? _databaseService;
  late final NotificationService _notificationService; // Added NotificationService

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService(); // Initialize NotificationService
    _initializeDatabaseService();
  }

  void _initializeDatabaseService() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _databaseService = DatabaseService(uid: user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (user == null) {
      return Scaffold(body: Center(child: Text('Please sign in', style: textTheme.bodyLarge?.copyWith(color: colorScheme.onBackground))));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recovery Plus'),
        foregroundColor: colorScheme.onPrimary, // Ensure text/icons are visible
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.person, color: colorScheme.onPrimary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
              );
            },
            tooltip: 'Profile',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Welcome section
            _buildWelcomeSection(user.uid, colorScheme, textTheme),
            SizedBox(height: 20),

            // Recovery Progress
            _buildRecoveryProgress(user.uid),
            SizedBox(height: 20),

            // Medication Summary
            _buildMedicationSummary(user.uid, colorScheme, textTheme),
            SizedBox(height: 20),

            // Quick Actions
            _buildQuickActions(context, colorScheme, textTheme),
            SizedBox(height: 20),

            // Pain Tracker
            PainTrackerWidget(),
            SizedBox(height: 20),

            // Today's Pain History
            _buildPainHistory(user.uid, colorScheme, textTheme),
            SizedBox(height: 20),

            // Daily Tips
            _buildDailyTips(colorScheme, textTheme),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(String userId, ColorScheme colorScheme, TextTheme textTheme) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('recovery_data')
          .doc(userId)
          .get(),
      builder: (context, snapshot) {
        String userName = 'Patient';
        String surgeryType = 'Recovery';

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          userName = data?['name'] ?? 'Patient';
          surgeryType = data?['surgeryType'] ?? 'Recovery';
        }

        return Card(
          color: colorScheme.surface, // Use surface for card background
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(
                  Icons.health_and_safety,
                  size: 64,
                  color: colorScheme.primary,
                ),
                SizedBox(height: 10),
                Text(
                  'Hello, $userName!',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  '$surgeryType Recovery Journey',
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 5),
                Text(
                  'How are you feeling today?',
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecoveryProgress(String userId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('recovery_data')
          .doc(userId)
          .get(),
      builder: (context, snapshot) {
        DateTime? surgeryDate;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          surgeryDate = data?['surgeryDate']?.toDate();
        }

        return RecoveryProgressWidget(surgeryDate: surgeryDate);
      },
    );
  }

  Widget _buildMedicationSummary(String userId, ColorScheme colorScheme, TextTheme textTheme) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('recovery_data')
          .doc(userId)
          .collection('medications')
          .where('taken', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return SizedBox.shrink();
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator(color: colorScheme.primary);
        }

        final medications = snapshot.data?.docs ?? [];

        if (medications.isEmpty) {
          return SizedBox.shrink();
        }

        return Card(
          color: colorScheme.surface, // Use surface for card background
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.medication, color: colorScheme.secondary),
                    SizedBox(width: 10),
                    Text(
                      'Medication Reminder',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                  'You have ${medications.length} medication(s) to take today',
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 5),
                Text(
                  'Tap below to manage medications',
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      color: colorScheme.surface, // Use surface for card background
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Quick Actions',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActionButton(
                  context,
                  Icons.medication,
                  'Meds',
                  colorScheme.secondary,
                  colorScheme.secondary.withOpacity(0.1), // Use secondary with opacity
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MedicationScreen(),
                      ),
                    );
                  },
                ),
                _buildActionButton(
                  context,
                  Icons.fitness_center,
                  'Exercise',
                  colorScheme.primary,
                  colorScheme.primary.withOpacity(0.1), // Use primary with opacity
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ExerciseScreen()),
                    );
                  },
                ),
                _buildActionButton(
                  context,
                  Icons.calendar_today,
                  'Appointments',
                  colorScheme.tertiary, // Use tertiary for accent
                  colorScheme.tertiary.withOpacity(0.1), // Use tertiary with opacity
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AppointmentsScreen(),
                      ),
                    );
                  },
                ),
                _buildActionButton(
                  context,
                  Icons.person,
                  'Profile',
                  colorScheme.error,
                  colorScheme.error.withOpacity(0.1), // Use error with opacity
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ProfileScreen()),
                    );
                  },
                ),
                _buildActionButton(
                  context,
                  Icons.document_scanner,
                  'Scan Rx',
                  colorScheme.tertiary,
                  colorScheme.tertiary.withOpacity(0.1),
                  _pickImageAndProcessPrescription,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String label,
    Color iconColor,
    Color bgColor,
    VoidCallback onPressed,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: iconColor.withOpacity(0.3)),
          ),
          child: IconButton(
            icon: Icon(icon, size: 30),
            onPressed: onPressed,
            color: iconColor,
          ),
        ),
        SizedBox(height: 5),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500, color: colorScheme.onSurface),
        ),
      ],
    );
  }

  Widget _buildPainHistory(String userId, ColorScheme colorScheme, TextTheme textTheme) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('recovery_data')
          .doc(userId)
          .collection('pain_logs')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SizedBox.shrink();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: colorScheme.primary));
        }

        final painLogs = snapshot.data?.docs ?? [];
        final now = DateTime.now();

        final todaysLogs = painLogs.where((log) {
          final timestamp = log['timestamp']?.toDate();
          return timestamp != null &&
              timestamp.day == now.day &&
              timestamp.month == now.month &&
              timestamp.year == now.year;
        }).toList();

        if (todaysLogs.isEmpty) {
          return SizedBox.shrink();
        }

        return Card(
          elevation: 3,
          color: colorScheme.surface, // Use surface for card background
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.history, color: colorScheme.primary),
                    SizedBox(width: 8),
                    Text(
                      "Today's Pain History",
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Column(
                  children: todaysLogs.map((log) {
                    final data = log.data() as Map<String, dynamic>;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getPainColor(data['painLevel'], colorScheme),
                        child: Text(
                          data['painLevel'].toString(),
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        'Level ${data['painLevel']}/10',
                        style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                      ),
                      subtitle:
                          data['notes'] != null && data['notes'].isNotEmpty
                          ? Text(data['notes'], style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.8)))
                          : Text('No notes provided', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.6))),
                      trailing: Text(
                        _formatTime(data['timestamp']?.toDate()),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 8),
                Divider(color: colorScheme.onSurface.withOpacity(0.2)), // Theme color
                Text(
                  'Total entries today: ${todaysLogs.length}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDailyTips(ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      elevation: 3,
      color: colorScheme.surface, // Use surface for card background
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Recovery Tips',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            SizedBox(height: 12),
            _buildTipItem(
              'Take medications as prescribed',
              Icons.medication,
              colorScheme.primary.withOpacity(0.1), // Use primary with opacity
              colorScheme.primary,
            ),
            _buildTipItem(
              'Drink plenty of water',
              Icons.local_drink,
              colorScheme.secondary.withOpacity(0.1), // Use secondary with opacity
              colorScheme.secondary,
            ),
            _buildTipItem(
              'Perform recommended exercises',
              Icons.fitness_center,
              colorScheme.tertiary.withOpacity(0.1), // Use tertiary with opacity
              colorScheme.tertiary,
            ),
            _buildTipItem(
              'Rest when feeling tired',
              Icons.hotel,
              colorScheme.surface, // Use surface
              colorScheme.primary, // Icon color
            ),
            _buildTipItem(
              'Track your pain levels regularly',
              Icons.analytics,
              colorScheme.error.withOpacity(0.1), // Use error with opacity
              colorScheme.error,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem(String text, IconData icon, Color bgColor, Color iconColor) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          SizedBox(width: 12),
          Expanded(child: Text(text, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface))),
        ],
      ),
    );
  }

  Color _getPainColor(int level, ColorScheme colorScheme) {
    if (level <= 3) return colorScheme.secondary;
    if (level <= 6) return colorScheme.tertiary;
    return colorScheme.error;
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickImageAndProcessPrescription() async {
    print("DashboardScreen: _pickImageAndProcessPrescription started.");
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) {
      print("DashboardScreen: Image picking cancelled.");
      return;
    }

    print("DashboardScreen: Image picked successfully: ${pickedFile.path}");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Processing prescription...'), duration: Duration(seconds: 3)),
      );
    }

    try {
      final String backendUrl = dotenv.env['BACKEND_URL']!;
      print("DashboardScreen: Calling Python backend at $backendUrl/process_prescription...");
      
      var request = http.MultipartRequest('POST', Uri.parse('$backendUrl/process_prescription'));
      request.files.add(await http.MultipartFile.fromPath('image', pickedFile.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final Map<String, dynamic> structuredData = jsonDecode(responseBody);
        print('DashboardScreen: Backend call successful. Structured Data: $structuredData');

        final List<dynamic> medicationsData = structuredData['medications'] ?? [];
        final List<dynamic> exercisesData = structuredData['exercises'] ?? [];

        for (var medData in medicationsData) {
          print("DashboardScreen: Raw timings data for ${medData['name']} from backend: ${medData['timings']}"); // Moved logging
          if (_databaseService != null) {
            final medicationName = medData['name'] ?? '';
            final dosage = medData['dosage'] ?? '';
            final timings = (medData['timings'] as List<dynamic>?)?.cast<String>() ?? [];

            final docId = await _databaseService!.addMedication(
              medicationName,
              dosage,
              timings,
            );
            print("DashboardScreen: Medication added to Firebase: $medicationName with timings: $timings");

            for (var timeString in timings) {
              try {
                final parts = timeString.split(':');
                if (parts.length == 2) {
                  final hour = int.parse(parts[0]);
                  final minute = int.parse(parts[1]);
                  final timeOfDay = TimeOfDay(hour: hour, minute: minute);

                  await _notificationService.scheduleBackgroundCompatibleReminder(
                    docId: docId,
                    medicationName: medicationName,
                    dosage: dosage,
                    time: timeOfDay,
                  );
                  print("DashboardScreen: Notification scheduled for $medicationName at $timeString");
                }
              } catch (e) {
                print("DashboardScreen: Error parsing time '$timeString' for notification: $e");
              }
            }
          }
        }

        for (var exData in exercisesData) { // exercisesData is correctly scoped here
          if (_databaseService != null) {
            // await _databaseService!.addExercise(
            //   exData['name'] ?? '',
            //   exData['duration'] ?? '',
            //   exData['frequency'] ?? '',
            //   exData['category'] ?? ''
            // );
            print("DashboardScreen: Exercise added to Firebase: ${exData['name']}");
          }
        }

        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Prescription processed successfully!'), duration: const Duration(seconds: 3)),
          );
          // Add navigation to MedicationScreen
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => MedicationScreen()),
          );
        }
        print("DashboardScreen: Prescription processed successfully.");

      } else {
        final responseBody = await response.stream.bytesToString();
        print("DashboardScreen: Backend Error: Status Code ${response.statusCode}, Body: $responseBody");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error processing prescription: ${response.statusCode} - $responseBody'), duration: const Duration(seconds: 5)),
          );
        }
      }

    } catch (e, stackTrace) {
      print("DashboardScreen: Error processing prescription: $e\n$stackTrace");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing prescription: $e'), duration: const Duration(seconds: 5)),
        );
      }
    }
  }
}
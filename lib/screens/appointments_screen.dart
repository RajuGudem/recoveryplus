import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:recoveryplus/models/appointment.dart';
import 'package:recoveryplus/services/appointment_service.dart';
import 'package:recoveryplus/widgets/appointment_form.dart';
import 'package:url_launcher/url_launcher.dart';

class AppointmentsScreen extends StatefulWidget {
  @override
  _AppointmentsScreenState createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  int _selectedIndex = 0;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            _userProfile = userDoc.data() as Map<String, dynamic>;
          });
        }
      } catch (e) {
        print('Error loading user profile: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Please sign in',
            style: TextStyle(color: colorScheme.onSurface),
          ),
        ),
        backgroundColor: colorScheme.background,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recovery Plus'),
        foregroundColor: colorScheme.onPrimary,
        actions: [],
        elevation: 0,
      ),
      body: Column(
        children: [
          // Segmented Control
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Text('Upcoming'),
                    selected: _selectedIndex == 0,
                    onSelected: (selected) {
                      setState(() {
                        _selectedIndex = selected ? 0 : _selectedIndex;
                      });
                    },
                    selectedColor: colorScheme.primary,
                    labelStyle: TextStyle(
                      color: _selectedIndex == 0
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                    ),
                    backgroundColor: colorScheme.surface,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: Text('Past'),
                    selected: _selectedIndex == 1,
                    onSelected: (selected) {
                      setState(() {
                        _selectedIndex = selected ? 1 : _selectedIndex;
                      });
                    },
                    selectedColor: colorScheme.primary,
                    labelStyle: TextStyle(
                      color: _selectedIndex == 1
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                    ),
                    backgroundColor: colorScheme.surface,
                  ),
                ),
              ],
            ),
          ),
          // Appointments List
          Expanded(
            child: _selectedIndex == 0
                ? _buildUpcomingAppointments()
                : _buildPastAppointments(),
          ),
        ],
      ),
      backgroundColor: colorScheme.background,
      
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAppointmentDialog(context),
        backgroundColor: colorScheme.primary,
        child: Icon(Icons.add, color: colorScheme.onPrimary),
      ),
    );
  }

  Widget _buildUpcomingAppointments() {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<Appointment>>(
      stream: AppointmentService.getUpcomingAppointments(user!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: colorScheme.primary));
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 48, color: colorScheme.error),
                SizedBox(height: 16),
                Text(
                  'Error loading appointments',
                  style: TextStyle(fontSize: 16, color: colorScheme.error),
                ),
              ],
            ),
          );
        }

        final appointments = snapshot.data ?? [];

        if (appointments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, size: 64, color: colorScheme.onSurface.withAlpha(128)),
                SizedBox(height: 16),
                Text(
                  'No upcoming appointments',
                  style: TextStyle(fontSize: 18, color: colorScheme.onSurface.withAlpha(179)),
                ),
                Text(
                  'Use the + button to add your first appointment',
                  style: TextStyle(color: colorScheme.onSurface.withAlpha(179)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final appointment = appointments[index];
            return _buildAppointmentCard(appointment, false);
          },
        );
      },
    );
  }

  Widget _buildPastAppointments() {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<Appointment>>(
      stream: AppointmentService.getAppointments(user!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: colorScheme.primary));
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 48, color: colorScheme.error),
                SizedBox(height: 16),
                Text(
                  'Error loading past appointments',
                  style: TextStyle(fontSize: 16, color: colorScheme.error),
                ),
              ],
            ),
          );
        }

        final appointments = snapshot.data ?? [];

        // Filter for past appointments (completed or date in past)
        final pastAppointments = appointments.where((appt) {
          return appt.isCompleted || appt.dateTime.isBefore(DateTime.now());
        }).toList();

        if (pastAppointments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: colorScheme.onSurface.withAlpha(128)),
                SizedBox(height: 16),
                Text(
                  'No past appointments',
                  style: TextStyle(fontSize: 18, color: colorScheme.onSurface.withAlpha(179)),
                ),
                Text(
                  'Completed appointments will appear here',
                  style: TextStyle(color: colorScheme.onSurface.withAlpha(179)),
                ),
              ],
            ),
          );
        }

        // Sort by date (newest first)
        pastAppointments.sort((a, b) => b.dateTime.compareTo(a.dateTime));

        return ListView.builder(
          itemCount: pastAppointments.length,
          itemBuilder: (context, index) {
            final appointment = pastAppointments[index];
            return _buildAppointmentCard(appointment, true);
          },
        );
      },
    );
  }

  Widget _buildAppointmentCard(Appointment appointment, bool isPast) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colorScheme.surface,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPast
              ? colorScheme.onSurface.withAlpha(51) // 20% opacity
              : colorScheme.primary,
          child: Icon(Icons.calendar_today, color: colorScheme.onPrimary, size: 20),
        ),
        title: Text(
          appointment.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: isPast ? TextDecoration.lineThrough : null,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dr. ${appointment.doctorName}', style: TextStyle(color: colorScheme.onSurface.withAlpha(204))), // 80%
            Text(
              DateFormat('MMM dd, yyyy - hh:mm a').format(appointment.dateTime),
              style: TextStyle(color: colorScheme.onSurface.withAlpha(204)),
            ),
            if (appointment.location.isNotEmpty)
              Text(appointment.location, style: TextStyle(color: colorScheme.onSurface.withAlpha(204))),
            if (appointment.hospitalContact.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    Icon(Icons.phone, size: 16, color: colorScheme.onSurface.withAlpha(179)), // 70%
                    SizedBox(width: 4),
                    Text(appointment.hospitalContact, style: TextStyle(color: colorScheme.onSurface.withAlpha(204))),
                  ],
                ),
              ),
            if (appointment.notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text('Notes: ${appointment.notes}', style: TextStyle(color: colorScheme.onSurface.withAlpha(204))),
              ),
          ],
        ),
        trailing: isPast
            ? IconButton(
                icon: Icon(Icons.delete, color: colorScheme.error),
                onPressed: () => _deleteAppointment(appointment),
              )
            : PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(child: Text('Edit', style: TextStyle(color: colorScheme.onSurface)), value: 'edit'),
                  PopupMenuItem(
                    child: Text('Mark Complete', style: TextStyle(color: colorScheme.onSurface)),
                    value: 'complete',
                  ),
                  if (appointment.hospitalContact.isNotEmpty)
                    PopupMenuItem(
                      child: Text('Request via WhatsApp', style: TextStyle(color: colorScheme.onSurface)),
                      value: 'whatsapp',
                    ),
                  PopupMenuItem(child: Text('Delete', style: TextStyle(color: colorScheme.error)), value: 'delete'),
                ],
                onSelected: (value) => _handleAppointmentAction(value, appointment),
                color: colorScheme.surface,
              ),
        onTap: !isPast ? () => _editAppointment(appointment) : null,
      ),
    );
  }

  void _handleAppointmentAction(String action, Appointment appointment) {
    switch (action) {
      case 'edit':
        _editAppointment(appointment);
        break;
      case 'complete':
        _markAsCompleted(appointment);
        break;
      case 'whatsapp':
        _requestAppointmentViaWhatsApp(appointment);
        break;
      case 'delete':
        _deleteAppointment(appointment);
        break;
    }
  }

  void _editAppointment(Appointment appointment) {
    showDialog(
      context: context,
      builder: (context) => AppointmentForm(
        appointment: appointment,
        onSave: (updatedAppointment) async {
          try {
            await AppointmentService.updateAppointment(updatedAppointment);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Appointment updated successfully', style: TextStyle(color: Theme.of(context).colorScheme.onSecondary)),
                backgroundColor: Theme.of(context).colorScheme.secondary,
                duration: const Duration(seconds: 3),
              ),
            );
          } catch (e) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error updating appointment: ${e.toString()}', style: TextStyle(color: Theme.of(context).colorScheme.onError)),
                backgroundColor: Theme.of(context).colorScheme.error,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        },
      ),
    );
  }

  void _markAsCompleted(Appointment appointment) async {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    try {
      await AppointmentService.markAsCompleted(appointment.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appointment status updated!', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSecondary)),
          backgroundColor: colorScheme.secondary,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}', style: TextStyle(color: Theme.of(context).colorScheme.onError)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _deleteAppointment(Appointment appointment) async {
    final colorScheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Appointment', style: TextStyle(color: colorScheme.onSurface)),
        content: Text(
          'Are you sure you want to delete this appointment? This action cannot be undone.',
          style: TextStyle(color: colorScheme.onSurface.withAlpha(204)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: colorScheme.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: colorScheme.error)),
          ),
        ],
        backgroundColor: colorScheme.surface,
      ),
    );

    if (confirmed == true) {
      final colorScheme = Theme.of(context).colorScheme;
      final textTheme = Theme.of(context).textTheme;
      try {
        await AppointmentService.deleteAppointment(appointment.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Appointment deleted successfully', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSecondary)),
        backgroundColor: colorScheme.secondary,
        duration: const Duration(seconds: 3),
      ),
    );
      } catch (e) {
      final textTheme = Theme.of(context).textTheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete appointment: ${e.toString()}', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onError)),
          backgroundColor: colorScheme.error,
          duration: const Duration(seconds: 5),
        ),
      );
      }
    }
  }

  void _showAddAppointmentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AppointmentForm(
        onSave: (appointment) async {
          try {
            await AppointmentService.addAppointment(appointment);
            Navigator.pop(context);

            // Show option to request appointment via WhatsApp
            if (appointment.hospitalContact.isNotEmpty) {
              _showWhatsAppRequestDialog(appointment);
            } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Appointment added successfully', style: TextStyle(color: Theme.of(context).colorScheme.onSecondary)), backgroundColor: Theme.of(context).colorScheme.secondary, duration: const Duration(seconds: 3)),              );
            }
          } catch (e) {
            Navigator.pop(context);
            final colorScheme = Theme.of(context).colorScheme;
            final textTheme = Theme.of(context).textTheme;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to add appointment: ${e.toString()}', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onError)),
                backgroundColor: colorScheme.error,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        },
      ),
    );
  }

  void _showWhatsAppRequestDialog(Appointment appointment) {
    final colorScheme = Theme.of(context).colorScheme;

    // First validate if the phone number is valid
    String formattedNumber = _formatPhoneNumber(appointment.hospitalContact);
    bool hasValidContact = formattedNumber.isNotEmpty;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Appointment Added', style: TextStyle(color: colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your appointment has been added to your list.', style: TextStyle(color: colorScheme.onSurface)),
            if (!hasValidContact) ...[
              SizedBox(height: 12),
              Text(
                'Note: The contact number provided may not be valid for WhatsApp.',
                style: TextStyle(color: colorScheme.secondary),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Appointment added successfully', style: TextStyle(color: colorScheme.onSecondary)),
                  backgroundColor: colorScheme.secondary,
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            child: Text('Not Now', style: TextStyle(color: colorScheme.primary)),
          ),
          if (hasValidContact)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _requestAppointmentViaWhatsApp(appointment);
              },
              child: Text('Request via WhatsApp', style: TextStyle(color: colorScheme.primary)),
            ),
        ],
        backgroundColor: colorScheme.surface,
      ),
    );
  }

  void _requestAppointmentViaWhatsApp(Appointment appointment) async {
    final colorScheme = Theme.of(context).colorScheme;

    if (appointment.hospitalContact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No contact number available for this appointment', style: TextStyle(color: colorScheme.onError)),
          backgroundColor: colorScheme.error,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    try {
      // Clean and format the phone number
      String phoneNumber = _formatPhoneNumber(appointment.hospitalContact);

      if (phoneNumber.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text('Invalid phone number format', style: TextStyle(color: colorScheme.onError)),
            backgroundColor: colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      // Create detailed message with all appointment information and user profile
      String message = await _createDetailedAppointmentMessage(appointment);

      // Create the WhatsApp URL
      String url =
          'https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}';

      try {
        debugPrint('Attempting to launch WhatsApp URL: $url');
        await launch(url);
      } catch (e) {
        debugPrint('Error launching WhatsApp: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not launch WhatsApp. Please ensure it is installed and the number is valid.',
              style: TextStyle(color: colorScheme.onError),
            ),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}', style: TextStyle(color: colorScheme.onError)),
          backgroundColor: colorScheme.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<String> _createDetailedAppointmentMessage(
    Appointment appointment,
  ) async {
    String date = DateFormat(
      'EEEE, MMMM dd, yyyy',
    ).format(appointment.dateTime);
    String time = DateFormat('hh:mm a').format(appointment.dateTime);

    // Get user profile data
    String userName = user?.displayName ?? 'Patient';
    String userEmail = user?.email ?? '';
    String userAge = _userProfile?['age']?.toString() ?? 'Not specified';
    String userGender = _userProfile?['gender']?.toString() ?? 'Not specified';
    String userBloodGroup =
        _userProfile?['bloodGroup']?.toString() ?? 'Not specified';
    String userMedicalHistory =
        _userProfile?['medicalHistory']?.toString() ?? 'None';

    return '''
Hello, I would like to request an appointment with the following details:

*PATIENT INFORMATION*
👤 *Name*: ${appointment.userName}
📧 *Email*: $userEmail
📞 *Phone*: ${appointment.userContact?.isNotEmpty == true ? appointment.userContact! : 'Will provide'}
🎂 *Age*: ${appointment.userAge}
🚻 *Gender*: ${appointment.userGender}
🩸 *Blood Group*: $userBloodGroup
📋 *Medical History*: ${appointment.medicalHistory}

*APPOINTMENT DETAILS*
📋 *Type*: ${appointment.title}
👨‍⚕️ *Doctor*: Dr. ${appointment.doctorName}
📅 *Preferred Date*: $date
⏰ *Preferred Time*: $time
📍 *Location*: ${appointment.location.isNotEmpty ? appointment.location : 'To be confirmed'}

*CONTACT INFORMATION*
🏥 *Hospital Contact*: ${appointment.hospitalContact.isNotEmpty ? appointment.hospitalContact : 'Not provided'}

${appointment.notes.isNotEmpty ? '📝 *Additional Notes*: ${appointment.notes}' : ''}

Please confirm if this time works or let me know your available slots.

Looking forward to your response.

Thank you!
''';
  }

  String _formatPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleaned.isEmpty) return '';

    // If number starts with 0, remove it
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }

    // Add country code if not present (adjust for your region)
    // if (!cleaned.startsWith('+')) {
    //   // Check if it already has country code
    //   if (cleaned.length <= 10) {
    //     cleaned = '1$cleaned'; // Default to US/Canada (+1)
    //   }
    // }

    return cleaned;
  }
}
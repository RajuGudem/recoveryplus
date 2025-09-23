import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:recoveryplus/services/database_service.dart';
import 'package:recoveryplus/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:recoveryplus/providers/theme_provider.dart';
import 'package:recoveryplus/services/export_service.dart';
import 'package:recoveryplus/screens/auth_screen.dart'; // Added import

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  _RealProfileScreenState createState() => _RealProfileScreenState();
}

class _RealProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surgeryTypeController = TextEditingController();
  final _surgeryDateController = TextEditingController();
  final _doctorNameController = TextEditingController();

  DateTime? _surgeryDate;
  bool _isEditing = false;
  bool _isLoading = false;
  User? _user;
  DatabaseService? _databaseService;

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _loadUserData();
  }

  void _initializeUser() {
    _user = FirebaseAuth.instance.currentUser;
    if (_user != null) {
      _databaseService = DatabaseService(uid: _user!.uid);
    }
  }

  Future<void> _loadUserData() async {
    if (_user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('recovery_data')
          .doc(_user!.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _nameController.text = data['name'] ?? '';
          _surgeryTypeController.text = data['surgeryType'] ?? '';
          _doctorNameController.text = data['doctorName'] ?? '';

          if (data['surgeryDate'] != null) {
            _surgeryDate = data['surgeryDate'].toDate();
            _surgeryDateController.text = _formatDate(_surgeryDate!);
          }
        });
      }
    } catch (error) {
      print('Error loading user data: $error');
    }
  }

  Future<void> _exportAllData() async {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Preparing your data export...', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSecondary)), backgroundColor: colorScheme.secondary, duration: const Duration(seconds: 3)));

      await ExportService.exportData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data exported successfully!', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSecondary)),
          backgroundColor: colorScheme.secondary,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $error', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onError)),
          backgroundColor: colorScheme.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _exportPainData() async {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Preparing pain data export...', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSecondary)), backgroundColor: colorScheme.secondary, duration: const Duration(seconds: 3)));

      await ExportService.exportPainData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pain data exported successfully!', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSecondary)),
          backgroundColor: colorScheme.secondary,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $error', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onError)),
          backgroundColor: colorScheme.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _exportMedicationData() async {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preparing medication data export...', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSecondary)), backgroundColor: colorScheme.secondary, duration: const Duration(seconds: 3)),
      );

      await ExportService.exportMedicationData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Medication data exported successfully!', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSecondary)),
          backgroundColor: colorScheme.secondary,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $error', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onError)),
          backgroundColor: colorScheme.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    if (_user == null) {
      return _buildAuthRequiredScreen(isDarkMode);
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recovery Plus'),
        foregroundColor: colorScheme.onPrimary, // Ensure text/icons are visible
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit, color: colorScheme.onPrimary),
            onPressed: () {
              if (_isEditing) {
                _saveProfile();
              } else {
                setState(() {
                  _isEditing = true;
                });
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.logout, color: colorScheme.onPrimary),
            onPressed: () {
              _showLogoutConfirmation(context, authService);
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildProfileAvatar(isDarkMode),
                    SizedBox(height: 24),
                    _buildEditableField(
                      controller: _nameController,
                      label: 'Full Name',
                      icon: Icons.person,
                      isEditing: _isEditing,
                      isDarkMode: isDarkMode,
                    ),
                    SizedBox(height: 16),
                    _buildEditableField(
                      controller: _surgeryTypeController,
                      label: 'Surgery Type',
                      icon: Icons.medical_services,
                      isEditing: _isEditing,
                      isDarkMode: isDarkMode,
                    ),
                    SizedBox(height: 16),
                    _buildDateField(isDarkMode),
                    SizedBox(height: 16),
                    _buildEditableField(
                      controller: _doctorNameController,
                      label: 'Doctor\'s Name',
                      icon: Icons.medical_services,
                      isEditing: _isEditing,
                      isDarkMode: isDarkMode,
                    ),
                    SizedBox(height: 24),
                    if (_isEditing)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text('Save Changes'),
                        ),
                      ),
                    SizedBox(height: 20),
                    _buildAppInfo(isDarkMode),
                    SizedBox(height: 20),
                    _buildThemeSelector(isDarkMode),
                    _buildDataExportOptions(isDarkMode),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAuthRequiredScreen(bool isDarkMode) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recovery Plus'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person, size: 64, color: colorScheme.onBackground),
            SizedBox(height: 20),
            Text(
              'Please sign in to view profile',
              style: textTheme.bodyLarge?.copyWith(color: colorScheme.onBackground),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _initializeUser();
                _loadUserData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              child: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(bool isDarkMode) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: CircleAvatar(
        radius: 50,
        backgroundColor: colorScheme.primary,
        child: Icon(
          Icons.person,
          size: 50,
          color: colorScheme.onPrimary,
        ),
      ),
    );
  }

  Widget _buildEditableField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isEditing,
    required bool isDarkMode,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return TextFormField(
      controller: controller,
      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: textTheme.labelLarge?.copyWith(
          color: colorScheme.onSurface.withOpacity(0.7),
        ),
        prefixIcon: Icon(
          icon,
          color: colorScheme.onSurface.withOpacity(0.7),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: !isEditing,
        fillColor: colorScheme.surface,
      ),
      readOnly: !isEditing,
      validator: (value) {
        if (isEditing && (value == null || value.isEmpty)) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }

  Widget _buildDateField(bool isDarkMode) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return TextFormField(
      controller: _surgeryDateController,
      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: 'Surgery Date',
        labelStyle: textTheme.labelLarge?.copyWith(
          color: colorScheme.onSurface.withOpacity(0.7),
        ),
        prefixIcon: Icon(
          Icons.calendar_today,
          color: colorScheme.onSurface.withOpacity(0.7),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: !_isEditing,
        fillColor: colorScheme.surface,
      ),
      readOnly: true,
      onTap: _isEditing
          ? () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _surgeryDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: colorScheme.copyWith(
                        primary: colorScheme.primary, // Header background color
                        onPrimary: colorScheme.onPrimary, // Header text color
                        onSurface: colorScheme.onSurface, // Body text color
                      ),
                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(foregroundColor: colorScheme.primary), // Button text color
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (date != null) {
                setState(() {
                  _surgeryDate = date;
                  _surgeryDateController.text = _formatDate(date);
                });
              }
            }
          : null,
      validator: (value) {
        if (_isEditing && (value == null || value.isEmpty)) {
          return 'Please select surgery date';
        }
        return null;
      },
    );
  }

  Widget _buildAppInfo(bool isDarkMode) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      color: colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'App Information',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 12),
            ListTile(
              leading: Icon(
                Icons.info,
                color: colorScheme.secondary,
              ),
              title: Text(
                'Version 1.0.0',
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.medical_services,
                color: colorScheme.secondary,
              ),
              title: Text(
                'Post Surgery Recovery App',
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.support,
                color: colorScheme.secondary,
              ),
              title: Text(
                'Support: support@recoveryapp.com',
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSelector(bool isDarkMode) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Card(
      color: colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appearance',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 12),
            ListTile(
              leading: Icon(
                Icons.color_lens,
                color: colorScheme.secondary,
              ),
              title: Text(
                'Dark Mode',
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
              ),
              trailing: Switch(
                value: themeProvider.isDarkMode,
                onChanged: (value) {
                  themeProvider.setTheme(value);
                },
                activeColor: colorScheme.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    if (_formKey.currentState!.validate() && _surgeryDate != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        if (_databaseService != null) {
          await _databaseService!.updateUserData(
            _nameController.text.trim(),
            _surgeryTypeController.text.trim(),
            _surgeryDate!,
            _doctorNameController.text.trim(),
          );
        }

        setState(() {
          _isEditing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile updated successfully!', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSecondary)),
            backgroundColor: colorScheme.secondary,
            duration: const Duration(seconds: 3),
          ),
        );
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $error', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onError)),
            backgroundColor: colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Widget _buildDataExportOptions(bool isDarkMode) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      color: colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data Export',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 12),
            ListTile(
              leading: Icon(
                Icons.download,
                color: colorScheme.secondary,
              ),
              title: Text(
                'Export All Data',
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
              ),
              subtitle: Text(
                'CSV format for doctors',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
              ),
              onTap: _exportAllData,
            ),
            ListTile(
              leading: Icon(
                Icons.analytics,
                color: colorScheme.secondary,
              ),
              title: Text(
                'Export Pain Data',
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
              ),
              subtitle: Text(
                'Pain logs only',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
              ),
              onTap: _exportPainData,
            ),
            ListTile(
              leading: Icon(
                Icons.medication,
                color: colorScheme.secondary,
              ),
              title: Text(
                'Export Medication History',
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
              ),
              subtitle: Text(
                'Medication records',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
              ),
              onTap: _exportMedicationData,
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context, AuthService authService) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colorScheme.surface, // Theme color
          title: Text('Logout', style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface)),
          content: Text('Are you sure you want to logout?', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.primary,
              ),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                debugPrint('[ProfileScreen] User confirmed logout. Signing out...');
                await authService.signOut();
                Navigator.of(context).pop(); // Close the dialog
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => AuthScreen()),
                  (Route<dynamic> route) => false,
                );
                debugPrint('[ProfileScreen] Sign out call completed and navigated to AuthScreen.');
              },
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.error,
              ),
              child: Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surgeryTypeController.dispose();
    _surgeryDateController.dispose();
    _doctorNameController.dispose();
    super.dispose();
  }
}
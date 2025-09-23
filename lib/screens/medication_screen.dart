import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:recoveryplus/services/database_service.dart';
import 'package:recoveryplus/services/notification_service.dart';

class MedicationScreen extends StatefulWidget {
  const MedicationScreen({Key? key}) : super(key: key);
  @override
  MedicationScreenState createState() => MedicationScreenState();
}

class MedicationScreenState extends State<MedicationScreen> {
  // Controllers
  final _formKey = GlobalKey<FormState>();
  final _medicationController = TextEditingController();
  final _dosageController = TextEditingController();
  final _timeController = TextEditingController();

  // State variables
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _showForm = false;
  bool _isLoading = false;
  User? _user;
  DatabaseService? _databaseService;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Services
  late final NotificationService _notificationService;
  final Map<String, int> _medicationNotificationIds = {};

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService();
    _initializeServices();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  Future<void> _initializeServices() async {
    _user = FirebaseAuth.instance.currentUser;
    if (_user != null) {
      _databaseService = DatabaseService(uid: _user!.uid);
    }
    debugPrint('[MedicationScreen] Initializing NotificationService...');
    await _notificationService.initialize();
    debugPrint('[MedicationScreen] NotificationService initialized.');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recovery Plus'),
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_sweep, color: colorScheme.onPrimary),
            onPressed: _clearAllMedications,
            tooltip: 'Clear all medications',
          ),
        ],
      ),
      body: _user == null
          ? _buildAuthRequiredScreen(colorScheme, textTheme)
          : Column(
              children: [
                if (_showForm) _buildAddMedicationForm(colorScheme, textTheme),
                Expanded(child: _buildMedicationList(colorScheme, textTheme)),
              ],
            ),
      floatingActionButton: _user != null
          ? FloatingActionButton(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              onPressed: _toggleFormVisibility,
              tooltip: _showForm ? 'Close form' : 'Add medication',
              child: Icon(_showForm ? Icons.close : Icons.add),
            )
          : null,
      
    );
  }

  Widget _buildAuthRequiredScreen(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: colorScheme.secondary),
          SizedBox(height: 20),
          Text(
            'Authentication Required',
            style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
          ),
          SizedBox(height: 10),
          Text(
            'Please sign in to manage medications',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _initializeServices,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildAddMedicationForm(ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 3,
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add New Medication',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              _buildMedicationField(colorScheme, textTheme),
              const SizedBox(height: 12),
              _buildDosageField(colorScheme, textTheme),
              const SizedBox(height: 12),
              _buildTimeField(colorScheme, textTheme),
              const SizedBox(height: 16),
              _buildFormButtons(colorScheme, textTheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedicationField(ColorScheme colorScheme, TextTheme textTheme) {
    return TextFormField(
      controller: _medicationController,
      decoration: InputDecoration(
        labelText: 'Medication Name',
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: colorScheme.surface.withAlpha((0.95 * 255).toInt()),
        prefixIcon: Icon(Icons.medication, color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt())),
        labelStyle: textTheme.labelLarge?.copyWith(color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt())),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.primary),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.outline.withAlpha((0.4 * 255).toInt())),
        ),
      ),
      validator: (value) =>
          value?.isEmpty ?? true ? 'Please enter medication name' : null,
      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
    );
  }

  Widget _buildDosageField(ColorScheme colorScheme, TextTheme textTheme) {
    return TextFormField(
      controller: _dosageController,
      decoration: InputDecoration(
        labelText: 'Dosage (e.g., 500mg, 1 tablet)',
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: colorScheme.surface.withAlpha((0.95 * 255).toInt()),
        prefixIcon: Icon(Icons.line_weight, color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt())),
        labelStyle: textTheme.labelLarge?.copyWith(color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt())),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.primary),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.outline.withAlpha((0.4 * 255).toInt())),
        ),
      ),
      validator: (value) =>
          value?.isEmpty ?? true ? 'Please enter dosage' : null,
      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
    );
  }

  Widget _buildTimeField(ColorScheme colorScheme, TextTheme textTheme) {
    return TextFormField(
      controller: _timeController,
      decoration: InputDecoration(
        labelText: 'Time',
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: colorScheme.surface.withAlpha((0.95 * 255).toInt()),
        prefixIcon: Icon(Icons.access_time, color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt())),
        labelStyle: textTheme.labelLarge?.copyWith(color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt())),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.primary),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.outline.withAlpha((0.4 * 255).toInt())),
        ),
      ),
      readOnly: true,
      onTap: () async => await _selectTime(),
      validator: (value) =>
          value?.isEmpty ?? true ? 'Please select time' : null,
      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
    );
  }

  Widget _buildFormButtons(ColorScheme colorScheme, TextTheme textTheme) {
    return _isLoading
        ? CircularProgressIndicator(color: colorScheme.primary)
        : Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancelForm,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: colorScheme.surface,
                    foregroundColor: colorScheme.onSurface,
                    side: BorderSide(color: colorScheme.outline.withAlpha((0.5 * 255).toInt())),
                  ),
                  child: Text('Cancel', style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurface)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                  child: Text('Add Medication', style: textTheme.labelLarge?.copyWith(color: colorScheme.onPrimary)),
                ),
              ),
            ],
          );
  }

  Widget _buildMedicationList(ColorScheme colorScheme, TextTheme textTheme) {
    if (_databaseService == null) {
      return Center(child: CircularProgressIndicator(color: colorScheme.primary));
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Medications',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _databaseService!.medicationsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading medications', style: textTheme.bodyLarge?.copyWith(color: colorScheme.error)));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: colorScheme.primary));
                }
                final medications = snapshot.data?.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final medicationName = data['medication'] as String? ?? '';
                  return medicationName.toLowerCase().contains(_searchQuery.toLowerCase());
                }).toList() ?? [];

                if (medications.isEmpty) {
                  return _buildEmptyState(colorScheme, textTheme);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: medications.length,
                  itemBuilder: (context, index) {
                    final medication = medications[index];
                    final data = medication.data() as Map<String, dynamic>;
                    final isTaken = data['taken'] ?? false;
                    return _buildMedicationCard(medication.id, data, isTaken, colorScheme, textTheme);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medication, size: 64, color: colorScheme.onSurface.withAlpha((0.5 * 255).toInt())),
          const SizedBox(height: 16),
          Text(
            'No medications added yet',
            style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add your first medication',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(
    String docId,
    Map<String, dynamic> data,
    bool isTaken,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final notificationId = _medicationNotificationIds[docId];
    final hasScheduledNotification =
        notificationId != null &&
        _notificationService.isNotificationScheduled(notificationId);
    if (notificationId != null) {
      debugPrint('[MedicationScreen] Notification status for docId $docId (notificationId $notificationId): scheduled=$hasScheduledNotification');
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: colorScheme.surface,
      child: ListTile(
        isThreeLine: true,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isTaken
                ? colorScheme.secondary.withAlpha((0.8 * 255).toInt())
                : colorScheme.surface.withAlpha((0.95 * 255).toInt()),
            shape: BoxShape.circle,
            border: Border.all(
              color: isTaken ? colorScheme.secondary : colorScheme.primary,
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.medication,
            color: isTaken ? colorScheme.onSecondary : colorScheme.primary,
          ),
        ),
        title: Text(
          data['medication'] ?? 'Unknown',
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            decoration: isTaken ? TextDecoration.lineThrough : null,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dosage: ${data['dosage'] ?? ''}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withAlpha((0.8 * 255).toInt())),
            ),
            Text(
              'Time: ${(data['timings'] as List<dynamic>?)?.join(', ') ?? ''}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withAlpha((0.8 * 255).toInt())),
            ),
            if (hasScheduledNotification)
              Text(
                '🔔 Reminder set',
                style: textTheme.bodySmall?.copyWith(fontSize: 12, color: colorScheme.primary),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            if (data['createdAt'] != null)
              Text(
                'Added: ${_formatDate(data['createdAt']?.toDate())}',
                style: textTheme.bodySmall?.copyWith(fontSize: 12, color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt())),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: isTaken,
              onChanged: (value) =>
                  _updateMedicationStatus(docId, value ?? false),
              activeColor: colorScheme.primary,
              checkColor: colorScheme.onPrimary,
            ),
            IconButton(
              icon: Icon(Icons.delete, color: colorScheme.error),
              onPressed: () => _deleteMedication(docId),
              tooltip: 'Delete medication',
            ),
          ],
        ),
      ),
    );
  }

  // Event handlers and helpers
  void _toggleFormVisibility() {
    setState(() => _showForm = !_showForm);
  }

  Future<void> _selectTime() async {
    final themeColors = Theme.of(context).colorScheme;
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: themeColors,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: themeColors.primary),
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() {
        _selectedTime = time;
        _timeController.text = '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  void _cancelForm() {
    setState(() => _showForm = false);
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _addMedication();
    }
  }

  Future<void> _addMedication() async {
    if (_databaseService == null) return;
    setState(() => _isLoading = true);
    try {
      final docId = await _databaseService!.addMedication(
        _medicationController.text.trim(),
        _dosageController.text.trim(),
        [_timeController.text.trim()], // Wrap the single time string in a list
      );
      debugPrint('[MedicationScreen] Scheduling notification for medication: ${_medicationController.text.trim()}');
      await _notificationService.scheduleBackgroundCompatibleReminder(
        docId: docId,
        medicationName: _medicationController.text.trim(),
        dosage: _dosageController.text.trim(),
        time: _selectedTime,
      );
      debugPrint('[MedicationScreen] Notification scheduled for medication: ${_medicationController.text.trim()}');
      final notificationId = '$docId-${_timeController.text.trim()}'.hashCode;
      _medicationNotificationIds[docId] = notificationId;
      _showSuccess('Medication added with reminder!');
      _resetForm();
    } catch (error) {
      _showError('Failed to add medication: $error');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateMedicationStatus(String docId, bool taken) async {
    if (_databaseService == null) return;
    try {
      await _databaseService!.updateMedication(docId, taken);
      _showSuccess('Medication marked as ${taken ? 'taken' : 'not taken'}');
    } catch (error) {
      _showError('Failed to update medication: $error');
    }
  }

  Future<void> _deleteMedication(String docId) async {
    if (_databaseService == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Medication'),
        content: const Text('Are you sure you want to delete this medication?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result ?? false) {
      try {
        final notificationId = _medicationNotificationIds[docId];
        if (notificationId != null) {
          debugPrint('[MedicationScreen] Cancelling notification with id: $notificationId');
          await _notificationService.cancelNotification(notificationId);
          debugPrint('[MedicationScreen] Notification with id: $notificationId cancelled.');
          _medicationNotificationIds.remove(docId);
        }
        await _databaseService!.deleteMedication(docId);
        _showSuccess('Medication deleted successfully');
      } catch (error) {
        _showError('Failed to delete medication: $error');
      }
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: colorScheme.onSecondary)),
        backgroundColor: colorScheme.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3), // Added duration
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: colorScheme.onError)),
        backgroundColor: colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5), // Added duration, slightly longer for errors
      ),
    );
  }

  void _resetForm() {
    _medicationController.clear();
    _dosageController.clear();
    _timeController.clear();
    setState(() => _showForm = false);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _clearAllMedications() async {
    if (_databaseService == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Medications'),
        content: const Text('Are you sure you want to delete all medications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (result ?? false) {
      try {
        final medications = await _databaseService!.medicationsStream.first;
        for (final doc in medications.docs) {
          await _databaseService!.deleteMedication(doc.id);
        }
        _showSuccess('All medications cleared');
      } catch (error) {
        _showError('Failed to clear medications: $error');
      }
    }
  }

  @override
  void dispose() {
    _medicationController.dispose();
    _dosageController.dispose();
    _timeController.dispose();
    super.dispose();
  }
}
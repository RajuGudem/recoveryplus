import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:recoveryplus/services/database_service.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  DatabaseService? _databaseService;
  User? _user;
  String? _surgeryType;
  Stream<QuerySnapshot>? _exerciseStream;
  bool _showForm = false;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _timeController = TextEditingController();
  bool _isLoading = false;
  String? _selectedCategory;
  final List<String> _exerciseCategories = [
    'Range of Motion',
    'Strengthening',
    'Balance',
    'Flexibility',
    'Endurance'
  ];

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    _user = FirebaseAuth.instance.currentUser;
    if (_user != null) {
      _databaseService = DatabaseService(uid: _user!.uid);
      await _loadUserData();
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadUserData() async {
    if (_databaseService == null) return;
    final userData = await _databaseService!.getUserData();
    if (userData.exists) {
      if (mounted) {
        setState(() {
          _surgeryType = userData.get('surgeryType');
        });
      }
    }

    if (_surgeryType != null) {
      // Check if exercises for this surgery type have already been copied
      final userExercisesSnapshot = await _databaseService!
          .recoveryCollection
          .doc(_user!.uid)
          .collection('exercises')
          .where('surgeryType', isEqualTo: _surgeryType)
          .where('addedBy', isEqualTo: 'system') // Check for system-added exercises
          .get();

      if (userExercisesSnapshot.docs.isEmpty) {
        // If not, fetch from the global collection and copy them over
        final globalExercisesSnapshot = await FirebaseFirestore.instance
            .collection('exercises')
            .where('surgeryType', isEqualTo: _surgeryType)
            .get();

        print("Found ${globalExercisesSnapshot.docs.length} global exercises for surgery type: $_surgeryType. Copying now...");

        for (var exerciseDoc in globalExercisesSnapshot.docs) {
          final exerciseData = exerciseDoc.data();
          await _databaseService!.addExercise(
            exerciseData['title'] ?? '',
            exerciseData['description'] ?? '',
            exerciseData['category'] ?? '',
            exerciseData['surgeryType'] ?? '',
            exerciseData['frequency'] ?? '',
            exerciseData['time'] ?? '',
            addedBy: 'system', // Pass the special value
          );
        }
      }
    }

    // Set the stream to the user's subcollection
    if (mounted) {
      setState(() {
        if (_surgeryType != null && _databaseService != null) {
          _exerciseStream =
              _databaseService!.getExercisesBySurgeryType(_surgeryType!);
        } else if (_databaseService != null) {
          _exerciseStream = _databaseService!.getGeneralExercises();
        } else {
          _exerciseStream = Stream.empty();
        }
      });
    }
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
      ),
      body: _user == null
          ? _buildAuthRequiredScreen(colorScheme, textTheme)
          : SingleChildScrollView(
              child: Column(
                children: [
                  if (_surgeryType != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Exercises for: $_surgeryType',
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (_showForm) _buildAddExerciseForm(colorScheme, textTheme),
                  _buildExerciseList(colorScheme, textTheme),
                ],
              ),
            ),
      floatingActionButton: _user != null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: "addExerciseBtn",
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  onPressed: _toggleFormVisibility,
                  tooltip: _showForm ? 'Close form' : 'Add exercise',
                  child: Icon(_showForm ? Icons.close : Icons.add),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "debugExerciseBtn",
                  backgroundColor: colorScheme.secondary,
                  foregroundColor: colorScheme.onSecondary,
                  onPressed: _printDebugInfo,
                  tooltip: 'Debug Info',
                  child: const Icon(Icons.bug_report),
                ),
              ],
            )
          : null,
    );
  }

  void _printDebugInfo() async {
    // TODO: Implement debug info printing
    print("Debug info requested.");
  }
  Widget _buildAuthRequiredScreen(
      ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: colorScheme.secondary),
          const SizedBox(height: 20),
          Text(
            'Authentication Required',
            style: textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 10),
          Text(
            'Please sign in to manage exercises',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
            ),
          ),
          const SizedBox(height: 20),
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

  Widget _buildAddExerciseForm(ColorScheme colorScheme, TextTheme textTheme) {
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
                'Add New Exercise',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              _buildTitleField(colorScheme, textTheme),
              const SizedBox(height: 12),
              _buildCategoryDropdown(colorScheme, textTheme),
              const SizedBox(height: 12),
              _buildDescriptionField(colorScheme, textTheme),
              const SizedBox(height: 12),
              _buildFrequencyField(colorScheme, textTheme),
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

  Widget _buildCategoryDropdown(ColorScheme colorScheme, TextTheme textTheme) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCategory,
      decoration: InputDecoration(
        labelText: 'Category',
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: colorScheme.surface.withAlpha((0.95 * 255).toInt()),
        prefixIcon: Icon(Icons.category,
            color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt())),
        labelStyle: textTheme.labelLarge
            ?.copyWith(color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt())),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.primary),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
              color: colorScheme.outline.withAlpha((0.4 * 255).toInt())),
        ),
      ),
      items: _exerciseCategories.map((String category) {
        return DropdownMenuItem<String>(
          value: category,
          child: Text(category),
        );
      }).toList(),
      onChanged: (newValue) {
        setState(() {
          _selectedCategory = newValue;
        });
      },
      validator: (value) => value == null ? 'Please select a category' : null,
    );
  }

  Widget _buildTitleField(ColorScheme colorScheme, TextTheme textTheme) {
    return TextFormField(
      controller: _titleController,
      decoration: InputDecoration(
        labelText: 'Title',
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: colorScheme.surface.withAlpha((0.95 * 255).toInt()),
        prefixIcon: Icon(Icons.fitness_center,
            color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt())),
        labelStyle: textTheme.labelLarge
            ?.copyWith(color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt())),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.primary),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
              color: colorScheme.outline.withAlpha((0.4 * 255).toInt())),
        ),
      ),
      validator: (value) =>
          value?.isEmpty ?? true ? 'Please enter a title' : null,
      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
    );
  }

  Widget _buildDescriptionField(ColorScheme colorScheme, TextTheme textTheme) {
    return TextFormField(
      controller: _descriptionController,
      decoration: InputDecoration(
        labelText: 'Description',
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: colorScheme.surface.withAlpha((0.95 * 255).toInt()),
        prefixIcon: Icon(Icons.notes,
            color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt())),
        labelStyle: textTheme.labelLarge
            ?.copyWith(color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt())),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.primary),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
              color: colorScheme.outline.withAlpha((0.4 * 255).toInt())),
        ),
      ),
      validator: (value) =>
          value?.isEmpty ?? true ? 'Please enter a description' : null,
      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
      maxLines: 3,
    );
  }

  Widget _buildFrequencyField(ColorScheme colorScheme, TextTheme textTheme) {
    return TextFormField(
      controller: _frequencyController,
      decoration: InputDecoration(
        labelText: 'Frequency',
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: colorScheme.surface.withAlpha((0.95 * 255).toInt()),
        prefixIcon: Icon(Icons.repeat,
            color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt())),
        labelStyle: textTheme.labelLarge
            ?.copyWith(color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt())),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.primary),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
              color: colorScheme.outline.withAlpha((0.4 * 255).toInt())),
        ),
      ),
      validator: (value) =>
          value?.isEmpty ?? true ? 'Please enter a frequency' : null,
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
        prefixIcon: Icon(Icons.timer,
            color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt())),
        labelStyle: textTheme.labelLarge
            ?.copyWith(color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt())),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.primary),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
              color: colorScheme.outline.withAlpha((0.4 * 255).toInt())),
        ),
      ),
      validator: (value) =>
          value?.isEmpty ?? true ? 'Please enter a time' : null,
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
                    side: BorderSide(
                        color: colorScheme.outline.withAlpha((0.5 * 255).toInt())),
                  ),
                  child: Text('Cancel',
                      style: textTheme.labelLarge
                          ?.copyWith(color: colorScheme.onSurface)),
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
                  child: Text('Add Exercise',
                      style: textTheme.labelLarge
                          ?.copyWith(color: colorScheme.onPrimary)),
                ),
              ),
            ],
          );
  }

  Widget _buildExerciseList(ColorScheme colorScheme, TextTheme textTheme) {
    if (_exerciseStream == null) {
      return Center(
          child: CircularProgressIndicator(color: colorScheme.primary));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _exerciseStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Text('Error loading exercises',
                  style: textTheme.bodyLarge
                      ?.copyWith(color: colorScheme.error)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(color: colorScheme.primary));
        }
        final exercises = snapshot.data?.docs ?? [];
        if (exercises.isEmpty) {
          return _buildEmptyState(colorScheme, textTheme);
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: exercises.length,
          itemBuilder: (context, index) {
            final exercise = exercises[index];
            final data = exercise.data() as Map<String, dynamic>;
            return _buildExerciseCard(
                exercise.id, data, colorScheme, textTheme);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, TextTheme textTheme) {
    String message = 'No exercises found.';
    String subMessage = 'Add new exercises or check your surgery type settings.';

    if (_surgeryType != null && _surgeryType!.isNotEmpty) {
      message = 'No specific exercises found for your surgery type: $_surgeryType.';
      subMessage = 'Showing general recovery exercises or add new ones.';
    } else {
      message = 'No general exercises found.';
      subMessage = 'Add new exercises to get started.';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center,
              size: 64, color: colorScheme.onSurface.withAlpha((0.5 * 255).toInt())),
          const SizedBox(height: 16),
          Text(
            message,
            style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subMessage,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(
    String docId,
    Map<String, dynamic> data,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final Timestamp? lastCompletedTimestamp = data['lastCompletedDate'];
    final DateTime? lastCompletedDate = lastCompletedTimestamp?.toDate();
    final bool isCompletedToday = lastCompletedDate != null &&
        lastCompletedDate.year == DateTime.now().year &&
        lastCompletedDate.month == DateTime.now().month &&
        lastCompletedDate.day == DateTime.now().day;

    return AnimatedOpacity(
      opacity: isCompletedToday ? 0.5 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        color: colorScheme.surface,
        child: ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.surface.withAlpha((0.95 * 255).toInt()),
              shape: BoxShape.circle,
              border: Border.all(
                color: colorScheme.primary,
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.fitness_center,
              color: colorScheme.primary,
            ),
          ),
          title: Text(
            data['title'] ?? 'Unknown',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['description'] ?? '',
                style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withAlpha((0.8 * 255).toInt())),
              ),
              Text(
                'Frequency: ${data['frequency'] ?? ''}',
                style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withAlpha((0.8 * 255).toInt())),
              ),
              Text(
                'Time: ${data['time'] ?? ''}',
                style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withAlpha((0.8 * 255).toInt())),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: isCompletedToday,
                onChanged: (bool? newValue) {
                  if (newValue != null) {
                    _toggleExerciseCompletion(docId, newValue);
                  } 
                },
                activeColor: colorScheme.primary,
              ),
              IconButton(
                icon: Icon(Icons.delete, color: colorScheme.error),
                onPressed: () => _deleteExercise(docId),
                tooltip: 'Delete exercise',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleFormVisibility() {
    setState(() => _showForm = !_showForm);
  }

  void _cancelForm() {
    setState(() => _showForm = false);
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _addExercise();
    }
  }

  Future<void> _addExercise() async {
    if (_user == null || _databaseService == null) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _databaseService!.addExercise(
        _titleController.text.trim(),
        _descriptionController.text.trim(),
        _selectedCategory!,
        _surgeryType ?? 'General',
        _frequencyController.text.trim(),
        _timeController.text.trim(),
      );
      _showSuccess('Exercise added successfully!');
      _resetForm();
    } catch (error) {
      _showError('Failed to add exercise: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteExercise(String docId) async {
    if (_user == null || _databaseService == null) {
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Delete Exercise',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
        content: Text('Are you sure you want to delete this exercise?',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: Text('Cancel',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _databaseService!.deleteExercise(docId);
                _showSuccess('Exercise deleted successfully');
              } catch (error) {
                _showError('Failed to delete exercise: $error');
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text('Delete',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: colorScheme.onSecondary)),
        backgroundColor: colorScheme.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showError(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: colorScheme.onError)),
        backgroundColor: colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _toggleExerciseCompletion(String docId, bool newValue) async {
    if (_user == null || _databaseService == null) {
      return;
    }
    try {
      DateTime? lastCompletedDate = newValue ? DateTime.now() : null;
      await _databaseService!.updateExerciseStatus(docId, lastCompletedDate);
      _showSuccess(newValue ? 'Exercise marked as completed!' : 'Exercise marked as incomplete!');
    } catch (error) {
      _showError('Failed to update exercise status: $error');
    }
  }

  void _resetForm() {
    _titleController.clear();
    _descriptionController.clear();
    _frequencyController.clear();
    _timeController.clear();
    if (mounted) {
      setState(() {
        _showForm = false;
        _selectedCategory = null;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _frequencyController.dispose();
    _timeController.dispose();
    super.dispose();
  }
}

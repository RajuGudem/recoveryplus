import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:recoveryplus/services/database_service.dart';

class PainTrackerWidget extends StatefulWidget {
  @override
  _PainTrackerWidgetState createState() => _PainTrackerWidgetState();
}

class _PainTrackerWidgetState extends State<PainTrackerWidget> {
  double _currentPainLevel = 0;
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.surface, // Use theme surface color
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pain Level Today',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            SizedBox(height: 16),

            // Custom pain level selector
            Text(
              'Select your pain level:',
              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),

            // Number bubbles 0-10
            Container(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 11,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentPainLevel = index.toDouble();
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: index <= _currentPainLevel
                            ? _getColorForPainLevel(index, colorScheme)
                            : colorScheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: index <= _currentPainLevel
                              ? colorScheme.primary
                              : colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$index',
                          style: textTheme.bodyLarge?.copyWith(
                            color: index <= _currentPainLevel
                                ? colorScheme.onPrimary
                                : colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            SizedBox(height: 16),
            Text(
              'Pain Level: ${_currentPainLevel.toInt()}/10',
              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              'Notes (optional)',
              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Describe your pain or any concerns...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                hintStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
              ),
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
            ),
            SizedBox(height: 16),
            _isSubmitting
                ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _currentPainLevel > 0 ? _submitPainData : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Record Pain Level'),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Color _getColorForPainLevel(int level, ColorScheme colorScheme) {
    if (level <= 3) return colorScheme.secondary;
    if (level <= 6) return colorScheme.tertiary;
    return colorScheme.error;
  }

  // In lib/widgets/pain_tracker.dart
  Future<void> _submitPainData() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      // 1. Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Please sign in to save data');
      }

      // 2. Create database service instance
      final databaseService = DatabaseService(uid: user.uid);

      // 3. Call the data storage method
      await databaseService.addPainLevel(
        _currentPainLevel.toInt(),
        _notesController.text,
      );

      // 4. Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pain level saved successfully!', style: TextStyle(color: Theme.of(context).colorScheme.onSecondary)),
          backgroundColor: Theme.of(context).colorScheme.secondary,
          duration: const Duration(seconds: 3),
        ),
      );

      // 5. Reset form
      setState(() {
        _currentPainLevel = 0;
        _notesController.clear();
      });
    } catch (error) {
      // 6. Handle errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error', style: TextStyle(color: Theme.of(context).colorScheme.onError)),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}
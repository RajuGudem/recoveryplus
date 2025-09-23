import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recoveryplus/services/export_service.dart';
import 'package:recoveryplus/services/statistics_service.dart';
import 'package:recoveryplus/providers/theme_provider.dart';

class StatisticsScreen extends StatefulWidget {
  @override
  StatisticsScreenState createState() => StatisticsScreenState();
}

class StatisticsScreenState extends State<StatisticsScreen> {
  Map<String, dynamic> _statistics = {};
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final stats = await StatisticsService.getRecoveryStatistics();
      if (mounted) {
        setState(() {
          _statistics = stats;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _exportStatistics() async {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Preparing statistics report...', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSecondary)), backgroundColor: colorScheme.secondary, duration: const Duration(seconds: 3)));

      await ExportService.exportStatisticsReport();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Statistics report exported successfully!', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSecondary)),
          backgroundColor: colorScheme.secondary,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $error', style: textTheme.bodyMedium?.copyWith(color: colorScheme.error)),
          backgroundColor: colorScheme.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recovery Plus'),
        foregroundColor: colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: colorScheme.onPrimary),
            onPressed: _loadStatistics,
            tooltip: 'Refresh Statistics',
          ),
          IconButton(
            icon: Icon(Icons.download, color: colorScheme.onPrimary),
            onPressed: _exportStatistics,
            tooltip: 'Export Statistics Report',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : _hasError
          ? _buildErrorState(colorScheme, textTheme)
          : _statistics.isEmpty
          ? _buildEmptyState(colorScheme, textTheme)
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildOverallScore(colorScheme, textTheme),
                    SizedBox(height: 20),
                    _buildPainStatistics(colorScheme, textTheme),
                    SizedBox(height: 20),
                    _buildMedicationStatistics(colorScheme, textTheme),
                    SizedBox(height: 20),
                    _buildExerciseStatistics(colorScheme, textTheme),
                    SizedBox(height: 20),
                    _buildWeeklyProgressChart(colorScheme, textTheme),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildErrorState(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: colorScheme.error),
          SizedBox(height: 16),
          Text(
            'Failed to load statistics',
            style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface),
          ),
          SizedBox(height: 8),
          Text(
            'Please check your connection and try again',
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withAlpha(179)),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary),
            onPressed: _loadStatistics,
            child: Text('Try Again'),
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
          Icon(Icons.analytics, size: 64, color: colorScheme.onSurface.withAlpha(128)),
          SizedBox(height: 16),
          Text(
            'No data available yet',
            style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface),
          ),
          SizedBox(height: 8),
          Text(
            'Start tracking your recovery to see statistics',
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withAlpha(179)),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallScore(ColorScheme colorScheme, TextTheme textTheme) {
    final score = _statistics['overall_recovery_score'] ?? 0;
    return Card(
      color: colorScheme.surface,
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Overall Recovery Score',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 16),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 12,
                    backgroundColor: colorScheme.onSurface.withAlpha(51),
                    valueColor: AlwaysStoppedAnimation(_getScoreColor(score, colorScheme)),
                  ),
                ),
                Text(
                  '${score.toStringAsFixed(0)}%',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              _getScoreDescription(score),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withAlpha(179)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPainStatistics(ColorScheme colorScheme, TextTheme textTheme) {
    final pain = _statistics['pain'] as Map<String, dynamic>?;
    if (pain == null || pain.isEmpty) return SizedBox();

    return Card(
      color: colorScheme.surface,
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.health_and_safety, color: colorScheme.error),
                SizedBox(width: 8),
                Text(
                  'Pain Analysis',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildStatRow('Average Pain', '${pain['average_pain']?.toStringAsFixed(1) ?? "0"} / 10', colorScheme, textTheme),
            _buildStatRow('Highest Pain', '${pain['max_pain']?.toStringAsFixed(1) ?? "0"} / 10', colorScheme, textTheme),
            _buildStatRow('Lowest Pain', '${pain['min_pain']?.toStringAsFixed(1) ?? "0"} / 10', colorScheme, textTheme),
            _buildStatRow('Trend', pain['trend_description'] ?? 'No data', colorScheme, textTheme),
            _buildStatRow('Total Entries', '${pain['total_entries'] ?? 0}', colorScheme, textTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationStatistics(ColorScheme colorScheme, TextTheme textTheme) {
    final meds = _statistics['medications'] as Map<String, dynamic>?;
    if (meds == null || meds.isEmpty) return SizedBox();

    List<Widget> remindersWidgets = [];
    if (meds['reminders'] != null && meds['reminders'] is List && (meds['reminders'] as List).isNotEmpty) {
      remindersWidgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
          child: Text(
            'Reminders:',
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary),
          ),
        ),
      );
      remindersWidgets.addAll((meds['reminders'] as List)
          .map<Widget>((reminder) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  children: [
                    Icon(Icons.alarm, size: 18, color: colorScheme.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reminder.toString(),
                        style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ))
          .toList());
    }

    return Card(
      color: colorScheme.surface,
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.medication, color: colorScheme.primary),
                SizedBox(width: 8),
                Text(
                  'Medication Adherence',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildStatRow('Adherence Rate', '${meds['adherence_rate']?.toStringAsFixed(1) ?? "0"}%', colorScheme, textTheme),
            _buildStatRow('Level', meds['adherence_level'] ?? 'No data', colorScheme, textTheme),
            _buildStatRow('Taken', '${meds['taken_medications']} / ${meds['total_medications']}', colorScheme, textTheme),
            _buildStatRow('Missed', '${meds['missed_medications']}', colorScheme, textTheme),
            ...remindersWidgets,
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseStatistics(ColorScheme colorScheme, TextTheme textTheme) {
    final exercises = _statistics['exercises'] as Map<String, dynamic>?;
    if (exercises == null || exercises.isEmpty) return SizedBox();

    final exercisesByCategory = exercises['exercises_by_category'] as Map<String, dynamic>? ?? {};
    final exercisesBySurgeryType = exercises['exercises_by_surgery_type'] as Map<String, dynamic>? ?? {};

    return Card(
      color: colorScheme.surface,
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fitness_center, color: colorScheme.secondary),
                SizedBox(width: 8),
                Text(
                  'Exercise Progress',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildStatRow('Completion Rate', '${exercises['completion_rate']?.toStringAsFixed(1) ?? "0"}%', colorScheme, textTheme),
            _buildStatRow('Level', exercises['completion_level'] ?? 'No data', colorScheme, textTheme),
            _buildStatRow('Completed', '${exercises['completed_exercises']} / ${exercises['total_exercises']}', colorScheme, textTheme),
            _buildStatRow('Pending', '${exercises['pending_exercises']}', colorScheme, textTheme),
            _buildStatRow('Most Frequent Category', exercises['most_frequent_category'] ?? 'N/A', colorScheme, textTheme),
            _buildStatRow('Total Time', '${exercises['total_time_minutes'] ?? 0} minutes', colorScheme, textTheme),
            if (exercisesByCategory.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('By Category:', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ...exercisesByCategory.entries.map((entry) => _buildStatRow(entry.key, entry.value.toString(), colorScheme, textTheme)),
                  ],
                ),
              ),
            if (exercisesBySurgeryType.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('By Surgery Type:', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ...exercisesBySurgeryType.entries.map((entry) => _buildStatRow(entry.key, entry.value.toString(), colorScheme, textTheme)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyProgressChart(ColorScheme colorScheme, TextTheme textTheme) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: StatisticsService.getWeeklyProgress(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return SizedBox();

        final weeklyData = snapshot.data!;
        return Card(
          color: colorScheme.surface,
          elevation: 3,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.timeline, color: colorScheme.tertiary),
                    SizedBox(width: 8),
                    Text(
                      'Weekly Pain Trend',
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                ...weeklyData.map(
                  (week) => _buildWeekProgress(week, colorScheme, textTheme),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWeekProgress(Map<String, dynamic> week, ColorScheme colorScheme, TextTheme textTheme) {
    final pain = (week['average_pain'] ?? 0).toDouble();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              week['week'],
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: LinearProgressIndicator(
              value: pain / 10,
              backgroundColor: colorScheme.onSurface.withAlpha(51),
              valueColor: AlwaysStoppedAnimation(_getPainColor(pain, colorScheme)),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: Text(
              pain.toStringAsFixed(1),
              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, ColorScheme colorScheme, TextTheme textTheme) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withAlpha(179))),
          Text(value, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
        ],
      ),
    );
  }

  Color _getScoreColor(double score, ColorScheme colorScheme) {
    if (score >= 80) return colorScheme.secondary;
    if (score >= 60) return colorScheme.tertiary;
    return colorScheme.error;
  }

  Color _getPainColor(double pain, ColorScheme colorScheme) {
    if (pain <= 3) return colorScheme.secondary;
    if (pain <= 6) return colorScheme.tertiary;
    return colorScheme.error;
  }

  String _getScoreDescription(double score) {
    if (score >= 80) return 'Excellent recovery progress! Keep it up!';
    if (score >= 60) return 'Good progress. You\'re on the right track!';
    if (score >= 40) return 'Steady progress. Keep following your plan.';
    return 'Let\'s work on improving your recovery routine.';
  }
}

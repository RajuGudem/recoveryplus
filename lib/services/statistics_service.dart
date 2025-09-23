// lib/services/statistics_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StatisticsService {
  static Future<Map<String, dynamic>> getRecoveryStatistics() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    try {
      final data = await _fetchUserData(user.uid);
      return _calculateStatistics(data);
    } catch (error) {
      print('Statistics error: $error');
      return {};
    }
  }

  static Future<Map<String, dynamic>> _fetchUserData(String userId) async {
    final painLogs = await FirebaseFirestore.instance
        .collection('recovery_data')
        .doc(userId)
        .collection('pain_logs')
        .orderBy('timestamp')
        .get();

    final medications = await FirebaseFirestore.instance
        .collection('recovery_data')
        .doc(userId)
        .collection('medications')
        .get();

    final exercises = await FirebaseFirestore.instance
        .collection('recovery_data')
        .doc(userId)
        .collection('exercises')
        .get();

    return {
      'pain_logs': painLogs.docs.map((doc) => doc.data()).toList(),
      'medications': medications.docs.map((doc) => doc.data()).toList(),
      'exercises': exercises.docs.map((doc) => doc.data()).toList(),
    };
  }

  static Map<String, dynamic> _calculateStatistics(Map<String, dynamic> data) {
    final painLogs = data['pain_logs'] as List<dynamic>;
    final medications = data['medications'] as List<dynamic>;
    final exercises = data['exercises'] as List<dynamic>;

    // Pain statistics
    final painStats = _calculatePainStatistics(painLogs);

    // Medication statistics
    final medicationStats = _calculateMedicationStatistics(medications);

    // Exercise statistics
    final exerciseStats = _calculateExerciseStatistics(exercises);

    return {
      'pain': painStats,
      'medications': medicationStats,
      'exercises': exerciseStats,
      'overall_recovery_score': _calculateOverallScore(
        painStats,
        medicationStats,
        exerciseStats,
      ),
    };
  }

  static Map<String, dynamic> _calculatePainStatistics(List<dynamic> painLogs) {
    if (painLogs.isEmpty) return {};

    final painLevels = painLogs
        .map((log) => (log['painLevel'] as num).toDouble())
        .toList();
    final totalEntries = painLogs.length;

    // Calculate trends (last 7 days vs previous 7 days)
    final now = DateTime.now();
    final recentPain = painLogs
        .where((log) {
          final date = log['timestamp']?.toDate();
          return date != null && date.isAfter(now.subtract(Duration(days: 7)));
        })
        .map((log) => (log['painLevel'] as num).toDouble())
        .toList();

    final previousPain = painLogs
        .where((log) {
          final date = log['timestamp']?.toDate();
          return date != null &&
              date.isAfter(now.subtract(Duration(days: 14))) &&
              date.isBefore(now.subtract(Duration(days: 7)));
        })
        .map((log) => (log['painLevel'] as num).toDouble())
        .toList();

    final recentAvg = recentPain.isNotEmpty
        ? recentPain.reduce((a, b) => a + b) / recentPain.length
        : 0;
    final previousAvg = previousPain.isNotEmpty
        ? previousPain.reduce((a, b) => a + b) / previousPain.length
        : 0;
    final trend = recentAvg - previousAvg;

    return {
      'average_pain': painLevels.reduce((a, b) => a + b) / painLevels.length,
      'max_pain': painLevels.reduce((a, b) => a > b ? a : b),
      'min_pain': painLevels.reduce((a, b) => a < b ? a : b),
      'total_entries': totalEntries,
      'trend': trend,
      'trend_description': trend < 0
          ? 'Improving'
          : trend > 0
          ? 'Worsening'
          : 'Stable',
      'recent_avg_pain': recentAvg,
    };
  }

  static Map<String, dynamic> _calculateMedicationStatistics(
    List<dynamic> medications,
  ) {
    if (medications.isEmpty) return {};

    final takenMeds = medications.where((med) => med['taken'] == true).length;
    final totalMeds = medications.length;
    final adherenceRate = (takenMeds / totalMeds * 100);

    return {
      'total_medications': totalMeds,
      'taken_medications': takenMeds,
      'missed_medications': totalMeds - takenMeds,
      'adherence_rate': adherenceRate,
      'adherence_level': adherenceRate >= 90
          ? 'Excellent'
          : adherenceRate >= 75
          ? 'Good'
          : adherenceRate >= 50
          ? 'Fair'
          : 'Poor',
    };
  }

  static Map<String, dynamic> _calculateExerciseStatistics(
    List<dynamic> exercises,
  ) {
    if (exercises.isEmpty) return {};

    final completedExercises = exercises
        .where((ex) => ex['completed'] == true)
        .length;
    final totalExercises = exercises.length;
    final completionRate = (completedExercises / totalExercises * 100);

    final exercisesByCategory = <String, int>{};
    final exercisesBySurgeryType = <String, int>{};
    int totalTime = 0;

    for (var ex in exercises) {
      if (ex['completed'] == true) {
        final category = ex['category'] as String?;
        if (category != null) {
          exercisesByCategory[category] = (exercisesByCategory[category] ?? 0) + 1;
        }

        final surgeryType = ex['surgeryType'] as String?;
        if (surgeryType != null) {
          exercisesBySurgeryType[surgeryType] = (exercisesBySurgeryType[surgeryType] ?? 0) + 1;
        }

        final time = ex['time'] as String?;
        if (time != null) {
          final timeParts = time.split(' ');
          if (timeParts.length == 2) {
            final value = int.tryParse(timeParts[0]);
            if (value != null) {
              if (timeParts[1].toLowerCase().startsWith('min')) {
                totalTime += value;
              } else if (timeParts[1].toLowerCase().startsWith('hr')) {
                totalTime += value * 60;
              }
            }
          }
        }
      }
    }

    String? mostFrequentCategory;
    if (exercisesByCategory.isNotEmpty) {
      mostFrequentCategory = exercisesByCategory.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }

    return {
      'total_exercises': totalExercises,
      'completed_exercises': completedExercises,
      'pending_exercises': totalExercises - completedExercises,
      'completion_rate': completionRate,
      'completion_level': completionRate >= 90
          ? 'Excellent'
          : completionRate >= 75
          ? 'Good'
          : completionRate >= 50
          ? 'Fair'
          : 'Needs Improvement',
      'exercises_by_category': exercisesByCategory,
      'most_frequent_category': mostFrequentCategory,
      'exercises_by_surgery_type': exercisesBySurgeryType,
      'total_time_minutes': totalTime,
    };
  }

  static double _calculateOverallScore(
    Map<String, dynamic> painStats,
    Map<String, dynamic> medicationStats,
    Map<String, dynamic> exerciseStats,
  ) {
    double score = 50.0; // Base score

    // Pain contributes 40% (lower pain = higher score)
    if (painStats.isNotEmpty) {
      final painScore = (10 - (painStats['average_pain'] as double)) * 4;
      score += painScore;
    }

    // Medication adherence contributes 30%
    if (medicationStats.isNotEmpty) {
      final medScore = (medicationStats['adherence_rate'] as double) * 0.3;
      score += medScore;
    }

    // Exercise completion contributes 30%
    if (exerciseStats.isNotEmpty) {
      final exerciseScore = (exerciseStats['completion_rate'] as double) * 0.3;
      score += exerciseScore;
    }

    return score.clamp(0, 100).toDouble();
  }

  // Weekly progress tracking
  static Future<List<Map<String, dynamic>>> getWeeklyProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final painLogs = await FirebaseFirestore.instance
        .collection('recovery_data')
        .doc(user.uid)
        .collection('pain_logs')
        .orderBy('timestamp')
        .get();

    final weeklyData = <Map<String, dynamic>>[];
    final now = DateTime.now();

    for (int i = 3; i >= 0; i--) {
      final weekStart = now.subtract(Duration(days: 7 * (i + 1)));
      final weekEnd = now.subtract(Duration(days: 7 * i));

      final weekPain = painLogs.docs
          .where((doc) {
            final date = doc.data()['timestamp']?.toDate();
            return date != null &&
                date.isAfter(weekStart) &&
                date.isBefore(weekEnd);
          })
          .map((doc) => (doc.data()['painLevel'] as num).toDouble())
          .toList();

      weeklyData.add({
        'week': 'Week ${i + 1}',
        'average_pain': weekPain.isNotEmpty
            ? weekPain.reduce((a, b) => a + b) / weekPain.length
            : 0,
        'entries': weekPain.length,
      });
    }

    return weeklyData;
  }
}

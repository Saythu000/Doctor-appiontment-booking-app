class VitalsRecord {
  // Core Activity
  final int? steps;
  final double? caloriesKcal;
  final double? distanceMeters;
  final int? totalActiveMinutes;

  // Exercise
  final String? activityName;
  final double? exerciseDurationMinutes;
  final int? activeZoneMinutes;
  final int? fatburnActiveZoneMinutes;
  final int? cardioActiveZoneMinutes;
  final int? peakActiveZoneMinutes;

  // Vitals
  final int? restingHeartRate;
  final int? heartRate;
  final double? heartRateVariability;
  final int? stressManagementScore;
  final int? bloodPressureSystolic;
  final int? bloodPressureDiastolic;

  // Sleep
  final int? sleepMinutes;
  final int? remSleepMinutes;
  final int? deepSleepMinutes;
  final int? lightSleepMinutes;
  final int? awakeMinutes;
  final String? bedTime;
  final String? wakeUpTime;
  final double? deepSleepPercent;
  final double? remSleepPercent;
  final double? lightSleepPercent;
  final double? awakePercent;

  // Biometrics
  final double? weightKg;
  final double? heightCm;
  final int? age;
  final String? gender;

  // Metadata
  final String? recordedAt;
  final String? date;

  VitalsRecord({
    this.steps,
    this.caloriesKcal,
    this.distanceMeters,
    this.totalActiveMinutes,
    this.activityName,
    this.exerciseDurationMinutes,
    this.activeZoneMinutes,
    this.fatburnActiveZoneMinutes,
    this.cardioActiveZoneMinutes,
    this.peakActiveZoneMinutes,
    this.restingHeartRate,
    this.heartRate,
    this.heartRateVariability,
    this.stressManagementScore,
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.sleepMinutes,
    this.remSleepMinutes,
    this.deepSleepMinutes,
    this.lightSleepMinutes,
    this.awakeMinutes,
    this.bedTime,
    this.wakeUpTime,
    this.deepSleepPercent,
    this.remSleepPercent,
    this.lightSleepPercent,
    this.awakePercent,
    this.weightKg,
    this.heightCm,
    this.age,
    this.gender,
    this.recordedAt,
    this.date,
  });

  factory VitalsRecord.fromJson(Map<String, dynamic> json) {
    return VitalsRecord(
      steps: json['steps'],
      caloriesKcal: json['calories_kcal'] != null ? (json['calories_kcal'] as num).toDouble() : null,
      distanceMeters: json['distance_meters'] != null ? (json['distance_meters'] as num).toDouble() : null,
      totalActiveMinutes: json['total_active_minutes'],
      activityName: json['activity_name'],
      exerciseDurationMinutes: json['exercise_duration_minutes'] != null ? (json['exercise_duration_minutes'] as num).toDouble() : null,
      activeZoneMinutes: json['active_zone_minutes'],
      fatburnActiveZoneMinutes: json['fatburn_active_zone_minutes'],
      cardioActiveZoneMinutes: json['cardio_active_zone_minutes'],
      peakActiveZoneMinutes: json['peak_active_zone_minutes'],
      restingHeartRate: json['resting_heart_rate'],
      heartRate: json['heart_rate'],
      heartRateVariability: json['heart_rate_variability'] != null ? (json['heart_rate_variability'] as num).toDouble() : null,
      stressManagementScore: json['stress_management_score'],
      bloodPressureSystolic: json['blood_pressure_systolic'],
      bloodPressureDiastolic: json['blood_pressure_diastolic'],
      sleepMinutes: json['sleep_minutes'],
      remSleepMinutes: json['rem_sleep_minutes'],
      deepSleepMinutes: json['deep_sleep_minutes'],
      lightSleepMinutes: json['light_sleep_minutes'],
      awakeMinutes: json['awake_minutes'],
      bedTime: json['bed_time'],
      wakeUpTime: json['wake_up_time'],
      deepSleepPercent: json['deep_sleep_percent'] != null ? (json['deep_sleep_percent'] as num).toDouble() : null,
      remSleepPercent: json['rem_sleep_percent'] != null ? (json['rem_sleep_percent'] as num).toDouble() : null,
      lightSleepPercent: json['light_sleep_percent'] != null ? (json['light_sleep_percent'] as num).toDouble() : null,
      awakePercent: json['awake_percent'] != null ? (json['awake_percent'] as num).toDouble() : null,
      weightKg: json['weight_kg'] != null ? (json['weight_kg'] as num).toDouble() : null,
      heightCm: json['height_cm'] != null ? (json['height_cm'] as num).toDouble() : null,
      age: json['age'],
      gender: json['gender'],
      recordedAt: json['recorded_at'],
      date: json['date'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (steps != null) 'steps': steps,
      if (caloriesKcal != null) 'calories_kcal': caloriesKcal,
      if (distanceMeters != null) 'distance_meters': distanceMeters,
      if (totalActiveMinutes != null) 'total_active_minutes': totalActiveMinutes,
      if (activityName != null) 'activity_name': activityName,
      if (exerciseDurationMinutes != null) 'exercise_duration_minutes': exerciseDurationMinutes,
      if (activeZoneMinutes != null) 'active_zone_minutes': activeZoneMinutes,
      if (fatburnActiveZoneMinutes != null) 'fatburn_active_zone_minutes': fatburnActiveZoneMinutes,
      if (cardioActiveZoneMinutes != null) 'cardio_active_zone_minutes': cardioActiveZoneMinutes,
      if (peakActiveZoneMinutes != null) 'peak_active_zone_minutes': peakActiveZoneMinutes,
      if (restingHeartRate != null) 'resting_heart_rate': restingHeartRate,
      if (heartRate != null) 'heart_rate': heartRate,
      if (heartRateVariability != null) 'heart_rate_variability': heartRateVariability,
      'stress_management_score': stressManagementScore,
      'blood_pressure_systolic': bloodPressureSystolic,
      'blood_pressure_diastolic': bloodPressureDiastolic,
      if (sleepMinutes != null) 'sleep_minutes': sleepMinutes,
      if (remSleepMinutes != null) 'rem_sleep_minutes': remSleepMinutes,
      if (deepSleepMinutes != null) 'deep_sleep_minutes': deepSleepMinutes,
      if (lightSleepMinutes != null) 'light_sleep_minutes': lightSleepMinutes,
      if (awakeMinutes != null) 'awake_minutes': awakeMinutes,
      if (bedTime != null) 'bed_time': bedTime,
      if (wakeUpTime != null) 'wake_up_time': wakeUpTime,
      if (deepSleepPercent != null) 'deep_sleep_percent': deepSleepPercent,
      if (remSleepPercent != null) 'rem_sleep_percent': remSleepPercent,
      if (lightSleepPercent != null) 'light_sleep_percent': lightSleepPercent,
      if (awakePercent != null) 'awake_percent': awakePercent,
      if (weightKg != null) 'weight_kg': weightKg,
      if (heightCm != null) 'height_cm': heightCm,
      'age': age,
      'gender': gender,
      'recorded_at': recordedAt ?? DateTime.now().toIso8601String().substring(0, 19),
      'date': date ?? DateTime.now().toIso8601String().split('T')[0],
    };
  }
}

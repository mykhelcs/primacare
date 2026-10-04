class ClinicalVitals {
  final String bloodPressure;
  final double heartRate;
  final double temperature;
  final int respiratoryRate;
  final double? weightKg;
  final double? heightCm;
  final String? chiefComplaint;
  final String? clinicalNotes;
  final DateTime recordedAt;

  const ClinicalVitals({
    this.bloodPressure = '120/80',
    this.heartRate = 75,
    this.temperature = 36.5,
    this.respiratoryRate = 18,
    this.weightKg,
    this.heightCm,
    this.chiefComplaint,
    this.clinicalNotes,
    required this.recordedAt,
  });

  /// 1-Tap preset for non-tech clinic staff to quickly fill standard normal vitals
  static ClinicalVitals normalBaseline() {
    return ClinicalVitals(
      bloodPressure: '120/80',
      heartRate: 72,
      temperature: 36.5,
      respiratoryRate: 16,
      weightKg: 60.0,
      heightCm: 165.0,
      chiefComplaint: 'Routine Outpatient Consultation',
      clinicalNotes: 'Vitals stable and within normal baseline. Patient conscious, coherent, and ambulatory.',
      recordedAt: DateTime.now(),
    );
  }

  bool get isFever => temperature >= 37.8;
  bool get isHypertensive {
    final parts = bloodPressure.split('/');
    if (parts.length == 2) {
      final sys = int.tryParse(parts[0].trim()) ?? 120;
      final dia = int.tryParse(parts[1].trim()) ?? 80;
      return sys >= 140 || dia >= 90;
    }
    return false;
  }

  factory ClinicalVitals.fromJson(Map<String, dynamic> json) {
    return ClinicalVitals(
      bloodPressure: json['blood_pressure'] as String? ?? '120/80',
      heartRate: (json['heart_rate'] as num?)?.toDouble() ?? 75.0,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 36.5,
      respiratoryRate: (json['respiratory_rate'] as num?)?.toInt() ?? 18,
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      chiefComplaint: json['chief_complaint'] as String?,
      clinicalNotes: json['clinical_notes'] as String?,
      recordedAt: json['recorded_at'] != null
          ? DateTime.tryParse(json['recorded_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'blood_pressure': bloodPressure,
      'heart_rate': heartRate,
      'temperature': temperature,
      'respiratory_rate': respiratoryRate,
      if (weightKg != null) 'weight_kg': weightKg,
      if (heightCm != null) 'height_cm': heightCm,
      if (chiefComplaint != null) 'chief_complaint': chiefComplaint,
      if (clinicalNotes != null) 'clinical_notes': clinicalNotes,
      'recorded_at': recordedAt.toIso8601String(),
    };
  }

  ClinicalVitals copyWith({
    String? bloodPressure,
    double? heartRate,
    double? temperature,
    int? respiratoryRate,
    double? weightKg,
    double? heightCm,
    String? chiefComplaint,
    String? clinicalNotes,
    DateTime? recordedAt,
  }) {
    return ClinicalVitals(
      bloodPressure: bloodPressure ?? this.bloodPressure,
      heartRate: heartRate ?? this.heartRate,
      temperature: temperature ?? this.temperature,
      respiratoryRate: respiratoryRate ?? this.respiratoryRate,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      chiefComplaint: chiefComplaint ?? this.chiefComplaint,
      clinicalNotes: clinicalNotes ?? this.clinicalNotes,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }
}

class NotificationItem {
  final String id;
  final String patientId;
  final String? patientName;
  final String type; // vaccine_reminder | follow_up | bill_reminder
  final String message;
  final DateTime? scheduledFor;
  final DateTime? sentAt;
  final String status; // pending | sent | failed

  const NotificationItem({
    required this.id,
    required this.patientId,
    this.patientName,
    required this.type,
    required this.message,
    this.scheduledFor,
    this.sentAt,
    this.status = 'pending',
  });

  bool get isPending => status == 'pending';
  bool get isSent => status == 'sent';
  bool get isFailed => status == 'failed';

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      patientName: json['patient_name'] as String?,
      type: json['type'] as String? ?? 'follow_up',
      message: json['message'] as String? ?? '',
      scheduledFor: json['scheduled_for'] != null
          ? DateTime.tryParse(json['scheduled_for'] as String)
          : null,
      sentAt: json['sent_at'] != null
          ? DateTime.tryParse(json['sent_at'] as String)
          : null,
      status: json['status'] as String? ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'type': type,
      'message': message,
      'status': status,
      if (scheduledFor != null) 'scheduled_for': scheduledFor!.toIso8601String(),
      if (sentAt != null) 'sent_at': sentAt!.toIso8601String(),
    };
  }
}

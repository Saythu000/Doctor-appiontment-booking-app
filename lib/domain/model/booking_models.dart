class PractitionerRoleBooking {
  final int id;
  final bool active;
  final int? practitionerRefId;
  final String? practitionerDisplay;
  final String? organizationDisplay;
  final String? availabilityExceptions;
  final List<String> specialties;
  final List<PractitionerAvailability> availability;
  final PractitionerDetail? practitionerDetail;
  final String? orgId;

  PractitionerRoleBooking({
    required this.id,
    required this.active,
    this.practitionerRefId,
    this.practitionerDisplay,
    this.organizationDisplay,
    this.availabilityExceptions,
    required this.specialties,
    required this.availability,
    this.practitionerDetail,
    this.orgId,
  });

  factory PractitionerRoleBooking.fromJson(Map<String, dynamic> json) {
    // Parse specialties
    final specList = json['specialty'] as List?;
    final specs = <String>[];
    if (specList != null) {
      for (var s in specList) {
        if (s is Map<String, dynamic>) {
          final text = s['text'] as String?;
          final display = s['coding_display'] as String?;
          if (text != null && text.isNotEmpty) {
            specs.add(text);
          } else if (display != null && display.isNotEmpty) {
            specs.add(display);
          }
        }
      }
    }

    // Parse availability
    final availList = json['availability'] as List?;
    final avails = <PractitionerAvailability>[];
    if (availList != null) {
      for (var a in availList) {
        if (a is Map<String, dynamic>) {
          avails.add(PractitionerAvailability.fromJson(a));
        }
      }
    }

    // Parse practitioner detail
    final detailMap = json['practitioner_detail'] as Map<String, dynamic>?;
    final detail = detailMap != null ? PractitionerDetail.fromJson(detailMap) : null;

    return PractitionerRoleBooking(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      active: json['active'] ?? false,
      practitionerRefId: json['practitioner_ref_id'] != null
          ? (json['practitioner_ref_id'] is int
              ? json['practitioner_ref_id']
              : int.parse(json['practitioner_ref_id'].toString()))
          : null,
      practitionerDisplay: json['practitioner_display'],
      organizationDisplay: json['organization_display'],
      availabilityExceptions: json['availability_exceptions'],
      specialties: specs,
      availability: avails,
      practitionerDetail: detail,
      orgId: json['org_id'],
    );
  }
}

class PractitionerDetail {
  final int id;
  final String? gender;
  final String fullName;
  final String? photoUrl;
  final List<PractitionerQualification> qualifications;

  PractitionerDetail({
    required this.id,
    this.gender,
    required this.fullName,
    this.photoUrl,
    required this.qualifications,
  });

  factory PractitionerDetail.fromJson(Map<String, dynamic> json) {
    // Parse name text
    String nameText = 'Attending Specialist';
    final nameMap = json['name'] as Map<String, dynamic>?;
    if (nameMap != null) {
      if (nameMap['text'] != null && nameMap['text'].toString().isNotEmpty) {
        nameText = nameMap['text'].toString();
      } else {
        final given = nameMap['given'] as List?;
        final family = nameMap['family'] as String?;
        final givenStr = given != null && given.isNotEmpty ? given.join(' ') : '';
        nameText = 'Dr. $givenStr ${family ?? ''}'.trim();
      }
    }

    // Parse qualifications
    final qualList = json['qualifications'] as List?;
    final quals = <PractitionerQualification>[];
    if (qualList != null) {
      for (var q in qualList) {
        if (q is Map<String, dynamic>) {
          quals.add(PractitionerQualification.fromJson(q));
        }
      }
    }

    return PractitionerDetail(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      gender: json['gender'],
      fullName: nameText,
      photoUrl: json['photo_url'],
      qualifications: quals,
    );
  }
}

class PractitionerQualification {
  final String? code;
  final String? display;
  final String? text;

  PractitionerQualification({this.code, this.display, this.text});

  factory PractitionerQualification.fromJson(Map<String, dynamic> json) {
    return PractitionerQualification(
      code: json['code'],
      display: json['display'],
      text: json['text'],
    );
  }
}

class PractitionerAvailability {
  final int id;
  final List<AvailableTimeSlot> availableTimes;

  PractitionerAvailability({required this.id, required this.availableTimes});

  factory PractitionerAvailability.fromJson(Map<String, dynamic> json) {
    final timesList = json['available_times'] as List?;
    final times = <AvailableTimeSlot>[];
    if (timesList != null) {
      for (var t in timesList) {
        if (t is Map<String, dynamic>) {
          times.add(AvailableTimeSlot.fromJson(t));
        }
      }
    }
    return PractitionerAvailability(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      availableTimes: times,
    );
  }
}

class AvailableTimeSlot {
  final int id;
  final List<String> daysOfWeek;
  final bool allDay;
  final String? availableStartTime;
  final String? availableEndTime;

  AvailableTimeSlot({
    required this.id,
    required this.daysOfWeek,
    required this.allDay,
    this.availableStartTime,
    this.availableEndTime,
  });

  factory AvailableTimeSlot.fromJson(Map<String, dynamic> json) {
    final days = (json['days_of_week'] as List?)?.map((x) => x.toString()).toList() ?? [];
    return AvailableTimeSlot(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      daysOfWeek: days,
      allDay: json['all_day'] ?? false,
      availableStartTime: json['available_start_time'],
      availableEndTime: json['available_end_time'],
    );
  }
}

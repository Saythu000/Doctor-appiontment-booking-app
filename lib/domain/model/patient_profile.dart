class PlainPatientName {
  final String givenName;
  final String? familyName;
  final String? use;

  PlainPatientName({
    required this.givenName,
    this.familyName,
    this.use,
  });

  factory PlainPatientName.fromJson(Map<String, dynamic> json) {
    String givenNameStr = '';
    final givenFromJson = json['given_name'] ?? json['given'];
    if (givenFromJson != null) {
      if (givenFromJson is List) {
        givenNameStr = givenFromJson.join(' ');
      } else {
        givenNameStr = givenFromJson.toString();
      }
    }

    return PlainPatientName(
      givenName: givenNameStr,
      familyName: json['family_name'] ?? json['family'],
      use: json['use'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'given_name': givenName,
      if (familyName != null) 'family_name': familyName,
      if (use != null) 'use': use,
    };
  }

  String get fullName => familyName != null ? '$givenName $familyName' : givenName;
}

class PlainPatientTelecom {
  final String system;
  final String value;
  final String? use;

  PlainPatientTelecom({
    required this.system,
    required this.value,
    this.use,
  });

  factory PlainPatientTelecom.fromJson(Map<String, dynamic> json) {
    return PlainPatientTelecom(
      system: json['system'] ?? '',
      value: json['value'] ?? '',
      use: json['use'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'system': system,
      'value': value,
      if (use != null) 'use': use,
    };
  }
}

class PlainPatientAddress {
  final List<String> line;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;

  PlainPatientAddress({
    required this.line,
    this.city,
    this.state,
    this.postalCode,
    this.country,
  });

  factory PlainPatientAddress.fromJson(Map<String, dynamic> json) {
    var lineFromJson = json['line'];
    List<String> linesList = [];
    if (lineFromJson != null) {
      if (lineFromJson is List) {
        linesList = List<String>.from(lineFromJson);
      } else if (lineFromJson is String) {
        linesList = [lineFromJson];
      }
    }

    return PlainPatientAddress(
      line: linesList,
      city: json['city'],
      state: json['state'],
      postalCode: json['postal_code'] ?? json['postalCode'],
      country: json['country'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'line': line,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (postalCode != null) 'postal_code': postalCode,
      if (country != null) 'country': country,
    };
  }
}

class PlainPatient {
  final int id;
  final String? userId;
  final String? orgId;
  final bool active;
  final String? gender;
  final String? birthDate;
  final List<PlainPatientName>? name;
  final List<PlainPatientTelecom>? telecom;
  final List<PlainPatientAddress>? address;

  PlainPatient({
    required this.id,
    this.userId,
    this.orgId,
    required this.active,
    this.gender,
    this.birthDate,
    this.name,
    this.telecom,
    this.address,
  });

  factory PlainPatient.fromJson(Map<String, dynamic> json) {
    var nameList = json['name'] as List?;
    var telecomList = json['telecom'] as List?;
    var addressList = json['address'] as List?;

    return PlainPatient(
      id: json['id'] is String ? int.parse(json['id']) : (json['id'] ?? 0),
      userId: json['user_id'],
      orgId: json['org_id'],
      active: json['active'] ?? true,
      gender: json['gender'],
      birthDate: json['birth_date'],
      name: nameList?.map((x) => PlainPatientName.fromJson(x)).toList(),
      telecom: telecomList?.map((x) => PlainPatientTelecom.fromJson(x)).toList(),
      address: addressList?.map((x) => PlainPatientAddress.fromJson(x)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      if (orgId != null) 'org_id': orgId,
      'active': active,
      if (gender != null) 'gender': gender,
      if (birthDate != null) 'birth_date': birthDate,
      if (name != null) 'name': name!.map((x) => x.toJson()).toList(),
      if (telecom != null) 'telecom': telecom!.map((x) => x.toJson()).toList(),
      if (address != null) 'address': address!.map((x) => x.toJson()).toList(),
    };
  }

  /// Helper to get the primary full name of the patient
  String get primaryName {
    if (name == null || name!.isEmpty) return 'Operator';
    return name!.first.fullName;
  }

  /// Helper to get primary email contact
  String get primaryEmail {
    if (telecom == null) return '';
    try {
      return telecom!.firstWhere((t) => t.system == 'email').value;
    } catch (_) {
      return '';
    }
  }

  /// Helper to get primary phone contact
  String get primaryPhone {
    if (telecom == null) return '';
    try {
      return telecom!.firstWhere((t) => t.system == 'phone').value;
    } catch (_) {
      return '';
    }
  }
}

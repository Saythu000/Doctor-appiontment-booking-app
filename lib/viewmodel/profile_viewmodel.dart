import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/model/patient_profile.dart';
import '../../data/repository/profile_repository.dart';
import '../../data/repository/health_repository.dart';

class ProfileViewModel extends ChangeNotifier {
  final ProfileRepository profileRepository;
  final HealthRepository healthRepository;

  PlainPatient? currentProfile;
  bool isProfileLoading = false;
  Timer? _backgroundSyncTimer;
  String? profileImagePath;

  ProfileViewModel({
    required this.profileRepository,
    required this.healthRepository,
  }) {
    fetchOrInitProfile();
    _startBackgroundSyncTimer();
  }

  void resetState() {
    currentProfile = null;
    profileImagePath = null;
    notifyListeners();
  }

  Future<void> saveProfileImagePath(String? path) async {
    profileImagePath = path;
    await healthRepository.saveProfileValue('profile_image_path', path ?? '');
    notifyListeners();
  }

  Future<void> fetchOrInitProfile() async {
    isProfileLoading = true;
    notifyListeners();

    profileImagePath = await healthRepository.getProfileValue('profile_image_path');

    try {
      final userId = await healthRepository.getSetting('iam_user_id') ?? '';
      final orgId = await healthRepository.getSetting('iam_org_id') ?? '';
      PlainPatient? profile = await profileRepository.getMyProfile(userId: userId, orgId: orgId);
      profile ??= await profileRepository.createInitialProfile(userId: userId, orgId: orgId);
      // If profile has no name, seed with real logged in user_name
      final savedName = await healthRepository.getSetting('user_name') ?? '';
      if ((profile.name == null || profile.name!.isEmpty) && savedName.isNotEmpty) {
        final parts = savedName.trim().split(' ');
        final g = parts.first;
        final f = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        profile = PlainPatient(
          id: profile.id,
          userId: profile.userId,
          orgId: profile.orgId,
          active: profile.active,
          gender: profile.gender,
          birthDate: profile.birthDate,
          name: [PlainPatientName(givenName: g, familyName: f)],
          telecom: profile.telecom,
          address: profile.address,
        );
        // Persist to FHIR backend so the server has the real patient name attached
        try {
          profileRepository.addName(patientId: profile.id, givenName: g, familyName: f).then((_) {}).catchError((_) {});
        } catch (_) {}
      }

      // Retrieve local cache to enrich or fallback any missing fields
      final cachedGiven = await healthRepository.getProfileValue('given_name');
      final cachedFamily = await healthRepository.getProfileValue('family_name');
      final cachedGender = await healthRepository.getProfileValue('gender');
      final cachedDob = await healthRepository.getProfileValue('birth_date');
      final cachedPhone = await healthRepository.getProfileValue('phone');
      final cachedStreet = await healthRepository.getProfileValue('street');
      final cachedCity = await healthRepository.getProfileValue('city');
      final cachedState = await healthRepository.getProfileValue('state');
      final cachedZip = await healthRepository.getProfileValue('zip');
      final cachedCountry = await healthRepository.getProfileValue('country');

      // Enrich profile with cached phone if server returned none
      List<PlainPatientTelecom> telecoms = List.from(profile.telecom ?? []);
      if (profile.primaryPhone.isEmpty && cachedPhone != null && cachedPhone.isNotEmpty) {
        telecoms.add(PlainPatientTelecom(system: 'phone', value: cachedPhone));
      }

      // Enrich profile with cached address if server returned none
      List<PlainPatientAddress> addresses = List.from(profile.address ?? []);
      if (addresses.isEmpty && cachedStreet != null && cachedStreet.isNotEmpty) {
        addresses.add(PlainPatientAddress(
          line: [cachedStreet],
          city: cachedCity?.isNotEmpty == true ? cachedCity : null,
          state: cachedState?.isNotEmpty == true ? cachedState : null,
          postalCode: cachedZip?.isNotEmpty == true ? cachedZip : null,
          country: cachedCountry?.isNotEmpty == true ? cachedCountry : null,
        ));
      }

      currentProfile = PlainPatient(
        id: profile.id,
        userId: profile.userId,
        orgId: profile.orgId,
        active: profile.active,
        gender: profile.gender ?? cachedGender,
        birthDate: profile.birthDate ?? cachedDob,
        name: (profile.name != null && profile.name!.isNotEmpty)
            ? profile.name
            : (cachedGiven != null && cachedGiven.isNotEmpty
                ? [PlainPatientName(givenName: cachedGiven, familyName: cachedFamily)]
                : profile.name),
        telecom: telecoms.isNotEmpty ? telecoms : null,
        address: addresses.isNotEmpty ? addresses : null,
      );

      // Cache successfully fetched demographics locally
      if (currentProfile?.name != null && currentProfile!.name!.isNotEmpty) {
        await healthRepository.saveProfileValue('given_name', currentProfile!.name!.first.givenName);
        await healthRepository.saveProfileValue('family_name', currentProfile!.name!.first.familyName ?? '');
      }
      if (currentProfile?.gender != null) {
        await healthRepository.saveProfileValue('gender', currentProfile!.gender!);
      }
      if (currentProfile?.birthDate != null) {
        await healthRepository.saveProfileValue('birth_date', currentProfile!.birthDate!);
      }
      if (currentProfile?.primaryPhone.isNotEmpty == true) {
        await healthRepository.saveProfileValue('phone', currentProfile!.primaryPhone);
      }
      if (currentProfile?.address != null && currentProfile!.address!.isNotEmpty) {
        final addr = currentProfile!.address!.first;
        await healthRepository.saveProfileValue('street', addr.line.join(', '));
        if (addr.city != null) await healthRepository.saveProfileValue('city', addr.city!);
        if (addr.state != null) await healthRepository.saveProfileValue('state', addr.state!);
        if (addr.postalCode != null) await healthRepository.saveProfileValue('zip', addr.postalCode!);
        if (addr.country != null) await healthRepository.saveProfileValue('country', addr.country!);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ProfileViewModel] Failed to fetch/init patient profile: $e');
      }
      // Load offline fallback profile from authentic credentials / SQLite cache
      final String? cachedGiven = await healthRepository.getProfileValue('given_name');
      final String? cachedFamily = await healthRepository.getProfileValue('family_name');
      final String? cachedGender = await healthRepository.getProfileValue('gender');
      final String? cachedDob = await healthRepository.getProfileValue('birth_date');
      final String? cachedPhone = await healthRepository.getProfileValue('phone');
      final String? cachedStreet = await healthRepository.getProfileValue('street');
      final String? cachedCity = await healthRepository.getProfileValue('city');
      final String? cachedState = await healthRepository.getProfileValue('state');
      final String? cachedZip = await healthRepository.getProfileValue('zip');
      final String? cachedCountry = await healthRepository.getProfileValue('country');
      final String? savedName = await healthRepository.getSetting('user_name');
      final String? savedEmail = await healthRepository.getSetting('user_email');

      String given = cachedGiven ?? '';
      String family = cachedFamily ?? '';
      if (given.isEmpty && savedName != null && savedName.trim().isNotEmpty) {
        final parts = savedName.trim().split(' ');
        given = parts.first;
        family = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      }

      List<PlainPatientTelecom> telecoms = [];
      if (savedEmail != null && savedEmail.isNotEmpty) {
        telecoms.add(PlainPatientTelecom(system: 'email', value: savedEmail));
      }
      if (cachedPhone != null && cachedPhone.isNotEmpty) {
        telecoms.add(PlainPatientTelecom(system: 'phone', value: cachedPhone));
      }

      List<PlainPatientAddress>? addresses;
      if ((cachedStreet != null && cachedStreet.isNotEmpty) ||
          (cachedCity != null && cachedCity.isNotEmpty) ||
          (cachedState != null && cachedState.isNotEmpty) ||
          (cachedZip != null && cachedZip.isNotEmpty) ||
          (cachedCountry != null && cachedCountry.isNotEmpty)) {
        addresses = [
          PlainPatientAddress(
            line: (cachedStreet != null && cachedStreet.isNotEmpty) ? [cachedStreet] : [],
            city: cachedCity,
            state: cachedState,
            postalCode: cachedZip,
            country: cachedCountry,
          ),
        ];
      }

      currentProfile = PlainPatient(
        id: 0,
        active: true,
        gender: (cachedGender != null && cachedGender.isNotEmpty) ? cachedGender : null,
        birthDate: (cachedDob != null && cachedDob.isNotEmpty) ? cachedDob : null,
        name: given.isNotEmpty
            ? [
                PlainPatientName(
                  givenName: given,
                  familyName: family,
                ),
              ]
            : null,
        telecom: telecoms.isNotEmpty ? telecoms : null,
        address: addresses,
      );
    } finally {
      isProfileLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveProfileDetails({
    required String givenName,
    required String familyName,
    required String gender,
    required String birthDate,
    required String email,
    required String phone,
    required String street,
    required String city,
    required String state,
    required String zip,
    required String country,
  }) async {
    isProfileLoading = true;
    notifyListeners();

    // 1. Save profile details locally first to ensure we always have offline cache
    await healthRepository.saveProfileValue('given_name', givenName);
    await healthRepository.saveProfileValue('family_name', familyName);
    await healthRepository.saveProfileValue('gender', gender);
    await healthRepository.saveProfileValue('birth_date', birthDate);
    if (phone.isNotEmpty) {
      await healthRepository.saveProfileValue('phone', phone);
    }
    await healthRepository.saveProfileValue('street', street);
    await healthRepository.saveProfileValue('city', city);
    await healthRepository.saveProfileValue('state', state);
    await healthRepository.saveProfileValue('zip', zip);
    await healthRepository.saveProfileValue('country', country);

    List<PlainPatientTelecom> initialTelecoms = [];
    if (email.isNotEmpty) {
      initialTelecoms.add(PlainPatientTelecom(system: 'email', value: email));
    }
    if (phone.isNotEmpty) {
      initialTelecoms.add(PlainPatientTelecom(system: 'phone', value: phone));
    }

    List<PlainPatientAddress>? initialAddresses;
    if (street.isNotEmpty || city.isNotEmpty || state.isNotEmpty || zip.isNotEmpty || country.isNotEmpty) {
      initialAddresses = [
        PlainPatientAddress(
          line: street.isNotEmpty ? [street] : [],
          city: city.isNotEmpty ? city : null,
          state: state.isNotEmpty ? state : null,
          postalCode: zip.isNotEmpty ? zip : null,
          country: country.isNotEmpty ? country : null,
        ),
      ];
    }

    final int existingId = (currentProfile != null && currentProfile!.id != 0) ? currentProfile!.id : 0;

    // 2. Hydrate local memory state immediately in case backend request throws
    currentProfile = PlainPatient(
      id: existingId,
      active: true,
      gender: gender,
      birthDate: birthDate,
      name: [
        PlainPatientName(
          givenName: givenName,
          familyName: familyName,
        ),
      ],
      telecom: initialTelecoms.isNotEmpty ? initialTelecoms : null,
      address: initialAddresses,
    );

    try {
      int pId = existingId;
      // If we don't have a profile yet, check or create one on the server
      if (pId == 0) {
        final userId = await healthRepository.getSetting('iam_user_id') ?? '';
        final orgId = await healthRepository.getSetting('iam_org_id') ?? '';
        PlainPatient? profile = await profileRepository.getMyProfile(userId: userId, orgId: orgId);
        profile ??= await profileRepository.createInitialProfile(userId: userId, orgId: orgId);
        pId = profile.id;
      }
      
      if (pId != 0) {
        // Patch Core Demographics (DOB, Gender)
        PlainPatient updated = await profileRepository.patchDemographics(
          patientId: pId,
          gender: gender,
          birthDate: birthDate,
        );

      // Sync Name Subresource
      updated = await profileRepository.addName(
        patientId: pId,
        givenName: givenName,
        familyName: familyName,
      );

      // Sync Email Subresource
      if (email.isNotEmpty) {
        updated = await profileRepository.addTelecom(
          patientId: pId,
          system: 'email',
          value: email,
        );
      }

      // Sync Phone Subresource
      if (phone.isNotEmpty) {
        updated = await profileRepository.addTelecom(
          patientId: pId,
          system: 'phone',
          value: phone,
        );
      }

      // Sync Address Subresource
      if (street.isNotEmpty || city.isNotEmpty || state.isNotEmpty || zip.isNotEmpty || country.isNotEmpty) {
        updated = await profileRepository.addAddress(
          patientId: pId,
          street: street,
          city: city,
          state: state,
          zip: zip,
          country: country,
        );
      }

        currentProfile = updated;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ProfileViewModel] Save profile details failed, falling back to local storage: $e');
      }
      // Re-throw so callers know it failed, but we already have hydrated the offline fallback memory state!
      rethrow;
    } finally {
      isProfileLoading = false;
      notifyListeners();
    }
  }

  void _startBackgroundSyncTimer() {
    _backgroundSyncTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      _performSilentBackgroundSync();
    });
  }

  Future<void> _performSilentBackgroundSync() async {
    try {
      if (currentProfile != null) {
        await healthRepository.uploadPendingMetrics();
        final nowStr = DateTime.now().toIso8601String().substring(0, 16).replaceAll('T', ' ');
        await healthRepository.saveSetting('lastCloudSyncTime', nowStr);
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ProfileViewModel] Silent background sync failed: $e');
      }
    }
  }

  @override
  void dispose() {
    _backgroundSyncTimer?.cancel();
    super.dispose();
  }
}

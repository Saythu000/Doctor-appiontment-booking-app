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
      currentProfile = profile;

      // Cache successfully fetched demographics locally
      if (profile.name != null && profile.name!.isNotEmpty) {
        await healthRepository.saveProfileValue('given_name', profile.name!.first.givenName);
        await healthRepository.saveProfileValue('family_name', profile.name!.first.familyName ?? '');
      }
      if (profile.gender != null) {
        await healthRepository.saveProfileValue('gender', profile.gender!);
      }
      if (profile.birthDate != null) {
        await healthRepository.saveProfileValue('birth_date', profile.birthDate!);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ProfileViewModel] Failed to fetch/init patient profile: $e');
      }
      // Load offline fallback profile from local SQLite cache
      final String? cachedGiven = await healthRepository.getProfileValue('given_name');
      final String? cachedFamily = await healthRepository.getProfileValue('family_name');
      final String? cachedGender = await healthRepository.getProfileValue('gender');
      final String? cachedDob = await healthRepository.getProfileValue('birth_date');

      if (cachedGiven != null || cachedFamily != null || cachedGender != null || cachedDob != null) {
        currentProfile = PlainPatient(
          id: 10001,
          active: true,
          gender: cachedGender ?? 'MALE',
          birthDate: cachedDob ?? '2000-01-01',
          name: [
            PlainPatientName(
              givenName: cachedGiven ?? '',
              familyName: cachedFamily ?? '',
            ),
          ],
        );
      } else {
        // Fallback to a mock active profile if offline and cache is empty
        currentProfile = PlainPatient(
          id: 10001,
          active: true,
          gender: 'MALE',
          birthDate: '1995-05-15',
          name: [
            PlainPatientName(
              givenName: 'John',
              familyName: 'Doe',
            ),
          ],
        );
      }
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

    // 2. Hydrate local memory state immediately in case backend request throws
    currentProfile = PlainPatient(
      id: (currentProfile != null && currentProfile!.id != 0) ? currentProfile!.id : 0,
      active: true,
      gender: gender,
      birthDate: birthDate,
      name: [
        PlainPatientName(
          givenName: givenName,
          familyName: familyName,
        ),
      ],
    );

    try {
      // If we don't have a profile yet, check or create one on the server
      if (currentProfile == null || currentProfile!.id == 0) {
        final userId = await healthRepository.getSetting('iam_user_id') ?? '';
        final orgId = await healthRepository.getSetting('iam_org_id') ?? '';
        PlainPatient? profile = await profileRepository.getMyProfile(userId: userId, orgId: orgId);
        profile ??= await profileRepository.createInitialProfile(userId: userId, orgId: orgId);
        currentProfile = profile;
      }
      
      int pId = currentProfile!.id;

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

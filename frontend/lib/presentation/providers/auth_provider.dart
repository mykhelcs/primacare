import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/models/staff_profile.dart';
import '../../domain/models/user_role.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

class AuthStateData {
  final StaffProfile? profile;
  final bool isLoading;
  final String? errorMessage;

  const AuthStateData({
    this.profile,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isAuthenticated => profile != null;

  AuthStateData copyWith({
    StaffProfile? profile,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool clearProfile = false,
  }) {
    return AuthStateData(
      profile: clearProfile ? null : (profile ?? this.profile),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthNotifier extends Notifier<AuthStateData> {
  late final AuthRepository _repository;

  @override
  AuthStateData build() {
    _repository = ref.watch(authRepositoryProvider);

    final initialUser = _repository.currentUser;
    if (initialUser != null) {
      return AuthStateData(
        profile: StaffProfile(
          id: initialUser.id,
          email: initialUser.email ?? 'staff@primacare.ph',
          fullName: initialUser.userMetadata?['full_name'] as String? ?? 'Clinical Staff',
          role: UserRole.fromString(initialUser.userMetadata?['role'] as String?),
          clinic: ClinicTenant.centralBranch(),
        ),
      );
    }

    if (_repository.activeProfile != null) {
      return AuthStateData(profile: _repository.activeProfile);
    }

    return const AuthStateData();
  }

  void switchClinic(ClinicTenant newClinic) {
    if (state.profile != null) {
      final updated = state.profile!.copyWith(clinic: newClinic);
      _repository.switchClinic(newClinic);
      state = state.copyWith(profile: updated);
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _repository.signInWithEmailPassword(
        email: email,
        password: password,
      );
      state = AuthStateData(profile: profile, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e is AuthException ? e.message : e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> signInAsDemo(UserRole role) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _repository.signInAsDemo(role);
      state = AuthStateData(profile: profile, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    await _repository.signOut();
    state = const AuthStateData(profile: null, isLoading: false);
  }
}

final authControllerProvider = NotifierProvider<AuthNotifier, AuthStateData>(() {
  return AuthNotifier();
});

final currentStaffProfileProvider = Provider<StaffProfile?>((ref) {
  return ref.watch(authControllerProvider).profile;
});

final currentClinicProvider = Provider<ClinicTenant>((ref) {
  final profile = ref.watch(currentStaffProfileProvider);
  return profile?.clinic ?? ClinicTenant.centralBranch();
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authControllerProvider).isAuthenticated;
});

final currentUserRoleProvider = Provider<UserRole>((ref) {
  final profile = ref.watch(currentStaffProfileProvider);
  return profile?.role ?? UserRole.nurse;
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import 'auth_repository.dart';

class SessionState {
  const SessionState({this.role, this.token});
  final String? role;
  final String? token;
}

class SessionController extends AsyncNotifier<SessionState> {
  @override
  Future<SessionState> build() async => const SessionState();

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      final result = await repo.login(email, password);
      currentAuthToken = result.token;
      return SessionState(role: result.role, token: result.token);
    });
  }

  void logout() {
    currentAuthToken = null;
    state = const AsyncData(SessionState());
  }
}

final sessionControllerProvider = AsyncNotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

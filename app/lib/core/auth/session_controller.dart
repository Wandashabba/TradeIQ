import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';

class SessionState {
  const SessionState({this.role});
  final String? role;
}

class SessionController extends AsyncNotifier<SessionState> {
  @override
  Future<SessionState> build() async => const SessionState();

  Future<void> login(String email, String password) async {
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.login(email, password);
    state = AsyncData(SessionState(role: result.role));
  }
}

final sessionControllerProvider = AsyncNotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

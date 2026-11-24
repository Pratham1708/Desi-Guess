/// Domain and application-level failure types.
sealed class AppFailure implements Exception {
  const AppFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'AppFailure($code): $message';
}

final class GameRuleFailure extends AppFailure {
  const GameRuleFailure(super.message, {super.code = 'game_rule'});
}

final class AuthFailure extends AppFailure {
  const AuthFailure(super.message, {super.code = 'auth_error'});
}

final class RoomFailure extends AppFailure {
  const RoomFailure(super.message, {super.code = 'room_error'});
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message, {super.code = 'network_error'});
}

final class PermissionFailure extends AppFailure {
  const PermissionFailure(super.message, {super.code = 'permission_denied'});
}

final class StorageFailure extends AppFailure {
  const StorageFailure(super.message, {super.code = 'storage_error'});
}

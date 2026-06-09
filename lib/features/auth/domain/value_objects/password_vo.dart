import '../../../../core/error/auth_failure.dart';

class PasswordVO {
  final String value;

  const PasswordVO._(this.value);

  static (PasswordVO?, AuthFailure?) create(String input) {
    if (input.length < 8) {
      return (null, WeakPasswordFailure());
    }
    return (PasswordVO._(input), null);
  }
}

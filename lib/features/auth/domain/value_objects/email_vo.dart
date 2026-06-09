import '../../../../core/error/auth_failure.dart';

class EmailVO {
  final String value;

  const EmailVO._(this.value);

  static (EmailVO?, AuthFailure?) create(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return (null, InvalidEmailFailure());
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(trimmed)) {
      return (null, InvalidEmailFailure());
    }
    return (EmailVO._(trimmed), null);
  }
}

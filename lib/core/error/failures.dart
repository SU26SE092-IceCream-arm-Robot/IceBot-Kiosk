import 'package:equatable/equatable.dart';

/// Base Failure class for Clean Architecture.
/// All domain-level errors should extend this class.
abstract class Failure extends Equatable {
  final String message;
  
  const Failure([this.message = 'An unexpected error occurred']);

  @override
  List<Object?> get props => [message];
}

/// Represents failure from remote API/Server.
class ServerFailure extends Failure {
  final int? statusCode;

  const ServerFailure({String message = 'Server error occurred', this.statusCode})
      : super(message);

  @override
  List<Object?> get props => [message, statusCode];
}

/// Represents failure from local storage (SQLite, SharedPreferences, SecureStorage).
class CacheFailure extends Failure {
  const CacheFailure({String message = 'Cache access failure'}) : super(message);
}

/// Represents network connectivity failures.
class NetworkFailure extends Failure {
  const NetworkFailure({String message = 'No internet connection'}) : super(message);
}

/// Represents validation errors.
class ValidationFailure extends Failure {
  const ValidationFailure({required String message}) : super(message);
}

import '../errors/app_error.dart';

sealed class Result<T> {
  const Result();

  bool get isOk => this is Ok<T>;
  bool get isFailure => this is Failure<T>;

  R fold<R>(R Function(T value) onOk, R Function(AppError error) onFailure) {
    return switch (this) {
      Ok<T>(:final value) => onOk(value),
      Failure<T>(:final error) => onFailure(error),
    };
  }
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error);

  final AppError error;
}

sealed class Result<T> {
  const Result();

  R when<R>({
    required R Function(T data) success,
    required R Function(String message) failure,
  });
}

class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(String message) failure,
  }) =>
      success(data);
}

class FailureResult<T> extends Result<T> {
  const FailureResult(this.message);
  final String message;

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(String message) failure,
  }) =>
      failure(message);
}

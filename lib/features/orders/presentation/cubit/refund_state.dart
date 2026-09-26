import '../../../../domain/entities/refund.dart';

class RefundState {
  final bool isSubmitting;
  final Refund? refund;
  final String? errorMessage;

  const RefundState({
    this.isSubmitting = false,
    this.refund,
    this.errorMessage,
  });

  bool get isSuccess => refund != null;
  bool get hasError => errorMessage != null;

  RefundState copyWith({
    bool? isSubmitting,
    Refund? refund,
    bool clearRefund = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return RefundState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      refund: clearRefund ? null : (refund ?? this.refund),
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RefundState &&
          runtimeType == other.runtimeType &&
          isSubmitting == other.isSubmitting &&
          refund == other.refund &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(isSubmitting, refund, errorMessage);
}

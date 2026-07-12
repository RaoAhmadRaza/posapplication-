import '../../domain/entities/customer_payment_result.dart';

class CustomerPaymentResultModel {
  static CustomerPaymentResult fromJson(Map<String, dynamic> j) {
    return CustomerPaymentResult(
      paymentId: j['payment_id'] as String,
      balance: double.tryParse(j['balance'].toString()) ?? 0,
      status: j['status'] as String? ?? '',
    );
  }
}

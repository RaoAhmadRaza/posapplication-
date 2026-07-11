import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/cart_line.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/held_sale.dart';
import '../../domain/entities/sale_result.dart';
import '../../domain/failures/sales_failure.dart';
import '../../domain/usecases/create_sale.dart';
import '../../domain/usecases/hold_sale.dart';
import '../../domain/usecases/load_held_sales.dart';
import '../../domain/usecases/delete_held_sale.dart';

enum PaymentMethodLabel { cash, bankTransfer, card, mobileWallet, cheque, loyaltyPoints, creditNote }

class CartPayment {
  final PaymentMethodLabel method;
  final double amount;
  final String? reference;

  const CartPayment({required this.method, required this.amount, this.reference});
}

class CartState {
  final List<CartLine> lines;
  final Customer? customer;
  final List<CartPayment> payments;
  final bool submitting;
  final SalesFailure? lastError;
  final SaleResult? lastResult;
  final SalesFailure? heldError;

  const CartState({
    this.lines = const [],
    this.customer,
    this.payments = const [],
    this.submitting = false,
    this.lastError,
    this.lastResult,
    this.heldError,
  });

  CartState copyWith({
    List<CartLine>? lines,
    Customer? customer,
    List<CartPayment>? payments,
    bool? submitting,
    SalesFailure? lastError,
    SaleResult? lastResult,
    SalesFailure? heldError,
    bool clearHeldError = false,
  }) {
    return CartState(
      lines: lines ?? this.lines,
      customer: customer ?? this.customer,
      payments: payments ?? this.payments,
      submitting: submitting ?? this.submitting,
      lastError: lastError ?? this.lastError,
      lastResult: lastResult ?? this.lastResult,
      heldError: clearHeldError ? null : (heldError ?? this.heldError),
    );
  }

  double get subtotal => lines.fold(0.0, (s, l) => s + (l.qty * l.unitPrice));
  double get discountTotal => lines.fold(0.0, (s, l) => s + l.discountAmount);
  double get taxTotal => lines.fold(0.0, (s, l) => s + l.taxAmount);
  double get grandTotal => lines.fold(0.0, (s, l) => s + l.lineTotal);
  double get paid => payments.fold(0.0, (s, p) => s + p.amount);
  double get balance => (grandTotal - paid).clamp(0, double.infinity);
  double get change => (paid - grandTotal).clamp(0, double.infinity);
  int get lineCount => lines.length;
  int get totalItems => lines.fold(0, (s, l) => s + l.qty.toInt());
}

final posCartProvider = NotifierProvider<PosCartController, CartState>(
  PosCartController.new,
);

class PosCartController extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  int _nextLineId = 1;

  void addLine({
    required String productId,
    required String productName,
    String? sku,
    String? barcode,
    required double qty,
    required double unitPrice,
    double discountPct = 0,
    double taxPct = 0,
    String? imeiId,
  }) {
    final lines = List<CartLine>.from(state.lines);
    final existingIdx = lines.indexWhere((l) =>
        l.productId == productId && l.imeiId == imeiId);
    if (existingIdx >= 0) {
      final existing = lines[existingIdx];
      lines[existingIdx] = existing.copyWith(qty: existing.qty + qty);
    } else {
      final id = '${_nextLineId++}';
      lines.add(CartLine(
        id: id,
        productId: productId,
        productName: productName,
        sku: sku,
        barcode: barcode,
        qty: qty,
        unitPrice: unitPrice,
        discountPct: discountPct,
        taxPct: taxPct,
        imeiId: imeiId,
      ));
    }
    state = CartState(lines: lines, customer: state.customer, payments: state.payments);
  }

  void updateQty(String lineId, double qty) {
    final lines = state.lines
        .map((l) => l.id == lineId ? l.copyWith(qty: qty) : l)
        .toList();
    state = CartState(lines: lines, customer: state.customer, payments: state.payments);
  }

  void removeLine(String lineId) {
    final lines = state.lines.where((l) => l.id != lineId).toList();
    state = CartState(lines: lines, customer: state.customer, payments: state.payments);
  }

  void setCustomer(Customer? customer) {
    state = CartState(lines: state.lines, customer: customer, payments: state.payments);
  }

  void addPayment(PaymentMethodLabel method, double amount, {String? reference}) {
    final payments = List<CartPayment>.from(state.payments);
    payments.add(CartPayment(method: method, amount: amount, reference: reference));
    state = CartState(
      lines: state.lines,
      customer: state.customer,
      payments: payments,
    );
  }

  void removePayment(int index) {
    final payments = List<CartPayment>.from(state.payments);
    if (index >= 0 && index < payments.length) payments.removeAt(index);
    state = CartState(
      lines: state.lines,
      customer: state.customer,
      payments: payments,
    );
  }

  void clear() {
    state = const CartState();
  }

  void clearResult() {
    state = CartState(
      lines: state.lines,
      customer: state.customer,
      payments: state.payments,
    );
  }

  double get subtotal => state.subtotal;
  double get discountTotal => state.discountTotal;
  double get taxTotal => state.taxTotal;
  double get grandTotal => state.grandTotal;
  double get paid => state.paid;
  double get balance => state.balance;
  double get change => state.change;
  int get lineCount => state.lineCount;
  int get totalItems => state.totalItems;

  Future<bool> hold({
    required String branchId,
    String? sessionId,
    required String label,
  }) async {
    final cartJson = <String, dynamic>{
      'lines': state.lines.map((l) => <String, dynamic>{
            'productId': l.productId,
            'productName': l.productName,
            'sku': l.sku,
            'barcode': l.barcode,
            'qty': l.qty,
            'unitPrice': l.unitPrice,
            'discountPct': l.discountPct,
            'taxPct': l.taxPct,
            'imeiId': l.imeiId,
          }).toList(),
      'customerName': state.customer?.name,
    };
    final (ok, failure) = await ref.read(holdSaleUseCaseProvider).call(
          branchId: branchId,
          sessionId: sessionId,
          customerId: state.customer?.id,
          cartJson: cartJson,
          label: label,
        );
    if (ok) {
      state = const CartState();
      return true;
    }
    return false;
  }

  Future<List<HeldSale>> loadHeld({String? branchId}) async {
    final (list, failure) =
        await ref.read(loadHeldSalesUseCaseProvider).call(branchId: branchId);
    state = failure != null
        ? state.copyWith(heldError: failure)
        : state.copyWith(clearHeldError: true);
    return list;
  }

  void resume(HeldSale heldSale) {
    final cartJson = heldSale.cartJson;
    final linesList = (cartJson['lines'] as List<dynamic>?) ?? [];
    final lines = <CartLine>[];
    int id = 1;
    for (final l in linesList) {
      final m = l as Map<String, dynamic>;
      lines.add(CartLine(
        id: '${id++}',
        productId: m['productId'] as String,
        productName: m['productName'] as String,
        sku: m['sku'] as String?,
        barcode: m['barcode'] as String?,
        qty: (m['qty'] as num).toDouble(),
        unitPrice: (m['unitPrice'] as num).toDouble(),
        discountPct: (m['discountPct'] as num?)?.toDouble() ?? 0,
        taxPct: (m['taxPct'] as num?)?.toDouble() ?? 0,
        imeiId: m['imeiId'] as String?,
      ));
    }
    state = CartState(lines: lines, customer: null, payments: []);
  }

  Future<void> deleteHeld(String id) async {
    await ref.read(deleteHeldSaleUseCaseProvider).call(id);
  }

  Future<SalesFailure?> checkout({
    required String branchId,
    String? sessionId,
  }) async {
    if (state.lines.isEmpty) return EmptyCartFailure();
    state = CartState(
      lines: state.lines,
      customer: state.customer,
      payments: state.payments,
      submitting: true,
    );

    final items = state.lines.map((l) => <String, dynamic>{
          'product_id': l.productId,
          'qty': l.qty,
          'unit_price': l.unitPrice,
          if (l.discountPct > 0) 'discount_pct': l.discountPct,
          if (l.taxPct > 0) 'tax_pct': l.taxPct,
          if (l.imeiId != null) 'imei_id': l.imeiId,
        }).toList();

    final payments = state.payments.map((p) => <String, dynamic>{
          'method': p.method.name.toUpperCase(),
          'amount': p.amount,
          if (p.reference != null && p.reference!.isNotEmpty) 'reference': p.reference,
        }).toList();

    final (result, failure) = await ref.read(createSaleUseCaseProvider).call(
          branchId: branchId,
          customerId: state.customer?.id,
          items: items,
          payments: payments,
          sessionId: sessionId,
        );

    if (failure != null) {
      state = CartState(
        lines: state.lines,
        customer: state.customer,
        payments: state.payments,
        submitting: false,
        lastError: failure,
      );
      return failure;
    }

    state = CartState(
      lines: [],
      customer: null,
      payments: [],
      submitting: false,
      lastResult: result,
    );
    return null;
  }
}

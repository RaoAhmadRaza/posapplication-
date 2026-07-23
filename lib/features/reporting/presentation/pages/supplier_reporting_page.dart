import 'package:flutter/material.dart';
import '../controllers/reporting_controllers.dart';
import '../widgets/aging_report_view.dart';

class SupplierReportingPage extends StatelessWidget {
  const SupplierReportingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AgingReportView(
      provider: supplierAgingProvider,
      title: 'Supplier aging',
      description: 'Outstanding payables grouped by age.',
      entityLabel: 'Supplier',
    );
  }
}

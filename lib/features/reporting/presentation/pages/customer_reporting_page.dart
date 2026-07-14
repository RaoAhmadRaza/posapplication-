import 'package:flutter/material.dart';
import '../controllers/reporting_controllers.dart';
import '../widgets/aging_report_view.dart';

class CustomerReportingPage extends StatelessWidget {
  const CustomerReportingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AgingReportView(
      provider: customerAgingProvider,
      title: 'Customer Aging',
      entityLabel: 'Customer',
    );
  }
}

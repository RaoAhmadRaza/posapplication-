# Purchasing, Reporting, Sales, Settings Features Test Catalog

**Catalogued:** ✓ | **Pages:** 37 | **Routes:** 38 | **Format:** Table summary (critical tests only)

---

## Purchasing (13 pages)

| Page | Route | Guard | Key RPC |
|---|---|---|---|
| PurchaseHubPage | /purchasing | NONE | Navigation only |
| PurchaseOrdersPage | /purchasing/orders | NONE | loadPurchaseOrders, setFilters, search |
| PurchaseOrderFormPage | /purchasing/orders/create | purchasing:create | savePurchaseOrder (create with line items) |
| PurchaseOrderDetailPage | /purchasing/orders/:id | purchasing:update | fetchOrderDetail, changeStatus, addLine, removeLine |
| GrnReceivePage | /purchasing/orders/:id/receive | purchasing:create | receiveGoods (partial/full GRN posting) |
| PurchaseInvoiceMatchPage | /purchasing/orders/:id/invoice | purchasing:create | matchInvoiceToPo (GL posting) |
| PurchaseInvoicesPage | /purchasing/invoices | NONE | loadPurchaseInvoices, setFilters |
| PurchaseInvoiceDetailPage | /purchasing/invoices/:id | NONE | fetchInvoiceDetail, approveInvoice |
| SupplierPaymentPage | /purchasing/payments/create | purchasing:create | recordSupplierPayment (GL posting + cheque) |
| ReorderSuggestionsPage | /purchasing/reorder | NONE | loadReorderSuggestions (ROP calc) |
| PurchaseReturnsPage | /purchasing/returns | NONE | loadPurchaseReturns, setStatus |
| PurchaseReturnFormPage | /purchasing/returns/create | purchasing:create | createPurchaseReturn (debit note + stock reversal) |
| PurchaseReturnDetailPage | /purchasing/returns/:id | NONE | fetchReturnDetail |

**P0-MONEY:** GrnReceivePage (stock debit), InvoiceMatchPage (GL posting), SupplierPaymentPage (GL posting)
**Critical tests:** Create PO → receive partial GRN → match invoice → post GL → verify ledger; full return flow

---

## Reporting (9 pages)

| Page | Route | Guard | Key RPC |
|---|---|---|---|
| ReportsHubPage | /reports | reports:read | Navigation only |
| InventoryReportingPage | /reports/inventory | reports:read | loadInventoryValuation (FIFO costing) |
| ProductPerformancePage | /reports/products | reports:read | loadProductPerformance (profit margin by product) |
| CustomerReportingPage | /reports/customers | reports:read | loadCustomerAging (A/R by bucket) |
| SupplierReportingPage | /reports/suppliers | reports:read | loadSupplierAging (A/P by bucket) |
| TrendAnalysisPage | /reports/trends | reports:read | loadDailySales (sales by day, week, month) |
| ScheduledReportsPage | /reports/schedules | reports:read | loadReportSchedules (email delivery config) |
| SmartInsightsPage | /reports/insights | reports:read | loadAiRecommendations (reorder alerts, low-stock) |
| ForecastingPage | /reports/forecast | reports:read | loadDailySales (demand forecast by SKU) |

**P2-READ:** All read-only; data load + rendering
**Critical tests:** Inventory report FIFO costing correct; aging buckets match GL; forecast accuracy

---

## Sales (9 pages)

| Page | Route | Guard | Key RPC |
|---|---|---|---|
| PosTerminalPage | /sales/pos | sales:create | createInvoice (full POS flow: add line, discount, tax, payment, GL posting) |
| OpenSessionPage | /sales/open | sales:create | createSalesSession (open cash drawer, init session) |
| CloseSessionPage | /sales/session/close | sales:create | closeSalesSession (reconcile cash, GL posting) |
| PaymentSheet | /sales/payment | sales:create | recordPayment (cash/card/cheque, GL account resolve) |
| SaleSuccessPage | /sales/success | NONE | Navigation/display only |
| ReceiptPage | /sales/receipt | NONE | fetchInvoiceReceipt (PDF generation) |
| SalesHistoryPage | /sales/history | sales:read | loadInvoices (search, filter, export) |
| InvoiceDetailPage | /sales/invoice/:invoiceId | sales:read | fetchInvoiceDetail (view, reprint, mark paid) |
| SalesReturnPage | /sales/return | sales:create | createSalesReturn (debit note + stock reversal) |

**P0-MONEY:** PosTerminalPage (GL posting for every sale), CloseSessionPage (cash reconciliation), SalesReturnPage (credit note)
**Critical tests:** POS complete flow: add 3 items → apply discount → select payment → confirm → GL posted; session close balances

---

## Settings (6 pages)

| Page | Route | Guard | Key RPC |
|---|---|---|---|
| SettingsHubPage | /settings | settings:read | Navigation only |
| BusinessSettingsPage | /settings/business | settings:update | updateBusinessSettings (company name, tax ID, logo, fiscal year) |
| BranchesPage | /settings/branches | settings:read | loadBranches (per-branch config: currency, GL accounts, warehouse) |
| PaymentMethodsPage | /settings/payment-methods | settings:read | loadPaymentMethods (bank link, GL account per method) |
| NumberSeriesPage | /settings/number-series | settings:read | loadNumberSeries (invoice #, PO #, receipt # templates, read-only) |
| PreferencesPage | /settings/preferences | settings:read | loadPreferences (theme, language, default branch, decimal places) |

**P1-DATA:** BusinessSettingsPage update; BranchesPage config affects all GL posting
**Critical tests:** Change business tax ID → verify appears on invoice; change branch currency → POS uses it

---

## Summary

**Purchasing:** 13 pages (PO → GRN → Invoice → Payment flow)
**Reporting:** 9 pages (read-only dashboards: inventory, A/R, A/P, trends, forecast)
**Sales:** 9 pages (POS terminal, session close, returns, invoice view)
**Settings:** 6 pages (config hub: business, branches, payment methods, number series, preferences)

**Total P0-MONEY:** 8 pages (all GL-posting RPCs)
**Total P1-DATA:** 10 pages (creates/updates)
**Total P2-READ:** 15 pages (reports, detail views)
**Total P3-NAV:** 4 pages (hubs, navigation)

---

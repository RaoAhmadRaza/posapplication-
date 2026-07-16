# Suppliers Feature Test Catalog

**Catalogued:** ✓ | **Pages:** 3 | **Routes:** 4 | **Format:** Table summary

---

## Suppliers (3 pages)

| Page | Route | Elements | Guard | RPC | Test Case |
|------|-------|----------|-------|-----|-----------|
| SuppliersPage | /suppliers | Search field, status filter chips (All/Active/Inactive/Blacklisted), supplier card list (name, phone, payable amount, status badge), FAB "New Supplier" | PermissionGate(purchase:create) on FAB | suppliersProvider, payablesAgingProvider | List suppliers with payables aging balance shown per card; search suppliers by name; filter by status |
| SupplierFormPage (create) | /suppliers/create | Text fields: name, contact person, phone, email, address (2 lines), city, state, postal code, country; payment terms (days), currency, opening balance, bank name/account; status dropdown (active/inactive/blacklisted); tags, notes; Submit button | None (guarded at route/controller via module permissions) | createSupplierUseCaseProvider (validation: name required, terms ≥0, opening balance numeric, currency required) | Create supplier with all required fields; verify success pop and list refresh |
| SupplierFormPage (edit) | /suppliers/:supplierId/edit | Same as create; pre-populated from existing supplier | None | loadSupplierUseCaseProvider (load for seed), updateSupplierUseCaseProvider | Load existing supplier; edit name/payment terms; verify update persists |
| SupplierDetailPage | /suppliers/:supplierId | Header card (name, contact person, phone, email, payment terms label); ledger section (balance amount, transaction list with icons/reference/running balance); "Record Payment" button; edit/delete icon buttons in appbar | Edit: PermissionGate(purchase:update), Delete: PermissionGate(purchase:delete) | loadSupplierUseCaseProvider, supplierLedgerProvider (invoices, returns, payments), softDeleteSupplierUseCaseProvider | Display supplier detail with ledger entries (INVOICE/RETURN/PAYMENT kinds with running balance); confirm soft-delete supplier; verify removal from list |

---

## Summary

**Pages:** 3 (suppliers list, form create/edit, detail view)
**P0-MONEY:** Supplier payment ledger accuracy
**P1-DATA:** Supplier creation/edit, payment terms tracking
**P2-READ:** Supplier list, aging balances, ledger view
**P3-NAV:** Navigation to detail/form

---


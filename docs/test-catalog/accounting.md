# Accounting Feature Test Catalog

**Catalogued:** ✓ | **Pages:** 19 | **Routes:** 19 | **Format:** Table summary

---

## Accounting (19 pages)

| Page | Route | Elements | Guard | RPC | Test Case |
|------|-------|----------|-------|-----|-----------|
| AccountingHubPage | /accounting | HubRow tiles (Chart of Accounts, Journal, Vouchers, Expenses, Banks, Tax Rules, Reports, Fiscal Periods) | None | None | Navigation routing to all features; all tiles render and navigate correctly |
| ChartOfAccountsPage | /accounting/accounts | SearchField, ExpansionTile by type, AccountRow (code, name, balance) | None (read-only) | chartOfAccountsProvider | P0-MONEY: Load COA, display 5 account types hierarchically (asset, liability, equity, revenue, expense); search filter by code/name returns correct sub-hierarchy |
| ManualVoucherPage | /accounting/vouchers/create | TypeDropdown (payment/receipt/contra/journal), TextFields (description, reference), LineEditor (account picker, debit/credit fields), Totals validator, Post button | module:accounting, action:create | voucherControllerProvider.createVoucher | P0-MONEY: Post 3-line balanced voucher (debit=credit); verify GL posting to accounts; reject unbalanced voucher with error states |
| JournalEntriesPage | /accounting/journal | EntryCard (entry number, date, description, reversing badge), FAB (gated create), error/empty states | action:create on FAB | journalEntriesProvider | Load 10 entries; display reversing badge correctly; tap entry navigates to detail |
| JournalEntryDetailPage | /accounting/journal/:id | Header card (entry number, date, description), LinesCard (account code + name, debit/credit colored), Reverse button (modal reason) | module:accounting, action:approve | journalEntryDetailProvider, journalControllerProvider.reverseJournal | P0-MONEY: Load entry + 4 lines; display debit in green, credit in red; reverse entry with reason; verify reversing entry posted with amounts negated |
| BankAccountsPage | /accounting/banks | BankCard (name, balance, bank, reconcile button), FAB (gated create), error/empty states | action:create on FAB | bankAccountsProvider | Load bank accounts; display balance per account; reconcile button navigates to reconciliation page |
| BankAccountFormPage | /accounting/banks/create, /accounting/banks/:id/edit | TextFields (name, bank, account number, IBAN, SWIFT, currency, opening balance), AccountDropdown (asset accounts only), Active toggle, Create/Update button | action:create or action:update | bankAccountsController.create, bankAccountsController.edit | P0-MONEY: Create bank account linked to chart asset account; validate required fields; opening balance posted to GL; edit account; update GL link |
| BankReconciliationPage | /accounting/banks/:id/reconcile | DatePicker (statement date), TextFields (statement balance, reconciled balance), BankCard display, Create/Complete buttons, difference rows | module:accounting | bankReconciliationControllerProvider.createReconciliation, bankReconciliationControllerProvider.completeReconciliation | P0-MONEY: Create reconciliation; calculate differences; complete reconciliation; verify reconciliation entry posts to GL with difference as adjustment entry |
| TrialBalancePage | /accounting/reports/trial-balance | DateChip (as of), BranchDropdown, BalancedBadge (green if debit=credit), rows (code, name, debit right-aligned, credit right-aligned), totals row | action:export | trialBalanceProvider((asOf, branchId)) | P0-MONEY: Load TB as of date; verify balanced badge shows (total debit = total credit); filter by branch; TB remains balanced |
| BalanceSheetPage | /accounting/reports/balance-sheet | DateChip (as of), BranchDropdown, badge (balanced), rows (Assets, Liabilities, Equity, Retained Earnings), total Liabilities+Equity | None | balanceSheetProvider((asOf, branchId)) | P0-MONEY: Load BS; verify Assets = Liabilities + Equity + Retained Earnings (balanced); retained earnings calculated from P&L period postings |
| ProfitLossPage | /accounting/reports/profit-loss | DateChips (from, to), BranchDropdown, rows (Revenue, Expenses, COGS, Gross Profit, Operating Expenses, Net Profit) | None | profitLossProvider((from, to, branchId)) | P0-MONEY: Load P&L for month; net profit = revenue - expenses - COGS; filter by branch; sum matches branch revenue/expense account GL balances |
| AccountLedgerPage | /accounting/accounts/:id/ledger | OpeningBalance card, rows (date, description, debit/credit, running balance), empty state | None (read-only) | accountLedgerProvider(accountId) | Load ledger; display opening balance; running balance accumulates correctly per line; tap line shows source entry |
| CashBankBookPage | /accounting/reports/cash-bank-book | AccountDropdown (1000 cash, 1010 bank), DateChips (from, to), rows (date, ref, debit, credit, running balance) | None | cashBankBookProvider((accountCode, from, to)) | Load cash book; running balance starts at opening balance; accumulates per transaction; 1000 vs 1010 code switches account |
| ExpensesPage | /accounting/expenses | ExpenseCard (category, amount, date, method), FAB (gated create), error/empty states | action:create on FAB | expensesProvider, expenseCategoriesProvider | Load 5 expenses; display category name (lookup), amount, payment method; sort by date descending |
| ExpenseFormPage | /accounting/expenses/create | TextFields (amount, tax, reference, description), DatePicker (expense date), CategoryDropdown (linked to expense accounts), MethodDropdown (CASH/BANK_TRANSFER/CARD/MOBILE_WALLET/CHEQUE), BankAccountDropdown (hidden if CASH), Create button | None | expensesController.createExpense | P0-MONEY: Create cash expense; post debit to category account, credit to cash account (1000); tax amount posts to tax payable account; create bank transfer expense; GL posts to bank account selected |
| ExpenseCategoriesPage | /accounting/expense-categories | CategoryTile (name, account code + name), FAB (gated add), dialog (name + account picker) | action:create on FAB | expensesProvider.notifier.createCategory | Create category linked to expense account; list shows category + account; used in expense form dropdown |
| TaxRulesPage | /accounting/tax-rules | TaxCard (name, rate %, mode badge, default badge), FAB (gated create), error/empty states | action:create on FAB | taxRulesProvider | Load tax rules; display default indicator; show rate + mode (inclusive/exclusive); tap navigates to edit |
| TaxRuleFormPage | /accounting/tax-rules/create, /accounting/tax-rules/:id/edit | TextFields (name, code, rate, appliesTo, description), ModeDropdown (inclusive/exclusive), DatePickers (effective from, effective until), toggles (default, active), Create/Update button | action:create or action:update | taxRulesController.create, taxRulesController.edit | Create tax rule; rate >= 0 validation; code required; set effective date ranges; default toggles to single rule per tenant |
| FiscalPeriodsPage | /accounting/periods | PeriodCard (fiscal year-quarter-month, status closed/open), Close button (confirmation dialog), Reopen button | None | fiscalPeriodsProvider.notifier.close, fiscalPeriodsProvider.notifier.reopen | Close period; blocks posting to that period; GL entries locked; Reopen period; allows posting again |

---

## P0-MONEY Critical Paths

1. **GL Posting (Manual Voucher):** Post payment voucher: Debit Bank 1100 (500), Credit Payable 2100 (500) → Trial balance shows both accounts; debit/credit balanced
2. **Journal Entry Reversal:** Post journal entry with 3 lines → Reverse with reason → Reversing entry appears; amounts negated; both entries in trial balance
3. **Bank Reconciliation:** Create bank account (1010), post 2 payment vouchers → Reconcile → Reconciliation entry posts; bank account marked reconciled as of date
4. **Financial Reports Accuracy:** Post 5 diverse vouchers → Trial Balance: verify debit = credit; Balance Sheet: verify Assets = Liabilities + Equity; P&L: verify Net Profit = Revenue - Expenses
5. **Expense GL Resolution:** Create expense category linked to GL 6100; post cash + bank expenses → Verify GL postings per payment method

---

## Test Data Setup

**Chart of Accounts:** 1000 Cash, 1010 Bank, 1100 AR, 2100 AP, 3100 Common Stock, 6100 Expense, 7100 Revenue, 8100 Tax Payable

**Bank Account:** "Primary Bank", Account# "12345", Currency "PKR", GL 1010, Opening Balance 10000

**Expense Categories:** "Office Supplies" → GL 6100, "Travel" → GL 6100

**Tax Rule:** "GST", Rate 17%, Mode Exclusive, Default true

---


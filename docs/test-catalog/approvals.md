# Approvals Feature Test Catalog

**Catalogued:** ✓ | **Pages:** 5 | **Routes:** 4 (1 unreachable) | **Format:** Table summary

---

## Approvals (5 pages)

| Page | Route | Elements | Guard | RPC | Test Case |
|------|-------|----------|-------|-----|-----------|
| PendingApprovalsPage | /approvals | Approval list, type chips filter, refresh, empty state | PermissionGate(approvals:approve) on settings button | loadOpenApprovalsUseCase, pendingApprovalsProvider | Load & filter by type (PO, Stock Adj, etc.); refresh pending approvals list |
| ApprovalDetailPage | /approvals/:id | Request summary, approval ladder, history timeline, decision buttons (Approve/Reject/Cancel) | PermissionGate(approvals:approve) on Approve/Reject/Cancel | loadApprovalDetailUseCase, actOnApprovalUseCase, cancelApprovalUseCase | Approve request with optional comment; reject & require comment (validation error if empty) |
| ApprovalHistoryPage | /approvals/history | Search field, request cards (completed requests), empty state | None | loadApprovalHistoryUseCase | Search by entity type or workflow type; load completed requests (Approved, Rejected, Cancelled, Expired) |
| ApprovalWorkflowsPage | /approvals/workflows | Workflow list grouped by type, toggle active/inactive, add FAB, empty state | PermissionGate(approvals:update) on create/edit/toggle | loadWorkflowsUseCase, upsertWorkflowUseCase | Create new workflow (name, levels, threshold); toggle workflow active (soft-delete via upsert) |
| WorkflowFormPage | **UNREACHABLE** | Type dropdown (immutable on edit), name/description/threshold/TTL fields, levels editor (reorder, add, remove), Active switch, Save button | None | tenantRoleNamesProvider, upsertWorkflowUseCaseProvider | Create multi-level workflow (role selection, min approvers per level); validate required name & at least one level with role assigned |

---

## Critical Paths

**P0-MONEY:** Approval decision on financial transactions (PO, stock adjustment, payment authorization)
**P1-DATA:** Workflow creation/edit, approval state transitions
**P2-READ:** Approval history, workflow list
**P3-NAV:** Approval detail routing

---

## Notes

- **WorkflowFormPage:** Only accessed via `MaterialPageRoute()` from ApprovalWorkflowsPage—not in go_router tree. Create/edit workflows push this as an overlay.
- **Reachable Routes:** `/approvals`, `/approvals/:id`, `/approvals/history`, `/approvals/workflows` (4 routes)
- **Key Invariant:** All approval outcomes (APPROVED/REJECTED) require role assignment in ladder; TTL (time-to-live) gates approval expiration

---

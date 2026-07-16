# Migration, Notifications, Repair Features Test Catalog

**Catalogued:** ✓ | **Pages:** 12 | **Routes:** 12 | **Format:** Table summary

---

## Migration Import (1 page)

| Page | Route | Elements | Guard | Key RPC |
|---|---|---|---|---|
| MigrationImportPage | /inventory/import-migration | CSV picker step cards (vendor selection, upload, mapping, preview, confirm) | PermissionGate(inventory:create) | migrationImportProvider.pickAndParse(kind), run(kind) |

**Test:** Upload vendor CSV → map columns → preview 100 rows → execute bulk import → all rows inserted into DB.

---

## Notifications (6 pages)

| Page | Route | Elements | Guard | Key RPC |
|---|---|---|---|---|
| NotificationsPage | /notifications | List + filter bar (unread, by action type) + mark read + refresh | NONE | notificationsControllerProvider, markAllRead(), markRead(id), refresh() |
| NotificationSettingsPage | /notifications/settings | Admin links + channel toggles per event type (login, payment, stock, etc.) | PermissionGate(notifications:read/update/create) | notificationPreferencesProvider, upsert(p) |
| TemplatesAdminPage | /notifications/templates | SMS/Email template rows + edit modal | PermissionGate(notifications:create) | messageTemplatesProvider, upsert(updated) |
| BulkCommunicationPage | /notifications/bulk | Segment picker + channel selector (SMS/Email) + template dropdown + preview → enqueue | PermissionGate(notifications:create) | bulkCommunicationControllerProvider.preview(...), enqueue(...) |
| CommunicationLogsPage | /notifications/logs | Log entries list + channel/status filter + pagination | PermissionGate(notifications:read) | communicationLogProvider, refresh() |

**Critical Tests:** 
- NotificationsPage: mark unread → read state updates + unread count decrements
- BulkCommunicationPage: select segment + template → preview shows correct data → enqueue → logs appear

---

## Repair (5 pages)

| Page | Route | Elements | Guard | Key RPC |
|---|---|---|---|---|
| RepairKanbanPage | /repair | Kanban board by status (Intake/In-Progress/Ready/Delivered) or list view + FAB to create | PermissionGate(repair:create) | repairJobsProvider, setFilters(), changeStatus(), bulkChangeStatus() |
| RepairIntakePage | /repair/intake | Customer picker + device type dropdown + issue description → create job | NONE | repairJobsProvider.notifier.create({...}) |
| RepairDetailPage | /repair/:id | Header (job #, status) + diagnosis form + parts section + history timeline + actions (assign, close, warranty) | PermissionGate(repair:update) | repairJobDetailProvider(id), changeStatus(), assignTechnician(), setDiagnosis(), addPart(), removePart(), closeJob(), openWarrantyClaim(), closeWarrantyClaim() |
| RepairHistoryPage | /repair/history | Searchable list of delivered + cancelled jobs with status badge + detail link | NONE | closedRepairJobsProvider, refresh() |
| TechnicianWorkloadPage | /repair/workload | Workload card per technician (open jobs count, avg days in progress) | NONE | technicianWorkloadProvider |

**Critical Tests:**
- RepairDetailPage: change status → updateStatus RPC fires → status badge updates + history appends
- RepairDetailPage: assign technician → technicianWorkloadPage shows updated count
- RepairKanbanPage: drag card to different column → RPC fires → other views reflect change

---

## Summary

**Migration:** 1 page (data import pipeline)
**Notifications:** 6 pages (user notifications + admin config + bulk comms + logs)
**Repair:** 5 pages (CRUD repair jobs + kanban + workload)

**P0-MONEY:** Repair status changes (affects warranty, billing)
**P1-DATA:** Notification settings, bulk communication, repair job creation/update
**P2-READ:** Notification list, repair history, workload dashboard
**P3-NAV:** Kanban drag-drop navigation

---

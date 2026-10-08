# DataImports operational compatibility

## Evidence boundaries

Pre-industry C# at Git `5425869` calls the original write procedures directly. `base-procedure-evidence.json` preserves the previously read 13 October database definitions of the three base procedures plus the then-existing Get/monthly scoped variants. It is historical schema code, not fresh certification of the current deployment database. A fresh SELECT-only TDS 7.0 attempt timed out. Current data, original base Get, deployed audit rights and actual monthly records remain unverified.

| Operation | Initial candidate | Corrected execution | Preserved contract / deliberate security correction |
|---|---|---|---|
| Create / Update | ImportController inherited IndustryScopedReportController; Biz Demand canonical membership → ImportDatas_IndustryScope → base | AppController's original Add/Edit checks → independent operational enterprise check → base `p_Report_DataImports_ImportDatas` | 8 parameters: EnterpriseId, ForMonth, TypeReport, TypeReportName, DataReportWithIndexLevel, ReportFile, Reason, ImportBy. CreatedBy still supplies ImportBy. Period/deadline/lock/signature/business checks unchanged. |
| Delete | Canonical Demand → wrapper compares email DeleteBy to username → base | Original Delete permission + operational membership → base `p_Report_DataImports_Delete` | 4 parameters: EnterpriseId, OnMonth, Reason, DeleteBy. SavedBy/User.Email retains its existing audit meaning. Success remains return value == EnterpriseId; base failure remains false. No email-to-username rewrite. |
| CheckDataImport | Dashboard Demand + View/Add/Edit wrapper → base | Existing operational workflow + operational membership → base `p_Report_DataImports_CheckDataImport` | 3 parameters: OnMonth, EnterpriseId, DataReport TVP. Original result rows/validation errors retained. |
| Get | Reporting visibility substituted for operational admin/assignment filtering | New Get_Operational uses existing query fields, grouping, period, sort, offset/limit and recompile behavior against operational membership | Reporting Get_IndustryScope retained for reporting consumers. SQL verifies ForEmp == authenticated operation subject. |
| GetDataImport | Same reporting-scoped reader served editing/validation | GetDataImport_Operational for Import controller; scoped reporting helper retained | Original rows/type fields/month comparisons preserved. Server subject is appended internally, not exposed as a client bypass flag. |
| GetViaEnterpriseOnMonth | Reporting-scoped metadata could block Edit/Delete dialog | GetViaEnterpriseOnMonth_Operational for operation metadata | Same result/CanDelete/audit display grouping. Object permission checked on GET and POST before reading/writing. |
| GetForUserOnMonth | HasExplicitPermissions computed but unused; all generally visible enterprises could enter personal worklist | Both operational and reporting variants require explicit Cate_EnterprisePermissions; reporting variant also intersects canonical population | Month range, IsDeleted, CanDelete deadline, GROUP BY/created-date precision unchanged. No new sorting/paging added to a previously unpaged worklist. Weak name/email/tax-code ownership matching stays removed. |
| SearchSelect2 | General reporting population used for editing selector | Server-owned operational search for Import; existing canonical search retained as separate reporting SQL/XML contract | Existing type/approval/search filters and stable pagination retained. An operational assignment outside a manager's Dashboard industry is eligible; mere Dashboard visibility is insufficient for a nonadministrator write. |

## Independent operational relationship

`ReportDataImportScope` and `f_Report_DataImportEnterprises` deliberately do not invoke `f_Report_IndustryEnterprises` or inspect industry grants. The captured existing Get variant recognizes administrator roles 1/6, explicit assignments, and—only when assignments are absent—record CreatedBy. The corrected function uses the existing configured SystemAdministrator/IndustryAdministrator semantic keys instead of new hard-coded IDs, verified assignments, and **exact server-maintained Report_DataImports.CreatedBy = authenticated username**. The operational population also requires an existing Import View/Add/Edit/Delete permission through an active role/function. This prevents AllowAnyPermission picker helpers from disclosing operational data to accounts with only Dashboard rights; Add-only and Edit-only callers remain eligible for their original MVC action checks. No unverified enterprise email, display-name, tax-code or creator alias grants access. An explicit assignment list takes precedence over the creator fallback.

The new server-side HTTP/Biz membership check closes a pre-existing gap: the pre-industry controller showed an assignment selector but did not consistently authorize direct enterprise IDs on POST. It does not equate a dropdown or Add/Edit/Delete function permission with object authorization. Administrator-wide operational scope follows the captured Get rule, not Dashboard scope. Confirm that this rule and audit-creator provenance match the deployment DB's base Get/ownership rules; do not silently expand it to other management roles. Personal worklists remain explicit assignments even for these administrators.

Current reporting defaults and mixed-role precedence are unchanged: role 1 all, roles 2–4/6 industry, role 5 enterprise; management industry grants override assignment row restrictions for reporting, zero grants fall back to assignments. Operational scope is a distinct server contract. Consequently this task supersedes the earlier change that made Import's editing picker use Dashboard visibility. MyEnterprise and Report/Report general viewing pickers retain reporting scope.

## Before / after call graphs

Before: `Import action → IndustryScopedReportController.Begin/Demand → ReportDataImportCache → Biz canonical Demand → *_IndustryScope wrapper → base write`.

After: `Import action → existing AppController/ActionType permission filters → ReportDataImportScope.Begin/Demand → cache bypass for active operational context → Biz operational Demand → unchanged base write`.

Reporting remains: `Report/ReportController or Dashboard → ReportIndustryScope → scoped read`. Chatbot import tools use fresh assigned object membership; reporting tools use scoped SQL and capability/identity checks. No client-controlled ignoreScope/isAdmin flag was added.

## Base transaction, audit and failure compatibility

The original ImportDatas/Delete bodies are not emitted/altered by this release. Their existing transactions, TRY/CATCH rollback, audit-log inserts, SQL error logging and return values remain untouched. CheckDataImport retains its existing TVP and result contract. There is no new outer write transaction and no actor equality comparison. Base exception propagation is unchanged; unauthorized HTTP/Biz object requests now fail before invoking SQL. Actual commit/rollback/audit behavior requires isolated staging execution and a target log dependency/INSERT-rights review.

Removed future wrappers: ImportDatas_IndustryScope, Delete_IndustryScope, CheckDataImport_IndustryScope. No DROP is issued; installed copies remain unused candidates for later DBA review.

Operational membership is a request snapshot and is not atomic with the original base write transaction. Verify concurrency/revocation expectations on staging; the release does not claim instant mid-request revocation or replace existing write transaction boundaries.

## Creator-only ownership is record-level

The captured original Get used rdi.CreatedBy only for matching records. A creator relationship therefore does not authorize all enterprise rows. Operational read materialization now carries CanManageAllRecords; administrators/explicit assignees can manage the enterprise population, while a creator-only principal sees only records whose CreatedBy equals the authenticated username.

A separate **read-only** CheckOwnership procedure checks the exact base write set before original Import/Delete: same calendar month, Import type filter (NULL/0 means all, matching the base procedure), all affected rows owned by that user, and Import's month-wide Report_ReportFiles header owned by that user if present. Existing deleted rows are included because the base write also touches them. Creator-only access cannot create an unrelated new month or overwrite other creators' records/files. Delete checks all month rows. Assigned/administrator workflows retain their original enterprise-level eligibility. CheckDataImport remains the original TVP validation path with operational object membership, without a new write-set restriction. No new write wrapper/transaction or audit rewrite was added. Native ownership/read fixtures are prepared; current target creator/audit provenance still needs staging verification.

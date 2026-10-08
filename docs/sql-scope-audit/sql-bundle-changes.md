# SQL bundle correction and coordinated rollback

## Inventory and source changes

Initial 49 procedures/7 functions → corrected **53 procedures/8 functions**. No physical DROP. Seven read-only operational/ownership procedures and one operational authorization function replace three unnecessary write/validation wrappers. Eight existing procedure bodies change (six Dashboard failure-resolution guards, monthly assignment filtering and one whitespace-only Get normalization); one existing function changes (Chatbot role-list validation). Thirty-eight procedure bodies and six function bodies are identical to the initial inventory.

- Changed: `f_Chatbot_AuthorizedEnterprises`.
- Changed: `p_Report_Dashboard_FilterOptions_IndustryScope`.
- Changed: `p_Report_Dashboard_IndustrialSnapshot_IndustryScope`.
- Changed: `p_Report_Dashboard_OverviewSummary_IndustryScope`.
- Changed: `p_Report_Dashboard_ProgressDetails_IndustryScope`.
- Changed: `p_Report_Dashboard_StatisticEnterprise_IndustryScope`.
- Changed: `p_Report_Dashboard_StatisticTypeBusiness_IndustryScope`.
- Changed: `p_Report_DataImports_GetForUserOnMonth_IndustryScope`.

- Added: `f_Report_DataImportEnterprises`.
- Added: `p_Report_DataImports_Enterprises_SearchSelect2`.
- Added: `p_Report_DataImports_GetDataImport_Operational`.
- Added: `p_Report_DataImports_GetForUserOnMonth_Operational`.
- Added: `p_Report_DataImports_GetViaEnterpriseOnMonth_Operational`.
- Added: `p_Report_DataImports_Get_Operational`.
- Added: `p_Report_DataImports_OperationalScope`.

- Removed from future release only: `p_Report_DataImports_CheckDataImport_IndustryScope`.
- Removed from future release only: `p_Report_DataImports_Delete_IndustryScope`.
- Removed from future release only: `p_Report_DataImports_ImportDatas_IndustryScope`.

The generated object manifest names all 61 definitions. Default staging artifacts remain Deploy_SCT_All.sql, Deploy_SCT_IndustryChatbot.sql, Deploy_SCT_ReportPerformanceIndexes.sql, Preflight_SCT_IndustryChatbot.sql and Verify_SCT_IndustryChatbot.sql. Existing base DataImports write/read procedures, the five registered base usp_Report plugin procedures and dbo.fnSplit remain external prerequisites. Preflight now explicitly requires the three base write procedures and surfaces their current cross-database dependencies for audit-log review. It does not rewrite base audit references, grant rights or migrate roles.

Both SysMessages seeds insert only missing keys with their existing lock/transaction protection. Existing custom text is preserved. Verification requires each expected label to exist once; it no longer requires equality to default text. There are still 204 seed keys and six index coverage requirements.

## Exact application/source changes

| File | Purpose |
|---|---|
| Biz/Report/ReportDataImportScope.cs; Biz csproj | Independent request-local operational membership and server routing, compiled into existing Biz assembly |
| Biz/Report/ReportDataImportBiz.cs | Original write/validation keys, parameter counts/audit/return values; separate operational read selection; assigned monthly readers |
| Caches/Report/ReportDataImportCache.cs | Bypass cross-request caches in active operational context |
| ReportModule/Areas/Report/Controllers/ImportController.cs | Original AppController pipeline; operational object guard, editing selector and operational search instead of Dashboard scope |
| Biz/Report/ReportRoleMapping.cs; ReportDeployment.Common.ps1 | Align strict key/boolean/duplicate/required-semantic validation without changing any configured role values |
| Biz/Report/ReportBiz.cs | Missing procedure result raises 503; genuine empty DataTables remain valid; no unscoped fallback |
| Both Report_StoredProcedures.xml copies | Remove three wrapper aliases; add seven operational read/ownership mappings |
| 03_ScopedReportProcedures.sql | Scope-resolution errors and verified-assignment monthly filter |
| 05_ScopedWrites.sql | Removed source definitions; no automatic drop of installed objects |
| 06_DataImportOperations.sql | New separate operational function/read procedures |
| Chatbot/f_Chatbot_AuthorizedEnterprises.sql | Role-list consistency validated before row population |
| Two seed scripts; both deployment builders/checks | Safe label preservation, base prerequisites/audit dependency output, regenerated inventory/bundle/verifier |
| tools/sql_scope_audit and tests/sql_scope_audit | Inventory, SELECT-only evidence, executable offline contracts/catalog checks, native isolated fixtures and operator HTTP cases |

Existing Configs/AppSettings.config RoleIds/scope values, user-modified Web.config and separate production optimization artifacts were not changed by this task. Prior deleted documents/scripts were not restored.

## Portability and execution order

Default bundle is for baocao.sct.cenit.vn(.cate), while current operator Web.config selects baocaosct.khanhhoa.gov.vn(.cate). Regenerate to the intended Category/Report pair or stage an environment-matching Web.config; do not mix them. Database identifiers with spaces/dots are tested; bracket/semicolon injection is rejected. AppSettings credentials are not copied into SQL artifacts; only nonsecret role mapping values appear in the manifest. Identical inputs produce identical bytes on repeated generation.

Order: read-only preflight → indexes outside schema transaction → Category role table/map and scope → report scope/read definitions → operational function/read definitions → Chatbot functions/procedures → insert-only labels → schema COMMIT → verifier. Nested read calls are resolved after their definitions are installed. SQL verification after COMMIT cannot roll back a committed release. Under SQLCMD -b, a disconnect rolls back an open transaction; SSMS may retain its session, so inspect @@TRANCOUNT/XACT_STATE on that same connection.

## Coordinated rollback

Before any staging/production release, capture full application/config binaries/content; exact current SQL definitions, grants and base TVP/signature metadata; role map rows; label/missing-label and index inventories; role/assignment/permission/grant hashes; current base audit database references and rights; operator-approved DB recovery backups. Preserve post-cutover business writes/audit records.

- Before schema commit: keep traffic stopped, inspect the deployment connection and roll back its open transaction. Successfully built indexes may persist because they run outside that transaction; compare inventory and handle only release-created indexes under DBA approval.
- After commit/verifier failure: changes are installed. Keep traffic stopped; apply a reviewed compensating schema/map/config rollback from captured definitions, or complete the matching accepted application deployment. Do not rerun blindly. Preserve existing labels; inserted missing labels can remain pending cleanup rather than deleting unknown custom/business records.
- After application failures: restore the complete prior application/configuration and matching SQL definitions together. New operational aliases and changed scope functions make binary-only rollback unsafe. Do not overwrite later business/audit writes with a blind database restore.
- Removed-from-bundle wrappers can remain installed and unreferenced. Their names above are DBA cleanup candidates only; this release supplies no DROP script. Similarly newly added objects may remain unused after rollback rather than being destroyed automatically.
- Recheck target namespaces, mapping consistency, permissions, representative reads/writes, audit placement and transaction state before reopening traffic. If the prior matched version has an unsafe scope, keep affected routes closed until an accepted safe package is available.

- Added read-only `p_Report_DataImports_CheckOwnership`: validates creator-only write sets before calling unchanged base writes; no write delegation or transaction wrapper.
- `p_Report_DataImports_Get_IndustryScope` also has whitespace-only normalization; no calculation or authorization change in that retained reporting reader.

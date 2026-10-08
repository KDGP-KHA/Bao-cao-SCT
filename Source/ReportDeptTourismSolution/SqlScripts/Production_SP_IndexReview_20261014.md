# Production stored-procedure index review — 14 October 2026

**Indexes alone help many access paths, but cannot fully optimize every procedure.**

Reviewed all **293 installed procedures** (230 category, 63 report) and **9 functions/views** in the two databases configured in Web.config. Definitions, columns, existing indexes, table cardinalities, dependency metadata, dynamic SQL fragments and wrapper calls were inspected through explicit, negotiated **TDS 7.0**. SQL Server is 2012 Enterprise, compatibility 110. The companion CSV contains one review row for every procedure, including inactive/backup/obsolete definitions; installation does not prove that a procedure is used by live traffic.

This is a static review with selected estimated SELECT plans. No stored procedure or business SELECT was executed, no benchmark/load test was run, and no production index/data/procedure was modified by this review. Server-level runtime DMVs remain inaccessible: total CPU, actual reads, request duration, blocking history and index usage frequency could not be measured. Cross-database audit/log targets and their own modules are outside the two configured database snapshots; their runtime availability, triggers and write costs are not certified.

## What is now verified

All eight indexes from the initial script are present in refreshed production metadata. Selected estimated SELECT plans now choose these access paths:

| SELECT shape | Current estimated access | Meaning |
|---|---|---|
| `ForUser` lookup with a `varchar` comparison | Seek on `IX_SCTProd_Assignments_UserEnterprise` | Exact assignment access is index eligible. |
| Enterprise lookup / join by `EnterpriseId` | Seek on `IX_SCTProd_Enterprises_Id` | Removes the previous heap scan for this lookup. |
| Enterprise-side normalized permission check | Seek on `IX_SCTProd_Assignments_EnterpriseUser`, then residual CASE filter | Enterprise narrowing works; username normalization remains. |
| User email lookup with a `varchar` comparison | Seek on `IX_SCTProd_Users_Email` | Exact email access is index eligible. |
| `ForMonth` date-range report aggregation | Seek on `IX_SCTProd_Imports_Period`, with type/deletion residual filters and sort | Date range improves; aggregation/sort work remains. |

These are plan observations for representative SELECTs, not measured endpoint speedups or proof that every SP/parameter combination chooses a seek.

## Two additional ordinary-index candidates

The combined `Optimize_SCT_Production_20261014.sql` now contains **10 default nonunique, unfiltered indexes**: the existing eight plus these two candidates. Running it again reuses existing coverage and only creates missing indexes. `@Apply=0` previews; `@Apply=1` applies. The optional eleventh computed-column index remains disabled.

| Candidate | Keys / coverage | Procedures / evidence | Limit |
|---|---|---|---|
| `IX_SCTProd_Docs_Object` | `(ObjectId, TypeObject, IsDeleted) INCLUDE (FileName, FileExt)`; clustered FileId is implicit | `p_Cate_Enterprises_Get`, `Get_Remove`, `GetByID` correlate attachment XML by ObjectId. The representative XML SELECT currently has a nested-loop document clustered scan. | Only 85 documents currently. Optimizer may still choose a scan; real endpoint benefit is unmeasured. Other certificate routines already seek FileId and do not all need this index. |
| `IX_SCTProd_Imports_Code` | `(Code, IsDeleted, ForMonth)` with EnterpriseId, TypeReport, Unit, Targets and four numeric metrics included | Legacy `p_Report_GenerateSaleOfTourism_*`, `p_Report_ThongKe_Tong*`, income/visitor reporting use code predicates and self-joins. A representative Code/Unit/Targets aggregation currently scans the heap. | Date functions remain residual. Code selectivity matters; broad code patterns may still scan. At 1,048 import rows, a scan can legitimately be cheap. Extra coverage increases index storage and import write maintenance. |

Both are ordinary indexes on existing columns. No table/column definitions, constraints, uniqueness, permissions or stored-procedure bodies change. Neither new index has been built, so its resulting production plan/latency has not been verified. No index hint or forced plan is added.

## Important limits: more ordinary indexes will not solve these

### Parameter conversions — confirmed in estimated plans

`p_Cate_EnterprisePermissions_Get` declares `@UserName nvarchar(30)` but compares it to `Cate_EnterprisePermissions.ForUser varchar(500)`. The SELECT shape with the actual parameter type still scans the **94,394-row** heap and has a residual `CONVERT_IMPLICIT(nvarchar(500), p.ForUser, 0) = @UserName`, despite the existing ForUser index. The earlier varchar-only lookup seek does **not** establish that this actual procedure is optimized.

`p_Sys_User_Login`, `LoginViaEmail`, `Token` and `SaveLogin` also use Unicode identity parameters against varchar UserName/Email. A representative login identity SELECT now scans the covering email index with implicit conversions rather than seeking. It covers the identity branch, not the complete password/login/logging procedure. Adding another ordinary UserName/Email index does not remove the conversion. A focused parameter/predicate correction would be needed to make the comparison seek eligible; it is deliberately **not included** under the no-SP-change requirement. Any future correction must preserve Unicode, lengths and caller behavior; blindly narrowing/casting a parameter could change matches.

This follows [SQL Server type precedence](https://learn.microsoft.com/en-us/sql/t-sql/data-types/data-type-precedence-transact-sql): lower-precedence varchar is converted to nvarchar. The scan behavior above is observed in this database's estimated plans, not assumed for every collation.

Other statically detected candidates are listed below; their full plans were not individually verified:

- `p_Cate_EnterprisePermissions_Get` (BaseApp).
- `p_Sys_Configs_Save` (BaseApp).
- `p_Sys_ModuleContentPanel_DeleteModule` (BaseApp).
- `p_Sys_ModuleContentPanel_Save` (BaseApp).
- `p_Sys_ModuleContentPanel_SaveList` (BaseApp).
- `p_Sys_User_Login` (BaseApp).
- `p_Sys_User_LoginViaEmail` (BaseApp).
- `p_Sys_User_SaveLogin` (BaseApp).
- `p_Sys_User_Token` (BaseApp).

### Date expressions

`p_Report_DataImports_Get`, `GetForUserOnMonth`, `GetDataImport`, `GetViaEnterpriseOnMonth`, `ImportDatas`, `Delete`, `CheckDataImport`, legacy dashboard/statistics and tourism reports repeatedly use `DATEDIFF(month, ..., ForMonth)`, `MONTH(ForMonth)`, `YEAR(ForMonth)` or formatted month strings. An EnterpriseId or Code leading key can narrow input without changing SPs. An ordinary ForMonth index does not generally turn these expressions into direct month-range seeks. Report file saves already have an EnterpriseId/ForMonth clustered primary key; duplicate indexes are unnecessary for that access path.

### Integer month

`p_Report_Manufacturing`, `p_Report_Trading`, `usp_Report_KTXH` and their wrappers use the existing nonpersisted computed `ForMonthInt`. The representative aggregate currently scans an index and performs heap RID lookups; the optional `IX_SCTProd_Imports_TypeMonthInt` can supply a direct TypeReport/month key and cover metrics without altering the SP or adding a column. It remains opt-in because **all writers** must use the required SET options, not just this deployment session. Saved module options were checked, but every import/admin/job connection was not verified. See [computed-column index requirements](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/indexes-on-computed-columns).

### CSV, substring search and sorting

IndustryIds/TypeBusiness CSV splitting, `LIKE '%search%'`, `CHARINDEX(@Search, column)`, `LEFT(Code, LEN(@CodePrefix))`, CASE username normalization, dynamic CASE sorting, repeated CTE/count/paging work and correlated XML remain. Existing indexes can reduce rows or cover columns; they do not automatically eliminate that work. `p_Cate_Enterprises_Get`, `SearchSelect2`, user lists and most chatbot filtering demonstrate these patterns. Existing business-product and industry search/industry indexes should be retained rather than duplicated. See [Microsoft's index design guidance](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-index-design-guide).

## Existing coverage and additions deferred

- UserId/RoleId membership, BusinessEnterprise EnterpriseId, business-product IDs and enterprise/product associations, ward/province IDs and FileId have existing leading primary/search keys. The new role/function index supports permission lookups. No further general indexes are justified solely by their presence in a JOIN.
- Ward-by-ProvinceId/WardCode and ConfigKey lookups have possible index candidates, but 3,321 wards and 18 configuration rows do not establish a production bottleneck. The ward-name normalization/filtering expressions would remain. No extra indexes were added for these paths.
- Accommodation, certificate, tourist-service, room/type-service tables currently contain zero to 41 rows each; EnterpriseId keys could help after meaningful growth, but indiscriminate indexing now is not justified by measured traffic.
- ReportTargetConfig (46 rows), ReportDynamicGroupRule (4), Report_ExtendInfos (0), registration notifications (17), menus/functions/roles and other small configuration tables do not warrant blanket index additions.
- Local user/procedure/active logs are append targets in the reviewed SPs. No read-path workload was established for new log indexes; adding indexes would add logging-write maintenance. Backup/staging/import-support tables are not treated as live application bottlenecks.
- Wrapper procedures inherit `Manufacturing`, `Trading` and `KTXH` limitations. Table-variable/report-generation routines can still repeat callee work; base-table indexes do not rewrite those algorithms.

## Missing/obsolete local references — not index problems

These object names are absent from the visible schema in the owning database. The procedures/branches that touch them require investigation if active; adding an index cannot create or correct a missing reference. Some installed procedures are legacy or may never be called. No compatibility objects, renames or schema fixes were introduced.

| Database | Procedure | Missing local reference |
|---|---|---|
| BaseApp | `p_Cate_BusinessEnterpriseProduct_Get` | `dbo.BusinessIndustry`, `dbo.BusinessProduct` |
| BaseApp | `p_Cate_BusinessEnterpriseProduct_GetByID` | `dbo.BusinessIndustry`, `dbo.BusinessProduct` |
| BaseApp | `p_Cate_BusinessEnterpriseProduct_Save` | `dbo.BusinessProduct` |
| BaseApp | `p_Cate_BusinessProductImpExp_Delete` | `dbo.Cate_BusinessProductImpExp` |
| BaseApp | `p_Cate_BusinessProductImpExp_Get` | `dbo.Cate_BusinessProductImpExp` |
| BaseApp | `p_Cate_BusinessProductImpExp_GetByID` | `dbo.Cate_BusinessProductImpExp` |
| BaseApp | `p_Cate_BusinessProductImpExp_Save` | `dbo.Cate_BusinessProductImpExp` |
| BaseApp | `p_Cate_Ward_GetByStreetId` | `Cate_Districts (dynamic SQL)` |
| BaseApp | `p_Report_IndustryPermissions_Save` | `dbo.Report_UserBusinessIndustryPermissions` |
| ReportTourismDB | `p_Sys_User_ChangeRequiredPassword` | `Sys_UserLogs`, `Sys_UserPasswordStatus`, `Sys_Users` |
| ReportTourismDB | `p_Sys_User_GetRequireChangePassword` | `Sys_UserPasswordStatus`, `Sys_Users` |
| ReportTourismDB | `p_Sys_User_SetRequireChangePassword` | `Sys_UserPasswordStatus`, `Sys_Users` |

`p_Cate_Ward_GetByStreetId` also constructs a dynamic query using obsolete district objects/columns. Dynamic SQL dependencies are not fully represented by sys.sql_expression_dependencies; its fragments were reviewed separately, and the CSV marks that issue. External log database references, including `BaoCaoSoDuLich.Log`, remain unverified rather than being declared missing from local metadata.

## Validation and use

- All 302 module definitions parsed with SQL Server 2012 ScriptDom; one review row exists for each of the 293 procedures. Static analysis and selected plans do not certify full-procedure behavior.
- The combined index script and every generated CREATE INDEX statement passed SQL Server 2012 syntax parsing and column/key-width checks against the refreshed schema.
- Read-only production preview with explicit negotiated TDS 7.0 passed: the eight original indexes are reused, two additions are planned; optional mode plans one additional computed-month index. No CREATE INDEX was executed by this review.
- After user deployment, verify real slow endpoints/import-save paths with representative accounts, filters, report types and sparse/dense months. Compare actual reads/time/CPU and import-write latency before deciding whether to retain the two new indexes. That runtime validation remains outstanding.
- Run the whole combined SQL file during low traffic using an account with visibility and ALTER rights across both databases. Online builds still need brief locks; the script limits lock waiting and returns rollback commands only for indexes it created.

The no-SP/no-column-change approach is a useful first step. It is **not sufficient for the confirmed type-conversion scans, unresolved object references, or all legacy date/search filters**.

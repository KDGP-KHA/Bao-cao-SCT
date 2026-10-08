# Verification commands and evidence — 14 October 2026

Statuses below separate executed offline checks from SQL/IIS acceptance. PowerShell 7 portable runtime and ScriptDom were already available in /tmp. No dependency/lockfile/version changes were made. The portable source-linked tests compile actual C# files against explicit test stubs; they **do not establish .NET Framework/IIS compatibility**. Native SQL fixtures were generated and parsed, not executed.

## Executed offline checks

| Check | Exact command | Exit | Expected / observed | Evidence |
|---|---|---:|---|---|
| Initial regression guards (red) | `PYTHONPYCACHEPREFIX=/tmp/report-audit-pycache python3 -m unittest discover -s tests/sql_scope_audit -v` | 1 | Six of eight guards fail on initial wrappers/monthly/filter/label/controller behavior, then pass after correction | red-stage.json; initial-inventory.json |
| Complete verification | `PYTHONPYCACHEPREFIX=/tmp/report-audit-pycache python3 -m tools.sql_scope_audit.verify --pwsh /tmp/report-powershell/pwsh --scriptdom /tmp/report-scriptdom/lib/netstandard2.0/Microsoft.SqlServer.TransactSql.ScriptDom.dll` | 0 | Repeated generation identical; alternate namespace generated; invalid identifier rejected; all child commands successful | evidence/verification-results.json |
| Source/config/mapping guards | `python3 -m unittest discover -s tests/sql_scope_audit -v` | 0 | Eight tests pass: removed wrappers, operational controller selection, explicit monthly assignments, scope failure errors, safe labels/verifier, XML dependencies, unchanged role defaults and no destructive bundle SQL | evidence/source-regressions.txt |
| C# call/audit/return/object checks | `/tmp/report-powershell/pwsh -NoLogo -NoProfile -File tests/sql_scope_audit/run-contracts.ps1` | 0 | Actual Biz/role/scope source executes base calls with 8/4/3 params, unchanged creator/email audit values, original success/failure returns, rejected foreign objects before SQL, separate read route and five invalid-config rejections; missing report null result returns 503 | evidence/csharp-contracts.txt |
| Chatbot argument tampering | `/tmp/report-powershell/pwsh -NoLogo -NoProfile -File tests/sql_scope_audit/run-catalog.ps1` | 0 | Actual catalog rejects allowProvince/userId/roleIds/ignoreScope/procedure/sql injection fields, accepts valid empty search | evidence/chatbot-tampering.txt |
| SQL Server 2012 parsing | `/tmp/report-powershell/pwsh -NoLogo -NoProfile -File tests/sql_scope_audit/validate-sql.ps1 -ScriptDomPath /tmp/report-scriptdom/lib/netstandard2.0/Microsoft.SqlServer.TransactSql.ScriptDom.dll` | 0 | 23 release/fixture files and 194 EXEC-embedded definitions parse using TSql110Parser | evidence/sql-2012-parse.txt |
| Fixture generation | `python3 -m tools.sql_scope_audit.build_fixtures` | 0 | Actual source bodies substituted into isolated fixture schema; all data/DDL wrapped in rollback and database-name/empty-schema guards | tests/sql_scope_audit/scope-fixtures.sql; evidence/fixtures-generate.txt |
| Inventory coverage | `python3 tools/sql_scope_audit/inventory.py` | 0 | Exactly 53 procedures/8 functions; source definition names equal bundle definition names | inventory.json; procedure-inventory.md |
| Determinism / portability | Two default builder runs, alternate `Audit Category.v2`/`Audit Report.v2`, malicious bracket/semicolon identifier | 0; malicious command expected nonzero | Byte-identical default outputs, only complete target identifiers, no AppSettings credentials copied, unsafe database name rejected | evidence/determinism.json; alternate-names.txt; identifier-rejection.json |
| Framework build attempt | `dotnet msbuild Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/CenIT.ReportTourism.Biz.csproj /t:Build /p:Configuration=Release` | 1 | BLOCKED: MSB3644, .NET Framework v4.5.2 reference assemblies absent on macOS | evidence/build.json |
| Current-DB SELECT-only comparison | `PYTHONPATH=/tmp/report-tds:. /tmp/report-powershell/pwsh -NoLogo -NoProfile -File /tmp/report-risk-connect.ps1 -AuditScript tools/sql_scope_audit/live_readonly.py -OutputDirectory docs/sql-scope-audit/evidence` | 1 | BLOCKED: TDS 7.0 connection timeout. No actual monthly gained/lost numbers, current signature or unchanged-role hashes claimed | evidence/live-attempt.json |

The C# contracts require an **isolated portable PowerShell runtime**, because the actual role loader resolves Configs/AppSettings.config relative to its host. The runner refuses to overwrite an existing runtime config, writes only the six nonsecret role keys, and removes that temporary config in finally. Catalog compilation suppresses only reference identity warning CS1701 for the bundled Newtonsoft assembly/runtime version; no TLS/security checks are disabled. Use Windows MSBuild for actual application certification.

## R01–R08 result matrix

| Requirement | Offline evidence | Native/runtime status | Remaining risk |
|---|---|---|---|
| R01 | Original Git/base definitions, source guards, actual C# call/audit/return/denial/ownership tests | IMPLEMENTED_NOT_STAGING_TESTED | Base SQL transactions/audit and original operational eligibility confirmation |
| R02 | Assignment predicate/source contract; native worklist assertions prepared | IMPLEMENTED_NOT_STAGING_TESTED; actual record comparison BLOCKED | Lost legacy identity-only access and actual month/status outputs |
| R03 | Explicit fail-closed guard; SQL syntax; exact empty/industry/native fixtures prepared | IMPLEMENTED_NOT_STAGING_TESTED | SQL binding and all option-kind outputs |
| R04 | Caller matrix; distinct server routes; actual C# routing; SQL search fixture | IMPLEMENTED_NOT_STAGING_TESTED; plugin SQL BLOCKED | HTTP edit/dropdown behavior, missing plugin SQL |
| R05 | Actual catalog injection tests; server SQL constants/permission guards; native AllowProvince fixtures | IMPLEMENTED_NOT_STAGING_TESTED | Token/CSRF/session integration and trusted DB-principal grants |
| R06 | Existing denominator/query traced; native expected missing-report fixture | NEEDS_BUSINESS_CONFIRMATION | Any report type versus required type/approved population policy |
| R07 | Unchanged default roles; actual invalid config checks; native exact-ID fixtures | IMPLEMENTED_NOT_STAGING_TESTED | Native role cases; mixed-role Web/Chatbot action gate confirmation |
| R08 | Nested dependencies and unchanged calculations; one native report-versus-raw aggregate fixture | BLOCKED | Five missing plugin definitions; real totals/export/period/performance comparison |

## Prepared native SQL tests (not executed)

```sh
python3 -m tools.sql_scope_audit.build_fixtures
sqlcmd -S '<isolated-test-server>' -d 'ScopeAuditFixtureRelease' -E -b -f 65001 -i tests/sql_scope_audit/scope-fixtures.sql
```

An operator must provide an **empty disposable database** with the exact ScopeAuditFixture prefix. This script does not create a database or connect automatically. It creates actual source functions/read procedures and synthetic fixtures inside one transaction, asserts exact expected enterprise IDs, operational assignment outside Dashboard industry, denied unrelated/identity-only access, assigned monthly worklist de-duplication, invalid/unknown account handling, role-list manipulation, stable approval-aware pagination, missing-report denominator and a concrete aggregate of 45, then rolls back all fixture changes. Those expected values are specifications, not results from an executed SQL Server test. The fixture-only fnSplit helper is not certification of the deployment's existing fnSplit implementation/collation/performance.

Write transaction/audit tests require an isolated **restored application database and IIS site**, not this minimal schema. The three base writes are intentionally not recreated from historical snapshots. Use valid operator-owned fixture forms and the HTTP runner below; compare expected base audit/return/error results and inspect rollback state in SQL.

```sh
python3 tools/sql_scope_audit/staging_http.py --origin https://isolated-staging.example --cases /private/tmp/sct-cases.json --output /private/tmp/sct-http-results.json --confirm-isolated-staging
```

Copy staging-cases.example.json privately, supply actual disposable fixture form files, CSRF token, cookie environment variables and observed baseline HTTP/JSON contracts. The example is not a ready authenticated request. The runner validates all prerequisites before sending requests, uses HTTPS certificate checks, does not follow redirects, and stores only status/pass/error type—not cookies, form bodies or response contents. Add operator cases for permission-denied accounts, monthly views, exports, Dashboard options, mixed-role/industry accounts and Chatbot capabilities.

The retained operator entry point for a fresh read-only comparison is:

```powershell
./tools/sql_scope_audit/Invoke-ReadOnlyAudit.ps1 -WebConfigPath '<reviewed-site>/Web.config' -OutputDirectory '<private-evidence-folder>'
```

Python with python-tds must already be available. Credentials travel on child stdin, not argv or evidence. This reads the explicitly selected configuration and executes SELECT only; it does not install the proposed functions.

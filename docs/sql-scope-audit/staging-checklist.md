# Staging, build and release checklist

**Current decision: GO for offline review; NO-GO for application staging deployment or production.** Running the rollback-only native fixture suite on a disposable empty SQL Server test database is the next safe validation step, not application deployment.

## Minimum before application staging

- [ ] Obtain the original SQL bodies/signatures/result schemas for the five registered usp_Report plugin procedures. Implement scoped equivalents and mappings from their actual calculations; do not invent them or fall back to unscoped reports. Recompute inventory and regenerate/test after adding them.
- [ ] Confirm the deployment DB's original operational Get policy: original administrator roles 1/6, assignment precedence, and exact server-maintained report creator fallback. Accept the deliberate denial of weak email/display-name/tax-code-only ownership. Verify all legitimately assigned nonadmins can edit outside unrelated Dashboard industries and cannot edit unassigned merely visible enterprises.
- [ ] Resolve mixed-role Web/Chatbot Dashboard/registry action gating and the missing-report any-type/approval denominator. Preserve current verified semantics until an explicit business decision.
- [ ] Run the prepared native SQL fixtures and the current-DB SELECT-only monthly comparison; record actual representative accounts, actual month/status gained/lost entries and hashes of unchanged role/assignment/permission/grant records. Use a real one-assignment enterprise, not nmdgio7a.dn.
- [ ] Pass a Windows Release build and module/Razor/package checks. .NET source-linked tests do not establish Framework compatibility.
- [ ] Align current Web.config database names and generated SQL target. Current operator Web.config selects production-style baocaosct.khanhhoa.gov.vn(.cate); default SCT bundle selects staging baocao.sct.cenit.vn(.cate). Preserve each environment's secrets.
- [ ] Review preflight base-write prerequisites, existing TVP shapes/signatures, target audit database references and runtime INSERT/EXECUTE rights. Confirm the shared application SQL principal is not exposed to end users; the database cannot infer human identity from caller-supplied UserId under that trusted login.
- [ ] Capture matched application/SQL/config rollback snapshots and backups; rehearse pre-commit, post-commit/verifier-failure and application-failure recovery on a disposable restored copy.

## Exact Windows build/package commands

Use Developer PowerShell with existing package versions and required Framework/Web Application targeting tools. Run from repository root; no package upgrade or credential edits.

```powershell
$root = (Resolve-Path './Source/ReportDeptTourismSolution').Path
$projects = @('CenIT.ReportTourism.Biz','CenIT.ReportTourism.Caches',
 'CenIT.ReportTourism.Modules.SysModule','CenIT.ReportTourism.Modules.ReportModule',
 'CenIT.ReportTourism.Modules.CateModule','CenIT.ReportTourism.WebApp')
foreach ($project in $projects) {
 & MSBuild.exe "$root/$project/$project.csproj" /t:Build /m:1 /p:Configuration=Release `
  "/p:SolutionDir=$root/" /p:PreBuildEvent= /p:PostBuildEvent= /p:MvcBuildViews=true
 if ($LASTEXITCODE -ne 0) { throw "Build failed: $project" }
}
```

Publish WebApp using the existing file-system publish process into a new reviewed directory. Biz/Caches use bin/Release; dynamically loaded SysModule/ReportModule/CateModule and WebApp use bin. Explicitly include all six rebuilt DLLs and their existing dependencies; module assemblies are dynamically loaded and may not be copied by WebApp project references. Include both updated Report_StoredProcedures.xml deployment copies, compiled views/assets through the existing module/package process, and environment-correct Configs/AppSettings.config with unchanged ReportRoles:* values. The obsolete ReportRoles.config should not return. Preserve target Web.config/machineKey/service credentials/uploads and environment configuration.

## SQL generation and coordinated staging cutover (after gates pass)

```powershell
$builder='./Source/ReportDeptTourismSolution/SqlScripts/Scripts/Build_SCT_IndustryChatbot_Deployment.ps1'
& $builder -CategoryDatabase '<staging-category>' -ReportDatabase '<staging-report>' `
 -RoleMappingPath '<reviewed-site>/Configs/AppSettings.config' -OutputDirectory '<secured-staging-sql-folder>'
& './Source/ReportDeptTourismSolution/SqlScripts/Scripts/Test_ReportConfiguration.ps1' `
 -WebConfigPath '<reviewed-site>/Web.config' -CategoryDatabase '<staging-category>' `
 -ReportDatabase '<staging-report>' -RoleMappingPath '<reviewed-site>/Configs/AppSettings.config'
```

Inspect sql-object-manifest.json and hashes; run the read-only preflight on the intended server. Confirm exact namespaces/audit references independently. Stop affected traffic/jobs; retain old matched package/snapshots. Operator runs the complete regenerated Deploy_All.sql in sqlcmd -b or SSMS SQLCMD mode, then installs the matching application/config package and recycles IIS. Verify and accept before opening traffic. Neither generation nor this agent executes deployment. Verification runs after schema COMMIT: failure means the SQL remains installed and requires compensating rollback or completing the accepted matched package.

## Executable acceptance on isolated restored staging

- [ ] Native exact-ID fixture suite passes for full admins with/without assignments; all management/enterprise/mixed/empty/inactive/deleted/invalid-map states; multi-industry and zero-grant fallback.
- [ ] Authorized Add/Edit/Delete and CheckDataImport preserve parameter/audit/return/error contracts. Each function-permission-denied account and foreign enterprise is denied; no write or audit row is created on denial. A Dashboard-visible unassigned enterprise is not automatically editable for a nonoperational administrator.
- [ ] Exercise failures before base commit, during audit insertion and after base commit/HTTP response. Verify @@TRANCOUNT/XACT_STATE and correct base error/return contracts; preserve audit identity exactly (including DeleteBy email). Do not inject failures into production.
- [ ] Personal monthly worklists show exactly assigned enterprises with actual records in the requested month; record gained/lost entries, statuses, duplicates and boundary dates. Full admin general visibility must not widen personal assignments.
- [ ] Operational Select2 supports empty/keyword/type searches and stable pages with correct totals; read-only report/MyEnterprise pickers remain canonical. Out-of-scope detail/open/render/POST IDs are denied.
- [ ] Dashboard FilterOptions kinds year/latest/ward/sector/industry/enterprise are consistent with query populations; valid empty population stays empty; unknown/inactive/failed resolution throws, full administrator retains the full registry.
- [ ] Chatbot capabilities, cookie identity, CSRF and protected token checks pass. Tampered catalog arguments cannot select roles/UserIds/SQL/AllowProvince. Assigned tools remain assignment-scoped; permitted reporting tools match Web scope/metrics where definitions are equivalent.
- [ ] Missing-report denominator is approved. Submitted plus missing counts reconcile only for the same active population, period and submission/type rule; never equate any-type legacy report with type-specific Dashboard progress without evidence.
- [ ] Execute all 53 generated procedures relevant to installed modules and external plugin equivalents after implementation; reconcile financial/statistical/grouping/period/pagination/export totals against the same authorized data. Review rounding, legacy date-equality and percent definitions rather than silently changing them.
- [ ] Measure warm/cold HTTP latency, SQL call counts/CPU/reads/plans and IIS resource cost with identical populations. New operational context bypasses cross-request cache; no performance improvement is claimed. Include full-registry admin, restricted manager and real single-assignment enterprise workloads.
- [ ] Customized labels survive, missing labels insert once, rerun seeds do not overwrite text; duplicates are surfaced for DBA review rather than automatically deleted.

## Production gate

Production remains NO-GO until staging evidence and business decisions above are approved. Reuse the accepted binaries, regenerate SQL with production Category/Report names and the exact accepted role keys, review the actual production base audit dependencies and grants, capture a fresh matched rollback set, rerun read-only authorization/worklist comparisons, and schedule a coordinated cutover. Do not run staging-named SQL against production, migrate roles, change credentials, restore over subsequent business writes or automatically DROP unused wrappers. Follow sql-bundle-changes.md for rollback phases.

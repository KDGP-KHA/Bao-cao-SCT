# SQL scope release audit — 14 October 2026

**GO for offline review. NO-GO for application staging deployment and production deployment.** It is safe to prepare/review the supplied fixture tests; they have not been executed against SQL Server or IIS. No SQL deployment, destructive SQL, credential change, role/permission/assignment/grant update, or commit was performed by this task.

## Executive summary

| Inventory | Count |
|---|---:|
| Initial generated procedures / functions | 49 / 7 |
| Corrected generated procedures / functions | **53 / 8** |
| Procedures retained with identical bodies | 38 |
| Existing procedure bodies changed (one whitespace-only) | 8 |
| Read-only operational/ownership procedures added | 7 |
| Write/validation call paths reverted to base procedures | 3 |
| Wrappers removed from future bundle | 3 |
| Functions unchanged / changed / added | 6 / 1 / 1 |
| Physical SQL objects dropped | **0** |

The only generated procedure that modifies persistent business authorization data is the existing, permission-checked `p_Report_IndustryPermissions_Save`; it is not executed by the agent. Procedures containing GenerateSaleOfTourism calculate result sets and nested report results; they do not save imports. Temporary tables/table variables used by reads are not classified as business writes.

DataImports no longer inherits the Dashboard scope controller. Create/update/delete/operational validation call the original procedures with original 8/4/3-argument contracts. Creator-only access remains record-level; a read-only ownership check prevents overwriting foreign rows or file headers. Server-side enterprise checks use a separate operational relationship, rather than industry visibility. Reporting, statistics and Chatbot retain canonical industry/enterprise visibility. Personal monthly worklists require verified assignments and do not expand to SpAdmin's entire reporting population. Safe seeds insert missing labels and preserve existing text.

**Additional blocker discovered:** all five registered `usp_Report_*` plugin paths dynamically request absent `_IndustryScope` mappings/definitions. Their original SQL bodies are not in the repository. A missing procedure result now raises HTTP 503 rather than silently becoming an empty report; no unscoped fallback was introduced. These report paths need their actual SQL definitions and tested scoped implementations before release.

**Environment blockers:** current Web.config selects `baocaosct.khanhhoa.gov.vn.cate` / `baocaosct.khanhhoa.gov.vn`, while the default SCT bundle targets `baocao.sct.cenit.vn.cate` / `baocao.sct.cenit.vn`. This pre-existing operator change was preserved. SELECT-only TDS 7.0 verification timed out. The Framework build exits 1 with MSB3644 (v4.5.2 targeting assemblies unavailable on macOS). No corrected real-user monthly totals or fresh role/permission hashes are claimed.

**Executed:** eight source/config regression guards; actual source-linked C# operational call/audit/return/denial tests; actual ChatbotCatalog rejection of six identity/scope/SQL injections; SQL Server 2012 parsing of release and fixture SQL; deterministic repeated generation; alternate database identifiers with spaces/dots; invalid-identifier rejection. These do not certify Framework/IIS, native SQL execution, business transactions or export reconciliation.

## Deliverables

- [Every generated procedure](procedure-inventory.md), [functions and dependencies](function-dependencies.md), [caller matrix](caller-matrix.md).
- [DataImports compatibility](dataimports-compatibility.md), [authorization findings](authorization-regression.md), [bundle changes and rollback](sql-bundle-changes.md).
- [Commands and evidence](test-evidence.md), [staging gates](staging-checklist.md).

Remaining ambiguities: deployment DB's exact original operational Get policy/creator provenance; mixed-role Dashboard operation gating; report-type/approval rules for missing-report denominator; legacy plugin SQL definitions and metric semantics; SQL principal access and target audit-log references. Preserve the documented verified behavior until these gates are resolved; do not invent extra filtering or silently invoke unscoped report procedures.

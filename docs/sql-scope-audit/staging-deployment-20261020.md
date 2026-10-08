# Staging deployment preparation — 2026-10-20

The current local application connections were inspected with SELECT-only queries:

- Server: `APPDEMO\MSSQL2012` (configured endpoint `10.57.30.10`).
- Report database: `baocao.sct.cenit.vn`.
- Category database: `baocao.sct.cenit.vn.cate`.

The regenerated `Preflight_SCT_IndustryChatbot.sql` completed successfully against
these connections. No required objects or columns were reported missing. Both
import table types exist, and equivalent indexes were found for all six requested
covering indexes.

The four `usp_Report_KTXH_*` export procedures are absent. Their names were
manually added to the old prerequisite list; they are not called or created by
the deployed dashboard/chatbot SQL. They now appear as informational optional
exports, alongside `usp_Report_HoatDongXuatKhau_TheoEnterprise`, which is installed.
This deployment does not implement the missing export procedures.

The staging artifacts are preserved under `SqlScripts/Staging/`; use
`Staging/Deploy_SCT_All.sql`. The root `SqlScripts/Deploy_SCT_All.sql` now targets
production at the user's subsequent request.

The staging script is generated as one server batch for DataGrip or sqlcmd.
Use a dedicated connection in auto-commit mode with no open transaction, pause
application traffic/jobs, and submit the entire file as one batch. No SQLCMD
mode or client-side stop-on-error directive is needed for this combined file.
Each internal batch runs in its explicitly selected staging database. Server-side
TRY/CATCH rolls back indexes, schema, role mappings and label changes if any batch
or final verification fails. Verification runs before the final commit. Index
builds are offline and can hold locks until the transaction finishes.

The component deployment/index scripts retain their standalone SQLCMD contracts;
use the combined file for the DataGrip execution described above.

Validation: live read-only preflight passed; eight existing regression tests
passed; release SQL and all 148 internal combined-script batches parsed as SQL
Server 2012 syntax; generation was checked for determinism. No deployment SQL
was executed against staging or production. Syntax and preflight checks do not
replace runtime acceptance after deployment.

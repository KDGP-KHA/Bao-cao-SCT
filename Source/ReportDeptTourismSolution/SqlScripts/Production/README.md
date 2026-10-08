# Production deployment — 2026-10-20

The current application connection was inspected with read-only metadata queries:

- Server: `DATABASETTDHSDL` (configured endpoint `10.57.30.156`).
- Category database: `baocaosct.khanhhoa.gov.vn.cate`.
- Report database: `baocaosct.khanhhoa.gov.vn`.

`Deploy_All.sql` is identical to the requested root `../Deploy_SCT_All.sql`.
The other production scripts are also copied to the corresponding root SCT files.
The previously prepared staging scripts are preserved under `../Staging/`.

The production preflight completed successfully without database writes. Both
import table types and all required schema dependencies were visible. Five
equivalent covering indexes already exist. The import enterprise/period index
still needs to be created by the deployment and can block traffic during its
offline build.

Use a dedicated DataGrip connection in auto-commit mode, with no open transaction.
Back up the databases/definitions and pause application traffic and jobs. Submit
the entire combined file as one server batch. No SQLCMD mode is required for the
combined file. Its transaction commits indexes, definitions, mappings and labels
only after final verification; errors roll the transaction back. Existing import
rows and user-industry assignments are not deleted by the deployment.

The standalone component files retain their SQLCMD requirements. Optional export
plugin procedures are reported for information and are not created by this release.

Regenerate the production package explicitly; the generator's no-argument defaults
still target staging:

```powershell
./Scripts/Build_SCT_IndustryChatbot_Deployment.ps1 `
  -CategoryDatabase baocaosct.khanhhoa.gov.vn.cate `
  -ReportDatabase baocaosct.khanhhoa.gov.vn `
  -OutputDirectory ./Production
```

Run that command from `SqlScripts/`. It writes this directory; it does not execute
SQL or refresh the root convenience copies. SHA-256 hashes are recorded in
`artifact-hashes.json`. No deployment was executed during preparation. Passing
preflight and syntax checks does not replace runtime acceptance after deployment.

param([string]$StubPath=(Join-Path $PSScriptRoot 'contract-stubs.cs'))
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
# Only six nonsecret role keys are staged into this temporary runtime; no credentials copied.
$appSettings=Join-Path $root 'Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Configs/AppSettings.config'
$doc=[xml]([IO.File]::ReadAllText($appSettings));$roleDoc=[xml]'<appSettings />'
foreach($n in $doc.appSettings.add){if($n.key.StartsWith('ReportRoles:')){[void]$roleDoc.DocumentElement.AppendChild($roleDoc.ImportNode($n,$true))}}
$runtime=[AppDomain]::CurrentDomain.BaseDirectory
$configDir=Join-Path $runtime 'Configs';$configFile=Join-Path $configDir 'AppSettings.config'
if(Test-Path $configFile){throw 'Run with an isolated PowerShell runtime; refusing to overwrite an existing runtime config.'}
$null=New-Item -ItemType Directory -Path $configDir -Force
try {
 $roleDoc.Save($configFile)
 $files=@($StubPath)+@('ReportRoleMapping','ReportIndustryScope','ReportDataImportScope','ReportDataImportBiz','ReportBiz' | ForEach-Object {Join-Path $root "Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/$_.cs"})
 # Passing file paths compiles separate syntax trees; no edits to actual application source.
 Add-Type -Path $files
 [ContractAssertions]::Run()
} finally {Remove-Item -LiteralPath $configFile -Force}

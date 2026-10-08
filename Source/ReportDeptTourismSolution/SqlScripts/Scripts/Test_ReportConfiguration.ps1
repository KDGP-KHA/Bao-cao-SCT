param(
 [Parameter(Mandatory=$true)][string]$WebConfigPath,
 [Parameter(Mandatory=$true)][string]$CategoryDatabase,
 [Parameter(Mandatory=$true)][string]$ReportDatabase,
 [Parameter(Mandatory=$true)][string]$RoleMappingPath
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'ReportDeployment.Common.ps1')
Assert-ReportDatabaseNames $CategoryDatabase $ReportDatabase
$null=Read-ReportRoleMapping $RoleMappingPath
$settings=New-Object System.Xml.XmlReaderSettings
$settings.DtdProcessing=[System.Xml.DtdProcessing]::Prohibit; $settings.XmlResolver=$null
$reader=[System.Xml.XmlReader]::Create([IO.Path]::GetFullPath($WebConfigPath),$settings)
try { $config=New-Object System.Xml.XmlDocument; $config.XmlResolver=$null; $config.Load($reader) } finally { $reader.Dispose() }
if ($config.configuration.connectionStrings.configSource) { throw 'Validate a staged Web.config with resolved connectionStrings; external connection file not loaded automatically.' }
foreach ($pair in @(@('BaseApp',$CategoryDatabase),@('ReportTourismDB',$ReportDatabase))) {
 $nodes=@($config.SelectNodes("/configuration/connectionStrings/add[@name='$($pair[0])']"))
 if ($nodes.Count -ne 1) { throw 'Required connection name is missing or ambiguous.' }
 try {
  $builder=New-Object System.Data.Common.DbConnectionStringBuilder
  $builder.set_ConnectionString($nodes[0].connectionString)
 } catch { throw 'Invalid connection string syntax; credentials omitted.' }
 $catalogs=@($builder.get_Keys() | Where-Object { $_ -ieq 'Initial Catalog' -or $_ -ieq 'Database' })
 if ($catalogs.Count -ne 1 -or [string]$builder.get_Item($catalogs[0]) -ine $pair[1]) { throw 'Connection database differs from requested deployment target; credentials omitted.' }
}
Write-Output 'PASS: connection database targets and application role mapping syntax agree. Run SQL preflight to validate DB roles/permissions.'

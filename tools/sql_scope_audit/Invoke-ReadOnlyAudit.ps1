param(
 [string]$WebConfigPath=(Join-Path $PSScriptRoot '../../Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Web.config'),
 [string]$OutputDirectory=(Join-Path $PSScriptRoot '../../docs/sql-scope-audit/evidence'),
 [string]$PythonExecutable='python3'
)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$settings=[System.Xml.XmlReaderSettings]::new();$settings.DtdProcessing=[System.Xml.DtdProcessing]::Prohibit;$settings.XmlResolver=$null
$reader=[System.Xml.XmlReader]::Create([IO.Path]::GetFullPath($WebConfigPath),$settings)
try {$xml=[System.Xml.XmlDocument]::new();$xml.XmlResolver=$null;$xml.Load($reader)} finally {$reader.Dispose()}
$connections=@(foreach($name in @('BaseApp','ReportTourismDB')) {
 $nodes=@($xml.SelectNodes("/configuration/connectionStrings/add[@name='$name']"))
 if($nodes.Count -ne 1){throw 'Required database connection missing or ambiguous; credentials omitted.'}
 $builder=[System.Data.Common.DbConnectionStringBuilder]::new()
 try {$builder.set_ConnectionString($nodes[0].connectionString)} catch {throw 'Invalid connection configuration; credentials omitted.'}
 $values=@{};foreach($key in $builder.get_Keys()) {$values[$key]=$builder.get_Item($key)}
 @{name=$name;values=$values}
})
$outputPath=[IO.Path]::GetFullPath($OutputDirectory)
Push-Location $root
try {
 ConvertTo-Json -InputObject $connections -Depth 4 -Compress | & $PythonExecutable -m tools.sql_scope_audit.live_readonly --output $outputPath
 $result=$LASTEXITCODE
} finally {Pop-Location}
exit $result

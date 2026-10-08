param([Parameter(Mandatory=$true)][string]$ScriptDomPath)
$ErrorActionPreference='Stop'
Add-Type -Path $ScriptDomPath
$parser=[Microsoft.SqlServer.TransactSql.ScriptDom.TSql110Parser]::new($true)
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$sqlRoot=Join-Path $root 'Source/ReportDeptTourismSolution/SqlScripts'
$files=@('Deploy_SCT_All.sql','Deploy_SCT_IndustryChatbot.sql','Preflight_SCT_IndustryChatbot.sql','Verify_SCT_IndustryChatbot.sql','Deploy_SCT_ReportPerformanceIndexes.sql'|ForEach-Object{Get-Item (Join-Path $sqlRoot $_)})
$files+=Get-ChildItem (Join-Path $sqlRoot '2. New Report Permission') -Filter *.sql
$files+=Get-ChildItem (Join-Path $sqlRoot 'Chatbot') -Filter *.sql
$files+=Get-Item (Join-Path $PSScriptRoot 'scope-fixtures.sql')
$count=0;$embedded=0
function Assert-Sql([string]$Name,[string]$Sql){$errors=$null;$reader=[IO.StringReader]::new($Sql);try{$null=$parser.Parse($reader,[ref]$errors)}finally{$reader.Dispose()};if($errors.Count){throw ($Name+': '+($errors -join '; '))}}
foreach($file in $files){$sql=[regex]::Replace([IO.File]::ReadAllText($file.FullName),'(?im)^:ON ERROR EXIT\s*$','');Assert-Sql $file.Name $sql;$count++;foreach($m in [regex]::Matches($sql,"(?is)\bEXEC\s*\(N?'((?:''|[^'])*)'\)")){Assert-Sql ($file.Name+' embedded') $m.Groups[1].Value.Replace("''","'");$embedded++}}
Write-Output "PASS: SQL Server 2012 parsing: $count release/fixture files and $embedded embedded definitions; syntax only."

# Shared validation used by both bundle builders. No database connections or secrets.
function Assert-ReportDatabaseNames([string]$CategoryDatabase,[string]$ReportDatabase) {
 foreach ($database in @($CategoryDatabase,$ReportDatabase)) {
  if ([string]::IsNullOrWhiteSpace($database) -or $database.Length -gt 128 -or
      $database -notmatch '^[\p{L}\p{N}_. -]+$' -or $database.Trim() -ne $database) {
   throw 'Invalid database identifier: use 1-128 letters/digits, underscores, dots, spaces or hyphens without surrounding whitespace.'
  }
 }
 if ($CategoryDatabase -eq $ReportDatabase) { throw 'Category and Report databases must be distinct.' }
}
function Convert-ReportDatabaseReferences([string]$Sql,[string]$CategoryDatabase,[string]$ReportDatabase) {
 # Only complete bracketed identifiers are executable retarget candidates. Never substring-replace a database prefix.
 $result=[regex]::Replace($Sql,'\[(baocaosct\.khanhhoa\.gov\.vn(?:\.cate)?)\]',{
  param($match)
  if ($match.Groups[1].Value.EndsWith('.cate')) { '['+$CategoryDatabase+']' } else { '['+$ReportDatabase+']' }
 })
 # Known documentation comments may mention the source environment; executable references must be bracketed.
 $executable=[regex]::Replace($result,'(?m)--[^\r\n]*','')
 if ($executable -match '(?<![\p{L}\p{N}_.])baocaosct\.khanhhoa\.gov\.vn(?:\.cate)?(?=\.(?:dbo|sys)\b|[^\p{L}\p{N}_.]|$)' -and
     $CategoryDatabase -ne 'baocaosct.khanhhoa.gov.vn.cate' -and $ReportDatabase -ne 'baocaosct.khanhhoa.gov.vn') {
  throw 'Unretargeted executable source database reference.'
 }
 return $result
}
function Read-ReportRoleMapping([string]$Path) {
 $settings=New-Object System.Xml.XmlReaderSettings
 $settings.DtdProcessing=[System.Xml.DtdProcessing]::Prohibit
 $settings.XmlResolver=$null
 $reader=[System.Xml.XmlReader]::Create([IO.Path]::GetFullPath($Path),$settings)
 try { $document=New-Object System.Xml.XmlDocument; $document.XmlResolver=$null; $document.Load($reader) } finally { $reader.Dispose() }
 $roles=@(foreach ($setting in $document.SelectNodes('/appSettings/add[starts-with(@key, "ReportRoles:")]')) {
  $values=$setting.GetAttribute('value').Split('|')
  if ($values.Count -ne 3) { throw 'Invalid report role setting; expected RoleId|scope|industryEditorTarget.' }
  $role=$document.CreateElement('role')
  $role.SetAttribute('key',$setting.GetAttribute('key').Substring('ReportRoles:'.Length))
  $role.SetAttribute('id',$values[0]); $role.SetAttribute('scope',$values[1]); $role.SetAttribute('industryEditorTarget',$values[2])
  $role
 })
 if (!$roles.Count) { throw 'Missing report role mappings.' }
 $ids=@{}; $keys=@{}
 foreach ($role in $roles) {
  $id=0
  if ($role.id -notmatch '^[0-9]+$' -or ![int]::TryParse($role.id,[ref]$id) -or $id -le 0 -or $ids.ContainsKey($id) -or
      $role.key -notmatch '^[A-Za-z][A-Za-z0-9_]{0,79}$' -or $keys.ContainsKey([string]$role.key)) { throw 'Invalid or duplicate role ID/key.' }
  foreach ($flag in @('industryEditorTarget')) {
   if ($role.GetAttribute($flag) -cnotin @('true','false')) { throw 'Role flags must be true or false.' }
  }
  if ($role.scope -cnotin @('all','industry','enterprise')) { throw 'Unknown reporting scope; use all, industry or enterprise.' }
  if ($role.scope -eq 'enterprise' -and $role.industryEditorTarget -eq 'true') { throw 'Enterprise role cannot confer administrative scope.' }
  $ids[$id]=$true; $keys[[string]$role.key]=$role
 }
 if (!$keys.ContainsKey('SystemAdministrator') -or !$keys.ContainsKey('Enterprise') -or
     $keys['SystemAdministrator'].key -cne 'SystemAdministrator' -or $keys['Enterprise'].key -cne 'Enterprise' -or
     $keys['SystemAdministrator'].scope -ne 'all' -or $keys['Enterprise'].scope -ne 'enterprise') { throw 'Required role semantics are missing or invalid.' }
 foreach ($scopeSet in @(@('all','industry'),@('enterprise'))) {
  $idsForFlag=(@($roles | Where-Object { $_.scope -in $scopeSet } | ForEach-Object { [int]$_.id }) -join ',')
  if ($idsForFlag.Length -gt 500) { throw 'Report role IDs exceed the SQL parameter contract.' }
 }
 return $roles
}
function Get-ReportRoleValues($Roles) {
 return (@($Roles | Sort-Object { [int]$_.id } | ForEach-Object {
  "('"+$_.key+"',"+([int]$_.id)+",'"+$_.scope+"',"+([int]($_.industryEditorTarget -eq 'true'))+")"
 }) -join ",`n")
}
function Get-ReportIndexCoverage($Index,[string]$Database) {
 $prefix='['+$Database+'].sys.'
 $terms=New-Object 'Collections.Generic.List[string]'
 $terms.Add("i.object_id=OBJECT_ID(N'[$Database].dbo.$($Index.table)') AND i.type IN(1,2) AND i.is_disabled=0 AND i.is_hypothetical=0 AND i.has_filter=0")
 $keys=@($Index.keys -split ','); $ordinal=0
 $terms.Add("(SELECT COUNT(*) FROM $($prefix)index_columns k WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal>0)>=$($keys.Count)")
 foreach ($column in $keys) {
  $ordinal++
  $terms.Add("EXISTS(SELECT 1 FROM $($prefix)index_columns k JOIN $($prefix)columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=$ordinal AND k.is_descending_key=0 AND c.name=N'$column')")
 }
 foreach ($column in ($Index.includes -split ',' | Where-Object { $_ })) {
  $terms.Add("(i.type=1 OR EXISTS(SELECT 1 FROM $($prefix)index_columns k JOIN $($prefix)columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name=N'$column'))")
 }
 return $terms -join ' AND '
}

param([string]$NewtonsoftPath=(Join-Path ([AppDomain]::CurrentDomain.BaseDirectory) 'Newtonsoft.Json.dll'))
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$source=Join-Path $root 'Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotCatalog.cs'
$refs=@(Get-ChildItem (Join-Path ([AppDomain]::CurrentDomain.BaseDirectory) 'ref') -Filter *.dll | ForEach-Object FullName)+@($NewtonsoftPath)
Add-Type -Path @((Join-Path $PSScriptRoot 'catalog-stubs.cs'),$source) -ReferencedAssemblies $refs -CompilerOptions /nowarn:1701
[CatalogAssertions]::Run((Join-Path $root 'Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp'))

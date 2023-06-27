param(
    [Parameter(Mandatory=$true)]
    [string]$ScriptFile,
    [Parameter(Mandatory=$false)]
    [string]$OutFile = ".\Documentation\$ScriptFile.md"
)

$comments = Select-String -Path $ScriptFile -Pattern '#'
$comments | ForEach-Object { $_.Line } | Out-File $OutFile
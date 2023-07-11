<#
.SYNOPSIS
    Purpose of this cmdlet is to generate a text file (md) with all code comments 
.DESCRIPTION
    The script returns all comments inside the code marked with a # sign. Then runs it through 
    a text summary feature (in progress) and returns the final content.
.NOTES
    Information or caveats about the function e.g. 'This function is not supported in Linux'
.LINK
    Specify a URI to a help page, this will show when Get-Help -Online is used.
.EXAMPLE
    ./generate_comments.ps1 <filename> <[optional]out-file>
    Explanation of the function or its result. You can include multiple examples with additional .EXAMPLE lines
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ScriptFile,
    [Parameter(Mandatory=$false)]
    [string]$OutFile = ".\Documentation\$ScriptFile.md"
)

$comments = Select-String -Path $ScriptFile -Pattern '#'
$comments | ForEach-Object { $_.Line } | Out-File $OutFile
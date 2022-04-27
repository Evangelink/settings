# ---------------------------------------------------------------------------
# Modules
# ---------------------------------------------------------------------------

$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"

$LazyLoadProfile = [PowerShell]::Create()
[void]$LazyLoadProfile.AddScript(@'
    Import-Module posh-git
    Import-Module -Name Terminal-Icons
    Import-Module "$ChocolateyProfile"
    Import-Module ZLocation
'@)
[void]$LazyLoadProfile.BeginInvoke()

$null = Register-ObjectEvent -InputObject $LazyLoadProfile -EventName InvocationStateChanged -Action {
    ## posh-git configuration
    Import-Module posh-git
    $global:GitPromptSettings.DefaultPromptPrefix.Text = 'PS '
    $global:GitPromptSettings.DefaultPromptBeforeSuffix.Text = '`n'

    ## Terminal-Icons configuration
    Import-Module -Name Terminal-Icons

    ## Chocolatey
    if (Test-Path($ChocolateyProfile)) {
        Import-Module "$ChocolateyProfile"
    }

    ## https://github.com/vors/ZLocation
    Import-Module ZLocation

    $LazyLoadProfile.Dispose()
}

## oh-my-posh configuration
Import-Module -Name oh-my-posh
Set-PoshPrompt -Theme slimfat

## PSReadLine configuration
# PSReadline provides Bash like keyboard cursor handling
Import-Module PSReadLine
# general
Set-PSReadLineOption -HistoryNoDuplicates
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineOption -HistorySaveStyle SaveIncrementally
Set-PSReadLineOption -MaximumHistoryCount 4000
Set-PSReadlineOption -ShowToolTips:$true
# history substring search
Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward
# tab completion
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadlineKeyHandler -Chord 'Shift+Tab' -Function Complete

Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Windows

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

<#
    Opens VS Code in the given path (default is current directory).
#>
function Open-VsCode ($Path = '.') {
    code -n $Path
}

<#
    Opens VS Code Insiders in the given path (default is current directory).
#>
function Open-VsCodeInsiders ($Path = '.') {
    code-insiders -n $Path
}

<#
    Finds the first smallest length solution in the current folder or src folder and open it.
#>
function Open-ShortestSolutionName () {
    # open the solution with the shortest name in the current folder or in src
    function get ($path) {
        Get-ChildItem $path *.sln |
        Sort-Object -Property { $_.Name.Length } |
        Select-Object -First 1
    }

    $sln = get $PWD.Path
    if ($null -eq $sln -or 0 -eq $sln.Count) {
        $path = Join-Path $PWD.Path "src"
        $sln = get $path
    }

    if ($null -ne $sln -and 1 -eq $sln.Count) {
        Invoke-Item $sln
    }
}

<#
    Clears all -dev nuget packages.
#>
function Remove-DevNugetPackage {
    $Path = @("~\.nuget\packages", "./packages")
    $paths = foreach ($p in $path) { 
        if (-not (Test-path $p)) {
            continue
        }
        Get-ChildItem "$p\*\*-dev" | Remove-Item -Force -Recurse -Verbose
    }
    Write-Host "Cleaned up all -dev nuget packages in $($Path -join " and ")."
}

<#
    Clears all bin and obj folders under the given path.
#>
function Remove-ObjAndBin ($Path = $pwd.Path, [switch]$WhatIf) {
    $dirs = Get-ChildItem $Path -Directory -Recurse `
        | Where-Object { $fullname = $_.FullName ; "*\obj", "*\bin" `
        | Where-Object { $fullname -like $_ } } `
        | Select-Object -ExpandProperty FullName

    if ($WhatIf) {
        $dirs
    }
    else {
        $dirs | Remove-Item -force -Recurse -Verbose
    }
}

function Stop-GivenProcess ($ProcessName) {
    Get-Process $ProcessName | Stop-Process -Force
}

function Stop-DevProcesses {
    Write-Output "Killing dotnet processes"
    taskkill /F /IM dotnet.exe /T

    Write-Output "Killing test processes"
    taskkill /F /IM VSTest.Console.exe /T
    taskkill /F /IM testhost.exe /T
    taskkill /F /IM datacollector.exe /T

    Write-Output "Killing msbuild and VBCSCompiler processes"
    taskkill /F /IM msbuild.exe /T | taskkill /F /IM VBCSCompiler.exe     
}

# http://stackoverflow.com/questions/39148304/fuser-equivalent-in-powershell/39148540#39148540
function Get-LockingProcesses($RelativeFile) {
    $file = Resolve-Path $RelativeFile
	Write-Output "Looking for processes using $file"
	foreach ($Process in (Get-Process)) {
		foreach ($Module in $Process.Modules) {
			if ($Module.FileName -like "$file*") {
				$Process | Select-Object id, path
			}
		}
	}
}

function Get-ProcessGraph ($Name = "testhost*", $Max = 1) {
    "Waiting for processes '$Name' to start:"
    $noneLimit = 5
    $none = $noneLimit
    $now = 0
    while ($true) { 
        $p = @(Get-Process $name | Sort-Object StartTime)
        if ($p.Count -eq 0) { 
            $none++
            # we havent seen any such process for 5 cycles (500ms)
            # we start timing from scratch
            if ($none -ge $noneLimit) {
                $now = 0
            }
        }
        else {
            # there was a gap where we did not write anything,
            # and we reset the timer
            # write empty lines to show that
            if($none -gt $noneLimit) {
                "`n`n"
            }  
            $none = 0
        }
        if ($none -lt $noneLimit) {
            $color = if ($p.Count -eq 0 ) {@{}} else {@{ ForegroundColor = if ($p.Count -gt $Max) { "Red" } else { "Green" }}}
            Write-Host @color "$("$now".PadLeft(7)) ms - $($p.Count) - $(($p | % {"$($_.ProcessName) - $("$($_.Id)".PadLeft(5))" }) -join ", ")";  
        }
        start-sleep -Milliseconds 100
        $now += 100; 
    }
}

function New-Dump {
    # dump content of all files that match the given pattern for easy posting of examples to github
    param([string[]] $Filter = '*.cs', $Path = $pwd.Path, [switch] $Recurse, [switch] $All, [switch] $clip)
    $nameExcludes = "*.AssemblyInfo.*"
    $pathExcludes = "*\bin\*", "*\obj\*", "*\packages\*"
    $text = [Text.StringBuilder]::new()
    foreach ($p in (Resolve-Path $Path).Path) {
        Get-ChildItem $p -File -Recurse:$Recurse |
        Where-Object { $fullName = $_.FullName; -not ($pathExcludes | Where-Object { $fullName -like $_ }) } |
        Where-Object { $name = $_.Name; $Filter | Where-Object { $name -like $_ } } |
        Where-Object { $name = $_.Name; if ($All) { $true } else { -not ($nameExcludes | Where-Object { $name -like $_ }) } } |
        ForEach-Object {
            if (0 -lt $text.Length) {
                $null = $text.AppendLine()
            }

            $lang = switch ($_.Extension) {
                { $_ -in ".ps1", ".psm1", ".psd1" } { "powershell" }
                default { $_.TrimStart('.') }
            }

            $null = $text.AppendLine(('```{0}' -f $lang))

            $comment = switch ($_.Extension) {
                { $_ -in ".cs", ".fs" } { "// file {0}" }
                { $_ -in ".csproj", ".fsproj", ".proj", ".props", ".targets", ".xml" } { "<!-- file {0} -->" }
                default { "# file {0}" }
            }
            $null = $text.AppendLine($comment -f ($_.FullName -replace [regex]::Escape($p)).TrimStart('\'))
            $null = $text.AppendLine((Get-Content $_.FullName -Raw))
            $null = $text.AppendLine(('```'))
        }
    }

    $text = $text.ToString()
    if ($clip) {
        $text | C:\WINDOWS\system32\clip.exe
    }

    $text
}

# ---------------------------------------------------------------------------
# Custom Aliases
# ---------------------------------------------------------------------------

Set-Alias -Name c -Value Open-VsCode
Set-Alias -Name ci -Value Open-VsCodeInsiders
Set-Alias -Name sln -Value Open-ShortestSolutionName
Set-Alias -Name nuke-nuget -Value Remove-DevNugetPackage
Set-Alias -Name nuke-proj -Value Remove-ObjAndBin
Set-Alias -Name kps -Value Stop-GivenProcess
Set-Alias -Name pkill -Value Stop-GivenProcess
Set-Alias -Name kps-dev -Value Stop-DevProcesses
Set-Alias -Name kdps -Value Stop-DevProcesses
Set-Alias -Name pdevkill -Value Stop-DevProcesses
Set-Alias -Name who-locks -Value Get-LockingProcesses
Set-Alias -Name fuser -Value Get-LockingProcesses
Set-Alias -Name dump -Value New-Dump
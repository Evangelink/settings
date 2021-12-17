
# <############### Start of PowerTab Initialization Code ########################
#     Added to profile by PowerTab setup for loading of custom tab expansion.
#     Import other modules after this, they may contain PowerTab integration.
# #>

# Import-Module "PowerTab" -ArgumentList "C:\Users\Amaury Leve\Documents\WindowsPowerShell\PowerTabConfig.xml"
# ################ End of PowerTab Initialization Code ##########################

# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile" -Force
}


## Get-ChildItemColor configuration
Import-Module Get-ChildItemColor
Set-Alias ls Get-ChildItemColor -Option AllScope
Set-Alias l Get-ChildItemColorFormatWide -Option AllScope

## posh-git configuration
Import-Module -Name posh-git

## oh-my-posh configuration
Import-Module -Name oh-my-posh
Set-PoshPrompt -Theme jandedobbeleer

## PSReadLine configuration
Import-Module PSReadLine
# general
Set-PSReadLineOption -HistoryNoDuplicates
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineOption -HistorySaveStyle SaveIncrementally
Set-PSReadLineOption -MaximumHistoryCount 4000
# history substring search
Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward
# tab completion
Set-PSReadlineKeyHandler -Chord 'Shift+Tab' -Function Complete
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete
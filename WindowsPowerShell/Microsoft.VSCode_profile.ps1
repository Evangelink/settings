if (Test-Path $env:OneDriveCommercial\Documents\PowerShell\Microsoft.PowerShell_profile.ps1) {
    . $env:OneDriveCommercial\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
} else {
    $myDocs = [Environment]::GetFolderPath("MyDocuments")
    if (Test-Path $myDocs\PowerShell\Microsoft.PowerShell_profile.ps1) {
        . $myDocs\PowerShell\Microsoft.PowerShell_profile.ps1
    } else {
        throw "Cannot find root powershell profile"
    }    
}
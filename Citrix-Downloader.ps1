<#
.SYNOPSIS
Download multiple VDA and ISO versions from Citrix.com
.DESCRIPTION
Download various Citrix components through a GUI without spending hours navigating through the various Citrix sub-sites.

.NOTES
  Version:          0.01.2
  Author:           Manuel Winkel <www.deyda.net>
  Creation Date:    2021-10-22

  // NOTE: Purpose/Change
  2020-06-20        Initial Version by Ryan Butler
  2021-10-22		Customization
  2021-12-22		Import of the download list into the script, no helper files needed anymore / Add Version Number and Version Check with Auto Update Function / Add Citrix 1912 CU4 and 2112 content

#>


$CSV = @"
"dlnumber","filename","name"
"19993","Citrix_Virtual_Apps_and_Desktops_7_1912_4000.iso","Citrix Virtual Apps and Desktops 7 1912 CU4 ISO"
"20115","Citrix_Virtual_Apps_and_Desktops_7_2112.iso","Citrix Virtual Apps and Desktops 7 2112 ISO"

"19994","VDAServerSetup_1912.exe","Multi-session OS Virtual Delivery Agent 1912 LTSR CU4"
"19995","VDAWorkstationSetup_1912.exe","Single-session OS Virtual Delivery Agent 1912 LTSR CU4"
"19996","VDAWorkstationCoreSetup_1912.exe","Single-session OS Core Services Virtual Delivery Agent 1912 LTSR CU4"

"20116","VDAServerSetup_2112.exe","Multi-session OS Virtual Delivery Agent 2112"
"20117","VDAWorkstationSetup_2112.exe","Single-session OS Virtual Delivery Agent 2112"
"20118","VDAWorkstationCoreSetup_2112.exe","Single-session OS Core Services Virtual Delivery Agent 2112"

"19997","ProfileMgmt_1912.zip","Profile Management 1912 LTSR CU4"
"19803","ProfileMgmt_2112.zip","Profile Management 2112"

"19999","Citrix_Provisioning_1912_19.iso","Citrix Provisioning 1912 CU4"
"20119","Citrix_Provisioning_2112.iso","Citrix Provisioning 2112"

"9803","Citrix_Licensing_11.17.2.0_BUILD_37000.zip","License Server for Windows - Version 11.17.2.0 Build 37000"

"19998","CitrixStoreFront-x64.exe ","StoreFront 1912 LTSR CU4"

"20209","Workspace-Environment-Management-v-2112-01-00-01.zip","Workspace Environment Management 2112"
"@

#Folder dialog
#https://stackoverflow.com/questions/25690038/how-do-i-properly-use-the-folderbrowserdialog-in-powershell
Function Get-Folder($initialDirectory)

{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")|Out-Null

    $foldername = New-Object System.Windows.Forms.FolderBrowserDialog
    $foldername.Description = "Select a folder"
    $foldername.rootfolder = "MyComputer"

    if($foldername.ShowDialog() -eq "OK")
    {
        $folder += $foldername.SelectedPath
    }
    return ($folder + "\") 
}

#Prompt for folder path
$path = Get-Folder

#Import Download Function
function get-ctxbinary {
	<#
.SYNOPSIS
  Downloads a Citrix VDA or ISO from Citrix.com utilizing authentication
.DESCRIPTION
  Downloads a Citrix VDA or ISO from Citrix.com utilizing authentication.
  Ryan Butler 2/6/2020
.PARAMETER DLNUMBER
  Number assigned to binary download
.PARAMETER DLEXE
  File to be downloaded
.PARAMETER DLPATH
  Path to store downloaded file. Must contain following slash (c:\temp\)
.PARAMETER CitrixUserName
  Citrix.com username
.PARAMETER CitrixPW
  Citrix.com password
.EXAMPLE
  Get-CTXBinary -DLNUMBER "16834" -DLEXE "Citrix_Virtual_Apps_and_Desktops_7_1912.iso" -CitrixUserName "mycitrixusername" -CitrixPW "mycitrixpassword" -DLPATH "C:\temp\"
#>
	Param(
		[Parameter(Mandatory = $true)]$DLNUMBER,
		[Parameter(Mandatory = $true)]$DLEXE,
		[Parameter(Mandatory = $true)]$DLPATH,
		[Parameter(Mandatory = $true)]$CitrixUserName,
		[Parameter(Mandatory = $true)]$CitrixPW
	)
	#Initialize Session 
	Invoke-WebRequest "https://identity.citrix.com/Utility/STS/Sign-In?ReturnUrl=%2fUtility%2fSTS%2fsaml20%2fpost-binding-response" -SessionVariable websession -UseBasicParsing | Out-Null

	#Set Form
	$form = @{
		"persistent" = "on"
		"userName"   = $CitrixUserName
		"password"   = $CitrixPW
	}

	#Authenticate
	try {
		Invoke-WebRequest -Uri ("https://identity.citrix.com/Utility/STS/Sign-In?ReturnUrl=%2fUtility%2fSTS%2fsaml20%2fpost-binding-response") -WebSession $websession -Method POST -Body $form -ContentType "application/x-www-form-urlencoded" -UseBasicParsing -ErrorAction Stop | Out-Null
	}
	catch {
		if ($_.Exception.Response.StatusCode.Value__ -eq 500) {
			Write-Verbose "500 returned on auth. Ignoring"
			Write-Verbose $_.Exception.Response
			Write-Verbose $_.Exception.Message
		}
		else {
			throw $_
		}

	}
	$dlurl = "https://secureportal.citrix.com/Licensing/Downloads/UnrestrictedDL.aspx?DLID=${DLNUMBER}&URL=https://downloads.citrix.com/${DLNUMBER}/${DLEXE}"
	$download = Invoke-WebRequest -Uri $dlurl -WebSession $websession -UseBasicParsing -Method GET
	$webform = @{ 
		"chkAccept"            = "on"
		"clbAccept"            = "Accept"
		"__VIEWSTATEGENERATOR" = ($download.InputFields | Where-Object { $_.id -eq "__VIEWSTATEGENERATOR" }).value
		"__VIEWSTATE"          = ($download.InputFields | Where-Object { $_.id -eq "__VIEWSTATE" }).value
		"__EVENTVALIDATION"    = ($download.InputFields | Where-Object { $_.id -eq "__EVENTVALIDATION" }).value
	}

	$outfile = ($DLPATH + $DLEXE)
	#Download
	Invoke-WebRequest -Uri $dlurl -WebSession $websession -Method POST -Body $webform -ContentType "application/x-www-form-urlencoded" -UseBasicParsing -OutFile $outfile
	return $outfile
}

# Disable progress bar while downloading
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'SilentlyContinue'

# Is there a newer Evergreen Script version?
# ========================================================================================================================================
$eVersion = "0.01.1"
[bool]$NewerVersion = $false
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$WebResponseVersion = Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/Deyda/Citrix-Downloader/main/Citrix-Downloader.ps1"
If (!$WebVersion) {
    $WebVersion = (($WebResponseVersion.tostring() -split "[`r`n]" | select-string "Version:" | Select-Object -First 1) -split ":")[1].Trim()
}
If ($WebVersion -gt $eVersion) {
    $NewerVersion = $true
}

# Shortcut Creation
If (!(Test-Path -Path "$env:USERPROFILE\Desktop\Citrix Downloader.lnk")) {
    $WScriptShell = New-Object -ComObject 'WScript.Shell'
    $ShortcutFile = "$env:USERPROFILE\Desktop\Citrix Downloader.lnk"
    $Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
    $Shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    $Shortcut.WorkingDirectory = "C:\Windows\System32\WindowsPowerShell\v1.0"
    If (!(Test-Path -Path "$PSScriptRoot\shortcut")) { New-Item -Path "$PSScriptRoot\shortcut" -ItemType Directory | Out-Null }
    If (!(Test-Path -Path "$PSScriptRoot\shortcut\CitrixDownloaderLogo.ico")) {Invoke-WebRequest -Uri https://raw.githubusercontent.com/Deyda/Citrix-Downloader/main/shortcut/CitrixDownloader.ico -OutFile ("$PSScriptRoot\shortcut\" + "CitrixDownloaderLogo.ico")}
    $shortcut.IconLocation="$PSScriptRoot\shortcut\CitrixDownloaderLogo.ico"
    $Shortcut.Arguments = '-noexit -ExecutionPolicy Bypass -file "' + "$PSScriptRoot" + '\Citrix-Downloader.ps1"'
    $Shortcut.Save()
    $Admin = [System.IO.File]::ReadAllBytes("$ShortcutFile")
    $Admin[0x15] = $Admin[0x15] -bor 0x20
    [System.IO.File]::WriteAllBytes("$ShortcutFile", $Admin)
}
If (!(Test-Path -Path "$PSScriptRoot\img\CitrixDownloaderLogo.png")) {
    If (!(Test-Path -Path "$PSScriptRoot\img")) { New-Item -Path "$PSScriptRoot\img" -ItemType Directory | Out-Null }
    Invoke-WebRequest -Uri https://github.com/Deyda/Citrix-Downloader/blob/main/img/CitrixDownloaderLogo.png -OutFile ("$PSScriptRoot\img\" + "CitrixDownloaderLogo.png")
}

# Script Version
# ========================================================================================================================================
Write-Output ""
Write-Host -BackgroundColor DarkGreen -ForegroundColor Yellow "                     Citrix Downloader                      "
Write-Host -BackgroundColor DarkGreen -ForegroundColor Yellow "      Manuel Winkel - Deyda Consulting (www.deyda.net)      "
Write-Host -BackgroundColor DarkGreen -ForegroundColor Yellow "                      Version $eVersion                        "
$host.ui.RawUI.WindowTitle ="Citrix Downloader - Manuel Winkel (www.deyda.net) - Version $eVersion"

If (!($NoUpdate)) {
    Write-Output ""
    Write-Host -Foregroundcolor DarkGray "Is there a newer Citrix Downloader version?"
    
    If ($NewerVersion -eq $false) {
        # No new version available
        Write-Host -Foregroundcolor Green "OK, script is newest version!"
        Write-Output ""
    }
    Else {
        # There is a new Evergreen Script Version
        Write-Host -Foregroundcolor Red "Attention! There is a new version of Citrix Downloader."
        Write-Output ""
        If ($file) {
            $update = @'
                Remove-Item -Path "$PSScriptRoot\Citrix-Downloader.ps1" -Force 
                Invoke-WebRequest -Uri https://raw.githubusercontent.com/Deyda/Citrix-Downloader/main/Citrix-Downloader.ps1 -OutFile ("$PSScriptRoot\" + "Citrix-Downloader.ps1")
                & "$PSScriptRoot\Citrix-Downloader.ps1" -download -file $file
'@
            $update > $PSScriptRoot\update.ps1
            & "$PSScriptRoot\update.ps1"
            Break
        }
        ElseIf ($GUIfile) {
            $update = @'
            Remove-Item -Path "$PSScriptRoot\Citrix-Downloader.ps1" -Force 
            Invoke-WebRequest -Uri https://raw.githubusercontent.com/Deyda/Citrix-Downloader/main/Citrix-Downloader.ps1 -OutFile ("$PSScriptRoot\" + "Citrix-Downloader.ps1")
                & "$PSScriptRoot\Citrix-Downloader.ps1" -download -GUIfile $GUIfile
'@
            $update > $PSScriptRoot\update.ps1
            & "$PSScriptRoot\update.ps1"
            Break
            
        }
        Else {
            $wshell = New-Object -ComObject Wscript.Shell
            $AnswerPending = $wshell.Popup("Do you want to download the new version?",0,"New Version Alert!",32+4)
            If ($AnswerPending -eq "6") {
                Start-Process "https://www.deyda.net"
                $update = @'
                    Remove-Item -Path "$PSScriptRoot\Citrix-Downloader.ps1" -Force 
                    Invoke-WebRequest -Uri https://raw.githubusercontent.com/Deyda/Citrix-Downloader/main/Citrix-Downloader.ps1 -OutFile ("$PSScriptRoot\" + "Citrix-Downloader.ps1")
                    & "$PSScriptRoot\Citrix-Downloader.ps1"
'@
                $update > $PSScriptRoot\update.ps1
                & "$PSScriptRoot\update.ps1"
                Break
            }
        }
    }
}


$creds = Get-Credential -Message "Citrix Credentials"
$CitrixUserName = $creds.UserName
$CitrixPW = $creds.GetNetworkCredential().Password

#Imports $CSV with download information
#$downloads = import-csv -Path ".\Helpers\Downloads.csv" -Delimiter ","
$downloads = $CSV | ConvertFrom-Csv -Delimiter ","

#Use CTRL to select multiple
$dls = $downloads | Out-GridView -PassThru -Title "Select Installer or ISO to download. CTRL to select multiple"

#Processes each download
foreach ($dl in $dls) {
    write-host "Downloading $($dl.filename)..."
    Get-CTXBinary -DLNUMBER $dl.dlnumber -DLEXE $dl.filename -CitrixUserName $CitrixUserName -CitrixPassword $CitrixPW -DLPATH $path
}

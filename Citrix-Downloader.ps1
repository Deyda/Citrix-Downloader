<#
.SYNOPSIS
Download multiple VDA and ISO versions from Citrix.com
.DESCRIPTION
Download various Citrix components through a GUI without spending hours navigating through the various Citrix sub-sites.

.NOTES
  Version:          0.01.6
  Author:           Manuel Winkel <www.deyda.net>
  Creation Date:    2021-10-22

  // NOTE: Purpose/Change
  2020-06-20    Initial Version by Ryan Butler
  2021-10-22    Customization
  2021-12-22    Import of the download list into the script, no helper files needed anymore / Add Version Number and Version Check with Auto Update Function / Add Citrix 1912 CU4 and 2112 content / Add shortcut creation
  2021-12-23    Change password fields
  2022-04-19    Add Version 1912 CU5 and 2203
  2022-05-24    Add Version 7.15 CU 8

#>


$CSV = @"
"dlnumber","filename","name"
"19758","XenApp_and_XenDesktop_7_15_8000.iso","XenApp 7.15.8000 / XenDesktop 7.15.8000"
"20477","Citrix_Virtual_Apps_and_Desktops_7_1912_5000.iso","Citrix Virtual Apps and Desktops 7 1912 CU5 ISO"
"20428","Citrix_Virtual_Apps_and_Desktops_7_2203.iso","Citrix Virtual Apps and Desktops 7 2203 ISO"

"20478","VDAServerSetup_1912.exe","Multi-session OS Virtual Delivery Agent 1912 LTSR CU5"
"20479","VDAWorkstationSetup_1912.exe","Single-session OS Virtual Delivery Agent 1912 LTSR CU5"
"20480","VDAWorkstationCoreSetup_1912.exe","Single-session OS Core Services Virtual Delivery Agent 1912 LTSR CU5"

"20429","VDAServerSetup_2203.exe","Multi-session OS Virtual Delivery Agent 2203 LTSR"
"20430","VDAWorkstationSetup_2203.exe","Single-session OS Virtual Delivery Agent 2203 LTSR"
"20431","VDAWorkstationCoreSetup_2203.exe","Single-session OS Core Services Virtual Delivery Agent 2203 LTSR"

"20482","ProfileMgmt_1912.zip","Profile Management 1912 LTSR CU5"
"19803","ProfileMgmt_2203.zip","Profile Management 2203 LTSR"

"20488","Citrix_Provisioning_1912_25.iso","Citrix Provisioning 1912 CU5"
"20432","Citrix_Provisioning_2203.iso","Citrix Provisioning 2203"

"9803","Citrix_Licensing_11.17.2.0_BUILD_37000.zip","License Server for Windows - Version 11.17.2.0 Build 37000"

"20485","CitrixStoreFront-x64.exe ","StoreFront 1912 LTSR CU5"
"20791","CitrixStoreFront-x64.exe ","StoreFront 2203 LTSR"

"20579","Workspace-Environment-Management-v-2203-01-00-01.zip","Workspace Environment Management 2203"
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

# Is there a newer Citrix Downloader version?
# ========================================================================================================================================
$eVersion = "0.01.6"
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
    If (!(Test-Path -Path "$PSScriptRoot\shortcut\CitrixDownloaderLogo.ico")) {Invoke-WebRequest -Uri https://raw.githubusercontent.com/Deyda/Citrix-Downloader/main/shortcut/CitrixDownloaderLogo.ico -OutFile ("$PSScriptRoot\shortcut\" + "CitrixDownloaderLogo.ico")}
    $shortcut.IconLocation="$PSScriptRoot\shortcut\CitrixDownloaderLogo.ico"
    $Shortcut.Arguments = '-noexit -ExecutionPolicy Bypass -file "' + "$PSScriptRoot" + '\Citrix-Downloader.ps1"'
    $Shortcut.Save()
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
$downloads = $CSV | ConvertFrom-Csv -Delimiter ","

#Use CTRL to select multiple
$dls = $downloads | Out-GridView -PassThru -Title "Select Installer or ISO to download. CTRL to select multiple"

#Processes each download
foreach ($dl in $dls) {
    write-host "Downloading $($dl.filename)..."
    Get-CTXBinary -DLNUMBER $dl.dlnumber -DLEXE $dl.filename -CitrixUserName $CitrixUserName -CitrixPW $CitrixPW -DLPATH $path
}
### Global variables
$RTOOLS_ARCH = ${env:RTOOLS_ARCH}
$RTOOLS_ZIP = "rtools43-5550-5548.exe"
$RTOOLS_EXE = "rtools43-5550-5548.exe"

### Use for bootstrapping installation
# $RTOOLS_MIRROR = "https://ftp.opencpu.org/rtools/installer/"
$RTOOLS_MIRROR = "https://cloud.r-project.org/bin/windows/Rtools/rtools43/files/"
# $RTOOLS_MIRROR = "https://ftp.opencpu.org/archive/rtools/4.0/"

### InnoSetup Mirror
# $INNO_MIRROR = "http://www.jrsoftware.org/download.php/is.exe?site=2"
### Latest InnoSetup does not support Vista anymore
$INNO_MIRROR = "http://files.jrsoftware.org/is/6/innosetup-6.0.4.exe"

### MikTex Mirror
$MIKTEX_MIRROR = "https://miktex.org/download/win/basic-miktex-x64.exe"
#$MIKTEX_MIRROR = "https://cloud.r-project.org/bin/windows/Rtools/basic-miktex-2.9.7152-x64.exe"

function CheckExitCode($msg) {
  if ($LastExitCode -ne 0) {
    Throw $msg
  }
}

# Unzip and Initiate Rtools dump
Function InstallRtoolsZip {
	Write-Host "Installing ${RTOOLS_ZIP}..." -ForegroundColor Cyan
	$tmp = "$($env:USERPROFILE)\${RTOOLS_ZIP}"
	(New-Object Net.WebClient).DownloadFile($RTOOLS_MIRROR + $RTOOLS_ZIP, $tmp)
	7z x $tmp -y -oC:\ | Out-Null
	CheckExitCode "Failed to extract ${RTOOLS_ZIP}"
	C:\rtools43\usr\bin\bash.exe --login -c exit 2>$null
	Write-Host "Installation of ${RTOOLS_ZIP} done!" -ForegroundColor Green
}

# Don't use installer when: (1) architecture doesn't match host (2) Dir C:/rtools43 already exists
Function InstallRtoolsExe {
	Write-Host "Installing ${RTOOLS_EXE}..." -ForegroundColor Cyan
	$tmp = "$($env:USERPROFILE)\${RTOOLS_EXE}"	
	(New-Object Net.WebClient).DownloadFile($RTOOLS_MIRROR + $RTOOLS_EXE, $tmp)
	Start-Process -FilePath $tmp -ArgumentList /VERYSILENT -NoNewWindow -Wait
	Write-Host "Installation of ${RTOOLS_EXE} done!" -ForegroundColor Green
}

function bash($command) {
    Write-Host $command -NoNewline
    cmd /c start /wait C:\rtools43\usr\bin\sh.exe --login -c $command
    Write-Host " - OK" -ForegroundColor Green
}

function InstallRtools {
	InstallRtoolsZip
	bash 'pacman -Sy --noconfirm pacman pacman-mirrors'
	bash 'pacman -Syyu --noconfirm --ask 20'
}

Function InstallInno {
  Write-Host "Downloading InnoSetup from: " + $INNO_MIRROR
  & "C:\Program Files\Git\mingw64\bin\curl.exe" -s -o ../innosetup.exe -L $INNO_MIRROR
  CheckExitCode "Failed to download $INNO_MIRROR"

  Write-Host "Installig InnoSetup..."
  Start-Process -FilePath ..\innosetup.exe -ArgumentList "/ALLUSERS /SILENT" -NoNewWindow -Wait
  CheckExitCode "Failed to install InnoSetup"

  Write-Host "InnoSetup installation: Done" -ForegroundColor Green
  Get-ItemProperty "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
}

function InnoBuild($iss){
	Write-Host "Creating installer..." -NoNewline
	& "C:\Program Files (x86)\Inno Setup 5\iscc.exe" "${env:RTOOLS_NAME}.iss" | Out-File output.log
	Write-Host "OK!" -ForegroundColor Green
}

function SignFiles($files) {
  (New-Object Net.WebClient).DownloadFile(${env:PfxUri}, 'C:\jeroen.pfx')
  & $env:SignTool sign /f C:\jeroen.pfx /p "$env:CertPassword" /tr http://sha256timestamp.ws.symantec.com/sha256/timestamp /td sha256 /fd sha256 $files
  CheckExitCode "Failed to sign files."
  Remove-Item 'C:\jeroen.pfx'
}

Function InstallMiktex {
  $miktexinstall = "--unattended --auto-install=yes --shared --package-set=basic"

  Write-Host "Downloading " + $MIKTEX_MIRROR
  & "C:\Program Files\Git\mingw64\bin\curl.exe" -s -o ../basic-miktex-x64.exe -L $MIKTEX_MIRROR

  Write-Host "Installing MiKTeX: " + $miktexinstall
  Start-Process -FilePath ..\basic-miktex-x64.exe -ArgumentList $miktexinstall -NoNewWindow -Wait

  Write-Host "Setting PATH variable for current process"
  $env:PATH = 'C:\Program Files\MiKTeX\miktex\bin\x64;' + $env:PATH

  Write-Host "Installing CTAN packages"
  mpm --admin --set-repository=https://ctan.math.illinois.edu/systems/win32/miktex/tm/packages/
  mpm --admin --verbose --update-db
  mpm --admin --verbose --update
  mpm --admin --install=inconsolata

  # Enable auto-install, just in case
  initexmf --admin --enable-installer
  initexmf --admin --set-config-value "[MPM]AutoInstall=1"   

  # See https://tex.stackexchange.com/a/129523/12890
  $conffile = "C:\Program Files\MiKTeX\miktex\config\updmap.cfg"
  Write-Host "Adding zi4.map"
  initexmf --admin --update-fndb
  Add-Content $conffile "`nMap zi4.map`n"
  initexmf --admin --mkmaps

  # First time running 'pdflatex' always fails with some inite
  Write-Host "Trying pdflatex..."
  # pdflatex.exe --version
  Write-Host "MiKTeX installation: Done" -ForegroundColor Green
}

########### OLD CODE ###########

Function InstallMSYS32 {
	Write-Host "Installing MSYS2 32-bit..." -ForegroundColor Cyan

	# download installer
	$zipPath = "$($env:USERPROFILE)\msys2-i686-latest.tar.xz"
	$tarPath = "$($env:USERPROFILE)\msys2-i686-latest.tar"
	Write-Host "Downloading MSYS installation package..."
	(New-Object Net.WebClient).DownloadFile('http://repo.msys2.org/distrib/msys2-i686-latest.tar.xz', $zipPath)

	Write-Host "Untaring installation package..."
	7z x $zipPath -y -o"$env:USERPROFILE" | Out-Null

	Write-Host "Unzipping installation package..."
	7z x $tarPath -y -oC:\ | Out-Null
	del $zipPath
	del $tarPath
}

function rtools_bootstrap {
	# AppVeyor only has msys64 preinstalled
	if($env:MSYS_VERSION -eq 'msys32') {
		InstallMSYS32
		bash 'pacman -Sy --noconfirm pacman pacman-mirrors'

		# May upgrade runtime, need to exit afterwards
		bash 'pacman -Syyuu --noconfirm --ask 20'
	}
	bash 'pacman --version'
	bash 'pacman --noconfirm -Rcsu mingw-w64-x86_64-toolchain mingw-w64-i686-toolchain'
	bash 'repman add rtools "https://dl.bintray.com/rtools/${MSYSTEM_CARCH}"'
	bash 'pacman --noconfirm --sync rtools/pacman-mirrors rtools/pacman rtools/tar'
	bash 'mv /etc/pacman.conf /etc/pacman.conf.old'
	bash 'mv /etc/pacman.conf.pacnew /etc/pacman.conf'
	bash 'pacman --noconfirm -Scc'
	bash 'pacman --noconfirm --ask 20 -Syyu'
}


Function SetTimezone {
	tzutil /g
	tzutil /s "GMT Standard Time"
	tzutil /g
}

@ECHO OFF
Setlocal EnableDelayedExpansion enableextensions
REM When you enable delayed expansion and change or set a variable
REM within a loop then the !variable! syntax allows you to use
REM the variable within the loop.
CLS

REM TODO
REM Need to find latest version of programs being searched for
REM --PHP and Chromium set to static versions for XP/Vista compatibility
REM -- WGET, SHA1, NIRCMDC, DOUR(whatever).ttf, Visual Studio 2008 shouldn't change
REM --7Zip seems to be the only thing that changes regularly
REM Use SETX for environment variables to make them global, supposed to immediately update Explorer. If not, can kill and restart Explorer. http://ss64.com/nt/setx.html
REM --NIRCMD has a "restartexplorer" option
REM SETX is supposed to not affect the current cmd window
REM Will need to unset variables in cleanup script.
REM SETX can be used to set variable to registry entry
REM Need to take into account URL's being bad or changing
REM Need to allow setting of toolkit folder
REM Need to specify list of mirrors and provide a way to check
REM Need to specify network share location to get files from
REM Need to add command line parameters
REM Need to specify toolkit directory
REM Logging - CALL function
REM Error handling
REM Need to more proactively unset variables
REM Put download URL's at top of script? Easier to update?
REM Internet-fix.bat built in with prompt
REM OpenSSL?
REM CMDOW
REM SysInternals Sigcheck to check versions of downloaded programs?
REM Backup power settings, then change power settings with powercfg http://ss64.com/nt/powercfg.html
REM --Also disable screen saver
REM --Different for XP http://ss64.com/nt/powercfg-xp.html

:ELEVATION
REM First check if we are running As Admin/Elevated
FSUTIL dirty query %SystemDrive% >nul
if %errorlevel% NEQ 0 (
	::Create and run a temporary VBScript to elevate this batch file
	Set _batchFile=%~f0
	Set _Args=%*
	:: double up any quotes
	Set _batchFile=""%_batchFile:"=%""
	Set _Args=%_Args:"=""%
	Echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\~ElevateMe.vbs"
	Echo UAC.ShellExecute "cmd", "/c ""%_batchFile% %_Args%""", "", "runas", 1 >> "%temp%\~ElevateMe.vbs"
	cscript "%temp%\~ElevateMe.vbs" 
	Exit /B
)

:START
REM Set the current directory to the batch file location
REM Directory may change after elevation
cd /d %~dp0

ECHO Adding toolkit\tools to path and setting base variables
ECHO.
REM Ensuring variables are unset can help stop weird problems,
REM but more importantly this section serves as a list of all variables used in the script
REM All variables start with TK to avoid variable clash, and because starting variables with a number causes problems
REM 
REM If you want to change where the Toolkit installs to, or have it run in the current folder, change this
SET TK=%temp%\toolkit
REM If you want to pause after each step (if it fails to run properly, for example), set tkpause to YES
SET TKPAUSE=NO
REM TKDLFN Toolkit download filename - temp variable
SET "TKDLFN="
REM TKDLFN2 Toolkit download function - If a file specified with TKDLFS
REM is found, this contains the last found example, if any - temp variable
SET "TKDLFN2="
REM TKDLFS Toolkit Download function: File name search
REM If this is set to a file name, like wget.exe, that file name
REM will be searched for on the entire C: drive - temp variable
SET "TKDLFS="
REM TKDLURL Toolkit download url - temp variable
SET "TKDLURL="
REM TKDLPATH Toolkit download path - temp variable
SET "TKDLPATH="
REM TKSEC Toolkit section to return to - temp variable
SET "TKSEC="
REM TKPSVER Powershell version - automatically set
SET TKPSVER=0
REM Windows 32/64 - automatically set
SET "TKWIN="
REM Command prompt executable 32/64 - automatically set
SET "TKCMD="
REM System32/SysWOW64 - automatically set
SET "TKSYS32="
REM Powershell.exe path - automatically set
SET "TKPSEXE="
REM 7Zip Path - automatically set
SET "TK7Z="
REM Backup PHPRC variable - automatically set
SET "PHPRCBAK=%PHPRC%"
REM Backup PHPINI variable - automatically set
SET "PHPINIBAK=%PHPINI%"
REM Portable Chromium path - temp variable
SET "TKCHROME="
REM Add Toolkit Tools folder to path
SET PATH=%PATH%;%TK%\tools

ECHO Set 32/64 bit variables
IF NOT EXIST %WINDIR%\sysnative\cmd.exe (
	ECHO It's either 64 on 64 or 32 on 32
	if EXIST "%PROGRAMFILES(X86)%" (
		echo 64 bit CMD on 64 bit Windows
		set "TKWIN=X64"
		set "TKCMD=X64"
		set "TKSYS32=SYSWOW64"
	) else (
		echo 32 bit CMD on 32 bit Windows
		set "TKWIN=X86"
		set "TKCMD=X86"
		set "TKSYS32=SYSTEM32"
	)
) else (
	echo 32 bit CMD on 64 bit Windows
	set "TKWIN=X64"
	set "TKCMD=X86"
	set "TKSYS32=SYSWOW64"
)
ECHO.

ECHO Setting Powershell Version
SET "TKPSEXE=%SYSTEMROOT%\SYSTEM32\WINDOWSPOWERSHELL\v1.0\POWERSHELL.EXE"
REM Was recommended to use PSVersionTable.PSVersion.Major but PSVersionTable doesn't exist on v1.0
FOR /F "tokens=* USEBACKQ" %%F IN (`%TKPSEXE% -command "$Host.Version.Major"`) DO (
	IF %%F GEQ 1 (
		ECHO Powershell Version=%%F
		SET "TKPSVER=%%F"
	)
)

IF %TKPSVER%==0 (
	ECHO Couldn't find Powershell
	ECHO.
) ELSE (
	ECHO Powershell Version is v%TKPSVER%.0
	ECHO.
)

ECHO Make toolit folder, switch to it
ECHO.
mkdir "%TK%" 2> nul
mkdir "%TK%\temp" 2> nul
mkdir "%TK%\php\htdocs" 2> nul
mkdir "%TK%\tools" 2> nul
mkdir "%TK%\tools\7z\Files\7-Zip" 2> nul
mkdir "%TK%\logs\virus" 2> nul
pushd !TK!
echo TK=%TK%
ECHO Working Directory=%cd%
ECHO.
REM Uncomment below to get full folder listing
REM dir /S /B
ECHO.

ECHO Toolkit folder creation complete
ECHO.
if %tkpause%==YES PAUSE
ECHO.

REM CLS



:TOOLKIT
ECHO Prep Phase
ECHO.
ECHO Accepting SysInternals EULA's
ECHO.
reg.exe ADD "HKCU\Software\Sysinternals\AccessChk" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\AccessEnum" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\AdExplorer" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\AdInsight" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\AdRestore" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\Autologon" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\Autoruns" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\BgInfo" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\BlueScreen" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\CacheSet" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\ClockRes" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\Contig" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\Coreinfo" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\Ctrl2cap" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\DebugView" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\Desktops" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\Disk Usage" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\Disk2vhd" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\DiskExt" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\Diskmon" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\DiskView" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\EFSDump" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\Handle" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\Hex2dec" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\Junction" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\LDMDump" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\ListDLLs" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\LiveKd" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\LoadOrder" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\LogonSessions" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\MoveFile" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\NTFSInfo" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\PageDefrag" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\PendMoves" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\PipeList" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\PortMon" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\ProcDump" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\Process Explorer" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\Process Monitor" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\ProcFeatures" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\PsExec" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\PsFile" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\PsGetSid" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\PsInfo" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\PsKill" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\PsList" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\PsLoggedOn" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\PsLogList" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\PsPasswd" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\PsService" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\PsShutdown" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\PsSuspend" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\PsTools" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\RAMMap" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\RegDelNull" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\RegJump" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\RootkitRevealer" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\SDelete" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\ShareEnum" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\ShellRunas" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\Sigcheck" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\Streams" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\Strings" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\Sync" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\TCPView" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\VMMap" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\VolumeId" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\Whois" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\WinObj" /v EulaAccepted /t REG_DWORD /d 1 /f> nul
reg.exe ADD "HKCU\Software\Sysinternals\ZoomIt" /v EulaAccepted /t REG_DWORD /d 1 /f> nul

ECHO Complete with SysInternals EULA's
ECHO.

REM cls

ECHO This code downloads what is necessary to run the toolkit,
ECHO then runs the necessary executables
ECHO.

if %tkpause%==YES PAUSE
ECHO.


:WGET
ECHO Checking for wget.exe
ECHO.
IF NOT EXIST "%TK%\tools\wget.exe" (
	ECHO wget.exe not found, defining variables
	ECHO.
	SET "TKDLFS=wget.exe"
	ECHO TKDLFS=!TKDLFS!
	SET "TKDLFN=wget.exe"
	ECHO TKDLFN=!TKDLFN!
	SET "TKDLURL=https://eternallybored.org/misc/wget/current/wget.exe"
	ECHO TKDLURL=!TKDLURL!
	SET "TKDLPATH=tools"
	ECHO TKDLPATH=!TKDLPATH!
	SET "TKSEC=WGET"
	ECHO TKSEC=!TKSEC!
	ECHO.
	ECHO Going to Search
	ECHO.
	if %tkpause%==YES PAUSE
	ECHO.
	GOTO SEARCH
) ELSE (
	ECHO wget.exe found
	ECHO.
	GOTO WGETEND
)
:WGETEND
if %tkpause%==YES PAUSE
ECHO.


:SHA1
ECHO Checking for sha1.exe
ECHO.
IF NOT EXIST "%TK%\tools\sha1.exe" (
	ECHO sha1.exe not found, Defining variables
	ECHO.
	SET TKDLFS=sha1.exe
	SET TKDLFN=sha1.exe
	SET TKDLURL=http://software.bigfix.com/download/bes/util/Sha1.exe
	SET TKDLPATH=tools
	SET TKSEC=SHA1
	ECHO Going to Search
	ECHO.
	GOTO SEARCH
) ELSE (
	ECHO sha1.exe found
	ECHO.
	GOTO SHA1END
)
:SHA1END
if %tkpause%==YES PAUSE
ECHO.


:TK7Z
ECHO Checking for 7z.exe
ECHO.
IF NOT EXIST "%TK%\tools\7z\Files\7-Zip\7z.exe" (
	IF EXIST "%TK%\tools\7z\7z.exe" (
		MOVE /Y "%TK%\tools\7z\7z.exe" "%TK%\tools\7z\Files\7-Zip\7z.exe"
		DEL /F /Q "%TK%\tools\7z\7z.exe"
		GOTO TK7Z
	)
	IF NOT EXIST "%TK%\tools\7z\7z.msi" (
		ECHO 7z.exe not found, Defining variables
		ECHO.
		SET TKDLFS=7z.exe
		SET TKDLFN=7z.msi
		SET TKDLURL=http://www.7-zip.org/a/7z1602.msi
		SET TKDLPATH=tools\7z
		SET TKSEC=TK7Z
		ECHO.
		ECHO Going to Search
		ECHO.
		GOTO SEARCH
	) ELSE (
		ECHO.
		ECHO Silently install 7zip to temp folder
		ECHO.
		ECHO Move MSI from TK\TOOLS\7Z to TK\TEMP\7Z
		move /Y "%TK%\tools\7z\7z.msi" "%TK%\temp\7z.msi"
		ECHO Delete orig 7z.msi (this may produce an error)
		del "%TK%\tools\7z\7z.msi" /F /Q > nul
		ECHO Extracting MSI
		msiexec /a "%TK%\temp\7z.msi" /qb TARGETDIR="%TK%\tools\7z"
		ECHO Deleting 7z.msi
		ECHO.
		del "%TK%\temp\7z.msi" /F /Q
		REM Can't start a variable with a number
		
		ECHO verifying
		if %tkpause%==YES PAUSE
		ECHO.
		GOTO TK7Z
	)
) ELSE (
	ECHO 7z.exe found
	ECHO.
	SET TK7Z=%TK%\tools\7z\Files\7-Zip\7z.exe
	GOTO TK7ZEND
)
:TK7ZEND
if "%tkpause%"=="YES" PAUSE
ECHO.

:NIRCMD
REM 
ECHO Checking for nircmdc.exe
ECHO.
IF NOT EXIST "%TK%\tools\nircmdc.exe" (
	IF NOT EXIST "%TK%\temp\nircmd.zip" (
		ECHO nircmdc.exe not found, Defining variables
		ECHO.
		SET TKDLFS=nircmdc.exe
		SET TKDLFN=nircmd.zip
		SET TKDLURL=http://www.nirsoft.net/utils/nircmd.zip
		SET TKDLPATH=temp
		SET TKSEC=NIRCMD
		ECHO.
		ECHO Going to Search
		ECHO.
		GOTO SEARCH
	) ELSE (
		ECHO.
		ECHO Extracting nircmdc.exe
		ECHO.
		"%TK7Z%" e "%TK%\temp\nircmd.zip" -o"%TK%\tools" nircmdc.exe -y
		ECHO Deleting archive
		DEL /F /Q "%TK%\temp\nircmd.zip"
		ECHO Extracted, Rechecking
		if %tkpause%==YES PAUSE
		ECHO.
		GOTO NIRCMD
	)
) ELSE (
	ECHO nircmdc.exe found
	ECHO.
	ECHO Emptying all recycle bins (sometimes script tries to copy files from recycle bin)
	ECHO.
	"%TK%\tools\nircmdc.exe" emptybin
	ECHO Complete
	ECHO.
	GOTO NIRCMDEND
)
:NIRCMDEND
if "%tkpause%"=="YES" PAUSE
ECHO.

:DCFONT

REM http://www.nirsoft.net/utils/nircmd.zip
ECHO Checking for dour65w.ttf
ECHO.
IF NOT EXIST "%TK%\php\htdocs\dour65w.ttf" (
	IF NOT EXIST "%TK%\temp\dc.zip" (
		ECHO dour65w.ttf not found, Defining variables
		ECHO.
		SET TKDLFS=dour65w.ttf
		SET TKDLFN=dc.zip
		REM http://h20566.www2.hp.com/hpsc/swd/public/detail?swItemId=lj611en&lang=en&cc=us
		REM whp-aus2.cold.extweb.hp.com/pub/printers/software/lj611en.exe
		SET TKDLURL=http://whp-aus2.cold.extweb.hp.com/pub/printers/software/lj611en.exe
		SET TKDLPATH=temp
		SET TKSEC=DCFONT
		ECHO.
		ECHO Going to Search
		ECHO.
		GOTO SEARCH
	) ELSE (
		ECHO.
		ECHO Extracting dour65w.ttf
		ECHO.
		"%TK7Z%" e "%TK%\temp\dc.zip" -o"%TK%\php\htdocs" dour65w.ttf -y
		ECHO Deleting archive
		DEL /F /Q "%TK%\temp\dc.zip"
		ECHO Extracted, Rechecking
		if %tkpause%==YES PAUSE
		ECHO.
		GOTO DCFONT
	)
) ELSE (
	ECHO dour65w.ttf found
	ECHO.
	GOTO DCFONTEND
)
:DCFONTEND
if "%tkpause%"=="YES" PAUSE
ECHO.


:VS2008
ECHO Checking for msvcr90.dll Visual Studio Redist 2008
ECHO.
REM Multiple Redistributable install switches http://asawicki.info/news_1597_installing_visual_c_redistributable_package_from_command_line.html
IF NOT EXIST %WINDIR%\WinSxS\x86_Microsoft.VC90.CRT_* (
	IF NOT EXIST "%TK%\temp\vs2008redist_x86.exe" (
		ECHO msvcr90.dll not found, Defining variables
		ECHO.
		SET TKDLFS=
		SET TKDLFN=vs2008redist_x86.exe
		SET TKDLURL=https://download.microsoft.com/download/d/d/9/dd9a82d0-52ef-40db-8dab-795376989c03/vcredist_x86.exe
		SET TKDLPATH=temp
		SET TKSEC=VS2008
		ECHO.
		ECHO Going to Search
		ECHO.
		GOTO SEARCH
	) ELSE (
		ECHO.
		ECHO Installing Microsoft Visual Studio 2008 Redistributable 32-Bit
		ECHO.
		"%TK%\temp\vs2008redist_x86.exe" /qb!repair
		ECHO Installed, Rechecking
		if %tkpause%==YES PAUSE
		ECHO.
		GOTO VS2008
	)
) ELSE (
	ECHO msvcr90.dll found
	ECHO.
	GOTO VS2008END
)
:VS2008END
if %tkpause%==YES PAUSE
ECHO.



:PHP
REM PHP 5.4.44 is the last version to support XP
REM Need to have it switch to latest for newer windows
REM Will also need to change Visual studio install script, vc9 = Studio 2008
ECHO Checking for PHP
ECHO.
IF NOT EXIST "%TK%\php\php.exe" (
	IF NOT EXIST "%TK%\temp\php.zip" (
		ECHO PHP not found, Defining variables
		ECHO.
		SET TKDLFS=
		SET TKDLFN=PHP.ZIP
		SET TKDLURL=http://windows.php.net/downloads/releases/archives/php-5.4.44-nts-Win32-VC9-x86.zip
		SET TKDLPATH=temp
		SET TKSEC=PHP
		ECHO.
		ECHO Going to Search
		ECHO.
		GOTO SEARCH
	) ELSE (
		ECHO.
		ECHO Extracting PHP
		ECHO.
		"%TK7Z%" x -o"%TK%\php" "%TK%\temp\php.zip" -y
		ECHO Deleting %TK%\temp\php.zip
		ECHO.
		DEL "%TK%\temp\php.zip" /F /Q
		ECHO Extracted, Rechecking
		if %tkpause%==YES PAUSE
		ECHO.
		GOTO PHP
	)
) ELSE (
	ECHO PHP found
	ECHO.
	REM GOTO PHPEND
)

if %tkpause%==YES PAUSE
ECHO.

ECHO Setting PHPRC variable
ECHO.
SET PHPRC=%TK%\php

ECHO This section will write a bare php.ini
ECHO.

SET phpini=%TK%\php\php.ini

ECHO [PHP] >%phpini%
ECHO max_execution_time = 0 >>%phpini%
ECHO max_input_time = -1 >>%phpini%
ECHO memory_limit = 256M >>%phpini%
ECHO error_reporting = E_ALL >>%phpini%
ECHO display_errors = On >>%phpini%
ECHO display_startup_errors = On >>%phpini%
ECHO log_errors = On >>%phpini%
ECHO log_errors_max_len = 10240 >>%phpini%
ECHO track_errors = On >>%phpini%
ECHO html_errors = On >>%phpini%
ECHO error_log = "%TK%\php\php_errors.log" >>%phpini%
ECHO request_order = "GP" >>%phpini%
ECHO post_max_size = 0 >>%phpini%
ECHO doc_root = "%TK%\php\htdocs" >>%phpini%
ECHO extension_dir = "ext" >>%phpini%
ECHO enable_dl = On >>%phpini%
ECHO file_uploads = On >>%phpini%
ECHO upload_max_filesize = 2048M >>%phpini%
ECHO max_file_uploads = 2000 >>%phpini%
ECHO extension=php_curl.dll >>%phpini%
ECHO extension=php_fileinfo.dll >>%phpini%
ECHO extension=php_gd2.dll >>%phpini%
ECHO extension=php_imap.dll >>%phpini%
ECHO extension=php_mbstring.dll >>%phpini%
ECHO extension=php_exif.dll ; Must be after mbstring as it depends on it >>%phpini%
ECHO extension=php_openssl.dll >>%phpini%
ECHO extension=php_sqlite3.dll >>%phpini%
ECHO cli_server.color = On >>%phpini%

ECHO PHP.INI complete, Write dummy index.php
ECHO.
echo ^<?PHP phpinfo() ?^> > "%TK%\php\htdocs\index.php"
ECHO Complete, Continuing
ECHO.

:PHPEND
if %tkpause%==YES PAUSE
ECHO.

:CHROMIUM
REM https://www.googleapis.com/download/storage/v1/b/chromium-browser-snapshots/o/Win%%2F369898%%2Fchrome-win32.zip?alt=media
REM That URL is for the last version of Chromium to support XP and Vista, 49.0.2623
ECHO Checking for Chromium
ECHO.
IF NOT EXIST "%TK%\chrome-win32\chrome.exe" (
	IF NOT EXIST "%TK%\temp\chromium.zip" (
		ECHO Chromium not found, Defining variables
		ECHO.
		SET TKDLFS=
		SET TKDLFN=chromium.zip
		SET TKDLURL=https://www.googleapis.com/download/storage/v1/b/chromium-browser-snapshots/o/Win%%2F369898%%2Fchrome-win32.zip?alt=media
		SET TKDLPATH=temp
		SET TKSEC=CHROMIUM
		ECHO Going to Search
		ECHO.
		GOTO SEARCH
	) ELSE (
		ECHO.
		ECHO Extracting Chromium
		ECHO.
		"%TK7Z%" x -o"%TK%" "%TK%\temp\chromium.zip" -y
		ECHO Deleting %TK%\temp\chromium.zip
		ECHO.
		DEL "%TK%\temp\chromium.zip" /F /Q
		ECHO Extracted, Rechecking
		if %tkpause%==YES PAUSE
		ECHO.
		GOTO CHROMIUM
	)
) ELSE (
	ECHO Chromium found
	ECHO.
	SET TKCHROME=%TK%\chrome-win32\chrome.exe
	GOTO CHROMIUMEND
)

:CHROMIUMEND
if %tkpause%==YES PAUSE
ECHO.


:LAUNCH
ECHO Launching PHP
ECHO.
start "" "%TK%\php\php.exe" -S 127.0.0.1:8080 -t "%TK%\php\htdocs" -c "%TK%\php\php.ini"

ECHO Waiting
ECHO.
ping 127.0.0.1>nul

if %tkpause%==YES PAUSE
ECHO.

ECHO Launching Chromium
ECHO.
start "" "%TKCHROME%" --app=http://127.0.0.1:8080/ --use-temporary-user-data-dir --homepage="http://127.0.0.1:8080/" --incognito --allow-file-access-from-files --allow-http-screen-capture --allow-insecure-localhost --allow-no-sandbox-job --allow-outdated-plugins --allow-running-insecure-content --allow-unchecked-dangerous-downloads --disable-accelerated-2d-canvas --disable-3d-apis --disable-accelerated-jpeg-decoding --disable-accelerated-mjpeg-decode --disable-accelerated-video-decode --disable-canvas-aa --disable-cloud-import --disable-d3d11 --disable-flash-3d --disable-flash-stage3d --disable-gpu --disable-ipv6 --disable-logging --disable-local-storage --disable-pepper-3d --disable-preconnect --disable-save-password-bubble --disable-software-rasterizer --disable-sync --dns-prefetch-disable --enable-fast-unload --enable-low-end-device-mode --ignore-certificate-errors --log-level=3 --no-default-browser-check --no-first-run --no-proxy-server --no-service-autorun --site-per-process --start-maximized

:TKENDOPT
CLS
SET TKENDOPT=9
REM Give opportunity to kill and relaunch Chromium and PHP
ECHO Chromium closed (or failed to launch)
ECHO Please type an option below and press enter:
ECHO.
ECHO.
ECHO 1 - Kill Chromium and relaunch
ECHO 2 - Kill Chromium and PHP then relaunch both
ECHO 3 - Kill PHP and relaunch
ECHO 4 - Restart script
ECHO 5 - Quit script
ECHO.
SET /P TKENDOPT= Please enter a number:

IF %TKENDOPT% GEQ 2 (
	IF %TKENDOPT% LEQ 3 (
		REM Kill and Relaunch PHP
		%TK%\tools\pskill.exe -t -nobanner php.exe
		ECHO Waiting
		ECHO.
		ping 127.0.0.1>nul
		ECHO Relaunching PHP
		ECHO.
		start "" "%TK%\php\php.exe" -S 127.0.0.1:8080 -t "%TK%\php\htdocs" -c "%TK%\php\php.ini"
		ECHO Waiting
		ECHO.
		ping 127.0.0.1>nul
		pause
	)
)

IF %TKENDOPT% LEQ 2 (
	set TKCHROME2=%TKCHROME:\=\\%
	REM set TKCHROME2=%TKCHROME2:~=\~%
	REM Kill Chromium
	REM Need to use SysInternals PSKill and WMIC to only kill Chrome.exe processes run from temp folder, and not normal Chrome sessions
	REM Need to add path to pskill
	
	FOR /F "tokens=* USEBACKQ" %%F IN (`wmic process where ExecutablePath^="!TKCHROME2!" get ProcessID /FORMAT:TABLE`) DO (
		IF %%F GEQ 1 (
			REM Should have something here telling you when it's killing a process
			call "%TK%\tools\pskill.exe" -t -nobanner %%F
		)
	)
	ECHO Waiting
	ECHO.
	PAUSE
	ping 127.0.0.1>nul
	ECHO Relaunching Chromium
	ECHO.
	start "" "%TKCHROME%" --app=http://127.0.0.1:8080/ --use-temporary-user-data-dir --homepage="http://127.0.0.1:8080/" --incognito --allow-file-access-from-files --allow-http-screen-capture --allow-insecure-localhost --allow-no-sandbox-job --allow-outdated-plugins --allow-running-insecure-content --allow-unchecked-dangerous-downloads --disable-accelerated-2d-canvas --disable-3d-apis --disable-accelerated-jpeg-decoding --disable-accelerated-mjpeg-decode --disable-accelerated-video-decode --disable-canvas-aa --disable-cloud-import --disable-d3d11 --disable-flash-3d --disable-flash-stage3d --disable-gpu --disable-ipv6 --disable-logging --disable-local-storage --disable-pepper-3d --disable-preconnect --disable-save-password-bubble --disable-software-rasterizer --disable-sync --dns-prefetch-disable --enable-fast-unload --enable-low-end-device-mode --ignore-certificate-errors --log-level=3 --no-default-browser-check --no-first-run --no-proxy-server --no-service-autorun --site-per-process --start-maximized
	pause
)

IF %TKENDOPT% LEQ 3 (
	REM Re-display options
	GOTO TKENDOPT
)

IF %TKENDOPT%==4 (
	REM Restart script
	GOTO ELEVATION
)

IF %TKENDOPT%==5 (
	REM Quit script
	REM Need this to kill the chrome and php
		set TKCHROME2=%TKCHROME:\=\\%
	REM set TKCHROME2=%TKCHROME2:~=\~%
	REM Kill Chromium
	REM Need to use SysInternals PSKill and WMIC to only kill Chrome.exe processes run from temp folder, and not normal Chrome sessions
	REM Need to add path to pskill
	
	FOR /F "tokens=* USEBACKQ" %%F IN (`wmic process where ExecutablePath^="!TKCHROME2!" get ProcessID /FORMAT:TABLE`) DO (
		IF %%F GEQ 1 (
			REM Should have something here telling you when it's killing a process
			call "%TK%\tools\pskill.exe" -t -nobanner %%F
		)
	)
	ECHO Waiting
	ECHO.
	PAUSE
	ping 127.0.0.1>nul
	ECHO Killing PHP
	ECHO.
	%TK%\tools\pskill.exe -t -nobanner php.exe
	ECHO Waiting
	ECHO.
	ping 127.0.0.1>nul
	GOTO END
)
ECHO You entered: %TKENDOPT%
ECHO Input not recognized.
ECHO Press any key to return to selection menu
PAUSE
GOTO TKENDOPT

ECHO Only functions below here, so skip all functions and GOTO END
ECHO.
GOTO END

:SEARCH
IF DEFINED TKDLFS (
	SET "TKDLFN2="
	ECHO Searching for !TKDLFS! on Drive C
	ECHO.
	for /F "delims=" %%F in ('dir /B /S c:\!TKDLFS! 2^> nul') do (
		Echo.%%F | findstr /C:"Recycle">nul && (
			ECHO Skipping %%F
			ECHO Reason: 'Recycle' found in file path
			ECHO.
		) || (
			SET "TKDLFN2=%%F"
			ECHO TKDLFN2=!TKDLFN2!
			ECHO.
		)
	)
	
	ECHO Final TKDLFN2=!TKDLFN2!
		ECHO.

	IF "!TKDLFN2!"=="" (
		ECHO Could not find !TKDLFS! on C drive, going to DOWNLOAD
		ECHO.
		if %tkpause%==YES PAUSE
		ECHO.
		GOTO DOWNLOAD
	) ELSE (
		ECHO.
		ECHO Copying !TKDLFN2! to toolkit
		ECHO.
		COPY /B /V /Y "!TKDLFN2!" "%TK%\!TKDLPATH!\!TKDLFS!" || ECHO Error Copying
		ECHO Returning to %TKSEC%
		ECHO.
		if %tkpause%==YES PAUSE
		ECHO.
		SET "TKDLFN2="
		GOTO !TKSEC!
	)
) ELSE GOTO DOWNLOAD
:SEARCHEND
if %tkpause%==YES PAUSE
ECHO.


:DOWNLOAD
ECHO %TKDLFN% not in %TK%\%TKDLPATH%, need to download.
ECHO.
if %tkpause%==YES PAUSE
ECHO.
IF %TKDLFN%==wget.exe (
	GOTO DOWNLOAD1
) ELSE (
	GOTO DOWNLOADWGET
)

:DOWNLOADWGET
ECHO Downloading %TKDLFN% with wget
ECHO.
WGET -O"%TK%\%TKDLPATH%\%TKDLFN%" --no-check-certificate %TKDLURL%
ECHO.
ECHO Verifying
ECHO.
if %tkpause%==YES PAUSE
ECHO.
GOTO %TKSEC%

:DOWNLOAD1
SET TKDL=DOWNLOAD2

for %%I in (bitsadmin.exe) do if not exist "%%~$PATH:I" (
	if %TKPSVER% LEQ 1 (
		ECHO No BitsAdmin.exe, couldn't determine Powershell Version or Version 1.0 - Detected v%TKPSVER% - Skipping
		ECHO.
		if %tkpause%==YES PAUSE
		GOTO DOWNLOADCHECK
	)
	ECHO BitsAdmin.exe Not in path, using Powershell
	ECHO.
	if %tkpause%==YES PAUSE
	ECHO.
	IF %TKPSVER%==2 (
		ECHO Using powershell to download %TKDLFN% with BITS Powershell v2
		ECHO.
		"%TKPSEXE%" -command "Start-BitsTransfer -Source %TKDLURL% -Destination '%TK%\%TKDLPATH%\%TKDLFN%'"
	) ELSE (
	ECHO Using powershell to download %TKDLFN% with BITS Powershell v3 and newer
	ECHO.
	"%TKPSEXE%" -command "import-module bitstransfer; Start-BitsTransfer -Source %TKDLURL% -Destination '%TK%\%TKDLPATH%\%TKDLFN%'"
	)
) else (
    ECHO Downloading %TKDLFN% with BITS via BitsAdmin.exe
	ECHO.
	Bitsadmin /Transfer Toolkit /Download /Priority HIGH /ACLFlags O %TKDLURL% "%TK%\%TKDLPATH%\%TKDLFN%" > nul
	ECHO Download with BITS via BitsAdmin.exe complete
	ECHO.
	if %tkpause%==YES PAUSE
	ECHO.
)

ECHO Complete, going to DOWNLOADCHECK...
ECHO.
GOTO DOWNLOADCHECK

:DOWNLOAD2
SET TKDL=DOWNLOAD3
	REM Don't forget to escape closing parentheses
	ECHO First attempt failed. Beginning second attempt using VBS and CScript.exe...
	ECHO.
	
	ECHO Writing VBScript to %TK%\temp\tkdl.vbs
	ECHO.

	REM VBScript to download a file
	echo strFileURL = "%TKDLURL%"												> "%TK%\temp\tkdl.vbs"
	echo strHDLocation = "%TK%\%TKDLPATH%\%TKDLFN%"									  >> "%TK%\temp\tkdl.vbs"
	echo Set objXMLHTTP = CreateObject("MSXML2.ServerXMLHTTP.6.0"^)						   >> "%TK%\temp\tkdl.vbs"
	echo objXMLHTTP.open "GET", strFileURL, false								   >> "%TK%\temp\tkdl.vbs"
	echo objXMLHTTP.send(^)														 >> "%TK%\temp\tkdl.vbs"
	echo If objXMLHTTP.Status = 200 Then											>> "%TK%\temp\tkdl.vbs"
	echo Set objADOStream = CreateObject("ADODB.Stream"^)						   >> "%TK%\temp\tkdl.vbs"
	echo objADOStream.Open														  >> "%TK%\temp\tkdl.vbs"
	echo objADOStream.Type = 1 'adTypeBinary										>> "%TK%\temp\tkdl.vbs"
	echo objADOStream.Write objXMLHTTP.ResponseBody								 >> "%TK%\temp\tkdl.vbs"
	echo objADOStream.Position = 0												  >> "%TK%\temp\tkdl.vbs"
	echo Set objFSO = Createobject("Scripting.FileSystemObject"^)				   >> "%TK%\temp\tkdl.vbs"
	echo If objFSO.Fileexists(strHDLocation^) Then objFSO.DeleteFile strHDLocation  >> "%TK%\temp\tkdl.vbs"
	echo Set objFSO = Nothing													   >> "%TK%\temp\tkdl.vbs"
	echo objADOStream.SaveToFile strHDLocation									  >> "%TK%\temp\tkdl.vbs"
	echo objADOStream.Close														 >> "%TK%\temp\tkdl.vbs"
	echo Set objADOStream = Nothing												 >> "%TK%\temp\tkdl.vbs"
	echo End if																	 >> "%TK%\temp\tkdl.vbs"
	echo Set objXMLHTTP = Nothing												   >> "%TK%\temp\tkdl.vbs"

	ECHO Execute temp script
	ECHO.
	cscript "%TK%\temp\tkdl.vbs"
	if %tkpause%==YES PAUSE
	ECHO.
	ECHO Deleting %TK%\temp\tkdl.vbs
	ECHO.
	del /f /q "%TK%\temp\tkdl.vbs"
	
ECHO Complete, going to DOWNLOADCHECK...
ECHO.
GOTO DOWNLOADCHECK

:DOWNLOAD3
SET TKDL=DOWNLOAD4
	ECHO Second attempt failed. Beginning third attempt using Powershell.
	ECHO.

	ECHO Attempting download with Powershell V2
	ECHO.
	REM Powershell V2 (XP optional, Windows 7 default)
	powershell -Command "(New-Object Net.WebClient).DownloadFile('%TKDLURL%', '%TK%\%TKDLPATH%\%TKDLFN%')"
	ECHO Attempting download with Powershell V3
	ECHO.
	REM Powershell V3
	powershell -Command "Invoke-WebRequest %TKDLURL% -OutFile '%TK%\%TKDLPATH%\%TKDLFN%'"

ECHO Complete, going to DOWNLOADCHECK...
ECHO.
GOTO DOWNLOADCHECK

:DOWNLOAD4
SET TKDL=DOWNLOAD5
	ECHO Third attempt failed. Beginning fourth attempt using Python.
	ECHO.
	ECHO Searching for Python on C:
	ECHO.

	for /F "delims=" %%F in ('dir /B /S c:\python.exe 2^> nul') do (
		ECHO Testing %%F
		ECHO.
		pushd %%~dF%%~pF
		ECHO Getting Python version
		ECHO.
		python.exe --version 2> %temp%\python.txt
		for /F "tokens=1,2,3,4 delims=. " %%G in (%temp%\python.txt) do (
			ECHO Name %%G VerMaj %%H VerMin %%I VerSub %%J
			IF %%G==Python (
				ECHO Python Found
				IF %%H==2 (
					ECHO Attempting Pythin 2 Download
					ECHO.
					"%%F" -c "import urllib; urllib.urlretrieve ('%TKDLURL%', '%TK%\%TKDLPATH%\%TKDLFN%'^)"
				)
				IF %%H==3 (
					ECHO Attempting Python 3 Download
					ECHO.
					"%%F" -c "import urllib.request; urllib.request.urlretrieve ('%TKDLURL%', '%TK%\%TKDLPATH%\%TKDLFN%')"
				)
			)
		)
		popd
		ECHO Deleting temp\python.txt
		ECHO.
		del /f /q %temp%\python.txt
		
	)

	GOTO DOWNLOADCHECK

:DOWNLOADCHECK
ECHO Checking if download successful...
ECHO.
IF EXIST "%TK%\%TKDLPATH%\%TKDLFN%" (
	ECHO Success! Returning to %TKSEC%
	ECHO.
	if %tkpause%==YES PAUSE
	ECHO.
	GOTO %TKSEC%
) ELSE (
	IF %TKDL%==DOWNLOAD5 (
		ECHO Couldn't find wget.exe, please download and place on C drive
		GOTO END
	)
	ECHO Download unsuccessful, going to %TKDL%
	ECHO.
	GOTO %TKDL%
)

:DOWNEND

:END
ECHO TKDLFN=%TKDLFN%
ECHO TKDLURL=%TKDLURL%
ECHO TKDLPATH=%TKDLPATH%
ECHO TKSEC=%TKSEC%
ECHO Undo PHPRC Variable
SET "PHPRC=%PHPRCBAK%"
ECHO Undo PHPINI Variable
SET "PHPINI=%PHPINIBAK%"
ECHO.
ECHO Return to previous directory
ECHO.
popd

:EOF
ECHO End of script
ECHO.
PAUSE
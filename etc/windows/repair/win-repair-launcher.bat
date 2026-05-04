@echo off
setlocal EnableDelayedExpansion
title Win Repair

REM ANSI Escape Code for Colors
set "reset=[0m"

REM Strong Foreground Colors
set "white_fg_strong=[90m"
set "red_fg_strong=[91m"
set "green_fg_strong=[92m"
set "yellow_fg_strong=[93m"
set "blue_fg_strong=[94m"
set "magenta_fg_strong=[95m"
set "cyan_fg_strong=[96m"

REM Normal Background Colors
set "red_bg=[41m"
set "blue_bg=[44m"


REM ==========================================
REM Initialization & Safety Checks
REM ==========================================
REM Fail-safe: Unload any stuck registry hives from previous crashes
reg unload HKLM\Z_OFFLINE >nul 2>&1

REM Check for Admin Rights (Critical for WinRE/WinPE)
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo %red_bg%[ERROR]%reset% %red_fg_strong%Administrator privileges required.%reset%
    echo Please right-click and run as Administrator.
    pause
    exit
)

REM Architecture Check (Warn if 32-bit env trying to fix 64-bit OS)
set "ENV_ARCH="
reg query "HKLM\Hardware\Description\System\CentralProcessor\0" /v Identifier | find /i "x86" >nul && set "ENV_ARCH=x86" || set "ENV_ARCH=x64"
echo %cyan_fg_strong%[SYSTEM]%reset% Detected Environment Architecture: %ENV_ARCH%

REM %~dp0 dynamically grabs the exact folder this .bat file is running from
set "LOG_FILE=%~dp0WinRepair_Log.txt"
set "LOG_DIR=%~dp0NativeLogs"

REM Write Log Header
echo ========================================================= >> "%LOG_FILE%"
echo [%date% %time%] REPAIR SESSION STARTED >> "%LOG_FILE%"
echo Environment Arch: %ENV_ARCH% >> "%LOG_FILE%"
echo ========================================================= >> "%LOG_FILE%"

REM ==========================================
REM Main Menu
REM ==========================================
:home
title Win Repair [HOME]
cls
echo %blue_fg_strong%/ Home%reset%
echo -------------------------------------
echo 1. Fix Windows OS Health [CHKDSK DISM SFC]
echo 2. Rebuild Bootloader [Auto-Detect UEFI/BIOS]
echo 3. Revert Stuck Windows Updates [Update Bootloop Fix]
echo 4. Toolbox / Advanced Options
echo 0. Exit
echo -------------------------------------
set "choice="
set /p "choice=Choose Your Destiny (default is 1): "

if not defined choice set "choice=1"

if "%choice%"=="1" goto :repair_os
if "%choice%"=="2" goto :repair_boot
if "%choice%"=="3" goto :revert_updates
if "%choice%"=="4" goto :toolbox
if "%choice%"=="0" (
    echo [%date% %time%] SESSION ENDED >> "%LOG_FILE%"
    exit
)

echo %red_bg%[%time%]%reset% %red_fg_strong%[ERROR] Invalid input.%reset%
pause
goto :home

REM ==========================================
REM 1. OS Health Repair (CHKDSK -> DISM -> SFC)
REM ==========================================
:repair_os
title Win Repair [OS HEALTH]
cls
call :FindOS
if not defined OS_DRIVE ( call :logError "Windows OS not found." & pause & goto :home )

call :log "Step 1: Running CHKDSK on %OS_DRIVE%..."
chkdsk "%OS_DRIVE%" /f /x
if !errorlevel! neq 0 (
    call :logWarning "CHKDSK reported/fixed errors or returned non-zero. Review output if issues persist."
)

call :log "Step 2: Running DISM Image Repair..."
set "DISM_SOURCE="
set "DISM_INDEX=1"

REM Auto-Detect Index & Select Source
if exist "%~dp0sources\install.wim" (
    call :DetectWimIndex "%~dp0sources\install.wim"
    set "DISM_SOURCE=/source:WIM:%~dp0sources\install.wim:!DISM_INDEX! /limitaccess"
) else if exist "%~dp0sources\install.esd" (
    call :DetectWimIndex "%~dp0sources\install.esd"
    set "DISM_SOURCE=/source:ESD:%~dp0sources\install.esd:!DISM_INDEX! /limitaccess"
)

REM Use the OS drive for Scratch to prevent WinRE RAMDisk (X:\) Out-Of-Memory errors
set "SCRATCH_DIR=%OS_DRIVE%\Scratch"
md "%SCRATCH_DIR%" >nul 2>&1

if defined DISM_SOURCE (
    call :logSuccess "Using Offline Source (Index !DISM_INDEX!)..."
    dism /image:%OS_DRIVE%\ /cleanup-image /restorehealth !DISM_SOURCE! /ScratchDir:"%SCRATCH_DIR%"
    set "DISM_ERR=!errorlevel!"
    
    REM Retry Logic: If offline USB source fails, retry using standard online fallback
    if !DISM_ERR! neq 0 (
        call :logWarning "Offline DISM failed. Retrying without USB source restrictions..."
        dism /image:%OS_DRIVE%\ /cleanup-image /restorehealth /ScratchDir:"%SCRATCH_DIR%"
        set "DISM_ERR=!errorlevel!"
    )
) else (
    call :logWarning "No local source found. Running standard DISM."
    dism /image:%OS_DRIVE%\ /cleanup-image /restorehealth /ScratchDir:"%SCRATCH_DIR%"
    set "DISM_ERR=!errorlevel!"
)

rd "%SCRATCH_DIR%" /s /q >nul 2>&1

if !DISM_ERR! neq 0 (
    call :logError "DISM failed completely! Check native logs for details."
    call :extract_logs
    pause & goto :home
)

call :log "Step 3: Running System File Checker (SFC)..."
call :FindBOOT
sfc /scannow /offbootdir=%BOOT_DRIVE%\ /offwindir="%OS_DRIVE%\Windows"

if !errorlevel! neq 0 (
    call :logWarning "SFC found issues or could not complete. Check CBS log."
) else (
    call :logSuccess "SFC completed successfully."
)

call :extract_logs
call :logSuccess "OS Health Repair Attempt Finished!"
pause
goto :home

REM ==========================================
REM 2. Rebuild Bootloader (IMPROVED)
REM ==========================================
:repair_boot
title Win Repair [BOOT REBUILD]
cls
call :FindOS
if not defined OS_DRIVE ( call :logError "Windows OS not found." & pause & goto :home )

call :log "Detecting Firmware (UEFI vs Legacy BIOS)..."
mountvol S: /S >nul 2>&1

if exist "S:\EFI\Microsoft\Boot" (
    call :logSuccess "UEFI System detected. EFI mounted to S:"
    if exist "S:\EFI\Microsoft\Boot\BCD" ren "S:\EFI\Microsoft\Boot\BCD" BCD.old
    bcdboot "%OS_DRIVE%\Windows" /s S: /f UEFI
    if !errorlevel! equ 0 (
        call :logSuccess "UEFI Bootloader rebuilt."
    ) else (
        call :logError "UEFI BCDboot failed."
    )
) else (
    call :logWarning "No valid EFI partition found. Assuming Legacy BIOS / MBR."
    
    REM CRITICAL FIX: In WinPE, 'bcdboot' without /s often defaults to the USB stick.
    REM We force the boot files to the OS Drive partition (common for modern single-partition installs)
    REM or the user must have a dedicated System Reserved partition.
    
    REM Try writing to OS Drive first (Modern Standard)
    bcdboot "%OS_DRIVE%\Windows" /s %OS_DRIVE% /f BIOS
    if !errorlevel! equ 0 (
        call :logSuccess "Legacy BIOS Bootloader written to %OS_DRIVE%"
        call :logWarning "NOTE: Ensure BIOS boot order points to this drive."
    ) else (
        call :logError "Failed to write Legacy bootloader. Disk layout may be corrupt."
    )
)
call :extract_logs
pause
goto :home

REM ==========================================
REM 3. Revert Windows Updates
REM ==========================================
:revert_updates
title Win Repair [REVERT UPDATES]
cls
call :FindOS
if not defined OS_DRIVE ( call :logError "Windows OS not found." & pause & goto :home )

call :log "Reverting pending Windows Updates via DISM..."
set "SCRATCH_DIR=%OS_DRIVE%\Scratch"
md "%SCRATCH_DIR%" >nul 2>&1

dism /image:%OS_DRIVE%\ /cleanup-image /revertpendingactions /ScratchDir:"%SCRATCH_DIR%"
set "DISM_UPD_ERR=!errorlevel!"

rd "%SCRATCH_DIR%" /s /q >nul 2>&1

if !DISM_UPD_ERR! neq 0 (
    call :logWarning "DISM update revert failed or no pending actions found."
) else (
    call :logSuccess "Pending actions reverted! Reboot PC to test."
)
call :extract_logs
pause
goto :home

REM ==========================================
REM 4. Toolbox Frontend
REM ==========================================
:toolbox
title Win Repair [TOOLBOX]
cls
echo %blue_fg_strong%/ Home / Toolbox%reset%
echo -------------------------------------
echo 1. Disable Auto-Repair Loop (Reveals true BSOD code)
echo 2. Force Safe Mode on next boot
echo 3. Re-enable Normal Boot
echo -------------------------------------
echo 4. Run CMD
echo 5. Run Regedit
echo 6. Run Network Check
echo 0. Back to Home
echo -------------------------------------
set "toolbox_choice="
set /p toolbox_choice=Choose Your Destiny: 

if "%toolbox_choice%"=="1" (
    call :FindBCD
    if defined BCD_PATH (
        bcdedit /store "!BCD_PATH!" /set {default} recoveryenabled No
        call :logSuccess "Auto-Repair Disabled. Reboot to see exact BSOD."
    )
    pause & goto :toolbox
)
if "%toolbox_choice%"=="2" (
    call :FindBCD
    if defined BCD_PATH (
        bcdedit /store "!BCD_PATH!" /set {default} safeboot minimal
        call :logSuccess "Safe Mode forced for next boot."
    )
    pause & goto :toolbox
)
if "%toolbox_choice%"=="3" (
    call :FindBCD
    if defined BCD_PATH (
        bcdedit /store "!BCD_PATH!" /deletevalue {default} safeboot >nul 2>&1
        bcdedit /store "!BCD_PATH!" /set {default} recoveryenabled Yes >nul 2>&1
        call :logSuccess "Boot settings reverted to normal."
    )
    pause & goto :toolbox
)
if "%toolbox_choice%"=="4" start cmd & goto :toolbox
if "%toolbox_choice%"=="5" start regedit & goto :toolbox
if "%toolbox_choice%"=="6" goto :run_networkcheck
if "%toolbox_choice%"=="0" goto :home

echo %red_bg%[%time%]%reset% %red_fg_strong%[ERROR] Invalid input.%reset%
pause
goto :toolbox

:run_networkcheck
call :log "Initializing Networking..."
wpeutil initializenetwork
ping google.com -n 2 >nul 2>&1
if !errorlevel! neq 0 ( call :logError "Network unreachable." & pause & goto :toolbox )

for /f "tokens=1* delims=: " %%A in ('nslookup myip.opendns.com. resolver1.opendns.com 2^>NUL ^| find "Address:"') do set "ExtIP=%%B"
echo External IP is: %cyan_fg_strong%!ExtIP!%reset%
pause
goto :toolbox

REM ==========================================
REM System Detection Subroutines (IMPROVED)
REM ==========================================
:FindOS
set "OS_DRIVE="
set "OS_COUNT=0"
set "OS_LIST="

REM Scan drives for Windows installations
for %%d in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%d:\Windows\System32\config\SOFTWARE" (
        set /a OS_COUNT+=1
        set "OS_!OS_COUNT!=%%d:"
        set "OS_LIST=!OS_LIST! !OS_COUNT!. %%d:"
    )
)

if !OS_COUNT! equ 0 exit /b

REM If multiple OS found, ask user to choose
if !OS_COUNT! gtr 1 (
    cls
    echo %yellow_fg_strong%Multiple Windows Installations Detected:%reset%
    echo -------------------------------------
    for /L %%i in (1,1,!OS_COUNT!) do echo !OS_LIST!
    echo -------------------------------------
    set /p "choice=Select OS to repair (1-!OS_COUNT!): "
    
    set "OS_DRIVE="
    for /L %%i in (1,1,!OS_COUNT!) do (
        if "!choice!"=="%%i" set "OS_DRIVE=!OS_%%i!"
    )
    
    if not defined OS_DRIVE (
        call :logError "Invalid Selection."
        pause
        set "OS_DRIVE="
        exit /b
    )
) else (
    set "OS_DRIVE=!OS_1!"
)

call :logSuccess "Target OS Drive selected: !OS_DRIVE!"
exit /b

:FindBOOT
set "BOOT_DRIVE=%OS_DRIVE%"
mountvol S: /S >nul 2>&1
if exist "S:\EFI\Microsoft\Boot" set "BOOT_DRIVE=S:"
exit /b

:FindBCD
set "BCD_PATH="
mountvol S: /S >nul 2>&1
for %%d in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%d:\EFI\Microsoft\Boot\BCD" set "BCD_PATH=%%d:\EFI\Microsoft\Boot\BCD" & exit /b
    if exist "%%d:\Boot\BCD" set "BCD_PATH=%%d:\Boot\BCD" & exit /b
)
call :logError "Could not locate offline BCD store!"
exit /b

REM ==========================================
REM The "Final Boss" Subroutine: Auto-Detect WIM Index (IMPROVED)
REM ==========================================
:DetectWimIndex
set "WIM_FILE=%~1"
set "DISM_INDEX=1"
set "OS_EDITION="

call :log "Loading offline registry to detect Windows Edition..."
reg load HKLM\Z_OFFLINE "%OS_DRIVE%\Windows\System32\config\SOFTWARE" >nul 2>&1

if !errorlevel! neq 0 (
    call :logWarning "Registry load failed (Locked/Corrupt). Defaulting to Index 1."
    exit /b
)

REM Fetch EditionID
for /f "tokens=3" %%A in ('reg query "HKLM\Z_OFFLINE\Microsoft\Windows NT\CurrentVersion" /v EditionID 2^>nul') do set "OS_EDITION=%%A"

REM ALWAYS unload immediately
reg unload HKLM\Z_OFFLINE >nul 2>&1

if not defined OS_EDITION (
    call :logWarning "EditionID missing from registry. Defaulting to Index 1."
    exit /b
)

REM Translate raw EditionID into standard WIM Name strings
set "SEARCH_TERM=!OS_EDITION!"
if /i "!OS_EDITION!"=="Core" set "SEARCH_TERM=Home"
if /i "!OS_EDITION!"=="CoreN" set "SEARCH_TERM=Home N"
if /i "!OS_EDITION!"=="CoreSingleLanguage" set "SEARCH_TERM=Home Single Language"
if /i "!OS_EDITION!"=="CoreCountrySpecific" set "SEARCH_TERM=Home China"
if /i "!OS_EDITION!"=="Professional" set "SEARCH_TERM=Pro"
if /i "!OS_EDITION!"=="ProfessionalN" set "SEARCH_TERM=Pro N"
if /i "!OS_EDITION!"=="ProfessionalEducation" set "SEARCH_TERM=Pro Education"
if /i "!OS_EDITION!"=="ProfessionalWorkstation" set "SEARCH_TERM=Pro for Workstations"
if /i "!OS_EDITION!"=="Education" set "SEARCH_TERM=Education"
if /i "!OS_EDITION!"=="Enterprise" set "SEARCH_TERM=Enterprise"
if /i "!OS_EDITION!"=="EnterpriseS" set "SEARCH_TERM=Enterprise LTSC"

call :log "Customer OS Edition detected as: !SEARCH_TERM!"

set "TEMP_IDX=1"
REM Parse DISM output safely
for /f "tokens=1,* delims=:" %%A in ('dism /Get-WimInfo /wimfile:"!WIM_FILE!" 2^>nul ^| findstr /i "Index Name"') do (
    set "KEY=%%A"
    set "VAL=%%B"
    
    REM Cleanup Whitespace
    for /f "tokens=* delims= " %%a in ("!KEY!") do set "KEY=%%a"
    for /f "tokens=* delims= " %%a in ("!VAL!") do set "VAL=%%a"

    if /i "!KEY!"=="Index" (
        set "TEMP_IDX=!VAL!"
    )
    if /i "!KEY!"=="Name" (
        echo !VAL! | findstr /i /c:"!SEARCH_TERM!" >nul
        if !errorlevel! equ 0 (
            set "DISM_INDEX=!TEMP_IDX!"
            call :logSuccess "Matched WIM Index !DISM_INDEX! to OS Edition!"
            exit /b
        )
    )
)
call :logWarning "Could not find exact WIM match for !SEARCH_TERM!. Defaulting to Index 1."
exit /b

REM ==========================================
REM Logging Subroutines
REM ==========================================
:extract_logs
call :log "Extracting native Windows logs to USB Drive..."
md "%LOG_DIR%" >nul 2>&1
copy "%OS_DRIVE%\Windows\Logs\CBS\CBS.log" "%LOG_DIR%\SFC_CBS.log" /Y >nul 2>&1
copy "%OS_DRIVE%\Windows\Logs\DISM\dism.log" "%LOG_DIR%\DISM.log" /Y >nul 2>&1
copy "%OS_DRIVE%\Windows\System32\LogFiles\Srt\SrtTrail.txt" "%LOG_DIR%\SrtTrail.txt" /Y >nul 2>&1
exit /b

:log
echo %blue_bg%[%time%]%reset% %blue_fg_strong%[INFO]%reset% %~1
echo [%time%] [INFO] %~1 >> "%LOG_FILE%"
exit /b

:logSuccess
echo %blue_bg%[%time%]%reset% %green_fg_strong%[SUCCESS]%reset% %~1
echo [%time%] [SUCCESS] %~1 >> "%LOG_FILE%"
exit /b

:logWarning
echo %blue_bg%[%time%]%reset% %yellow_fg_strong%[WARNING]%reset% %~1
echo [%time%] [WARNING] %~1 >> "%LOG_FILE%"
exit /b

:logError
echo %red_bg%[%time%]%reset% %red_fg_strong%[ERROR]%reset% %~1
echo [%time%] [ERROR] %~1 >> "%LOG_FILE%"
exit /b
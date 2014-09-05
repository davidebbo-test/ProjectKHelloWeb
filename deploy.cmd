:: Setup
:: -----
@ECHO OFF
setlocal enabledelayedexpansion

set SCM_KRE_VERSION=1.0.0-alpha3
set SCM_KRE_ARCH=x86
set SCM_KRE_CLR_EDITION=svr50
:: path to project.json relative to deploy.cmd
:: use .\project.json if they are in the same folder, {FolderName}\project.json if in sub folder
set PROJECT_JSON=ProjectKHelloWeb\project.json
set KRE_NUGET_API_URL=https://www.myget.org/F/aspnetmaster/api/v2

:: Work around Kudu issue #1310
set HOME=%HOMEDRIVE%%HOMEPATH%

set KRE_HOME=%USERPROFILE%\.kre
set KPM_PATH=%KRE_HOME%\packages\KRE-%SCM_KRE_CLR_EDITION%-%SCM_KRE_ARCH%.%SCM_KRE_VERSION%\bin\kpm

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Deployment
:: ----------

echo Handling ProjetK Web Application deployment.

:: 1. Install KRE
call :ExecuteCmd PowerShell -NoProfile -NoLogo -ExecutionPolicy unrestricted -Command "[System.Threading.Thread]::CurrentThread.CurrentCulture = ''; [System.Threading.Thread]::CurrentThread.CurrentUICulture = '';& '%~dp0kvm.ps1' %*" install %SCM_KRE_VERSION%
IF !ERRORLEVEL! NEQ 0 goto error

:: 2. Run KPM Restore
call :ExecuteCmd %KPM_PATH% restore %PROJECT_JSON% --source %KRE_NUGET_API_URL% --source https://nuget.org/api/v2/
IF !ERRORLEVEL! NEQ 0 goto error

:: 3. Rename AspNet.Loader.dll
if exist %HOME%\site\wwwroot\bin\AspNet.Loader.dll (
    move %HOME%\site\wwwroot\bin\AspNet.Loader.dll %HOME%\site\AspNet.Loader.dll_old
)

:: 4. Run KPM Pack
call :ExecuteCmd %KPM_PATH% pack %PROJECT_JSON% --runtime KRE-%SCM_KRE_CLR_EDITION%-%SCM_KRE_ARCH%.%SCM_KRE_VERSION% --appfolder wwwroot --out %HOME%\site
IF !ERRORLEVEL! NEQ 0 goto error

:: 5. Cleanup possible .git folder in approot
call :CleanupArtifactsFolder
IF !ERRORLEVEL! NEQ 0 goto error
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

goto end

:: deleting .git folder if it got copied to the approot folder
:CleanupArtifactsFolder
setlocal
if exist %HOME%\site\approot\src\repository\.git (
    rd /q /s %HOME%\site\approot\src\repository\.git
)
if exist %HOME%\site\approot\src\repository\kvm.ps1 (
    del %HOME%\site\approot\src\repository\kvm.ps1
)
if exist %HOME%\site\approot\src\repository\.deployment (
    del %HOME%\site\approot\src\repository\.deployment
)
if exist %HOME%\site\approot\src\repository\deploy.cmd (
    del %HOME%\site\approot\src\repository\deploy.cmd
)
exit /b 0

:: Execute command routine that will echo out when error
:ExecuteCmd
setlocal
set _CMD_=%*
call %_CMD_%
if "%ERRORLEVEL%" NEQ "0" echo Failed exitCode=%ERRORLEVEL%, command=%_CMD_%
exit /b %ERRORLEVEL%

:error
endlocal
echo An error has occurred during web site deployment.
call :exitSetErrorLevel
call :exitFromFunction 2>nul

:exitSetErrorLevel
exit /b 1

:exitFromFunction
()

:end
endlocal
echo Finished successfully.
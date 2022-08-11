@echo off

setlocal

cd %~dp0..
set BASE_DIR=%CD%
set BIN_DIR=%BASE_DIR%\bin
set LIB_DIR=%BASE_DIR%\lib
set CONF_DIR=%BASE_DIR%\conf
set LOG_DIR=%BASE_DIR%\logs
set MAIN_JAR=%LIB_DIR%\${project.artifactId}-${project.version}.jar


if "%JAVA_HOME%" == "" (
    set JAVACMD=java
) else (
    set JAVACMD=%JAVA_HOME%\bin\java
)

if "%1" == "debug" goto doDebug
if "%1" == "start" goto doStart
if "%1" == "stop" goto doStop
if "%1" == "version" goto showVersion

echo Usage: app ^<command^>
echo command:
echo   debug        Start application under JPDA debugger
echo   start        Start application
echo   stop         Stop application
echo   version      Show application version
goto end

:doDebug
set DEBUG_PORT=${debug.port}
set DEBUG_OPTS=-agentlib:jdwp=transport=dt_socket,address=%DEBUG_PORT%,suspend=y,server=y
echo Debugging application ${project.artifactId}-${project.version}...
"%JAVACMD%" %DEBUG_OPTS% -Dapp.name="${project.artifactId}" -Dapp.version="${project.version}" -Dapp.home="%BASE_DIR%" -Dapp.lib="%LIB_DIR%" -Dapp.conf="%CONF_DIR%" -jar "%MAIN_JAR%"
goto end

:doStart
echo Starting application ${project.artifactId}-${project.version}...
"%JAVACMD%"  -Dapp.name="${project.artifactId}" -Dapp.version="${project.version}" -Dapp.home="%BASE_DIR%" -Dapp.lib="%LIB_DIR%" -Dapp.conf="%CONF_DIR%"  -jar "%MAIN_JAR%"
goto end

:doStop
set FIND_APP=false
for /f "tokens=1" %%a in ('jps^|find "${project.artifactId}-${project.version}.jar"') do (
    set FIND_APP=true
    echo Stopping application ${project.artifactId}-${project.version}...
    taskkill /F /PID %%a
    echo Stopped application ${project.artifactId}-${project.version} success.
)
if "%FIND_APP%" == "false" (
    echo No startup application ${project.artifactId}-${project.version}.
)
goto end

:showVersion
echo ${project.artifactId}-${project.version}
goto end

:end

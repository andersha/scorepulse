@echo off

rem Gradle wrapper script for Windows command-line builds

set GRADLE_VERSION=8.13

where gradle >nul 2>nul
if %errorlevel%==0 (
    gradle %*
) else (
    echo Please install Gradle %GRADLE_VERSION% or run from Android Studio
    echo Download from: https://services.gradle.org/distributions/gradle-%GRADLE_VERSION%-bin.zip
    exit /b 1
)

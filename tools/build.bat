
:: This script for compile the mixplorer theme file.
:: version: v1.2.0
:: author: @sionta (anatt.)
:: repository: https://github.com/dracula/mixplorer

@echo off

setlocal

:: 1=major, 2=minor, 0=patch
rem set version=1.2.0

set "root=%~dp0.."
set "file=%root%\dracula-mixplorer"
where /q 7z.exe || set "path=%~dp0bin;%path%"
pushd "%root%" && (
  echo LICENSE
  echo drawable\*
  echo fonts\*
  echo properties.xml
  echo README.md
  echo INSTALL.md
  echo screenshot.png
)>"%file%.txt"
7z.exe a -tzip "%file%.zip" @"%file%.txt"
move /y "%file%.zip" "%file%.mit"
del /f /q "%file%.txt"
popd & endlocal
exit /b

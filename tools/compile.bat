
:: This script for compile the mixplorer theme file.
:: author: 0x5df (anatt.)
:: version: v1.2.0
:: url: https://github.com/dracula/mixplorer

@echo off

setlocal enabledelayedexpansion

pushd "%~dp0..\"
set "basename=%cd%\dracula-mixplorer"
set "listfile=%cd%\include-list.txt"

:: 1=major, 2=minor, 0=revision
:: uncoment to set version number
rem set version=1.2.0

if not defined version (del /f /q "dracula*")

where /q 7z.exe || set "path=%cd%\tools\bin;%path%"

@(echo drawable\*.png
  echo fonts\*.ttf
  echo fonts\*.txt
  echo INSTALL.md
  echo LICENSE
  echo properties.xml
  echo README.md
  echo screenshot.png
)>"%listfile%"

7z a -tzip "%basename%.zip" @"%listfile%"

:: like dracula-mixplorer-v1.2.0.mit
if defined version (set "basename=!basename!-v!version!")

move /y "%basename%.zip" "%basename%.mit"
del /f /q "%listfile%"

endlocal
exit /b

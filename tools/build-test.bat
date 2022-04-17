@echo off
setlocal

del /f /q dracula*

pushd "%~dp0..\"

set "sevenzip=.\tools\7z.exe"
set "basename=.\tools\dracula-mixplorer"
set "listfile=.\tools\include-list"

( echo drawable\*.png
  echo fonts\*.ttf
  echo INSTALL.md
  echo LICENSE
  echo properties.xml
  echo README.md
  echo screenshot.png
)>"%listfile%.txt"

%sevenzip% a -tzip "%basename%.zip" @"%listfile%.txt"
move /y "%basename%.zip" "%basename%.mit"

endlocal
popd
exit /b

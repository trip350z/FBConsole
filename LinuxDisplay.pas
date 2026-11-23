unit LinuxDisplay;

{$mode objfpc}{$H+}

interface

implementation

{$IFDEF LCLQt6}
{$IFDEF Linux}
uses SysUtils;

function SetEnvironment(Name, Value:PChar; Overwrite:LongInt):LongInt;
  cdecl; external 'c' name 'setenv';

initialization
  { Run before Interfaces initializes QApplication. WSLg's Wayland backend
    can leave a hidden secondary window on screen. Keep explicit user choices
    and native Linux desktops unchanged. }
  if (GetEnvironmentVariable('WSL_DISTRO_NAME')<>'') and
     (GetEnvironmentVariable('DISPLAY')<>'') and
     (GetEnvironmentVariable('QT_QPA_PLATFORM')='') then
    SetEnvironment('QT_QPA_PLATFORM','xcb',1);
{$ENDIF}
{$ENDIF}

end.

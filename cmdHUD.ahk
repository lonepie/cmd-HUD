; Mintty quake console: Visor-like functionality for Windows
; Version: 1.8
; Author: Jon Rogers (lonepie@gmail.com)
; URL: https://github.com/lonepie/cmdHUD
; Credits:
;   Based on: https://github.com/lonepie/mintty-quake-console
;
; MIT License
; Copyright (c) 2018 Jon Rogers

; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:

; The above copyright notice and this permission notice shall be included in all
; copies or substantial portions of the Software.

; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.

;*******************************************************************************
;               Settings
;*******************************************************************************
#NoEnv
#SingleInstance force
SendMode Input
DetectHiddenWindows, on
SetWinDelay, -1

;*******************************************************************************
;               Preferences & Variables
;*******************************************************************************
VERSION = 1.8
SCRIPTNAME := "cmdHUD"
iniFile := A_ScriptDir . "\" . SCRIPTNAME . ".ini"
localIniFile := StrReplace(iniFile, ".ini", ".local.ini")
if (FileExist(localIniFile)) {
  iniFile := localIniFile
}
IniRead, cmdPath, %iniFile%, General, cmd_path, "cmd.exe"
IniRead, cmdArgs, %iniFile%, General, cmd_args, -
IniRead, consoleHotkey, %iniFile%, General, hotkey, ^``
IniRead, startWithWindows, %iniFile%, General, start_with_windows, 0
IniRead, startHidden, %iniFile%, General, start_hidden, 1
IniRead, autohide, %iniFile%, General, autohide_by_default, 0

IniRead, initialHeight, %iniFile%, Display, initial_height, 400
IniRead, initialWidth, %iniFile%, Display, initial_width, 100 ; percent
IniRead, initialTrans, %iniFile%, Display, initial_trans, 235 ; 0-255 stepping
IniRead, windowBorders, %iniFile%, Display, window_borders, 0
IniRead, displayOnMonitor, %iniFile%, Display, display_on_monitor, 0

IniRead, animate, %iniFile%, Animation, animate, 1
IniRead, animationMode, %iniFile%, Animation, animation_mode, "fade"
IniRead, animationStep, %iniFile%, Animation, animation_step, 20
IniRead, animationTimeout, %iniFile%, Animation, animation_timeout, 10

if !FileExist(iniFile)
{
    SaveSettings()
}
else
{
    ; add/remove windows startup if needed
    CheckWindowsStartup(startWithWindows)
}

cmdPath := ExpandEnvVars(cmdPath)
cmdArgs := ExpandEnvVars(cmdArgs)

; wsltty instead of cygwin
if InStr(cmdPath, "wsltty")
  SplitPath, cmdPath, , cygwinBinDir

; path to cmd
cmdPath_args := cmdPath . " " . cmdArgs

; initial height and width of console window
heightConsoleWindow := initialHeight
widthConsoleWindow := initialWidth

isVisible := False

;*******************************************************************************
;               Hotkeys
;*******************************************************************************
Hotkey, %consoleHotkey%, ConsoleHotkey

;*******************************************************************************
;               Menu
;*******************************************************************************
if !InStr(A_ScriptName, ".exe")
  Menu, Tray, Icon, %A_ScriptDir%\%SCRIPTNAME%.ico
Menu, Tray, NoStandard
; Menu, Tray, MainWindow
Menu, Tray, Tip, %SCRIPTNAME% %VERSION%
Menu, Tray, Click, 1
Menu, Tray, Add, Show/Hide, ToggleVisible
Menu, Tray, Default, Show/Hide
Menu, Tray, Add, Enabled, ToggleScriptState
Menu, Tray, Check, Enabled
Menu, Tray, Add, Auto-Hide, ToggleAutoHide
if (autohide)
    Menu, Tray, Check, Auto-Hide
Menu, Tray, Add
Menu, Tray, Add, Options, ShowOptionsGui
Menu, Tray, Add, Edit Config, EditSettings
Menu, Tray, Add, About, AboutDlg
Menu, Tray, Add, Reload, ReloadSub
Menu, Tray, Add, Exit, ExitSub

init()
return
;*******************************************************************************
;               Functions / Labels
;*******************************************************************************
init()
{
    global
    initCount++
    ; get last active window
    WinGet, hw_current, ID, A
    if !WinExist("ahk_class cmd") {
        hw_cmd = 0
        Run %cmdPath_args%, %cygwinBinDir%, Hide, hw_cmd
        WinWait ahk_pid %hw_cmd%, , 1
        if ErrorLevel {
            ; WinWait Timed out (WHY?!?)
            WinGet, hw_cmd, PID, ahk_exe %cmdPath%
        }
    }
    else {
        WinGet, hw_cmd, PID, ahk_class cmd
    }

    WinGetPos, OrigXpos, OrigYpos, OrigWinWidth, OrigWinHeight, ahk_pid %hw_cmd%
    toggleScript("init")
}

toggle()
{
    global

    IfWinActive ahk_pid %hw_cmd%
    {
        Slide("ahk_pid" . hw_cmd, "Out")

        WinGet, hw_current_minmax, MinMax, ahk_id %hw_current%
        ; don't re-activate last window if we've minimized it
        if (hw_current_minmax <> -1) {
            ; reset focus to last active window
            WinActivate, ahk_id %hw_current%
        }
    }
    else
    {
        ; get last active window
        WinGet, hw_current, ID, A

        WinActivate ahk_pid %hw_cmd%
        Slide("ahk_pid" . hw_cmd, "In")
    }
}

Slide(Window, Dir)
{
    global widthConsoleWindow, animationModeFade, animationModeSlide, animationStep, animationTimeout, autohide, isVisible, currentTrans, initialTrans
    WinGetPos, Xpos, Ypos, WinWidth, WinHeight, %Window%

    WinGet, testTrans, Transparent, %Window%
    if (testTrans = "" or (animationModeFade and currentTrans = 0))
    {
        ; Solution for Windows 8 to find window without borders, only 1st call will flash borders
        WinSet, Style, +0x040000, %Window% ; show window border
        WinSet, Transparent, %currentTrans%, %Window%
        if (!windowBorders)
            WinSet, Style, -0x040000, %Window% ; hide window border
        ; this problem seems to happen if cmd's transparency is set to "Off"
        ; cmd will lose transparency when the window loses focus, so it's best to just use
        ; cmd's built in transparency setting
    }

    VirtScreenPos(ScreenLeft, ScreenTop, ScreenWidth, ScreenHeight)

    if (animationModeFade)
    {
        WinMove, %Window%,, WinLeft, ScreenTop
    }

    ; Multi monitor support.  Always move to current window
    If (Dir = "In")
    {
        WinShow %Window%
        width := ScreenWidth * widthConsoleWindow / 100
        if (displayOnMonitor  > 0)
            WinLeft := ScreenLeft
        else
            WinLeft := ScreenLeft + (1 - widthConsoleWindow/100) * ScreenWidth / 2
        WinMove, %Window%, , WinLeft, , width
    }
    Loop
    {
        inConditional := (animationModeSlide) ? (Ypos >= ScreenTop) : (currentTrans == initialTrans)
        outConditional := (animationModeSlide) ? (Ypos <= (-WinHeight)) : (currentTrans == 0)

        If (Dir = "In") And inConditional Or (Dir = "Out") And outConditional
            Break

        if (animationModeFade = 1)
        {
            dRate := animationStep/300*255
            dT := % (Dir = "In") ? currentTrans + dRate : currentTrans - dRate
            dT := (dT < 0) ? 0 : ((dT > initialTrans) ? initialTrans : dT)

            WinSet, Transparent, %dT%, %Window%
            currentTrans := dT
        }
        else
        {
            dRate := animationStep
            dY := % (Dir = "In") ? Ypos + dRate : Ypos - dRate
            WinMove, %Window%,,, dY
        }

        WinGetPos, Xpos, Ypos, WinWidth, WinHeight, %Window%
        Sleep, %animationTimeout%
    }

    If (Dir = "In")  {
        WinMove, %Window%,,, ScreenTop
        if (autohide)
            SetTimer, HideWhenInactive, 250
        isVisible := True
    }
    If (Dir = "Out")  {
        WinHide %Window%
        if (autohide)
            SetTimer, HideWhenInactive, Off
        isVisible := False
    }
}

toggleScript(state) {
    ; enable/disable script effects, hotkeys, etc
    global
    ; WinGetPos, Xpos, Ypos, WinWidth, WinHeight, ahk_pid %hw_cmd%
    if (state = "on" or state = "init") {
        If !WinExist("ahk_pid" . hw_cmd) {
            init()
            return
        }

        ; use cmd's transparency setting, if it's set
        WinGet, cmdTrans, Transparent, ahk_pid %hw_cmd%
        if (cmdTrans <> "")
            initialTrans:=cmdTrans
        WinSet, Transparent, %initialTrans%, ahk_pid %hw_cmd%
        currentTrans:=initialTrans

        WinHide ahk_pid %hw_cmd%
        if (!windowBorders)
            WinSet, Style, -0xC40000, ahk_pid %hw_cmd% ; hide window borders and caption/title

        VirtScreenPos(ScreenLeft, ScreenTop, ScreenWidth, ScreenHeight)

        width := ScreenWidth * widthConsoleWindow / 100
        left := ScreenLeft + ((ScreenWidth - width) /  2)
        WinMove, ahk_pid %hw_cmd%, , %left%, -%heightConsoleWindow%, %width%, %heightConsoleWindow% ; resize/move

        scriptEnabled := True
        Menu, Tray, Check, Enabled

        if (state = "init" and initCount = 1 and startHidden) {
            return
        }

        WinShow ahk_pid %hw_cmd%
        WinActivate ahk_pid %hw_cmd%
        Slide("ahk_pid" . hw_cmd, "In")
    }
    else if (state = "off") {
            WinSet, Style, +0xC40000, ahk_pid %hw_cmd% ; show window borders and caption/title
        if (OrigYpos >= 0)
            WinMove, ahk_pid %hw_cmd%, , %OrigXpos%, %OrigYpos%, %OrigWinWidth%, %OrigWinHeight% ; restore size / position
        else
            WinMove, ahk_pid %hw_cmd%, , %OrigXpos%, 100, %OrigWinWidth%, %OrigWinHeight%
        WinShow, ahk_pid %hw_cmd% ; show window
        scriptEnabled := False
        Menu, Tray, Uncheck, Enabled
    }
}

HideWhenInactive:
    IfWinNotActive ahk_pid %hw_cmd%
    {
        Slide("ahk_pid" . hw_cmd, "Out")
        SetTimer, HideWhenInactive, Off
    }
return

ToggleVisible:
    if (isVisible)
    {
        Slide("ahk_pid" . hw_cmd, "Out")
    }
    else
    {
        WinActivate ahk_pid %hw_cmd%
        Slide("ahk_pid" . hw_cmd, "In")
    }
return

ToggleScriptState:
    if (scriptEnabled)
        toggleScript("off")
    else
        toggleScript("on")
return

ToggleAutoHide:
    autohide := !autohide
    Menu, Tray, ToggleCheck, Auto-Hide
    SetTimer, HideWhenInactive, Off
    SaveSettings()
return

ConsoleHotkey:
    if (scriptEnabled) {
        IfWinExist ahk_pid %hw_cmd%
        {
            toggle()
        }
        else
        {
            init()
        }
    }
return

ExitSub:
    if A_ExitReason not in Logoff,Shutdown
    {
        MsgBox, 4, %SCRIPTNAME%, Are you sure you want to exit?
        IfMsgBox, No
            return
        toggleScript("off")
    }
ExitApp

ReloadSub:
Reload
return

AboutDlg:
    MsgBox, 64, About, %SCRIPTNAME% AutoHotkey script`nVersion: %VERSION%`nAuthor: Jonathon Rogers <lonepie@gmail.com>`nURL: https://github.com/lonepie/cmdHUD
return

ShowOptionsGui:
    OptionsGui()
return

EditSettings:
EnvGet, envEditor, Editor
if (StrLen(Trim(envEditor)) == 0)
    envEditor := "notepad.exe"
Run, %envEditor% %iniFile%
return

;*******************************************************************************
;               Extra Hotkeys
;*******************************************************************************
#IfWinActive ahk_class cmd
; why this method doesn't work, I don't know...
; IncreaseHeight:
^!NumpadAdd::
^+=::
    if (WinActive("ahk_pid" . hw_cmd)) {

    VirtScreenPos(ScreenLeft, ScreenTop, ScreenWidth, ScreenHeight)
    if (heightConsoleWindow < ScreenHeight) {
            heightConsoleWindow += animationStep
            WinMove, ahk_pid %hw_cmd%,,,,, heightConsoleWindow
        }
    }
return
; DecreaseHeight:
^!NumpadSub::
^+-::
    if (WinActive("ahk_pid" . hw_cmd)) {
        if (heightConsoleWindow > 100) {
            heightConsoleWindow -= animationStep
            WinMove, ahk_pid %hw_cmd%,,,,, heightConsoleWindow
        }
    }
return
; Decrease Width
^![::
    if (widthConsoleWindow >= 20) {
        widthConsoleWindow -= 5
        VirtScreenPos(ScreenLeft, ScreenTop, ScreenWidth, ScreenHeight)

        width := ScreenWidth * widthConsoleWindow / 100
        left := ScreenLeft + ((ScreenWidth - width) /  2)
        WinMove, ahk_pid %hw_cmd%, , %left%, , %width%  ; resize/move
    }
return
; Increase Width
^!]::
    if (widthConsoleWindow < 100) {
        widthConsoleWindow += 5

        VirtScreenPos(ScreenLeft, ScreenTop, ScreenWidth, ScreenHeight)

        width := ScreenWidth * widthConsoleWindow / 100
        left := ScreenLeft + ((ScreenWidth - width) /  2)
        WinMove, ahk_pid %hw_cmd%, , %left%, , %width%  ; resize/move
    }
return
; Toggle window borders
^!NumpadDiv::
    WinSet, Style, ^0xC40000, ahk_pid %hw_cmd%
    windowBorders := !windowBorders
return
; Save Height & border state to ini
^!NumpadMult::
    IniWrite, %heightConsoleWindow%, %iniFile%, Display, initial_height
    IniWrite, %widthConsoleWindow%, %iniFile%, Display, initial_width
    IniWrite, %windowBorders%, %iniFile%, Display, window_borders
return
; Toggle script on/off
^!NumpadDot::
    GoSub, ToggleScriptState
return
#IfWinActive

;*******************************************************************************
;               Options
;*******************************************************************************
SaveSettings()
{
    global
    IniWrite, %cmdPath%, %iniFile%, General, cmd_path
    IniWrite, %cmdArgs%, %iniFile%, General, cmd_args

    ; Special case : If there is no key entered and both windows key and control key are checked
    If (consoleHotkey == "" and ControlKey and WindowsKey)
    {
        consoleHotkey = ^LWin
    }
    Else If (consoleHotkey != "")
    {
        ; If the Windows Key checkbox is checked and there isn't already the Windows key in the hotkey string, we add it
        If (WindowsKey)
        {
            IfNotInString, consoleHotkey, #
                consoleHotkey = #%consoleHotkey%
        }

        ; If the Control Key checkbox is checked and there isn't already the Control key in the hotkey string, we add it
        If (ControlKey)
        {
            IfNotInString, consoleHotkey, ^
                consoleHotkey = ^%consoleHotkey%
        }

    }
    ; In case the hotkey is empty and only one of the checkbox is checked, we put back the default value
    Else
    {
        consoleHotkey = ^``
    }

    IniWrite, %consoleHotkey%, %iniFile%, General, hotkey
    IniWrite, %startWithWindows%, %iniFile%, Display, start_with_windows
    IniWrite, %startHidden%, %iniFile%, Display, start_hidden
    IniWrite, %heightConsoleWindow%, %iniFile%, Display, initial_height
    IniWrite, %widthConsoleWindow%, %iniFile%, Display, initial_width
    IniWrite, %initialTrans%, %iniFile%, Display, initial_trans
    IniWrite, %autohide%, %iniFile%, Display, autohide_by_default
    IniWrite, %animationModeSlide%, %iniFile%, Display, animation_mode_slide
    IniWrite, %animationModeFade%, %iniFile%, Display, animation_mode_fade
    IniWrite, %animationStep%, %inifile%, Display, animation_step
    IniWrite, %animationTimeout%, %iniFile%, Display, animation_timeout
    IniWrite, %windowBorders%, %iniFile%, Display, window_borders
    CheckWindowsStartup(startWithWindows)
}

CheckWindowsStartup(enable) {
    SplitPath, A_ScriptName, , , , OutNameNoExt
    LinkFile=%A_Startup%\%OutNameNoExt%.lnk

    if !FileExist(LinkFile) {
        if (enable) {
            FileCreateShortcut, %A_ScriptFullPath%, %LinkFile%
        }
    }
    else {
        if (!enable) {
            FileDelete, %LinkFile%
        }
    }
}

OptionsGui() {
    global
    If not WinExist("ahk_id" GuiID) {
        Gui, Add, GroupBox, x12 y10 w450 h110 , General
        Gui, Add, GroupBox, x12 y130 w450 h250 , Display
        Gui, Add, Button, x242 y390 w100 h30 Default, Save
        Gui, Add, Button, x362 y390 w100 h30 , Cancel
        Gui, Add, Text, x22 y30 w70 h20 , Mintty Path:
        Gui, Add, Edit, x92 y30 w250 h20 VcmdPath, %cmdPath%
        Gui, Add, Button, x352 y30 w100 h20, Browse
        Gui, Add, Text, x22 y60 w100 h20 , Mintty Arguments:
        Gui, Add, Edit, x122 y60 w330 h20 VcmdArgs, %cmdArgs%
        Gui, Add, Text, x22 y90 w100 h20 , Hotkey Trigger:
        Gui, Add, Text, x232 y92 w10 h10, +
        Gui, Add, CheckBox, x245 y89 w90 h20 VWindowsKey, Windows Key
        Gui, Add, Text, x340 y92 w10 h10, +
        Gui, Add, CheckBox, x360 y89 w80 h20 VControlKey, Control Key
        ; If there is a # (Windows Key) in the consoleHotkey var, we remove it, as the Hotkey control doesn't support it, and we check the Windows Key checkbox
        IfInString, consoleHotkey, #
        {
            GuiControl, , WindowsKey, 1
            StringReplace, consoleHotkey, consoleHotkey, # , , All
        }
        Gui, Add, Hotkey, x122 y90 w100 h20 VconsoleHotkey, %consoleHotkey%
        Gui, Add, CheckBox, x22 y150 w100 h30 VstartHidden Checked%startHidden%, Start Hidden
        Gui, Add, CheckBox, x22 y180 w150 h30 Vautohide Checked%autohide%, Auto-Hide when focus is lost
        Gui, Add, CheckBox, x22 y210 w120 h30 VstartWithWindows Checked%startWithWindows%, Start With Windows
        Gui, Add, Text, x22 y250 w100 h20 , Initial Height (px):
        Gui, Add, Edit, x22 y270 w100 h20 VinitialHeight, %heightConsoleWindow%
        Gui, Add, Text, x22 y300 w115 h20 , Initial Width (percent):
        Gui, Add, Edit, x22 y320 w100 h20 VinitialWidth, %widthConsoleWindow%

        Gui, Add, GroupBox, x232 y150 w220 h45 , Animation Type:
        Gui, Add, Radio, x252 y168 w70 h20 VanimationModeSlide group Checked%animationModeSlide%, Slide
        Gui, Add, Radio, x332 y168 w70 h20 VanimationModeFade Checked%animationModeFade%, Fade

        Gui, Add, Text, x232 y210 w220 h20 , Animation Delta (px):
        Gui, Add, Text, x232 y260 w220 h20 , Animation Time (ms):
        Gui, Add, Slider, x232 y230 w220 h30 VanimationStep Range1-100 TickInterval20 , %animationStep%
        Gui, Add, Slider, x232 y280 w220 h30 VanimationTimeout Range1-50 TickInterval10, %animationTimeout%
        Gui, Add, Text, x232 y310 w220 h20 , Window Transparency (`%):
        Gui, Add, Slider, x232 y330 w220 h30 VinitialTrans Range100-255 , %initialTrans%
        ; Gui, Add, Text, x232 y320 w220 h20 +Center, Animation Speed = Delta / Time
    }
    ; Generated using SmartGUI Creator 4.0
    Gui, Show, h440 w482, %SCRIPTNAME% Options
    Gui, +LastFound
    GuiID := WinExist()

    Loop {
        ;sleep to reduce CPU load
        Sleep, 100

        ;exit endless loop, when settings GUI closes
        If not WinExist("ahk_id" GuiID)
            Break
    }

    ButtonSave:
        Gui, Submit
        SaveSettings()
        Reload
    return

    ButtonBrowse:
        FileSelectFile, SelectedPath, 3, %A_MyDocuments%, Path to cmd.exe, Executables (*.exe)
        if SelectedPath !=
            GuiControl,, MinttyPath, %SelectedPath%
    return

    GuiClose:
    GuiEscape:
    ButtonCancel:
        Gui, Cancel
    return
}

;*******************************************************************************
;               Utility
;*******************************************************************************
; Gets the edge that the taskbar is docked to.  Returns:
;   "top"
;   "right"
;   "bottom"
;   "left"

VirtScreenPos(ByRef mLeft, ByRef mTop, ByRef mWidth, ByRef mHeight)
{
    global displayOnMonitor
    if (displayOnMonitor > 0) {
        SysGet, Mon, Monitor, %displayOnMonitor%
        SysGet, MonArea, MonitorWorkArea, %displayOnMonitor%

        mLeft:=MonAreaLeft
        mTop:=MonAreaTop
        mWidth:=(MonAreaRight - MonAreaLeft)
        mHeight:=(MonAreaBottom - MonAreaTop)
    }
    else {
        Coordmode, Mouse, Screen
        MouseGetPos,x,y
        SysGet, m, MonitorCount

        ; Iterate through all monitors.
        Loop, %m%
        {   ; Check if the window is on this monitor.
            SysGet, Mon, Monitor, %A_Index%
            SysGet, MonArea, MonitorWorkArea, %A_Index%
            if (x >= MonLeft && x <= MonRight && y >= MonTop && y <= MonBottom)
            {
                mLeft:=MonAreaLeft
                mTop:=MonAreaTop
                mWidth:=(MonAreaRight - MonAreaLeft)
                mHeight:=(MonAreaBottom - MonAreaTop)
            }
        }
    }
}
ExpandEnvVars(ppath)
{
	VarSetCapacity(dest, 2000)
	DllCall("ExpandEnvironmentStrings", "str", ppath, "str", dest, int, 1999, "Cdecl int")
	return dest
}

/*
ResizeAndCenter(w, h)
{
  ScreenX := GetScreenLeft()
  ScreenY := GetScreenTop()
  ScreenWidth := GetScreenWidth()
  ScreenHeight := GetScreenHeight()

  WinMove A,,ScreenX + (ScreenWidth/2)-(w/2),ScreenY + (ScreenHeight/2)-(h/2),w,h
}
*/

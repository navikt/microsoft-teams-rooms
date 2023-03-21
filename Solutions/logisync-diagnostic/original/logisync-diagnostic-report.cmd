@echo off

REM optional script param: [final zip path with collected info] [tmp_output_dir]
@if [%1]==[] (set final_archive="%HOMEDRIVE%%HOMEPATH%\Logitech-report.zip") else (set final_archive=%1)
@if [%2]==[] (
	@set tmp_output_dir="%tmp%\logi_logs"
) else (
	@set tmp_output_dir=%2
)
@echo temp dir is %tmp_output_dir%
@rd /s /q %tmp_output_dir%
@mkdir %tmp_output_dir%
@mkdir %tmp_output_dir%\sync

@echo Collecting system info
@systeminfo > %tmp_output_dir%\system_info.txt

@echo Collecting services info
@sc queryex type= service state= all > %tmp_output_dir%\services_info.txt

@echo Checking internet connection:
@echo - Ping Google DNS
@ping 8.8.8.8 > %tmp_output_dir%\ping.txt
@echo - Ping Logitech.com
@ping logitech.com >> %tmp_output_dir%\ping.txt

@echo Checking logitech network services
@call domains-diagnostic.cmd -verbose > %tmp_output_dir%\network_services.txt

@echo Print Logitech and other attached devices
"%~dp0devcon.exe" status *046d* > %tmp_output_dir%\devices.txt
@echo "" >> %tmp_output_dir%\devices.txt
@echo "ALL:" >> %tmp_output_dir%\devices.txt
"%~dp0devcon.exe" status * >> %tmp_output_dir%\devices.txt

@echo Collecting logs and settings
@xcopy %ProgramData%\Logitech\LogiSync\* %tmp_output_dir%\sync /s
@xcopy "%ProgramFiles(x86)%\Logitech\LogiSync\sync-agent\version.info" %tmp_output_dir%
@xcopy %SystemRoot%\Temp\RightSight.log %tmp_output_dir%
@move %tmp_output_dir%\RightSight.log %tmp_output_dir%\RightSight-old.log
@xcopy %SystemRoot%\ServiceProfiles\LocalService\AppData\Local\Temp\RightSight.log %tmp_output_dir%
REM copy files like *Provision/provisioning stub/result log/txt
@xcopy %SystemRoot%\Temp\LogiSync\*rovision* %tmp_output_dir%

@echo Preparing zip
@set zipper_script="%tmp%\Logitech-zip.vbs"
@echo Set objArgs = WScript.Arguments > %zipper_script%
@echo Set FS = CreateObject("Scripting.FileSystemObject") >> %zipper_script%
@echo InputFolder = FS.GetAbsolutePathName(objArgs(0)) >> %zipper_script%
@echo ZipFile = FS.GetAbsolutePathName(objArgs(1)) >> %zipper_script%
@echo|set /p="CreateObject("Scripting.FileSystemObject").CreateTextFile(ZipFile, True).Write "PK" & Chr(5) & Chr(6) & String(18, vbNullChar)" >> %zipper_script%
@echo. >> %zipper_script%
@echo Set objShell = CreateObject("Shell.Application") >> %zipper_script%
@echo Set source = objShell.NameSpace(InputFolder).Items >> %zipper_script%
REM sleep removal code from https://superuser.com/questions/110991/can-you-zip-a-file-from-the-command-prompt-using-only-windows-built-in-capabili
@echo Set ZipDest = objShell.NameSpace(ZipFile) >> %zipper_script%
REM Count gets 0 if no archive existed bedore
@echo Count=ZipDest.Items().Count >> %zipper_script%
@echo objShell.NameSpace(ZipFile).CopyHere(source) >> %zipper_script%
REM ZipDest.Items().Count will also contain 0 untill archive is updated
@echo Count=ZipDest.Items().Count >> %zipper_script%
@echo Do While Count = ZipDest.Items().Count >> %zipper_script%
@echo     wScript.Sleep 100 >> %zipper_script%
@echo Loop >> %zipper_script%

@cscript "%zipper_script%" "%tmp_output_dir%" %final_archive%
@if exist %final_archive% (
	@echo A zip file %final_archive% generated. Send it to developers.
) else (
	@echo Can't find generated file %final_archive%. Please send this info to developers.
)

@del %zipper_script%
if [%1]==[] pause
@echo Done

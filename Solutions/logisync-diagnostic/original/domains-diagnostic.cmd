@echo off

@chdir /D %~dp0

@NetworkDiagnosticTool.exe -host=sync.logitech.com -port=443 %1
@NetworkDiagnosticTool.exe -host=updates.logitech.com -port=80 %1
@NetworkDiagnosticTool.exe -host=logitech.com -port=443 %1
@NetworkDiagnosticTool.exe -host=updates.vc.logitech.com -port=443 %1
@NetworkDiagnosticTool.exe -host=svcs.vc.logitech.com -port=443 %1
::@NetworkDiagnosticTool.exe -host=cloudfront.net -port=443 %1
@NetworkDiagnosticTool.exe -host=releasenotes.vc.logitech.com -port=443 %1
@NetworkDiagnosticTool.exe -host=cdn.lr-ingest.io -port=443 %1
@NetworkDiagnosticTool.exe -host=r.lr-ingest.io -port=443 %1
@NetworkDiagnosticTool.exe -host=22ulqg35c4-dsn.algolia.net -port=443 %1
@NetworkDiagnosticTool.exe -host=a3fejkt9utwjk2-ats.iot.us-west-2.amazonaws.com -port=443 %1
@NetworkDiagnosticTool.exe -host=e937fa0aeeab484884e6be905b6106bb.us-west-2.aws.found.io -port=443 %1
::@NetworkDiagnosticTool.exe -host=elb.amazonaws.com -port=443 %1
@NetworkDiagnosticTool.exe -host=cognito-idp.us-west-2.amazonaws.com -port=443 %1

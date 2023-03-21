Push-Location "C:\Program Files (x86)\Logitech\LogiSync\sync-agent\"

$final_archive = if ($args[0]) { $args[0] } else { "$env:HOMEDRIVE$env:HOMEPATH\Logitech-report-$env:COMPUTERNAME-$((Get-Date).ToFileTime()).zip" }
$tmp_output_dir = if ($args[1]) { $args[1] } else { "$env:tmp\logi_logs" }
Write-Output "temp dir is $tmp_output_dir"
Remove-Item -Recurse -Force $tmp_output_dir -ErrorAction SilentlyContinue
Remove-Item -Force $final_archive -ErrorAction SilentlyContinue
New-Item -ItemType Directory $tmp_output_dir
New-Item -ItemType Directory "$tmp_output_dir\sync"

Write-Output "Collecting system info"
systeminfo | Out-File "$tmp_output_dir\system_info.txt"

Write-Output "Collecting services info"
sc.exe queryex type= service state= all | Out-File "$tmp_output_dir\services_info.txt"

Write-Output "Checking internet connection:"
Write-Output "- Ping Google DNS"
ping 8.8.8.8 | Out-File "$tmp_output_dir\ping.txt"
Write-Output "- Ping Logitech.com"
ping logitech.com | Out-File "$tmp_output_dir\ping.txt" -Append

Write-Output "Checking logitech network services"
.\domains-diagnostic.cmd -verbose | Out-File "$tmp_output_dir\network_services.txt"

Write-Output "Print Logitech and other attached devices"
& ".\devcon.exe" status *046d* | Out-File "$tmp_output_dir\devices.txt"
Out-File "$tmp_output_dir\devices.txt" -Append -InputObject ""
Out-File "$tmp_output_dir\devices.txt" -Append -InputObject "ALL:"
& ".\devcon.exe" status * | Out-File "$tmp_output_dir\devices.txt" -Append

Write-Output "Collecting logs and settings"
Copy-Item "$env:ProgramData\Logitech\LogiSync\*" "$tmp_output_dir\sync" -Recurse -ErrorAction SilentlyContinue
Copy-Item "version.info" $tmp_output_dir -ErrorAction SilentlyContinue
Copy-Item "$env:SystemRoot\Temp\RightSight.log" $tmp_output_dir -ErrorAction SilentlyContinue
Move-Item "$tmp_output_dir\RightSight.log" "$tmp_output_dir\RightSight-old.log" -ErrorAction SilentlyContinue
Copy-Item "$env:SystemRoot\ServiceProfiles\LocalService\AppData\Local\Temp\RightSight.log" $tmp_output_dir -ErrorAction SilentlyContinue
Copy-Item "$env:SystemRoot\Temp\LogiSync\*rovision*" $tmp_output_dir -Recurse -ErrorAction SilentlyContinue

Write-Output "Preparing zip"

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($tmp_output_dir, $final_archive)

if(Test-Path $final_archive) {
    Write-Output "Zip file created at: $final_archive"
}

# Upload file to Azure

# Replace the following placeholders with your storage account name and the SAS token
$storageAccountName = ""
$sasToken = ""

# Replace the following placeholder with the name of your storage container
$containerName = ""

# Replace the following placeholder with the path to the zip file
$filePath = $final_archive

# Get the file name from the file path
$fileName = Split-Path -Leaf $filePath

# Set the headers for the request
# Set the headers for the request
$headers = @{
    "Content-Type" = "application/octet-stream"
    "x-ms-blob-type" = "BlockBlob"
}


# Set the URI for the storage container, including the SAS token
$uri = "https://$storageAccountName.blob.core.windows.net/$containerName/$($fileName)?$sasToken"

# Read the contents of the file into a byte array
$fileContent = [IO.File]::ReadAllBytes($filePath)

# Send a PUT request to upload the file to the storage container
Invoke-RestMethod -Method Put -Uri $uri -Body $fileContent -Headers $headers


Write-Host "Hello..."
Write-Host "email from rundeck vault    :" $email
Write-Host "Api key from rundeck vault  :" $GLPIapiAppToken
Write-Host "Api user from rundeck vault :" $GLPIuserApiToken
Write-Host "GitHub Uri                  :" $GitHubUri

$gamOU = "/ZZ Chrome Devices/Writhlington Secondary" #writhlington MNSP instance
$gamParams = "cros_ou_and_children ""$gamOu"" print cros fields serialNumber,annotatedAssetId,ou,annotatedLocation,ethernetMacAddress,firmwareVersion,lastEnrollmentTime,lastSync,macAddress,model,notes,osVersion,status,meid,autoUpdateExpiration"

Invoke-Expression "$GamDir\gam.exe info domain" 
Invoke-Expression "$GamDir\gam.exe $gamParams" | out-file -FilePath $tempcsv -ErrorAction Continue #get all chromeOS devices from google workspace

$GsuiteChromeDevices = @()
$GsuiteChromeDevices = Import-Csv -Path $tempcsv #create array of all found Gsuite chrome devices
$GsuiteChromeDevices.Count


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

$SessionToken = Invoke-RestMethod -Verbose "$AppURL/initSession" -Method Get -Headers @{"Content-Type" = "application/json";"Authorization" = "user_token $UserToken";"App-Token"=$AppToken}
#https://www.urldecoder.org/

$SearchResultApi="?is_deleted=0&as_map=0&range=0-100000000&browse=0&criteria[0][link]=AND&criteria[0][field]=4&criteria[0][searchtype]=equals&criteria[0][value]=14&criteria[1][link]=OR&criteria[1][field]=4&criteria[1][searchtype]=equals&criteria[1][value]=15&itemtype=Computer&start=0"
$SearchResult=@()
#glpi device types 14 and 15 : chromebooks and chromeflexos
$SearchResult = Invoke-RestMethod "$AppURL/search/Computer$SearchResultApi" -Headers @{"session-token"=$SessionToken.session_token; "App-Token" = "$AppToken"}

$uuids=@()
$uuids = $SearchResult.data.1 # create uuids array from api returned results

#discovered glpi devices:
$uuids.count



#close api session...
Invoke-RestMethod "$AppURL/killSession" -Headers @{"session-token"=$SessionToken.session_token; "App-Token" = "$AppToken"}

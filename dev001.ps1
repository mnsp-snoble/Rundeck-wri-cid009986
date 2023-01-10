$GlobalGamBaseOU = "/ZZ Chrome Devices/" # MNSP root base OU

Write-Host $(Get-Date)
$ErrorActionPreference="Continue"
Set-Location $GamDir

#Get/Confirm Google instance
Invoke-Expression "$GamDir\gam.exe info domain" 

#create api session to glpi instance...
$SessionToken = Invoke-RestMethod -Verbose "$AppURL/initSession" -Method Get -Headers @{"Content-Type" = "application/json";"Authorization" = "user_token $UserToken";"App-Token"=$AppToken}
#https://www.urldecoder.org/

#get all entities from GLPI
$EntityResult = @() #empty array

#limit entity result to one ID:5 BCL - development - BeechenCliff/Writhlington (ID:1)
$EntityResult = Invoke-RestMethod "$AppURL/search/Entity?is_deleted=0&as_map=&range=0-10000000&criteria[1][link]=AND&criteria[1][field]=2&criteria[1][searchtype]=contains&criteria[1][value]=1&search=Search&itemtype=Entity&start=0" -Headers @{"session-token"=$SessionToken.session_token; "App-Token" = "$AppToken"}

#All entities: - Production
#$EntityResult = Invoke-RestMethod "$AppURL/search/Entity?is_deleted=0&as_map=0&range=0-1000000&criteria[0][link]=AND&criteria[0][field]=1&criteria[0][searchtype]=notequals&criteria[0][value]=0&search=Search&itemtype=Entity&start=0" -Headers @{"session-token"=$SessionToken.session_token; "App-Token" = "$AppToken"}

$entities = $EntityResult.data #convert api search into entities array
$SearchResult=@()
#type 14 only
#$SearchResult = Invoke-RestMethod "$AppURL/search/Computer?is_deleted=0&as_map=0&range=0-100000000&criteria[0][link]=AND&criteria[0][field]=4&criteria[0][searchtype]=equals&criteria[0][value]=14&search=Search&itemtype=Computer&start=0" -Headers @{"session-token"=$SessionToken.session_token; "App-Token" = "$AppToken"}

#glpi device types 14 and 15 : chromebooks and chromeflexos
$SearchResult = Invoke-RestMethod "$AppURL/search/Computer?is_deleted=0&as_map=0&range=0-100000000&browse=0&criteria[0][link]=AND&criteria[0][field]=4&criteria[0][searchtype]=equals&criteria[0][value]=14&criteria[1][link]=OR&criteria[1][field]=4&criteria[1][searchtype]=equals&criteria[1][value]=15&itemtype=Computer&start=0" -Headers @{"session-token"=$SessionToken.session_token; "App-Token" = "$AppToken"}

$uuids=@()
$uuids = $SearchResult.data.1 # create uuids array from api returned results

#discovered devices:
$uuids.count


foreach ( $entity in $entities ) {

$entityID = $entity.2
$entityName = $entity.14
$entityGoogleBaseOu = $entity.76673 #gsuite ou of device - 76673 (PROD)
$entityUpdateChromeUserGsuite = $entity.76674 # yes/no toggle from entity - returns 0 or 1 - 76674 (PROD)
$gamOU = "$GlobalGamBaseOU$entityGoogleBaseOu" #complete entity base ou
$gamParams = "cros_ou_and_children ""$gamOu"" print cros fields serialNumber,annotatedAssetId,ou,annotatedLocation,ethernetMacAddress,firmwareVersion,lastEnrollmentTime,lastSync,macAddress,model,notes,osVersion,status,meid,autoUpdateExpiration"

#
Write-host "-------------------------------------`n"
Write-Host "Processing entitiyID :" $entityID
Write-Host "Entity name          :" $entityName
Write-Host "Google workspace OU  :" $entityGoogleBaseOu
Write-host "-------------------------------------`n"

clear-content -Path $tempcsv
start-sleep 10
Invoke-Expression "$GamDir\gam.exe $gamParams" | out-file -FilePath $tempcsv -ErrorAction Continue #get all chromeOS devices from google workspace

$GsuiteChromeDevices = @()
$GsuiteChromeDevices = Import-Csv -Path $tempcsv #create array of all found Gsuite chrome devices
$GsuiteChromeDevices.Count

Write-warning "sleeping after updatting csv... "

Write-host "-------------------------------------------`n"

#compare google data and current glpi data creating/updating as necessary...
foreach ($ChDevice in $GsuiteChromeDevices ) {
#$ChDevice #dump curent content...    
$uuid = @() #reset uuid var
$manufacturers_id = @() #reset manufacturers_id var
$type = @() #reset device type var
Write-Host "------------------------------------"
$uuid = $($ChDevice.deviceId) #set uuid from imported google data
$Computer = $($ChDevice.deviceId)
$serial = $($ChDevice.SerialNumber)
$uuid = $($ChDevice.deviceId)

$DeviceType = $($ChDevice.model)
    if ($DeviceType -like "*Chromebook*" ) {
    $type = "14" } else { $type = "15" }

    $manufacturers_id = "1037" #failsafe unknown -1146 (PROD)
    $manufacturers_id_name = $($ChDevice.model.split(" "))[0] #set manufacturer_id_name by splitting at first word  "Dell Chromebook 3100" becomes "Dell"
        if ( $manufacturers_id_name -ilike "*Dell*" ) { $manufacturers_id = "3"}
        if ( $manufacturers_id_name -ilike "*Hewlett*" ) { $manufacturers_id = "97"}
        if ( $manufacturers_id_name -ilike "*HP*" ) { $manufacturers_id = "2"}
        if ( $manufacturers_id_name -ilike "*Apple*" ) { $manufacturers_id = "1"}
        if ( $manufacturers_id_name -ilike "*Asus*" ) { $manufacturers_id = "300"}
        if ( $manufacturers_id_name -ilike "*Lenovo*" ) { $manufacturers_id = "251"}
        if ( $manufacturers_id_name -ilike "*Acer*" ) { $manufacturers_id = "458"}
        if ( $manufacturers_id_name -ilike "*Samsung*" ) { $manufacturers_id = "7"}
        if ( $manufacturers_id_name -ilike "*GEO*" ) { $manufacturers_id = "1038"} #manually created id - 835 (PROD)
        if ( $manufacturers_id_name -ilike "*Dynabook*" ) { $manufacturers_id = "1039"} #manually created id -1147 (PROD)
         
    $otherserial = $($ChDevice.annotatedAssetId) #asset number
    $computermodels_id = $($ChDevice.model.Split('(')[0]) #not currently splitting as expected or setting manufacturer

    $entities_id = $entityID
    $operatingsystems_id = "4" #despite correct ID it is not currently associating?

    #$statusid = "1" #set status to active - needs to be google dynamic; active, disabled, provisioned, deprovisioned etc
    $statusid = "11" #failsafe unspecified
    if ( $ChDevice.status -like "*Active*" ) { $statusid = "9"} #manually created google workspace status
    if ( $ChDevice.status -like "*Disabled*" ) { $statusid = "10"} #manually created google workspace status
    if ( $ChDevice.status -like "*Deprovisioned*" ) { $statusid = "13"} #manually created google workspace status


    $eolhwswsupportfield=$($ChDevice.autoUpdateExpiration)
    $googleworkspaceoufield=$($ChDevice.orgUnitPath)
    $comments = $($ChDevice.notes)
    
    #        computermodels_id=$computermodels_id
    #        manufacturers_id=$manufacturers_id
    #        operatingsystems_id=$operatingsystems_id


#Write-host "Searching GLPI for chrome device by serial number:" $($ChDevice.SerialNumber)
Write-host "Searching GLPI for chrome device by UUID:" $uuid
Write-Host "Manufacturer :" $manufacturers_id
Write-Host "Model : $DeviceType"


if ($uuids.Contains($uuid)) { # check if uuid is already known, if no jump to create else update existing device by id...

 Write-Host "Updating existing device by uuid: $Computer"

        #get device database id using uuid:
        $ComputerDeviceID = $($ChDevice.deviceId)
        $SearchResultComputer=@()
        $SearchResultComputer = Invoke-RestMethod "$AppURL/search/Computer?is_deleted=0&as_map=0&browse=0&criteria[0][link]=AND&criteria[0][field]=1&criteria[0][searchtype]=contains&criteria[0][value]=$ComputerDeviceID&itemtype=Computer&start=0" -Headers @{"session-token"=$SessionToken.session_token; "App-Token" = "$AppToken"}
        $id=$searchResultComputer.data.2
        $googleworkspaceAnotatedUser = $searchResultComputer.data.70

               #create json content of values to update/set...
               $UpdateData = @{input=@{
               id=$id
               computertypes_id=$type
               states_id=$statusid
               otherserial=$otherserial
               manufacturers_id=$manufacturers_id
               eolhwswsupportfield=$eolhwswsupportfield
               googleworkspaceoufield=$googleworkspaceoufield
               comment=$comments
               }
               #operatingsystems_id=$operatingsystems_id
               #
            }
                      
            #update device by id using json content set earlier...
            $jsonupdate = $updateData | ConvertTo-Json
            $UpdateResult = Invoke-RestMethod "$AppURL/Computer" -Method Put -Headers @{"session-token"=$SessionToken.session_token; "App-Token" = "$AppToken"} -Body $jsonUpdate -ContentType 'application/json'
            $updateResult
            $jsonupdate

            #>
            Write-Host "----------------------------`n"
        
        }else{

    Write-warning "Missing device by uuid: $($ChDevice.uuid)"
    Write-Host "Creating new ChromeOS device..."
     
    $Data = @{input=@{
        name=$Computer
        computertypes_id=$type
        uuid=$uuid
        otherserial=$otherserial
        entities_id=$entities_id
        serial=$Serial}
    }

    $json = $Data | ConvertTo-Json
    $json
    $AddResult = Invoke-RestMethod "$AppURL/Computer" -Method Post -Headers @{"session-token"=$SessionToken.session_token; "App-Token" = "$AppToken"} -Body $json -ContentType 'application/json'
    Write-Host "GLPI - Computer created" -ForegroundColor Green
    $AddResult
    Write-Host "----------------------------`n"
    }
    #update current Chrome device in google instance user (email), using entity yes/no toggle...
    if ($entityUpdateChromeUserGsuite -eq "1") {
        #Write-Host "Updating current Google workspace chrome device uuid: $uuid with email: $googleworkspaceAnotatedUser attribute from GLPI"
        #set annotated Values using gamxtd3...
        Write-Host "gam update cros $uuid annotatedUser $googleworkspaceAnotatedUser"

    }
}
Write-Warning "sleeping before next entity...."

}

#close api session...
Invoke-RestMethod "$AppURL/killSession" -Headers @{"session-token"=$SessionToken.session_token; "App-Token" = "$AppToken"}

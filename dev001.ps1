

Write-Host "Hello..."
Write-Host "email from rundeck vault    :" $email
Write-Host "Api key from rundeck vault  :" $GLPIapiAppToken
Write-Host "Api user from rundeck vault :" $GLPIuserApiToken
Write-Host "GitHub Uri                  :" $GitHubUri

Set-Location $GamDir
Invoke-Expression "$GamDir\gam.exe info domain" 
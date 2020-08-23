$serviceDeskFunctions = 'Import-module C:\scripts\ServiceDesk-AD.psm1'

if((Test-Path $PROFILE.AllUsersAllHosts) -eq $false){
    New-Item -Type File -Force $PROFILE.AllUsersAllHosts
}

Add-Content $PROFILE.AllUsersAllHosts $serviceDeskFunctions

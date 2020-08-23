function Reset-PwdDate{
    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
    Param (
        [Parameter(Mandatory=$true)]
        [string[]]$UserNames
    )

    BEGIN{

        if (!(get-ElevatedStatus)){
            Write-Error "Please elevate powershell to your SRV account."
            exit
        }
    }
    PROCESS{

        
        foreach($UserName in $UserNames){
            if($PSCmdlet.ShouldProcess("$Username")){
                try {
                    $user = get-aduser $UserName -Properties pwdlastset
                    Set-ADUser -Identity $user.SamAccountNAme -Replace @{pwdlastset="-1"} 
                    Write-Host "Last password date set for $Username has been changed." -ForegroundColor Green
                }
                catch {
                    Write-Error "User $Username does not exist." 
                }
            } 
            else {
                Write-Error "$Username Password last set date cancelled"
            }
        }
    }
    END{}    
}

function Offboard-AdUser{
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [string]$UserName
    )
    BEGIN{
        if (!(get-ElevatedStatus)){
            Write-Host "This command requires an elevated prompt." -ForegroundColor Red
            exit
        }
        if (!(Test-ADUser $UserName)){
            Write-Host "Username ($Username) not found" -ForegroundColor Red
            exit
       }
    }

    PROCESS{

        $user = Get-aduser $UserName -properties enabled

        $title    = 'Offboard ' + $user
        $question = "Are you sure you want Offboard $Username ?"
        $choices  = '&Yes', '&No'

        $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
        if ($decision -eq 0) {
            Write-host "Performing AdOffboard for $UserName" -ForegroundColor Green
            
            try {
                $groupMembership = Get-ADPrincipalGroupMembership -Server corp.net -Identity $UserName | Where-Object {$_.Name -ne “Domain Users”}
                $description = "Old Group Membership:"
                foreach($group in $groupMembership){
            
                    $description += '"' + $group.name + '",'
                
                }
                Set-ADUser $UserName -Description $description
            }
            catch {
                Write-Host "Unable to set Descripion of $Username to old group memberships" -ForegroundColor Red
                $setGroupMembership = $false
            }
            if (!($setGroupMembership)) {
                try {
                    Remove-ADPrincipalGroupMembership -Identity $UserName -MemberOf $groupMembership -Confirm:$false -verbose
                }
                catch {
                    Write-Host "Unable to remove group membership for $Username" -ForegroundColor Red
                }
                
            }

            try {
                Disable-ADAccount $UserName
            }
            catch {
                Write-Host "Unable to Disable $Username";
            }
            
            try {
                Move-ADObject (get-aduser $UserName) -TargetPath "OU=Retired,OU=Accounts,OU=ClearCapital,DC=corp,DC=net"
            }
            catch {
                Write-Host "Unable to Move $Username";
            }
               
        } else {
            Write-Host 'cancelled' -ForegroundColor Red
        }
    }
    END{}

}

function get-ElevatedStatus {
    $user = $env:UserName
    #Change this to an elevated group in your Active Directory Environment
    $Elevated_AD_Group = "Elevated_AD_Group"
    $sd_members = Get-ADGroupMember -Identity $Elevated_AD_Group -Recursive | Select-Object -ExpandProperty SamAccountName

    $domain_admins = "Domain Admins"
    $admin_members = Get-ADGroupMember -Identity $domain_admins -Recursive | Select-Object -ExpandProperty SamAccountName

    If (($admin_members -contains $user) -or ($sd_members -contains $user)) {
        return $true
    } Else {
        return $false
    }
}

Function Test-ADUser {  
    [CmdletBinding()]  
   param(  
     [parameter(Mandatory=$true,position=0)]  
     [string]$Username  
     )  
      Try {  
        Get-ADuser $Username -ErrorAction Stop  
        return $true  
        }   
     Catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {  
         return $false  
         }  
 }

 Export-ModuleMember -Function 'Reset-PwdDate'
 Export-ModuleMember -Function 'Offboard-AdUser'
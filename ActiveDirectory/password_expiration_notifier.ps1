<# 
 .NOTES
 ===========================================================================
    Automate with Task Scheduler:

    powershell -ExecutionPolicy ByPass -File C:\sendEmail.ps1

 SMTPHOST: The smtp host it will use to send mail
 FromEmail: Who the script will send the e-mail from
 ExpireInDays: Amount of days before a password is set to expire it will look for.
 
 ===========================================================================
 .DESCRIPTION
 This script will send an e-mail notification to users where their password is set to expire soon. It includes step by step directions for them to 
 change it on their own.
 
 It will look for the users e-mail address in the emailaddress attribute.
 
 The script will log each run at $DirPath\log.txt
#>
 
#VARs

#SMTP Host
$emailSmtpServer = "SMPT.EMAIL.COM"
$emailFrom = "support@EMAIL.COM"

#Password expiry days
$expireindays = 7
 
#Program File Path
$DirPath = "C:\Scripts\PasswordExpirationNotifier"
 
$Date = Get-Date

#Check if program dir is present
$DirPathCheck = Test-Path -Path $DirPath
If (!($DirPathCheck))
{
    Try
    {
        #If not present then create the dir
        New-Item -ItemType Directory $DirPath -Force
    }
    Catch
    {
        $_ | Out-File ($DirPath + "\" + "Log.txt") -Append
    }
}

# Get Users From AD who are Enabled, Passwords Expire and are Not Currently Expired
"$Date - INFO: Importing AD Module" | Out-File ($DirPath + "\" + "Log.txt") -Append

Import-Module ActiveDirectory
"$Date - INFO: Getting users" | Out-File ($DirPath + "\" + "Log.txt") -Append

#Add in Vendor OU's or remove the AND Statements
$users = Get-Aduser -Server corp.net -properties Name, PasswordNeverExpires, PasswordExpired, `
PasswordLastSet, EmailAddress -filter { (Enabled -eq 'True') -and (PasswordNeverExpires -eq 'False') } `
-SearchBase "OU=Accounts,OU=ClearCapital,DC=corp,DC=net" | Where-Object { $_.PasswordExpired -eq $False `
    -and ($_.DistinguishedName -notlike "*,OU=Vendor OU,*") `
    -and ($_.DistinguishedName -notlike "*,OU=Second Vendor OU,*") `
    -and ($_.DistinguishedName -notlike "*,OU=Third Vendor OU,*") } 
 
$maxPasswordAge = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge
 
# Process Each User for Password Expiry
foreach ($user in $users)
{
    $Name = (Get-ADUser $user | ForEach-Object { $_.Name })
    Write-Host "Working on $Name..." -ForegroundColor White
    Write-Host "Getting e-mail address for $Name..." -ForegroundColor Yellow
    $emailaddress = $user.emailaddress
    If (!($emailaddress))
    {
        Write-Host "$Name has no email addresses to send an e-mail to!" -ForegroundColor Red
        #Don't continue on as we can't email $Null, but if there is an e-mail found it will email that address
        "$Date - WARNING: No email found for $Name" | Out-File ($DirPath + "\" + "Log.txt") -Append
    }

    #Get Password last set date
    $passwordSetDate = (Get-ADUser $user -properties * | ForEach-Object { $_.PasswordLastSet })

    #Check for Fine Grained Passwords
    $PasswordPol = (Get-ADUserResultantPasswordPolicy $user)
    if ($null -ne ($PasswordPol))
    {
        $maxPasswordAge = ($PasswordPol).MaxPasswordAge
    }
    
    $expireson = $passwordsetdate + $maxPasswordAge
    $today = (get-date)

    #Gets the count on how many days until the password expires and stores it in the $daystoexpire var
    $daystoexpire = (New-TimeSpan -Start $today -End $Expireson).Days
    
    If (($daystoexpire -ge "0") -and ($daystoexpire -lt $expireindays))
    {
        "$Date - INFO: Sending expiry notice email to $Name" | Out-File ($DirPath + "\" + "Log.txt") -Append
        Write-Host "Sending Password expiry email to $name" -ForegroundColor Yellow

        $emailSubject = "Your password will expire $daystoexpire days"

        #Customize HTML Email, but @ symbols must remain in current positions due to Powershell limitations
        $emailBody = @"
        <!DOCTYPE html>
        <html lang="en" dir="ltr">
          <head>
            <meta charset="utf-8">
            <title></title>
          </head>

          <body style="font-size:16px;">
            Hello <b>$Name</b>,
            <br><br>

            Your Domain (computer) password will expire in <b>$daystoexpire day(s)</b>. Please change it as soon as possible.
            <br><br>
            <div style="margin-left:2%; padding-left: 3%;padding-top: 30px;padding-bottom: 30px; margin-right: 5%;border:solid;background-color:#F0FFFF;">
              <b>To change your password, please follow the instructions below while hardwired in the office or on the VPN:</b>
              <br>
              <ol>
                <b><li>On your Windows computer</li></b>
                <ol type="a">
                  <li>If you are not in the office, logon and connect to VPN. Otherwise proceed to the next step.</li>
                  <li>Log onto your computer as usual and make sure you are connected to the internet.</li>
                  <li>Press Ctrl-Alt-Del and click on ""Change Password"".</li>
                  <li>Fill in your old password and set a new password.  See the password requirements below.</li>
                  <li>Press OK to return to your desktop.</li>
                </ol>
                <br>
                <b><li>On your Mac computer</li></b>
                <ol type="a">
                  <li>Choose Apple menu &#63743; > System Preferences, then click Users & Groups.</li>
                  <li>Click Change Password.</li>
                  <li>Enter your current password in the Old Password field.</li>
                  <li>Enter your new password in the New Password field, then enter it again in the Verify field.</li>
                  <p>(Note: Changing your password on the VPN may break your keychain.)</p>
                </ol>
                <b><li>On your Linux computer</li></b>
                <ol type="a">
                  <li>Open terminal</li>
                  <li>Run: kpasswd <b><i>username</i></b></li>
                  <li>Enter old, then new password</li>
                  <li>If there were no errors, logout and then re-login.</li>
                </ol>
              </ol>


              <b>The new password must meet the minimum requirements set forth in our corporate policies including:</b>
              <ol>
                <li>It must be at least 8 characters long.</li>
                <li>It must contain at least one character from 3 of the 4 following groups of characters:</li>
                <ol type="a">
                  <li>Uppercase letters (A-Z)</li>
                  <li>Lowercase letters (a-z)</li>
                  <li>Numbers (0-9)</li>
                  <li>Symbols (!@#$%^&*...)</li>
                </ol>
                <li>It cannot match any of your past 24 passwords.</li>
                <li>It cannot contain characters which match 3 or more consecutive characters of your username.</li>
                <li>You cannot change your password more often than once in a 24 hour period.</li>
              </ol>
            </div>


            <br>
            If you have any questions please contact our Support team at technical.support@clearcapital.com or call us at 530.550.2596
            <br><br>
            Thank you,
            <br>
            Help Desk

          </body>
        </html>

"@

        Write-Host "Sending E-mail to $emailaddress..." -ForegroundColor Green
        Try
        {
            Send-MailMessage -To $emailaddress -From $emailFrom -Subject $emailSubject `
            -Body $emailBody -SmtpServer $emailSmtpServer -Priority High `
            -DeliveryNotificationOption OnSuccess, OnFailure -BodyAsHtml
        }
        Catch
        {
            $_ | Out-File ($DirPath + "\" + "Log.txt") -Append
        }
    }
    Else
    {
        "$Date - INFO: Password for $Name not expiring for $daystoexpire days" | Out-File ($DirPath + "\" + "Log.txt") -Append
        Write-Host "Password for $Name does not expire for $daystoexpire days" -ForegroundColor White
    }
}
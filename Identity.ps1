Import-Module WorkdayApi
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$username = 'username'
$password = ConvertTo-SecureString 'password' -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($username, $password)
Set-WorkdayCredential -Credential $credential
Set-WorkdayEndpoint -Endpoint Human_Resources -Uri 'https://wd2-impl-services1.workday.com/ccx/service/Tenant/Human_Resources/'
Save-WorkdayConfiguration
#Fetching Info
$new_hires_ids = Get-WorkdayToAdData
#exporting list of users in last 24 hours
$d= [datetime]$(Get-Date -f "yyyy-MM-dd")
($new_hires_ids |where{($d-[datetime]$_.'Hire Date').days-eq 0}).'Employee or Contingent Worker Number' > $psscriptroot\first.txt
# existing list
#$null >> $psscriptroot\latest.txt

foreach($user in $(get-content first.txt)){ 
    if($(gc latest.txt)-notcontains $user){ #comparing each user with existing list
        $aduser = $new_hires_ids |where {$_.'Employee or Contingent Worker Number' -eq $user}  
        $svisor = $aduser.'Supervisor Employee Id'      
        $username = $aduser.'First Name'+'.'+$aduser.'Last Name'
        $displayname = $aduser.'Last Name'+','+$aduser.'First Name'
        $Ddescription = $aduser.'Job Title'
        $office = $aduser.'Location (Building)'
        $saravananpwd = ConvertTo-SecureString -String "password" -AsPlainText -Force
        $manager = (get-aduser -Filter {EmployeeID -eq $svisor}).samaccountname
        $upn = $username+'@company.com'
        $ou = "company.com/Users"
        if ($office -like "*USA - TX - Austin*") {$ou = "company.com/Austin/Users"}
        

    $path = "OU = Users, OU = $($ou.split('/')[1]) , DC = $($ou.split('/')[0].Split('.')[0]), DC = $($ou.split('/')[0].Split('.')[1])"
        New-ADUser -Name $username -UserPrincipalName $upn -Path $path -DisplayName $displayname -GivenName $aduser.'First Name' -Surname $aduser.'Last Name' -AccountPassword $saravananpwd -Description $Ddescription -Office $office -Manager $manager -Enabled $true
        Add-ADGroupMember -Identity "O365-Licensed-Users" -Members $username 

        #creating mailbox
        [pscredential]$credObject = New-Object System.Management.Automation.PSCredential ("user@company.com", $saravananpwd)
        $saravananpwd = ConvertTo-SecureString -String "password" -AsPlainText -Force
        $session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://exchange server FQDN/powershell/ -Authentication Kerberos
        Import-PSSession $Session -DisableNameChecking -AllowClobber | Out-Null
        $password = ConvertTo-SecureString -String "password" -AsPlainText -Force
        Enable-RemoteMailbox $username -RemoteRoutingAddress "$username@company.mail.onmicrosoft.com"
        #New-RemoteMailbox -Name $displayname -Alias $username -FirstName $aduser.'First Name' -LastName $aduser.'Last Name' -Password $password -ResetPasswordOnNextLogon $false -UserPrincipalName $upn -OnPremisesOrganizationalUnit "$ou" -Confirm:$false


        $user >> latest.txt #updating exisitng list
    }
}

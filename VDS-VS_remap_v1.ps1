# clear variables, clear screen
rv * -ea SilentlyContinue; rmo *; $error.Clear(); cls

# when Exception = stop script
$ErrorActionPreference = "Stop"

# set PowerCLI environment
Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -InvalidCertificateAction ignore -Confirm:$false | Out-Null

# Log location (create new file if not available already)
$outFile ="output.txt" 
if (!(Test-Path "$outFile")) {
   New-Item -Name $outFile -Type "file" | Out-Null
   Write-Host "[INFO] $outFile has been created at running path."
    }
else {
  Write-Host "[INFO] $outFile already exists."
    }

"`n"

# vCenter login (Option 1 - PROMPT) 
$viServer = Read-Host -Prompt 'vCenter (FQDN)'
Write-Host 'Please wait for login prompt...'
Connect-VIServer $viServer 
#


<# vCenter login (Option 2 - Predefined List) - to be improved
$vi0 = "vcsa101.atomiclab.one", "administrator@vsphere.local", "VMware1!"
$vi1 = "vcsa102.atomiclab.one", "administrator@vsphere.local", "VMware1!"
$vi2 = "vcsa103.atomiclab.one", "administrator@vsphere.local", "VMware1!"


$vSelect = ""

Write-Host 0 - $vi0[0]
Write-Host 1 - $vi1[0]
Write-Host 2 - $vi2[0]
"`n"

while (($vSelect -eq "") -or ($vSelect -notin 0..2)) {$vSelect = Read-Host ">> Select which vCenter (No.)"}

if ($vSelect -eq 0) {$viserver = $vi0}
elseif ($vSelect -eq 1) {$viserver = $vi1}
elseif ($vSelect -eq 2) {$viserver = $vi2}
else {Write-Host "none"}

Connect-VIServer $viserver[0] -User $viserver[1] -Password $viserver[2]
# End vCenter login (Option 2 - Predefined List)
#>

"`n"

do { 

    do { # Get Hosts list.
        $vmhost = Get-VMHost
        $vmhost | select @{N="No";E={$vmhost.indexof($_)}}, Name, Parent, ConnectionState, PowerState | ft -AutoSize

        $vmhost_no = "-1"
        while (($vmhost_no -eq "") -or ($vmhost_no -notin 0..($vmhost.Count-1))) {$vmhost_no = Read-Host ">> Select which host (No.)"}

        "`n"
        Write-Host -NoNewline $vmhost[$vmhost_no] -foregroundcolor black -backgroundcolor white ;Write-Host " has been selected, showing VMs Network Adapter:" ### Shows all VM's NetworkAdapter list of selected host.

        $networkadapter = Get-VMHost -Name $vmhost[$vmhost_no] | Get-VM | Get-NetworkAdapter
        $networkadapter_unique = $networkadapter | Select-Object -Property NetworkName -Unique
        $networkadapter | Select @{N='VM';E={$_.Parent.Name}},@{N='AdapterName';E={$_.Name}},@{N='VS/VDS';E={$_.NetworkName}},@{N='Type';E={$_.Type}} | ft

        $redo2 = ""
        if ($networkadapter.count -le 0) {$redo2 = "n"; Write-Host "`n>> No NetworkAdapter found, please reselect." -foregroundcolor yellow} ### Check for empty NetworkAdapter (of VM) list   
        while ($redo2 -notmatch "[y|n]") { $redo2 = Read-Host ">> Do you want to continue? (Y/N) [N] to reselect Host." }
        if ($redo2 -eq "y") {Write-Host ">> Continuing...`n" ; break }


    } While ($redo2 -ne "y")


    # List down all Unique PortGroup after filtering
    Write-Host
    "    ───────────────
      Unique PG  
    ───────────────"

    $networkadapter_unique | Select @{N='No';E={$networkadapter_unique.indexof($_)}},@{N='PortGroup';E={$_.NetworkName}} | ft

    $virtualswitch = Get-VMHost -Name $vmhost[$vmhost_no] | Get-VirtualSwitch -Standard
    $virtualportgroup = Get-VMHost -Name $vmhost[$vmhost_no] | Get-VirtualPortGroup
    $virtualswitch_unique = $virtualswitch | Select-Object -Property Name -Unique
    $virtualportgroup_unique = $virtualportgroup | Where {$_.Key -notlike "*kernel*" -and $_.Name -notlike "*dvuplinks*"} | Select -Unique


    do {   # Source to Destination PortGroup mapping.
        $n=0
        $hash_na = @{}
        $networkadapter_unique | ForEach-Object {
            $virtualportgroup_no = "-1"
            Write-Host `n============================================
            $virtualportgroup_unique | Select @{N='No';E={$virtualportgroup_unique.indexof($_)}},@{N='PortGroup';E={$_.Name}},VLanId | ft
            while (($virtualportgroup_no -eq "") -or ($virtualportgroup_no -notin 0..($virtualportgroup_unique.Count-1))) {Write-Host -NoNewline ">> Map "; Write-Host -NoNewline -foregroundcolor black -backgroundcolor white "["$_.NetworkName "]" ;Write-Host -NoNewline " to target Portgroup: " ;$virtualportgroup_no = Read-Host}

            $hash_na.add($_.NetworkName,$virtualportgroup_unique[$virtualportgroup_no].Name)

            $n++ 
            Write-Host ============================================`n;
        }

        # List down all Source to Destination PortGroup mapping.
        Write-Host
        "        ───────────────
          DVS --> VS  
        ───────────────"
        foreach ($key in $hash_na.Keys) {Write-Host $key ----> $hash_na[$key]} 

        "`n"
        $redo1="" 
        while ($redo1 -notmatch "[y|n]") {Write-Host -NoNewline ">> WARNING <<" -foregroundcolor yellow -backgroundcolor red; $redo1 = Read-Host " Continue? (Y/N) [N] to remap."}
            if ($redo1 -eq "y") {Write-Host ">> Continuing...`n"; break <#-foregroundcolor black -backgroundcolor white#>}
 
    } While ($redo1 -ne "y")


    # Add Date and selected hostname to output.txt.
    Add-Content $outFile "$(Get-Date -Format "yyyy:MM:dd-HH:mm:ss") - $($vmhost[$vmhost_no].name)"

    foreach ($key in $hash_na.Keys) {

    $networkadapter | Where {$_.NetworkName -eq $key} | foreach-object { Write-Host $_.Parent.Name - $_.Name - $_.NetworkName `> $hash_na[$key] -foregroundcolor black -backgroundcolor white ; Add-Content $outFile "$($_.Parent.Name),$($_.Name),$($_.NetworkName),$($hash_na[$key])" ; Set-NetworkAdapter $_ -NetworkName $hash_na[$key] -WhatIf }  
      
        }

    "`n"
    Write-Host "All Done"
    "`n"

    # Ready to continue for another host?
    $redo = ""
    while ($redo -notmatch "[y|n]") { $redo = Read-Host ">> Do you want to continue another Host? (Y/N) [Y] to select new Host." }
        if ($redo -eq "y") {Write-Host ">> Continuing...`n" ; Clear-Host }
            else {Write-Host ">> Bye bye`n" -foregroundcolor black -backgroundcolor white; break}

} While ($redo -eq "y")





function Get-AbrWinDNSInfrastructure {
    <#
    .SYNOPSIS
        Used by As Built Report to retrieve Microsoft AD Domain Name System Infrastructure information.
    .DESCRIPTION
        Documents the configuration of Microsoft Windows Server in Word/HTML/Text formats using PScribo.
    .NOTES
        Version:        0.3.0
        Author:         Jonathan Colon
        Twitter:        @jcolonfzenpr
        Github:         rebelinux
        Credits:        Iain Brighton (@iainbrighton) - PScribo module

    .LINK
        https://github.com/AsBuiltReport/AsBuiltReport.Microsoft.Windows
    #>
    [CmdletBinding()]
    param (
        [Parameter (
            Position = 0,
            Mandatory)]
            [string]
            $Domain,
            $Session
    )

    begin {
        Write-PscriboMessage "Discovering Active Directory Domain Name System Infrastructure information for $Domain"
    }

    process {
        try {
            $DCs = Invoke-Command -Session $Session {Get-ADDomain -Identity $using:Domain | Select-Object -ExpandProperty ReplicaDirectoryServers}
            if ($DCs) {
                Section -Style Heading5 "Infrastructure Summary" {
                    Paragraph "The following section provides a summary of the DNS Infrastructure configuration."
                    BlankLine
                    $OutObj = @()
                    Write-PscriboMessage "Discovered '$(($DCs | Measure-Object).Count)' Active Directory Domain Controller on $Domain"
                    foreach ($DC in $DCs) {
                        Write-PscriboMessage "Collecting Domain Name System Infrastructure information on '$($DC)'."
                        try {
                            $DNSSetting = Invoke-Command -Session $Session {Get-DnsServerSetting -ComputerName $using:DC}
                            $inObj = [ordered] @{
                                'DC Name' = $($DC.ToString().ToUpper().Split(".")[0])
                                'Build Number' = ConvertTo-EmptyToFiller $DNSSetting.BuildNumber
                                'IPv6' = ConvertTo-EmptyToFiller (ConvertTo-TextYN $DNSSetting.EnableIPv6)
                                'DnsSec' = ConvertTo-EmptyToFiller (ConvertTo-TextYN $DNSSetting.EnableDnsSec)
                                'ReadOnly DC' = ConvertTo-EmptyToFiller (ConvertTo-TextYN $DNSSetting.IsReadOnlyDC)
                                'Listening IP' = $DNSSetting.ListeningIPAddress
                            }
                            $OutObj += [pscustomobject]$inobj
                        }
                        catch {
                            Write-PscriboMessage -IsWarning " $($_.Exception.Message) (Infrastructure Summary)"
                        }
                    }

                    $TableParams = @{
                        Name = "Infrastructure Setting -$($Domain.ToString().ToUpper())"
                        List = $false
                        ColumnWidths = 30, 10, 9, 10, 11, 30
                    }
                    if ($Report.ShowTableCaptions) {
                        $TableParams['Caption'] = "- $($TableParams.Name)"
                    }
                    $OutObj | Sort-Object -Property 'DC Name' | Table @TableParams
                    #---------------------------------------------------------------------------------------------#
                    #                                 DNS IP Section                                              #
                    #---------------------------------------------------------------------------------------------#
                    if ($InfoLevel.DNS -ge 2) {
                        try {
                            Section -Style Heading6 "Domain Controller DNS IP Configuration" {
                                $OutObj = @()
                                Write-PscriboMessage "Discovered '$(($DCs | Measure-Object).Count)' Active Directory Domain Controller on $Domain"
                                foreach ($DC in $DCs) {
                                    $DCPssSession = New-PSSession $DC -Credential $Cred -Authentication Default
                                    Write-PscriboMessage "Collecting DNS IP Configuration information from $($DC)."
                                    try {
                                        $DNSSettings = Invoke-Command -Session $DCPssSession {Get-NetAdapter | Get-DnsClientServerAddress -AddressFamily}
                                        Remove-PSSession -Session $DCPssSession
                                        foreach ($DNSSetting in $DNSSettings) {
                                            try {
                                                $inObj = [ordered] @{
                                                    'DC Name' = $DC.ToString().ToUpper().Split(".")[0]
                                                    'Interface' = $DNSSetting.InterfaceAlias
                                                    'DNS IP 1' = ConvertTo-EmptyToFiller $DNSSetting.ServerAddresses[0]
                                                    'DNS IP 2' = ConvertTo-EmptyToFiller $DNSSetting.ServerAddresses[1]
                                                    'DNS IP 3' = ConvertTo-EmptyToFiller $DNSSetting.ServerAddresses[2]
                                                    'DNS IP 4' = ConvertTo-EmptyToFiller $DNSSetting.ServerAddresses[3]
                                                }
                                                $OutObj += [pscustomobject]$inobj
                                            }
                                            catch {
                                                Write-PscriboMessage -IsWarning $_.Exception.Message
                                            }
                                        }
                                    }
                                    catch {
                                        Write-PscriboMessage -IsWarning "$($_.Exception.Message) (DNS IP Configuration Item)"
                                    }
                                }

                                if ($HealthCheck.DNS.DP) {
                                    $OutObj | Where-Object { $_.'DNS IP 1' -eq "127.0.0.1"} | Set-Style -Style Warning -Property 'DNS IP 1'
                                }

                                $TableParams = @{
                                    Name = "IP Configuration -$($Domain.ToString().ToUpper())"
                                    List = $false
                                    ColumnWidths = 20, 20, 15, 15, 15, 15
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $OutObj | Sort-Object -Property 'DC Name' | Table @TableParams
                            }
                        }
                        catch {
                            Write-PscriboMessage -IsWarning "$($_.Exception.Message) (DNS IP Configuration Table)"
                        }
                    }
                    #---------------------------------------------------------------------------------------------#
                    #                            DNS Aplication Partitions Section                                #
                    #---------------------------------------------------------------------------------------------#
                    if ($InfoLevel.DNS -ge 2) {
                        try {
                            Section -Style Heading6 "Application Directory Partition" {
                                foreach ($DC in $DCs) {
                                    Section -Style Heading6 "$($DC.ToString().ToUpper().Split(".")[0]) Directory Partition" {
                                        Paragraph "The following section provides $($DC.ToString().ToUpper().Split(".")[0]) Directory Partition information."
                                        BlankLine
                                        $OutObj = @()
                                        Write-PscriboMessage "Collecting Directory Partition information from $($DC)."
                                        try {
                                            $DNSSetting = Invoke-Command -Session $Session {Get-DnsServerDirectoryPartition -ComputerName $using:DC}
                                            foreach ($Partition in $DNSSetting) {
                                                try {
                                                    $inObj = [ordered] @{
                                                        'Name' = $Partition.DirectoryPartitionName
                                                        'State' = ConvertTo-EmptyToFiller $Partition.State
                                                        'Flags' = $Partition.Flags
                                                        'Zone Count' = $Partition.ZoneCount
                                                    }
                                                    $OutObj += [pscustomobject]$inobj
                                                }
                                                catch {
                                                    Write-PscriboMessage -IsWarning $_.Exception.Message
                                                }
                                            }
                                        }
                                        catch {
                                            Write-PscriboMessage -IsWarning "$($_.Exception.Message) (Directory Partitions Item)"
                                        }
                                        if ($HealthCheck.DNS.DP) {
                                            $OutObj | Where-Object { $_.'State' -ne 0 -and $_.'State' -ne "-"} | Set-Style -Style Warning -Property 'Name','State','Flags','Zone Count'
                                        }

                                        $TableParams = @{
                                            Name = "Directory Partitions - $($Domain.ToString().ToUpper())"
                                            List = $false
                                            ColumnWidths = 50, 15, 25, 10
                                        }
                                        if ($Report.ShowTableCaptions) {
                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                        }
                                        $OutObj | Sort-Object -Property 'Name' | Table @TableParams
                                    }
                                }
                            }
                        }
                        catch {
                            Write-PscriboMessage -IsWarning "$($_.Exception.Message) (Directory Partitions Table)"
                        }
                    }
                    #---------------------------------------------------------------------------------------------#
                    #                                 DNS RRL Section                                             #
                    #---------------------------------------------------------------------------------------------#
                    if ($InfoLevel.DNS -ge 2) {
                        try {
                            Section -Style Heading6 "Response Rate Limiting (RRL)" {
                                $OutObj = @()
                                foreach ($DC in $DCs) {
                                    Write-PscriboMessage "Collecting Response Rate Limiting (RRL) information from $($DC)."
                                    try {
                                        $DNSSetting = Invoke-Command -Session $Session {Get-DnsServerResponseRateLimiting -ComputerName $using:DC}
                                        $inObj = [ordered] @{
                                            'DC Name' = $($DC.ToString().ToUpper().Split(".")[0])
                                            'Status' = ConvertTo-EmptyToFiller $DNSSetting.Mode
                                            'Responses Per Sec' = ConvertTo-EmptyToFiller $DNSSetting.ResponsesPerSec
                                            'Errors Per Sec' = ConvertTo-EmptyToFiller $DNSSetting.ErrorsPerSec
                                            'Window In Sec' = ConvertTo-EmptyToFiller $DNSSetting.WindowInSec
                                            'Leak Rate' = ConvertTo-EmptyToFiller $DNSSetting.LeakRate
                                            'Truncate Rate' = ConvertTo-EmptyToFiller $DNSSetting.TruncateRate

                                        }
                                        $OutObj += [pscustomobject]$inobj
                                    }
                                    catch {
                                        Write-PscriboMessage -IsWarning "$($_.Exception.Message) (Response Rate Limiting (RRL) Item)"
                                    }
                                }

                                $TableParams = @{
                                    Name = "Response Rate Limiting - $($Domain.ToString().ToUpper())"
                                    List = $false
                                    ColumnWidths = 30, 10, 12, 12, 12, 12, 12
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $OutObj | Sort-Object -Property 'DC Name' | Table @TableParams
                            }
                        }
                        catch {
                            Write-PscriboMessage -IsWarning "$($_.Exception.Message) (Response Rate Limiting (RRL) Table)"
                        }
                    }
                    #---------------------------------------------------------------------------------------------#
                    #                                 DNS Scanvenging Section                                     #
                    #---------------------------------------------------------------------------------------------#
                    if ($InfoLevel.DNS -ge 2) {
                        try {
                            Section -Style Heading6 "Scavenging Options" {
                                $OutObj = @()
                                foreach ($DC in $DCs) {
                                    Write-PscriboMessage "Collecting Scavenging Options information from $($DC)."
                                    try {
                                        $DNSSetting = Invoke-Command -Session $Session {Get-DnsServerScavenging -ComputerName $using:DC}
                                        $inObj = [ordered] @{
                                            'DC Name' = $($DC.ToString().ToUpper().Split(".")[0])
                                            'NoRefresh Interval' = ConvertTo-EmptyToFiller $DNSSetting.NoRefreshInterval
                                            'Refresh Interval' = ConvertTo-EmptyToFiller $DNSSetting.RefreshInterval
                                            'Scavenging Interval' = ConvertTo-EmptyToFiller $DNSSetting.ScavengingInterval
                                            'Last Scavenge Time' = Switch ($DNSSetting.LastScavengeTime) {
                                                "" {"-"; break}
                                                $Null {"-"; break}
                                                default {ConvertTo-EmptyToFiller ($DNSSetting.LastScavengeTime.ToString("MM/dd/yyyy"))}
                                            }
                                            'Scavenging State' = Switch ($DNSSetting.ScavengingState) {
                                                "True" {"Enabled"}
                                                "False" {"Disabled"}
                                                default {ConvertTo-EmptyToFiller $DNSSetting.ScavengingState}
                                            }
                                        }
                                        $OutObj += [pscustomobject]$inobj
                                    }
                                    catch {
                                        Write-PscriboMessage -IsWarning "$($_.Exception.Message) (Scavenging Item)"
                                    }
                                }

                                $TableParams = @{
                                    Name = "Scavenging - $($Domain.ToString().ToUpper())"
                                    List = $false
                                    ColumnWidths = 25, 15, 15, 15, 15, 15
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $OutObj | Sort-Object -Property 'DC Name' | Table @TableParams
                            }
                        }
                        catch {
                            Write-PscriboMessage -IsWarning "$($_.Exception.Message) (Scavenging Table)"
                        }
                    }
                    #---------------------------------------------------------------------------------------------#
                    #                                 DNS Forwarder Section                                       #
                    #---------------------------------------------------------------------------------------------#
                    try {
                        Section -Style Heading6 "Forwarder Options" {
                            $OutObj = @()
                            foreach ($DC in $DCs) {
                                Write-PscriboMessage "Collecting Forwarder Options information from $($DC)."
                                try {
                                    $DNSSetting = Invoke-Command -Session $Session {Get-DnsServerForwarder -ComputerName $using:DC}
                                    $Recursion = Invoke-Command -Session $Session {Get-DnsServerRecursion -ComputerName $using:DC | Select-Object -ExpandProperty Enable}
                                    $inObj = [ordered] @{
                                        'DC Name' = $($DC.ToString().ToUpper().Split(".")[0])
                                        'IP Address' = $DNSSetting.IPAddress
                                        'Timeout' = ("$($DNSSetting.Timeout)/s")
                                        'Use Root Hint' = ConvertTo-EmptyToFiller (ConvertTo-TextYN $DNSSetting.UseRootHint)
                                        'Use Recursion' = ConvertTo-EmptyToFiller (ConvertTo-TextYN $Recursion)
                                    }
                                    $OutObj += [pscustomobject]$inobj
                                }
                                catch {
                                    Write-PscriboMessage -IsWarning "$($_.Exception.Message) (Forwarder Item)"
                                }
                            }
                            $TableParams = @{
                                Name = "Forwarders - $($Domain.ToString().ToUpper())"
                                List = $false
                                ColumnWidths = 35, 15, 15, 15, 20
                            }
                            if ($Report.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $OutObj | Sort-Object -Property 'DC Name' | Table @TableParams
                        }
                    }
                    catch {
                        Write-PscriboMessage -IsWarning "$($_.Exception.Message) (Forwarder Table)"
                    }
                    #---------------------------------------------------------------------------------------------#
                    #                                 DNS Root Hints Section                                      #
                    #---------------------------------------------------------------------------------------------#
                    if ($InfoLevel.DNS -ge 2) {
                        try {
                            Section -Style Heading6 "Root Hints" {
                                foreach ($DC in $DCs) {
                                    Section -Style Heading6 "$($DC.ToString().ToUpper().Split(".")[0]) Root Hints" {
                                        Paragraph "The following section provides $($DC.ToString().ToUpper().Split(".")[0]) Root Hints information."
                                        BlankLine
                                        $OutObj = @()
                                        Write-PscriboMessage "Collecting Root Hint information from $($DC)."
                                        try {
                                            $DNSSetting = Invoke-Command -Session $Session {Get-DnsServerRootHint -ComputerName $using:DC | Select-Object @{Name="Name"; E={$_.NameServer.RecordData.Nameserver}},@{Name="IPAddress"; E={$_.IPAddress.RecordData.IPv6Address.IPAddressToString,$_.IPAddress.RecordData.IPv4Address.IPAddressToString} }}
                                            foreach ($Hints in $DNSSetting) {
                                                try {
                                                    $inObj = [ordered] @{
                                                        'Name' = $Hints.Name
                                                        'IP Address' = (($Hints.IPAddress).Where({ $_ -ne $Null })) -join ", "
                                                    }
                                                    $OutObj += [pscustomobject]$inobj
                                                }
                                                catch {
                                                    Write-PscriboMessage -IsWarning $_.Exception.Message
                                                }
                                            }
                                        }
                                        catch {
                                            Write-PscriboMessage -IsWarning "$($_.Exception.Message) (Root Hints Item)"
                                        }

                                        $TableParams = @{
                                            Name = "Root Hints - $($Domain.ToString().ToUpper())"
                                            List = $false
                                            ColumnWidths = 50, 50
                                        }
                                        if ($Report.ShowTableCaptions) {
                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                        }
                                        $OutObj | Sort-Object -Property 'Name' | Table @TableParams
                                    }
                                }
                            }
                        }
                        catch {
                            Write-PscriboMessage -IsWarning "$($_.Exception.Message) (Root Hints Table)"
                        }
                    }
                    #---------------------------------------------------------------------------------------------#
                    #                                 DNS Zone Scope Section                                      #
                    #---------------------------------------------------------------------------------------------#
                    if ($InfoLevel.DNS -ge 2) {
                        try {
                            Section -Style Heading6 "Zone Scope Recursion" {
                                $OutObj = @()
                                foreach ($DC in $DCs) {
                                    Write-PscriboMessage "Collecting Zone Scope Recursion information from $($DC)."
                                    try {
                                        $DNSSetting = Invoke-Command -Session $Session {Get-DnsServerRecursionScope -ComputerName $using:DC}
                                        $inObj = [ordered] @{
                                            'DC Name' = $($DC.ToString().ToUpper().Split(".")[0])
                                            'Zone Name' = Switch ($DNSSetting.Name) {
                                                "." {"Root"}
                                                default {ConvertTo-EmptyToFiller $DNSSetting.Name}
                                            }
                                            'Forwarder' = $DNSSetting.Forwarder
                                            'Use Recursion' = ConvertTo-EmptyToFiller (ConvertTo-TextYN $DNSSetting.EnableRecursion)
                                        }
                                        $OutObj += [pscustomobject]$inobj
                                    }
                                    catch {
                                        Write-PscriboMessage -IsWarning "$($_.Exception.Message) (Zone Scope Recursion Item)"
                                    }
                                }

                                $TableParams = @{
                                    Name = "Zone Scope Recursion - $($Domain.ToString().ToUpper())"
                                    List = $false
                                    ColumnWidths = 35, 25, 20, 20
                                }
                                if ($Report.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                $OutObj | Sort-Object -Property 'DC Name' | Table @TableParams
                            }
                        }
                        catch {
                            Write-PscriboMessage -IsWarning "$($_.Exception.Message) (Zone Scope Recursion Table)"
                        }
                    }
                }
            }
        }
        catch {
            Write-PscriboMessage -IsWarning "$($_.Exception.Message) (DNS Infrastructure Section)"
        }
    }

    end {}

}
function Get-AbrWinDHCPInfrastructure {
    <#
    .SYNOPSIS
        Used by As Built Report to retrieve Microsoft DHCP Servers
    .DESCRIPTION
        Documents the configuration of Microsoft Windows Server in Word/HTML/Text formats using PScribo.
    .NOTES
        Version:        0.5.4
        Author:         Jonathan Colon
        Twitter:        @jcolonfzenpr
        Github:         rebelinux
        Credits:        Iain Brighton (@iainbrighton) - PScribo module

    .LINK
        https://github.com/AsBuiltReport/AsBuiltReport.Microsoft.Windows
    #>

    [CmdletBinding()]
    param (
    )

    begin {
        Write-PScriboMessage "DHCP InfoLevel set at $($InfoLevel.DHCP)."
        Write-PScriboMessage "Collecting Host DHCP Server information."
    }

    process {
        try {
            $Settings = Get-DhcpServerSetting -CimSession $TempCIMSession
            $Database = Get-DhcpServerDatabase -CimSession $TempCIMSession
            $DNSCredential = Get-DhcpServerDnsCredential -CimSession $TempCIMSession
            if ($Settings -and $Database -and $DNSCredential) {
                $OutObj = @()
                try {
                    $inObj = [ordered] @{
                        'Domain Joined' = $Settings.IsDomainJoined
                        'Authorized' = $Settings.IsAuthorized
                        'Conflict Detection Attempts' = $Settings.ConflictDetectionAttempts
                        'Activate Policies' = $Settings.ActivatePolicies
                        'Dynamic Bootp' = $Settings.DynamicBootp
                        'Database Path' = $Database.FileName
                        'Database Backup Path' = $Database.BackupPath
                        'Database Backup Interval' = switch ([string]::IsNullOrEmpty($Database.BackupInterval)) {
                            $true { "--" }
                            $false { "$($Database.BackupInterval) min" }
                            default { 'Unknown' }
                        }
                        'Database Logging Enabled' = Switch ([string]::IsNullOrEmpty($Database.LoggingEnabled)) {
                            $true { "--" }
                            $false { $Database.LoggingEnabled }
                            default { 'Unknown' }
                        }
                        'User Name' = $DNSCredential.UserName
                        'Domain Name' = $DNSCredential.DomainName
                    }
                    $OutObj += [pscustomobject](ConvertTo-HashToYN $inObj)
                } catch {
                    Write-PScriboMessage -IsWarning $_.Exception.Message
                }

                if ($HealthCheck.DHCP.BP) {
                    $OutObj | Where-Object { $_.'Conflict Detection Attempts' -eq 0 } | Set-Style -Style Warning -Property 'Conflict Detection Attempts'
                    $OutObj | Where-Object { $_.'Authorized' -like 'No' } | Set-Style -Style Warning -Property 'Authorized'
                    $OutObj | Where-Object { $_.'User Name' -like "--" } | Set-Style -Style Warning -Property 'User Name', 'Domain Name'

                }

                $TableParams = @{
                    Name = "DHCP Servers Settings - $($System.toUpper().split(".")[0])"
                    List = $true
                    ColumnWidths = 40, 60
                }
                if ($Report.ShowTableCaptions) {
                    $TableParams['Caption'] = "- $($TableParams.Name)"
                }
                $OutObj | Table @TableParams
            }
        } catch {
            Write-PScriboMessage -IsWarning $_.Exception.Message
        }
    }

    end {}

}
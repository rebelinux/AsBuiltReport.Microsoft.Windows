function Get-AbrWinIISWebAppPool {
    <#
    .SYNOPSIS
    Used by As Built Report to retrieve Windows Server IIS Sites information.
    .DESCRIPTION
        Documents the configuration of Microsoft Windows Server in Word/HTML/Text formats using PScribo.
    .NOTES
        Version:        0.5.6
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
        Write-PScriboMessage "IIS InfoLevel set at $($InfoLevel.IIS)."
        Write-PScriboMessage "Collecting IIS Sites information."
    }

    process {
        if ($InfoLevel.IIS -ge 1) {
            try {
                $IISWebAppPools = Invoke-Command -Session $TempPssSession { Get-IISAppPool }
                if ($IISWebAppPools) {
                    Section -Style Heading3 'Application Pools' {
                        Paragraph 'The following table lists IIS Application Pools'
                        BlankLine
                        $OutObj = @()
                        foreach ($IISWebAppPool in $IISWebAppPools) {
                            try {
                                $inObj = [ordered] @{
                                    'Name' = $IISWebAppPool.Name
                                    'Status' = $IISWebAppPool.State
                                    'CLR Ver' = $IISWebAppPool.ManagedRuntimeVersion
                                    'Pipeline Mode ' = $IISWebAppPool.ManagedPipelineMode
                                    'Start Mode' = $IISWebAppPool.StartMode
                                }
                                $OutObj += [pscustomobject](ConvertTo-HashToYN $inObj)
                            } catch {
                                Write-PScriboMessage -IsWarning $_.Exception.Message
                            }
                        }

                        $TableParams = @{
                            Name = "Application Pools"
                            List = $false
                            ColumnWidths = 30, 15, 15, 20, 20
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $OutObj | Table @TableParams
                    }
                }
            } catch {
                Write-PScriboMessage -IsWarning $_.Exception.Message
            }
        }
    }
    end {}
}
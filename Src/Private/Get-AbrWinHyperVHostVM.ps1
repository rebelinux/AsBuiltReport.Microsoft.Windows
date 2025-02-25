function Get-AbrWinHyperVHostVM {
    <#
    .SYNOPSIS
    Used by As Built Report to retrieve Windows Server Hyper-V VM information.
    .DESCRIPTION
        Documents the configuration of Microsoft Windows Server in Word/HTML/Text formats using PScribo.
    .NOTES
        Version:        0.5.6
        Author:         Andrew Ramsay
        Editor:         Jonathan Colon
        Twitter:        @asbuiltreport
        Github:         AsBuiltReport
        Credits:        Iain Brighton (@iainbrighton) - PScribo module

    .LINK
        https://github.com/AsBuiltReport/AsBuiltReport.Microsoft.Windows
    #>
    [CmdletBinding()]
    param (
    )

    begin {
        Write-PScriboMessage "Hyper-V InfoLevel set at $($InfoLevel.HyperV)."
        Write-PScriboMessage "Collecting Hyper-V VM information."
    }

    process {
        if ($InfoLevel.HyperV -ge 1) {
            #$Vms = Get-VM -CimSession $TempCimSession
            $script:Vms = Invoke-Command -Session $TempPssSession { Get-VM }
            if ($Vms) {
                try {
                    Section -Style Heading3 'Hyper-V VMs' {
                        Paragraph 'The following section details the Hyper-V VMs running on this host'
                        BlankLine
                        $OutObj = @()
                        foreach ($Vm in $Vms) {
                            try {
                                $inObj = [ordered] @{
                                    'VM Name' = $Vm.Name
                                    'State' = $Vm.State
                                }
                                $OutObj += [pscustomobject](ConvertTo-HashToYN $inObj)
                            } catch {
                                Write-PScriboMessage -IsWarning $_.Exception.Message
                            }
                        }
                        $TableParams = @{
                            Name = "Virtual Machines"
                            List = $false
                            ColumnWidths = 50, 50
                        }
                        if ($Report.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $OutObj | Sort-Object 'VM Name' | Table @TableParams
                        foreach ($Vm in $Vms) {
                            try {
                                Section -Style Heading4 ($Vm.Name) {
                                    Paragraph 'The following sections detail the VM configuration settings'
                                    BlankLine
                                    try {
                                        Section -ExcludeFromTOC -Style NOTOCHeading5 'Virtual Machine Configuration' {
                                            $OutObj = @()
                                            $DVDDrives = Invoke-Command -Session $TempPssSession -ScriptBlock { Get-VMDvdDrive -VMName ($using:Vm).Name }
                                            $inObj = [ordered] @{
                                                'VM id' = $Vm.VMid
                                                'VM Path' = $Vm.Path
                                                'Uptime' = $Vm.Uptime
                                                'vCPU Count' = $Vm.ProcessorCount
                                                'Memory Assigned (GB)' = [Math]::Round($Vm.MemoryAssigned / 1gb)
                                                'Dynamic Memory Enabled' = $Vm.DynamicMemoryEnabled
                                                'Memory Startup (GB)' = [Math]::Round($Vm.MemoryStartup / 1gb)
                                                'Memory Minimum (GB)' = [Math]::Round($Vm.MemoryMinimum / 1gb)
                                                'Memory Maximum (GB)' = [Math]::Round($Vm.MemoryMaximum / 1gb)
                                                'Numa Aligned' = $Vm.NumaAligned
                                                'Nuber of Numa Nodes' = $Vm.NumaNodesCount
                                                'Number of Numa Sockets' = $Vm.NumaSocketCount
                                                'Check Point Type' = $Vm.CheckpointType
                                                'Parent Snapshot Id' = $Vm.ParentSnapshotId
                                                'Parent Snapshot Name' = $Vm.ParentSnapshotName
                                                'Generation' = $Vm.Generation
                                                'DVD Drives' = $DVDDrives | ForEach-Object { "Controller Type: $($_.ControllerType), Media Type: $($_.DvdMediaType), Path: $($_.Path)" }
                                            }
                                            $OutObj += [pscustomobject](ConvertTo-HashToYN $inObj)
                                            $TableParams = @{
                                                Name = "Virtual Machines"
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
                                    try {
                                        Section -ExcludeFromTOC -Style NOTOCHeading5 'Virtual Machine Guest Integration Service' {
                                            $OutObj = @()
                                            $VMIntegrationService = Invoke-Command -Session $TempPssSession -ScriptBlock { Get-VMIntegrationService -VMName ($using:Vm).Name }
                                            Foreach ($Service in $VMIntegrationService) {
                                                try {
                                                    $inObj = [ordered] @{
                                                        'Service Name' = $Service.Name
                                                        'Service State' = $Service.Enabled
                                                        'Primary Status' = $Service.PrimaryStatusDescription
                                                    }
                                                    $OutObj += [pscustomobject](ConvertTo-HashToYN $inObj)
                                                } catch {
                                                    Write-PScriboMessage -IsWarning $_.Exception.Message
                                                }
                                            }
                                            $TableParams = @{
                                                Name = "Integration Service"
                                                List = $false
                                                ColumnWidths = 40, 30, 30
                                            }
                                            if ($Report.ShowTableCaptions) {
                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                            }
                                            $OutObj | Table @TableParams
                                        }
                                    } catch {
                                        Write-PScriboMessage -IsWarning $_.Exception.Message
                                    }
                                    try {
                                        #$VmNetworkAdapters = Get-VMNetworkAdapter -CimSession $TempCimSession -VMName $VM.Name
                                        $VmNetworkAdapters = Invoke-Command -Session $TempPssSession -ScriptBlock { Get-VMNetworkAdapter -VMName ($using:Vm).Name }
                                        if ($VmNetworkAdapters) {
                                            Section -ExcludeFromTOC -Style NOTOCHeading5 'VM Network Adapters' {
                                                $OutObj = @()
                                                ForEach ($Adapter in $VmNetworkAdapters) {
                                                    try {
                                                        $inObj = [ordered] @{
                                                            'Name' = $Adapter.Name
                                                            'Mac Address' = $Adapter.MacAddress
                                                            'IP Address' = ($Adapter.IPAddresses)
                                                            'Switch Name' = $Adapter.SwitchName
                                                        }
                                                        $OutObj += [pscustomobject](ConvertTo-HashToYN $inObj)
                                                    } catch {
                                                        Write-PScriboMessage -IsWarning $_.Exception.Message
                                                    }
                                                }

                                                $TableParams = @{
                                                    Name = "VM Network Adapters"
                                                    List = $false
                                                    ColumnWidths = 25, 25, 25, 25
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $OutObj | Sort-Object -Property 'Name' | Table @TableParams
                                            }
                                        }
                                    } catch {
                                        Write-PScriboMessage -IsWarning $_.Exception.Message
                                    }
                                    try {
                                        #$VmAdapterVlan = Get-VMNetworkAdapterVlan -CimSession $TempCimSession -VMName $VM.Name
                                        $VmAdapterVlan = Invoke-Command -Session $TempPssSession -ScriptBlock { Get-VMNetworkAdapterVlan -VMName ($using:Vm).Name | Select-Object -Property * }
                                        if ($VmAdapterVlan) {
                                            Section -ExcludeFromTOC -Style NOTOCHeading5 'VM Network Adapter VLANs' {
                                                $OutObj = @()
                                                ForEach ($Adapter in $VmAdapterVlan) {
                                                    try {
                                                        $inObj = [ordered] @{
                                                            'Adapter Name' = $Adapter.ParentAdapter.Name
                                                            'Operation Mode' = $Adapter.OperationMode
                                                            'Vlan ID' = $Adapter.AccessVlanId
                                                            'Trunk Vlans' = $Adapter.AllowedVlanIdList -Join ","
                                                        }
                                                        $OutObj += [pscustomobject](ConvertTo-HashToYN $inObj)
                                                    } catch {
                                                        Write-PScriboMessage -IsWarning $_.Exception.Message
                                                    }
                                                }

                                                $TableParams = @{
                                                    Name = "VM Network Adapter Vlans"
                                                    List = $false
                                                    ColumnWidths = 25, 25, 25, 25
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $OutObj | Sort-Object -Property 'Adapter Name' | Table @TableParams
                                            }
                                        }
                                    } catch {
                                        Write-PScriboMessage -IsWarning $_.Exception.Message
                                    }
                                    try {
                                        #$VmHardDisks = Get-VMHardDiskDrive -CimSession $TempCimSession -VMName $VM.Name
                                        $VmHardDisks = Invoke-Command -Session $TempPssSession -ScriptBlock { Get-VMHardDiskDrive -VMName ($using:Vm).Name }
                                        if ($VmHardDisks) {
                                            Section -ExcludeFromTOC -Style NOTOCHeading5 'VM Hard Disks' {
                                                $OutObj = @()
                                                foreach ($VmHardDisk in $VMHardDisks) {
                                                    try {
                                                        $VmVhd = Invoke-Command -Session $TempPssSession -ScriptBlock { Get-VHD -Path ($using:VmHardDisk).Path }
                                                        $inObj = [ordered] @{
                                                            'Disk Path' = $VmVhd.Path
                                                            'Disk Format' = $VmVhd.VhdFormat
                                                            'Disk Type' = $VmVhd.VhdType
                                                            'Disk Used(GB)' = [Math]::Round($VmVhd.FileSize / 1gb)
                                                            'Disk Max(GB)' = [Math]::Round($VmVhd.Size / 1gb)
                                                            'Bus Type' = $VmHardDisk.ControllerType
                                                            'Bus No' = $VmHardDisk.ControllerNumber
                                                            'Bus Location' = $VmHardDisk.ControllerLocation
                                                        }
                                                        $OutObj += [pscustomobject](ConvertTo-HashToYN $inObj)
                                                    } catch {
                                                        Write-PScriboMessage -IsWarning $_.Exception.Message
                                                    }
                                                }

                                                $TableParams = @{
                                                    Name = "VM Hard disks"
                                                    List = $false
                                                    ColumnWidths = 30, 10, 10, 10, 10, 10, 10, 10
                                                }
                                                if ($Report.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $OutObj | Sort-Object -Property 'Disk Path' | Table @TableParams
                                            }
                                        }
                                    } catch {
                                        Write-PScriboMessage -IsWarning $_.Exception.Message
                                    }
                                }
                            } catch {
                                Write-PScriboMessage -IsWarning $_.Exception.Message
                            }
                        }
                    }
                } catch {
                    Write-PScriboMessage -IsWarning $_.Exception.Message
                }
            }
        }
    }

    end {}
}

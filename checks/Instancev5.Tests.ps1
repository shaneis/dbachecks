# So the v5 files need to be handled differently.
# Ww will start with a BeforeDiscovery which will gather the Instance Information up front
# Gather the instances we know are not contactable

BeforeDiscovery {
    # Gather the instances we know are not contactable
    [string[]]$NotContactable = (Get-PSFConfig -Module dbachecks -Name global.notcontactable).Value
    # Get all the tags in use in this run
    $Tags = Get-CheckInformation -Check $Check -Group Instance -AllChecks $AllChecks -ExcludeCheck $ChecksToExclude
    
    $InstancesToTest = @(Get-Instance).ForEach{
        # just add it to the Not Contactable list
        if ($NotContactable -notcontains $psitem) {
            $Instance = $psitem
            try {
                $InstanceSMO = Connect-DbaInstance  -SqlInstance $Instance -ErrorAction SilentlyContinue -ErrorVariable errorvar
            }
            catch {
                $NotContactable += $Instance
            }
            if ($NotContactable -notcontains $psitem) {
                if ($null -eq $InstanceSMO.version) {
                    $NotContactable += $Instance
                }
                else {
                    # Get the relevant information for the checks in one go to save repeated trips to the instance and set values for Not Contactable tests if required
                    NewGet-AllInstanceInfo -Instance $InstanceSMO -Tags $Tags
                }
            }
        }
    }
    Write-PSFMessage -Message "Instances = $($InstancesToTest.Name)" -Level Verbose
    Set-PSFConfig -Module dbachecks -Name global.notcontactable -Value $NotContactable
}

Describe "Default Trace" -Tag DefaultTrace, CIS, Low, Instance -ForEach $InstancesToTest {
    $skip = Get-DbcConfigValue skip.instance.defaulttrace
    Context "Checking Default Trace on <_.Name>" {
        It "The Default Trace should be enabled on <_.Name>"  -Skip:$skip {
            $PSItem.Configuration.DefaultTraceEnabled.ConfigValue   | Should -Be 1 -Because "We expected the Default Trace to be enabled"
        }
    }
}
Describe "OLE Automation Procedures Disabled" -Tag OleAutomationProceduresDisabled, CIS, Low, Instance -ForEach $InstancesToTest {
    $skip = Get-DbcConfigValue skip.instance.oleautomationproceduresdisabled
    Context "Checking OLE Automation Procedures on <_.Name>" {
        It "The OLE Automation Procedures should be disabled on <_.Name>"  -Skip:$skip {
            $PSItem.Configuration.OleAutomationProceduresEnabled.ConfigValue   | Should -Be 0 -Because "We expect the OLE Automation Procedures to be disabled"
        }
    }
}

Describe "Remote Access Disabled" -Tag RemoteAccessDisabled, Security, CIS, Low, Instance -ForEach $InstancesToTest {
    $skip = Get-DbcConfigValue skip.instance.remoteaccessdisabled
    Context "Checking Remote Access on <_.Name>" {
        It "Remote Access should be disabled on <_.Name>"  -Skip:$skip {
            $PSItem.Configuration.RemoteAccess.ConfigValue | Should -Be 0 -Because "We expected Remote Access to be disabled"
        }
    }
}

Describe "Cross Database Ownership Chaining" -Tag CrossDBOwnershipChaining, Security, CIS, Low, Instance -ForEach $InstancesToTest {
    $skip = Get-DbcConfigValue skip.instance.CrossDBOwnershipChaining
    Context "Checking Cross Database Ownership Chaining on <_.Name>" {
        It "Cross Database Ownership Chaining should be disabled on <_.Name>"  -Skip:$skip {
            $PSItem.Configuration.CrossDBOwnershipChaining.ConfigValue | Should -Be 0 -Because "We expected the Cross DB Ownership Chaining to be disabled"
        }
    }
}

Describe "Scan For Startup Procedures" -Tag ScanForStartupProceduresDisabled,  Security, CIS, Low, Instance -ForEach $InstancesToTest {
    $skip = Get-DbcConfigValue skip.instance.scanforstartupproceduresdisabled
    Context "Checking Scan For Startup Procedures on <_.Name>" {
        It "Scan For Startup Procedures is set to <_.ConfigValues.scanforstartupproceduresdisabled> on <_.Name>"  -Skip:$skip {
            $PSItem.Configuration.ScanForStartupProcedures.ConfigValue -eq 0 | Should -Be $PSItem.ConfigValues.scanforstartupproceduresdisabled -Because "We expected the Cross DB Ownership Chaining to be disabled"
        }
    }
}

Describe "SQL Mail XPs Disabled" -Tag SQLMailXPsDisabled,  Security, CIS, Low, Instance -ForEach $InstancesToTest {
    $skip = Get-DbcConfigValue skip.instance.SQLMailXPsDisabled
    Context "Checking SQL Mail XPs on <_.Name>" {
        It "SQL Mail XPs should be disabled on <_.Name>"  -Skip:($skip -or $psitem.VersionMajor -gt 10) {
            $PSItem.Configuration.SqlMailXPsEnabled.ConfigValue | Should -Be 0 -Because "We expected Sql Mail XPs to be disabled"
        }
    }
}

Describe "Dedicated Administrator Connection" -Tag DAC, Security, CIS, Low, Instance -ForEach $InstancesToTest {
    $skip = Get-DbcConfigValue skip.instance.dac
    Context "Checking Dedicated Administrator Connection on <_.Name>" {
        It "DAC is set to <_.ConfigValues.dacallowed> on <_.Name>"  -Skip:$skip {
            $PSItem.Configuration.RemoteDACConnectionsEnabled.ConfigValue -eq 1 | Should -Be $psitem.ConfigValues.dacallowed -Because 'This is the setting that you have chosen for DAC connections'
        }
    }
}

Describe "OLE Automation" -Tag OLEAutomation, Security, CIS, Low, Instance -ForEach $InstancesToTest {
    $skip = Get-DbcConfigValue skip.instance.oleautomation
    Context "Checking OLE Automation on <_.Name>" {
        It "OLE Automation is set to <_.ConfigValues.OLEAutomation> on <_.Name>"  -Skip:$skip {
            $PSItem.Configuration.OleAutomationProceduresEnabled.ConfigValue -eq 1 | Should -Be $psitem.ConfigValues.OLEAutomation -Because 'OLE Automation can introduce additional security risks'
        }
    }
}
Describe "Ad Hoc Workload Optimization" -Tag AdHocWorkload, Medium, Instance -ForEach $InstancesToTest {
    $skip = Get-DbcConfigValue skip.instance.AdHocWorkload
    Context "Checking Ad Hoc Workload Optimization on <_.Name>" {
        It "Ad Hoc Workload Optimization is enabled on <_.Name>"  -Skip:($skip -or $psitem.VersionMajor -lt 10) {
            $PSItem.Configuration.OptimizeAdhocWorkloads.ConfigValue -eq 1 | Should -Be 1 -Because "Optimize for ad hoc workloads is a recommended setting"
        }
    }
}

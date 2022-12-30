if(-not (Get-Module Az.ResourceGraph -ListAvailable))
{
  Install-Module Az.ResourceGraph -Scope CurrentUser -Force
}
$query = "policyresources
| where type == 'microsoft.authorization/policyassignments'
| project AssignmentName = tostring(properties.displayName), policyDefinitionId = tostring(properties.policyDefinitionId), enforcementMode = properties.enforcementMode, scope = tostring(properties.scope), Assignmentparameters = parse_json(properties.parameters)
| join kind = leftouter  ( resourcecontainers 
    | project scope = id, ScopeName = name, Scopetype = case(type endswith 'subscriptions', 'Subscription', type endswith 'resourcegroups', 'Resource Group', type endswith 'managementgroups', 'Management Group', 'Root Management Group'))
    on scope
| join kind = leftouter ( policyresources 
    | where type == 'microsoft.authorization/policydefinitions' or type == 'microsoft.authorization/policysetdefinitions'
    | project policyDefinitionId = id, PolicyName = properties.displayName, kind, PolicyType = properties.policyType, DefaultEffect = properties.parameters.effect.defaultValue ) 
    on policyDefinitionId
| project policyDefinitionId, ['Assignment Name'] = AssignmentName, ['Policy Name'] = PolicyName, Kind = case(kind=='policysetdefinitions', 'Initiative', 'Policy'), ['Policy Type'] = PolicyType , Scope = scope, ['Scope Name'] = ScopeName, ['Scope Type'] = Scopetype, ['Enforcement Mode'] = enforcementMode, ['Assignment Parameters'] = Assignmentparameters, ['Default Effect'] = DefaultEffect"

$results = Search-AzGraph -Query $query -UseTenantScope -First 1000
#$results | Export-Csv -Path "./assignmentsParametersReport.csv"
$parametersReport = @()
foreach ($assignment in $results)
{
    switch ($assignment.Kind) {
        "Initiative"
        { 
            if($assignment.'Enforcement Mode' -ne 'DoNotEnforce')
            {
                if($assignment.'Assignment Parameters')
                {
                    $props = Get-Member -InputObject $assignment.'Assignment Parameters' -MemberType NoteProperty
                    $definition = Get-AzPolicySetDefinition -Id $assignment.policyDefinitionId
                    
                    foreach ($prop in $props)
                    {
                        $parameterValue = (($assignment.'Assignment Parameters').($prop.Name)).value
                        if ($parameterValue -eq "disabled")
                        {
                            $policyDefinitionId = ($definition.Properties.PolicyDefinitions | Select-Object policyDefinitionId, parameters) | Where-Object {$_.parameters.effect.value -like "*$($prop.Name)*"} | Select-Object -ExpandProperty policyDefinitionId
                            if($policyDefinitionId)
                            {                                
                                if ($parameterValue)
                                {
                                    $activeEffect = $parameterValue
                                }
                                else
                                {
                                    $activeEffect = (($definition.Properties.Parameters).($prop.Name)).defaultValue
                                }
                                $properties = [ordered]@{
                                    'Assignment Name' = $assignment.'Assignment Name'                            
                                    'Enforcement Mode' = $assignment.'Enforcement Mode'
                                    #'Effect Parameter Internal Name' = $prop.Name                                    
                                    'Effect Parameter Display Name' = (($definition.Properties.Parameters).($prop.Name)).metadata.displayName
                                    'Active Effect' = $activeEffect
                                    #'Effect Parameter Assignment Value' = $parameterValue        
                                    #'Effect Parameter Default Value' = (($definition.Properties.Parameters).($prop.Name)).defaultValue
                                    #'Effect Parameter policyDefinitionId' = $policyDefinitionId
                                    'Effect Parameter Policy Name' = ((Get-AzPolicyDefinition -Id $policyDefinitionId).properties).DisplayName
                                    'Assignment Policy Name' = $assignment.'Policy Name'
                                    'Assignment Kind' = $assignment.Kind
                                    'Assignment Policy Type' = $assignment.'Policy Type'
                                    #'Assignment Scope' = $assignment.Scope
                                    'Scope Name' = $assignment.'Scope Name'
                                    'Scope Type'  = $assignment.'Scope Type'
                                }
                                $parametersReport += [pscustomobject]$properties
                            }
                        }
                    }
                }
            }
            else
            {
                    $properties = [ordered]@{
                        'Assignment Name' = $assignment.'Assignment Name'                            
                        'Enforcement Mode' = $assignment.'Enforcement Mode'
                        #'Effect Parameter Internal Name' = "NA"
                        'Effect Parameter Display Name' = "NA"
                        'Active Effect' = "NA"
                        #'Effect Parameter Assignment Value' = "NA"        
                        #'Effect Parameter Default Value' = "NA"
                        #'Effect Parameter policyDefinitionId' = "NA"
                        'Effect Parameter Policy Name' = "NA"
                        'Assignment Policy Name' = $assignment.'Policy Name'
                        'Assignment Kind' = $assignment.Kind
                        'Assignment Policy Type' = $assignment.'Policy Type'
                        #'Assignment Scope' = $assignment.Scope
                        'Scope Name' = $assignment.'Scope Name'
                        'Scope Type'  = $assignment.'Scope Type'
                    }
                    $parametersReport += [pscustomobject]$properties
            }
        }  
        "Policy" 
        {
            if($assignment.'Enforcement Mode' -ne 'DoNotEnforce')
            {
                if($assignment.'Assignment Parameters')
                {
                    $props = Get-Member -InputObject $assignment.'Assignment Parameters' -MemberType NoteProperty
                    $definition = Get-AzPolicyDefinition -Id $assignment.policyDefinitionId
                    
                    foreach ($prop in $props)
                    {
                        $parameterValue = (($assignment.'Assignment Parameters').($prop.Name)).value
                        if ($parameterValue -eq "disabled" -and $prop.Name -eq "effect")
                        {
                            $policyDefinitionId = $assignment.policyDefinitionId
                            if($policyDefinitionId)
                            {
                                if ($parameterValue)
                                {
                                    $activeEffect = $parameterValue
                                }
                                else
                                {
                                    $activeEffect = (($definition.Properties.Parameters).($prop.Name)).defaultValue
                                }
                                $properties = [ordered]@{
                                    'Assignment Name' = $assignment.'Assignment Name'                            
                                    'Enforcement Mode' = $assignment.'Enforcement Mode'
                                    #'Effect Parameter Internal Name' = $prop.Name
                                    'Effect Parameter Display Name' = (($definition.Properties.Parameters).($prop.Name)).metadata.displayName
                                    'Active Effect' = $activeEffect
                                    #'Effect Parameter Assignment Value' = $parameterValue        
                                    #'Effect Parameter Default Value' = (($definition.Properties.Parameters).($prop.Name)).defaultValue
                                    #'Effect Parameter policyDefinitionId' = $policyDefinitionId
                                    'Effect Parameter Policy Name' = ((Get-AzPolicyDefinition -Id $policyDefinitionId).properties).DisplayName
                                    'Assignment Policy Name' = $assignment.'Policy Name'
                                    'Assignment Kind' = $assignment.Kind
                                    'Assignment Policy Type' = $assignment.'Policy Type'
                                    #'Assignment Scope' = $assignment.Scope
                                    'Scope Name' = $assignment.'Scope Name'
                                    'Scope Type'  = $assignment.'Scope Type'
                                }
                                $parametersReport += [pscustomobject]$properties
                            }
                        }
                    }
                }
            }
            else
            {
                    $properties = [ordered]@{
                        'Assignment Name' = $assignment.'Assignment Name'                            
                        'Enforcement Mode' = $assignment.'Enforcement Mode'
                        #'Effect Parameter Internal Name' = "NA"
                        'Effect Parameter Display Name' = "NA"
                        'Active Effect' = "NA"
                        #'Effect Parameter Assignment Value' = "NA"        
                        #'Effect Parameter Default Value' = "NA"
                        #'Effect Parameter policyDefinitionId' = "NA"
                        'Effect Parameter Policy Name' = "NA"
                        'Assignment Policy Name' = $assignment.'Policy Name'
                        'Assignment Kind' = $assignment.Kind
                        'Assignment Policy Type' = $assignment.'Policy Type'
                        #'Assignment Scope' = $assignment.Scope
                        'Scope Name' = $assignment.'Scope Name'
                        'Scope Type'  = $assignment.'Scope Type'
                    }
                    $parametersReport += [pscustomobject]$properties
            }
        }
    }
}

$parametersReport | Export-Csv -Path "./assignmentsParametersReport.csv" 
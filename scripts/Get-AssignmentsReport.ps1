<#
$ManagementGroup = ""
if(-not (Get-Module Az.ResourceGraph -ListAvailable))
{
  Install-Module Az.ResourceGraph -Scope CurrentUser -Force
}
$query = "resourcecontainers | where type == 'microsoft.resources/subscriptions' | mv-expand managementGroupParent = properties.managementGroupAncestorsChain | where managementGroupParent.name =~ '$ManagementGroup' | project name, id | sort by name asc"
$subscriptions = Search-AzGraph -Query $query -UseTenantScope -First 1000
$assignments = @()
foreach ($subscription in $subscriptions)
{
    $assignments += Get-AzPolicyAssignment -scope $subscription.id -WarningAction SilentlyContinue | Select-Object -Property PolicyAssignmentId -ExpandProperty Properties | Select-Object PolicyAssignmentId, PolicyDefinitionId, DisplayName, Scope, NotScopes
    $subscriptionId = ($subscription.id -split("/"))[-1]
    $resourceGroupQuery = "resourcecontainers | where type == 'microsoft.resources/subscriptions/resourcegroups' | where subscriptionId == '$subscriptionId' | project id"
    $resourceGroups = Search-AzGraph -Query $resourceGroupQuery -First 1000
    foreach ($resourceGroup in $resourceGroups)
    {
        $assignments += Get-AzPolicyAssignment -scope $resourceGroup.id -WarningAction SilentlyContinue | Select-Object -Property PolicyAssignmentId -ExpandProperty Properties | Select-Object PolicyAssignmentId, PolicyDefinitionId, DisplayName, Scope, NotScopes
    }
}
$assignments = $assignments | Sort-Object -Unique PolicyAssignmentId | Sort-Object  DisplayName
$report = @()
foreach ($assignment in $assignments)
{
    switch (($assignment.PolicyDefinitionId -like "*/policySetDefinitions/*"))
    {
        $true { 

            $kind = "Initiative"
            $policy = (Get-AzPolicySetDefinition -Id $assignment.PolicyDefinitionId).Properties `
                | Select-Object DisplayName, @{Name='PolicyType';Expression={($_.PolicyType).ToString()}}, PolicyDefinitions

            $properties = [ordered]@{
                'Assignment Name' = $assignment.DisplayName
                'Policy Name' = $policy.DisplayName
                Kind = $kind
                'Policy Type' = $policy.PolicyType
                Scope = $assignment.Scope
                notScopes = $assignment.NotScopes
            }
            $report += [pscustomobject]$properties            
        }
        $false {

            $kind = "Policy"
            $policy = (Get-AzPolicyDefinition -Id $assignment.PolicyDefinitionId).Properties `
                | Select-Object DisplayName, @{Name='PolicyType';Expression={($_.PolicyType).ToString()}}

            $properties = [ordered]@{
                'Assignment Name' = $assignment.DisplayName
                'Policy Name' = $policy.DisplayName
                Kind = $kind
                'Policy Type' = $policy.PolicyType
                Scope = $assignment.Scope
                notScopes = $assignment.NotScopes
            }
            $report += [pscustomobject]$properties
        }
    }
}
#ConvertTo-Json -InputObject ($report | Sort-Object -Property kind) -Depth 100 | Out-File -FilePath "./assignmentsReport.json"
$report | Select-Object `
    'Assignment Name', `
    'Policy Name', `
    Kind, `
    'Policy Type', `
    Scope, `
    @{Name='notScopes';Expression={($_.notScopes) -join(" | ")}} `
    | Export-Csv -Path "./assignmentsReport.csv"



#>

$query = "policyresources
| where type == 'microsoft.authorization/policyassignments'
| project AssignmentName = tostring(properties.displayName), policyDefinitionId = tostring(properties.policyDefinitionId), scope = tostring(properties.scope), notScopes = properties.notScopes
| join kind = leftouter  ( resourcecontainers 
    | project scope = id, ScopeName = name, Scopetype = case(type endswith 'subscriptions', 'Subscription', type endswith 'resourcegroups', 'Resource Group', type endswith 'managementgroups', 'Management Group', 'Root Management Group'))
    on scope
| join kind = leftouter  ( policyresources 
    | where type == 'microsoft.authorization/policydefinitions' or type == 'microsoft.authorization/policysetdefinitions'
    | project policyDefinitionId = id, PolicyName = properties.displayName, kind, PolicyType = properties.policyType ) 
    on policyDefinitionId
| project ['Assignment Name'] = AssignmentName, ['Policy Name'] = PolicyName, Kind = case(kind=='policysetdefinitions', 'Initiative', 'Policy'), ['Policy Type'] = PolicyType, Scope = scope, ['Scope Name'] = iff(isempty(ScopeName), 'Tenant Root Group', ScopeName), ['Scope Type'] = iff(isempty(Scopetype), 'Root Management Group', Scopetype), notScopes
| order by ['Assignment Name'] asc"

$results = Search-AzGraph -Query $query -UseTenantScope -First 1000
$results | Select-Object `
            'Assignment Name', `
            'Policy Name', `
            Kind, `
            'Policy Type', `
            Scope, `
            'Scope Name', `
            'Scope Type', `
            @{Name='notScopes';Expression={($_.notScopes) -join(" | ")}} `
            | Export-Csv -Path "./assignmentsReport.csv"
#>    
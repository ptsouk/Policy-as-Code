$reportName = "myReport"
#Expand-Archive -Path "./$reportName.csv.zip" -Force
$entries = Import-Csv -Path "./$reportName.csv"
$report = @()
# get all unique subscriptions
$subscriptionIds = $entries.Resource_ID | ForEach-Object {($_ -split("/"))[2]} | Sort-Object -Unique
$subscriptions = @()
foreach ($subscriptionId in $subscriptionIds)
{
    $properties = [ordered]@{
        subscriptionName = Get-AzSubscription -TenantId (Get-AzContext).Tenant -SubscriptionId $subscriptionId | Select-Object -ExpandProperty Name
        SubscriptionId = $subscriptionId
    }
    $subscriptions += [pscustomobject]$properties
}
# get all unique assignments
$assignmentIds = $entries.POLICY_ASSG_ID | Sort-Object -Unique
$assignments = @()
foreach ($assignmentId in $assignmentIds)
{
    $properties = [ordered]@{
        assignmentName = (Get-AzPolicyAssignment -Id $assignmentId -WarningAction SilentlyContinue).Properties.DisplayName
        assignmentId = $assignmentId
    }
    $assignments += [pscustomobject]$properties
}
# get all unique policies
$policyIds = $entries.POLICY_DEF_ID | Sort-Object -Unique
$policies = @()
foreach ($policyId in $policyIds)
{
    $properties = [ordered]@{
        policyName = (Get-AzPolicyDefinition -Id $policyId -WarningAction SilentlyContinue).Properties.DisplayName
        policyId = $policyId
    }
    $policies += [pscustomobject]$properties
}
# get all unique initiatives
$initiativeIds = $entries.INITIATIVE_ID | Sort-Object -Unique
$initiatives = @()
foreach ($initiativeId in $initiativeIds)
{
    if ($initiativeId)
    {
        $properties = [ordered]@{
            initiativeName = (Get-AzPolicySetDefinition -Id $initiativeId -WarningAction SilentlyContinue).Properties.DisplayName
            initiativeId = $initiativeId
        }
        $initiatives += [pscustomobject]$properties
    }
    else
    {
        $properties = [ordered]@{
            initiativeName = "N/A"
            initiativeId = $null
        }
        $initiatives += [pscustomobject]$properties
    }
}

foreach ($entry in $entries)
{
    $data = $entry.RESOURCE_ID -split ("/")
    $subscription = $subscriptions | Where-Object {$_.SubscriptionId -eq $data[2]} | Select-Object -ExpandProperty subscriptionName
    if($entry.RESOURCE_LOCATION)
    {
        $resourceGroup = $data[4]
    }
    else 
    {
        $resourceGroup = "N/A"
    }
    $resourceName = $data[-1]
    $assignmentName = $assignments | Where-Object {$_.assignmentId -eq $entry.POLICY_ASSG_ID} | Select-Object -ExpandProperty assignmentName
    $policyName = $policies | Where-Object {$_.policyId -eq $entry.POLICY_DEF_ID} | Select-Object -ExpandProperty policyName
    $initiativeName = $initiatives | Where-Object {$_.initiativeId -eq $entry.INITIATIVE_ID} | Select-Object -ExpandProperty initiativeName

    $properties = [ordered]@{
        'Subscription Name' = $subscription
        'Resource Group' = $resourceGroup
        'Resource Type' = $entry.RESOURCE_TYPE
        'Resource Name' = $resourceName
        'Resource Location' = $entry.RESOURCE_LOCATION
        'Assignment Name' = $assignmentName
        'Policy Name' = $policyName
        'Initiative Name' = $initiativeName
        'Compliance State' = $entry.COMPLIANCE_STATE
    }
    $report += [pscustomobject]$properties      
}
$report | Export-Csv -Path "./$($reportName)_formatted.csv"
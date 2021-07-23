$scope = "/providers/Microsoft.Management/managementGroups/ES"
$assignments = Get-AzPolicyAssignment -scope $scope | Select-Object -ExpandProperty Properties
$report = @()
foreach ($assignment in $assignments)
{
    switch (($assignment.PolicyDefinitionId -split ("/"))[7]) {
        "policySetDefinitions" { 

            $kind = "Initiative"
            $policy = (Get-AzPolicySetDefinition -Id $assignment.PolicyDefinitionId).Properties `
                | Select-Object DisplayName, @{Name='PolicyType';Expression={($_.PolicyType).ToString()}}, PolicyDefinitions
            
            $referencedPolicies = @()
            foreach ($policyDefinitionId in $policy.PolicyDefinitions.policyDefinitionId) 
            {
                $referencedPolicies += (Get-AzPolicyDefinition -Id $policyDefinitionId).Properties | Select-Object DisplayName, @{Name='PolicyType';Expression={($_.PolicyType).ToString()}}
            }

            $properties = [ordered]@{
                kind = $kind
                PolicyType = $policy.PolicyType
                DisplayName = $policy.DisplayName
                referencedPolicies = $referencedPolicies
            }
            $report += [pscustomobject]$properties            
         }
        "policyDefinitions" {

            $kind = "Policy"
            $policy = (Get-AzPolicyDefinition -Id $assignment.PolicyDefinitionId).Properties `
                | Select-Object DisplayName, @{Name='PolicyType';Expression={($_.PolicyType).ToString()}}

            $properties = [ordered]@{
                kind = $kind
                PolicyType = $policy.PolicyType
                DisplayName = $policy.DisplayName
            }
            $report += [pscustomobject]$properties
        }
    }
}

ConvertTo-Json -InputObject ($report | Sort-Object -Property kind) -Depth 100 | Out-File -FilePath "./assignmentsReport.json"
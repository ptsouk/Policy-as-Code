$secret = '{
    "clientId": "",
    "clientSecret": "",
    "tenantId": ""
}'
$ManagementGroup = "a6e09f1d-1f05-497b-b499-da099ced752f"
$cred = $secret | ConvertFrom-Json
[securestring]$secStringPassword = ConvertTo-SecureString $cred.clientSecret -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential  $cred.clientId, $secStringPassword

Connect-AzAccount -ServicePrincipal -TenantId $cred.tenantId -Credential $Credential

$query = "resourcecontainers | where type == 'microsoft.resources/subscriptions' | mv-expand managementGroupParent = properties.managementGroupAncestorsChain | where managementGroupParent.name =~ '$ManagementGroup' | project name, id | sort by name asc"
$subscriptions = Search-AzGraph -Query $query -UseTenantScope
$subscriptions
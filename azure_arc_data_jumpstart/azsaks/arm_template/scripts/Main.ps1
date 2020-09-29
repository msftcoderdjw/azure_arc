[CmdletBinding()]
param (
    [string] $StampLocation="shanghai",
    [string] $OrchestratorRelease="1.17",
    [string] $OrchestratorVersion="1.17.11",
    [string] $PortalURL="https://portal.shanghai.int.azurestack.corp.microsoft.com/",
    [string] $IdentitySystem="azure_ad",
    [string] $DnsPrefix="k8s-jiadutest1",
    [string] $K8SAdminUser="azureuser",
    [string] $K8SPublicKey="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCbYi6m97Dtl9vcy7L8KPuzs1iU8hAAvAQp+DQsh1YzhGJL1oh5wZcqrKiUOQGfjpY7VEOWW6Boarv7Jc0aeB9sZzzkpFj3nDrucytOYeA9HBXY43aCofRkrY69+6YGjEwqtMoqZsvqXe8wpZf+Kl4zy4WOrETWS4JUQNjk1h0UOrcZGPbbltZKS73kJtD5RKEV0tne9oBGRqN/xaXbutSDkSnbNCqoPUfqnO1p0hn4po+J6BMPEYlzz6SD6rPzlYMSyk+MX2kh0TEgZHxubhoTpYq2vSkK+7fP235FRpt+5BRz1Mpom0APhmsjjoLGTmGx+kaSUab2u7CPDNy0+rB7 fareast\jiadu@jiadu-dev1",
    [string] $K8SPClientId="a154f21f-1c5f-4da5-867b-22f7aa5afcc4",
    [string] $K8SSPSecret="9Bw4.25O96K6A35pRegG.CqsIP1~0ida6~",
    [string] $K8STenantId="c157313f-ec36-46f2-ac00-d17e0d28b1cd",
    [string] $AzureEnv="AzureStackCloud",
    [string] $AzsK8SSubscriptionId="5b0b159e-daae-4ef1-af7d-6441c656227b",
    [string] $AzsK8SResourceGroup="k8s-jiadutest1",
    [string] $SampleAPIModelLocation="https://raw.githubusercontent.com/Azure/aks-engine/master/examples/azure-stack/kubernetes-azurestack.json",
    [ValidateSet("aks-engine-v0.55.4-windows-amd64")]
    [string] $AKSeVersion="aks-engine-v0.55.4-windows-amd64",
    [string] $AdminUsername="arcdemo",
    [string] $AZDATA_USERNAME="arcdemo",
    [string] $AZDATA_PASSWORD="ArcPassword123!!",
    [string] $ACCEPT_EULA="yes",
    [string] $REGISTRY_USERNAME,
    [string] $REGISTRY_PASSWORD,
    [string] $ARC_DC_NAME="jiaduk8s2-arcdata",
    [string] $ARC_DC_SUBSCRIPTION="746a51ba-0bd4-497f-89cc-f955a5db3bc8",
    [string] $ARC_DC_REGION="eastus",
    [string] $ARC_DC_RESOURCEGROUP="jiadu-TINA-Test-RG",
    [string] $chocolateyAppList,
    [string] $DOCKER_REGISTRY="mcr.microsoft.com",
    [string] $DOCKER_REPOSITORY="arcdata",
    [string] $DOCKER_TAG="latest"
)


# Step01 - Deploy a K8S cluster through AKSe
powershell.exe -ExecutionPolicy Bypass -File $PSScriptRoot\DeployK8SbyAKSe.ps1 -StampLocation $StampLocation `
    -OrchestratorRelease $OrchestratorRelease -OrchestratorVersion $OrchestratorVersion -PortalURL $PortalURL `
    -IdentitySystem $IdentitySystem -DnsPrefix $DnsPrefix -K8SAdminUser $K8SAdminUser -K8SPublicKey $K8SPublicKey -K8SPClientId $K8SPClientId `
    -K8SSPSecret $K8SSPSecret -AzureEnv $AzureEnv -AzsK8SSubscriptionId $AzsK8SSubscriptionId -AzsK8SResourceGroup $AzsK8SResourceGroup -SampleAPIModelLocation $SampleAPIModelLocation `
    -AKSeVersion $AKSeVersion

# Step02 - Run ClientTools.ps1 for azdata deployment
powershell.exe -ExecutionPolicy Bypass -File $PSScriptRoot\ClientTools.ps1 -servicePrincipalClientId $K8SPClientId `
    -servicePrincipalClientSecret $K8SSPSecret -adminUsername $AdminUsername -tenantId $K8STenantId -clusterName $DnsPrefix `
    -resourceGroup $ARC_DC_RESOURCEGROUP -AZDATA_USERNAME $AZDATA_USERNAME -AZDATA_PASSWORD $AZDATA_PASSWORD -ACCEPT_EULA $ACCEPT_EULA -REGISTRY_USERNAME $REGISTRY_USERNAME `
    -REGISTRY_PASSWORD $REGISTRY_PASSWORD -ARC_DC_NAME $ARC_DC_NAME -ARC_DC_SUBSCRIPTION $ARC_DC_SUBSCRIPTION -ARC_DC_REGION $ARC_DC_REGION -chocolateyAppList $chocolateyAppList `
    -DOCKER_REGISTRY $DOCKER_REGISTRY -DOCKER_REPOSITORY $DOCKER_REPOSITORY -DOCKER_TAG $DOCKER_TAG
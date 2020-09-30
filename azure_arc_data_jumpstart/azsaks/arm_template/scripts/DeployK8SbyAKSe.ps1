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
    [string] $AzureEnv="AzureStackCloud",
    [string] $AzsK8SSubscriptionId="5b0b159e-daae-4ef1-af7d-6441c656227b",
    [string] $AzsK8SResourceGroup="k8s-jiadutest1",
    [string] $SampleAPIModelLocation="https://raw.githubusercontent.com/Azure/aks-engine/master/examples/azure-stack/kubernetes-azurestack.json",
    [ValidateSet("aks-engine-v0.55.4-windows-amd64")]
    [string] $AKSeVersion="aks-engine-v0.55.4-windows-amd64",
    [string] $AgentPoolVMSize="Standard_DS12_v2"
)

$WorkingDir = "C:\k8stmp"
if (-not(Test-Path -Path $WorkingDir -PathType Container)) {
    New-Item -Path $WorkingDir -ItemType "directory" -Force
}

Start-Transcript "$WorkingDir\Logs\DeployK8S_$($(Get-Date).ToString("yyyy-MM-dd-HH-mm-ss")).txt"
$ErrorActionPreference = 'Stop'

Push-Location $WorkingDir
$Params2APIModelPropsKeyMapping = @{
    "StampLocation" = "location"
    "OrchestratorRelease" = "properties.orchestratorProfile.orchestratorRelease"
    "OrchestratorVersion" = "properties.orchestratorProfile.orchestratorVersion"
    "PortalURL" = "properties.customCloudProfile.portalURL"
    "IdentitySystem" = "properties.customCloudProfile.identitySystem"
    "DnsPrefix" = "properties.masterProfile.dnsPrefix"
    "K8SAdminUser" = "properties.linuxProfile.adminUsername"
    "K8SPublicKey" = "properties.linuxProfile.ssh.publicKeys[].keyData"
    "K8SPClientId" = "properties.servicePrincipalProfile.clientId"
    "K8SSPSecret" = "properties.servicePrincipalProfile.secret"
    "AgentPoolVMSize" = "properties.agentPoolProfiles[].vmSize"
}

Write-Verbose -Message "Using Parameters: " -Verbose
Write-Verbose -Message $($PSBoundParameters | ConvertTo-Json)  -Verbose

# workaround for WS 2016
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.ServicePointManager]::SecurityProtocol

$KUBECONFIGPath = "$WorkingDir\_output\$DnsPrefix\kubeconfig\kubeconfig.$($StampLocation).json"
if (-not (Test-Path -Path $KUBECONFIGPath -PathType Leaf)) {
    # Installing tools
    Invoke-WebRequest "https://aksereleases.blob.core.windows.net/public/$($AKSeVersion).zip" -OutFile "$WorkingDir\$($AKSeVersion).zip"
    Expand-Archive "$WorkingDir\$($AKSeVersion).zip" -DestinationPath "$WorkingDir" -Force
    $AKSeBinaryLocation = "$WorkingDir\$($AKSeVersion)\aks-engine.exe"

    $APIModelSampleLocation = "$WorkingDir\apimodel.json"
    $APIModelLocation = "$WorkingDir\apimodel-running.json"
    # Get the command name
    $CommandName = $PSCmdlet.MyInvocation.InvocationName;
    # Get the list of parameters for the command
    $ParameterList = (Get-Command -Name $CommandName).Parameters;

    # Using current folder as the running folder
    Invoke-WebRequest $SampleAPIModelLocation -OutFile $APIModelSampleLocation
    $apiModelJson = Get-Content $APIModelSampleLocation | ConvertFrom-Json
    # Composing the api model file
    foreach ($key in $ParameterList.Keys) {
        $value = (Get-Variable $key -ErrorAction SilentlyContinue).Value
        if ($Params2APIModelPropsKeyMapping.ContainsKey($key) -and ![string]::IsNullOrEmpty($value)) {
            $jsonKey = $Params2APIModelPropsKeyMapping[$key]
            Write-Host "Writing $value to $jsonKey" -ForegroundColor Yellow
            $hierachies = $jsonKey.split(".")
            $obj = $apiModelJson.PSObject.Properties
            for($i=0; $i -lt ($hierachies.Count-1); $i++) {
                $name = $hierachies[$i]
                if ($name.EndsWith("[]")) {
                    # array, will pick item0
                    $obj = ($obj | Where-Object {$_.Name -eq $name.TrimEnd("[]")}).Value[0].PSObject.Properties
                } else {
                    # object, will pick value
                    $obj = ($obj | Where-Object {$_.Name -eq $name}).Value.PSObject.Properties
                }
            }
            $name = $hierachies[$hierachies.Count - 1]
            if ($name.EndsWith("[]")) {
                # array
                ($obj | Where-Object {$_.Name -eq $name.TrimEnd("[]")}).Value = @($value)
            } else {
                # object
                ($obj | Where-Object {$_.Name -eq $name}).Value = $value
            }
        }
    }
    Write-Host "Generating running api model..." -ForegroundColor Green
    $apiModelJson | ConvertTo-Json -Depth 100  | Out-File $APIModelLocation -Encoding ascii -Force

    Write-Host "Deploying K8S cluster by AKSe, using API model: $((Get-Item $APIModelLocation).FullName), using AKSe: $AKSeBinaryLocation"  -ForegroundColor Green

    if ([string]::IsNullOrEmpty($AKSeBinaryLocation) -or [string]::IsNullOrEmpty($AzsK8SSubscriptionId) -or [string]::IsNullOrEmpty($K8SPClientId) `
        -or [string]::IsNullOrEmpty($K8SSPSecret) -or [string]::IsNullOrEmpty($StampLocation) -or [string]::IsNullOrEmpty($AzsK8SResourceGroup) `
        -or [string]::IsNullOrEmpty($AzureEnv) -or [string]::IsNullOrEmpty($IdentitySystem)) {
        Write-Error "Required parameter is null or empty, please check..."
        Pop-Location
        Stop-Transcript
        exit 1
    }

    & $AKSeBinaryLocation deploy --subscription-id $AzsK8SSubscriptionId --client-id $K8SPClientId `
        --client-secret $K8SSPSecret --location $StampLocation --resource-group $AzsK8SResourceGroup --api-model $((Get-Item $APIModelLocation).FullName) `
        --azure-env $AzureEnv --identity-system $IdentitySystem
} else {
    Write-Host "$KUBECONFIGPath already exists, will skip the K8S deployment" -ForegroundColor Yellow
}

# locate the k8s config file
if (-not (Test-Path -Path $KUBECONFIGPath -PathType Leaf)) {
    Write-Error "$KUBECONFIGPath doesn't exist after K8S deployment, please check..."
    Pop-Location
    Stop-Transcript
    exit 1
}

$KUBECONFIG = Get-Item $KUBECONFIGPath
Write-Host "Using kube config file: $($kubeConfig.FullName)" -ForegroundColor Green
[System.Environment]::SetEnvironmentVariable('KUBECONFIG', $KUBECONFIG,[System.EnvironmentVariableTarget]::Machine)

Pop-Location
Stop-Transcript
exit 0
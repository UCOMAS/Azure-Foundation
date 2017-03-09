Param(
        [string] $ResourceGroupName = "Feil",
        [ValidateSet("West Europe","North Europe","East US","East US 2","Central US","North Central US","South Central US","West Central US","West US","West US 2")] 
        [string] 
        $ResourceGroupLocation = "West Europe",
        [string] $MGMTResourceGroupName = "Feil"

    )

# Login to Azure
$RMContext = Get-AzureRmContext -ErrorAction SilentlyContinue
if (!$RMContext)
{
    Login-AzureRmAccount
}



# Pick Subscription/TenantID
$AzureInfo = 
    (Get-AzureRmSubscription `
        -ErrorAction Stop |
     Out-GridView `
        -Title 'Select a Subscription/Tenant ID for deployment...' `
        -PassThru)

# Select Subscription
Select-AzureRmSubscription `
    -SubscriptionId $AzureInfo.SubscriptionId `
    -TenantId $AzureInfo.TenantId `
    -ErrorAction Stop| Out-Null


#$PSScriptRoot = "C:\Source\Repos\AzureSMBOfferings\Azure-Foundation-Lite"
# Setting up some variables
[string] $TemplateFile = '\project\AzureFoundationLite\azuredeploy.json'
[string] $TemplateParametersFile = '\project\AzureFoundationLite\azuredeploy.parameters.json'
[string] $TemplateFileMGMT = '\project\AzureFoundationLite\azuredeploymanagement.json'
[string] $TemplateParametersFileMGMT = '\project\AzureFoundationLite\azuredeploymanagement.parameters.json'
[string] $AzCopyPath = 'project\AzureFoundationLite\Tools\AzCopy.exe'
[string] $NestedTempaltes = 'project\AzureFoundationLite\nested'
[string] $DSCSourceFolder = 'project\AzureFoundationLite\dsc'
[string] $RunbooksSourceFolder = 'project\AzureFoundationLite\runbooks'
$OptionalParameters = New-Object -TypeName Hashtable
$TemplateFile = Join-Path $PSScriptRoot $TemplateFile
$TemplateParametersFile = Join-Path $PSScriptRoot $TemplateParametersFile
$DSCSourceFolder = Join-Path $PSScriptRoot $DSCSourceFolder
$NestedFolder = Join-Path $PSScriptRoot $NestedTempaltes
Set-Variable ArtifactsLocationName '_artifactsLocation' -Option ReadOnly -Force
Set-Variable ArtifactsLocationSasTokenName '_artifactsLocationSasToken' -Option ReadOnly -Force
$OptionalParameters.Add($ArtifactsLocationName, $null)
$OptionalParameters.Add($ArtifactsLocationSasTokenName, $null)

$AzCopyPath = Join-Path $PSScriptRoot $AzCopyPath


# MGMT variables
$OptionalParametersMGMT = New-Object -TypeName Hashtable
$TemplateFileMGMT = Join-Path $PSScriptRoot $TemplateFileMGMT
$TemplateParametersFileMGMT = Join-Path $PSScriptRoot $TemplateParametersFileMGMT
$RunbooksSourceFolder  = Join-Path $PSScriptRoot $RunbooksSourceFolder 

$OptionalParametersMGMT.Add($ArtifactsLocationName, $null)
$OptionalParametersMGMT.Add($ArtifactsLocationSasTokenName, $null)



# Create Resource Group
Try
{
    Get-AzureRmResourceGroup -Name $ResourceGroupName `
                             -Location $ResourceGroupLocation `
                             -ErrorAction Stop 
}
Catch
{
    New-AzureRmResourceGroup -Name $ResourceGroupName `
                             -Location $ResourceGroupLocation `
                             -Force `
                             -ErrorAction Stop
}



# Create Temporary storage account and container to store nested tempaltes and DSC cofigs
$StorageAccountName = $ResourceGroupName.ToLowerInvariant() + 'artifacts1'
$StorageAccountName = $StorageAccountName.substring(0, [System.Math]::Min(24, $StorageAccountName.Length))
Try
{
    Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName  `
                              -Name $StorageAccountName `
                              -ErrorAction Stop
}
Catch
{
    New-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName `
                              -Name $StorageAccountName `
                              -SkuName Standard_LRS `
                              -Location $ResourceGroupLocation `
                              -ErrorAction Stop | Out-Null
}


$StorageAccountKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName)[0].Value
$StorageAccountContext = (Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName).Context
$StorageContainerName = $ResourceGroupName.ToLowerInvariant() + '-stageartifacts'

Try
{
    Get-AzureStorageContainer -Name $StorageContainerName `
                              -Context $StorageAccountContext `
                              -ErrorAction Stop
}
Catch
{
    New-AzureStorageContainer -Name $StorageContainerName `
                              -Permission Off `
                              -Context $StorageAccountContext `
                              -ErrorAction Stop | Out-Null

}






# Upload nested templates and dscconfigs to Storage container
$StorageAccountKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName)[0].Value
$StorageAccountContext = (Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName).Context

$ArtifactsLocation = $StorageAccountContext.BlobEndPoint + $StorageContainerName



# Use AzCopy to copy nested templates
& $AzCopyPath """$NestedFolder""", $ArtifactsLocation, "/DestKey:$StorageAccountKey", "/S", "/Y", "/Z:$env:LocalAppData\Microsoft\Azure\AzCopy\$ResourceGroupName"
if ($LASTEXITCODE -ne 0) { return }

# Use AzCopy to copy dsc configs
& $AzCopyPath """$DSCSourceFolder""", $ArtifactsLocation, "/DestKey:$StorageAccountKey", "/S", "/Y", "/Z:$env:LocalAppData\Microsoft\Azure\AzCopy\$ResourceGroupName"
if ($LASTEXITCODE -ne 0) { return }


# Use AzCopy to copy runbooks
& $AzCopyPath """$RunbooksSourceFolder""", $ArtifactsLocation, "/DestKey:$StorageAccountKey", "/S", "/Y", "/Z:$env:LocalAppData\Microsoft\Azure\AzCopy\$ResourceGroupName"
if ($LASTEXITCODE -ne 0) { return }

# Create a SAS token for the storage container - this gives temporary read-only access to the container
$ArtifactsLocationSasToken = New-AzureStorageContainerSASToken -Container $StorageContainerName -Context $StorageAccountContext -Permission r -ExpiryTime (Get-Date).AddHours(6)


# Construct Optional paremeters for Artificats location and sas token
$OptionalParameters[$ArtifactsLocationName] = $ArtifactsLocation
$OptionalParametersMGMT[$ArtifactsLocationName] = $ArtifactsLocation
$ArtifactsLocationSasToken = ConvertTo-SecureString $ArtifactsLocationSasToken -AsPlainText -Force
$OptionalParameters[$ArtifactsLocationSasTokenName] = $ArtifactsLocationSasToken
$OptionalParametersMGMT[$ArtifactsLocationSasTokenName] = $ArtifactsLocationSasToken


# Start Deployment
New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
                                   -ResourceGroupName $ResourceGroupName `
                                   -TemplateFile $TemplateFile `
                                   -TemplateParameterFile $TemplateParametersFile `
                                   @OptionalParameters `
                                   -Force -Verbose -ErrorAction Stop
                                  
                                  



# Start Mangement Deployment
# Create Resource Group
Try
{
    Get-AzureRmResourceGroup -Name $MGMTResourceGroupName `
                             -Location $ResourceGroupLocation `
                             -ErrorAction Stop
}
Catch
{
    New-AzureRmResourceGroup -Name $MGMTResourceGroupName `
                             -Location $ResourceGroupLocation `
                             -Force `
                             -ErrorAction Stop
}



# Set omsRecoveryServicesVaultLocation parameter
Set-Variable omsRecoveryServicesVaultLocation 'omsRecoveryServicesVaultLocation' -Option ReadOnly -Force
$OptionalParametersMGMT.Add($omsRecoveryServicesVaultLocation, $ResourceGroupLocation)

# Set runbookJobIdSetRecoveryVaultStorage parameter
$GUID = (New-guid).Guid.ToString()
Set-Variable runbookJobIdSetRecoveryVaultStorage 'runbookJobIdSetRecoveryVaultStorage' -Option ReadOnly -Force
$OptionalParametersMGMT.Add($runbookJobIdSetRecoveryVaultStorage, $GUID)


# Set backupScheduleRunTime parameter / You can change the default value of 02:00 local time if needed
[string]$backupScheduleRunTimeValue = ([datetime]"02:00").ToUniversalTime().ToString('HH:mm')
Set-Variable backupScheduleRunTime 'backupScheduleRunTime' -Option ReadOnly -Force
$OptionalParametersMGMT.Add($backupScheduleRunTime, $backupScheduleRunTimeValue)

# Set dailyRetentionDurationCount parameter
Set-Variable dailyRetentionDurationCount 'dailyRetentionDurationCount' -Option ReadOnly -Force
$OptionalParametersMGMT.Add($dailyRetentionDurationCount, 180)

$azureDeployParams = Get-Content -Path $TemplateParametersFile | ConvertFrom-Json 

# Set adVmName parameter
$adVMValue = $azureDeployParams.parameters.adVmName.value
Set-Variable adVmName 'adVmName' -Option ReadOnly -Force
$OptionalParametersMGMT.Add($adVmName, $adVMValue)

# Set adVmResourceGroupName parameter
Set-Variable adVmResourceGroupName 'adVmResourceGroupName' -Option ReadOnly -Force
$OptionalParametersMGMT.Add($adVmResourceGroupName, $ResourceGroupName)

# Set rdsVmName parameter
$rdsVMValue = $azureDeployParams.parameters.rdsVmName.value
Set-Variable rdsVmName 'rdsVmName' -Option ReadOnly -Force
$OptionalParametersMGMT.Add($rdsVmName, $rdsVMValue)

# Set rdsVmResourceGroupName parameter
Set-Variable rdsVmResourceGroupName 'rdsVmResourceGroupName' -Option ReadOnly -Force
$OptionalParametersMGMT.Add($rdsVmResourceGroupName, $ResourceGroupName)

# Set sqlVmName parameter
$appVMValue = $azureDeployParams.parameters.sqlVmName.value
Set-Variable sqlVmName 'sqlVmName' -Option ReadOnly -Force
$OptionalParametersMGMT.Add($sqlVmName, $appVMValue)

# Set appVmResourceGroupName parameter
Set-Variable appVmResourceGroupName 'appVmResourceGroupName' -Option ReadOnly -Force
$OptionalParametersMGMT.Add($appVmResourceGroupName, $ResourceGroupName)



New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $TemplateFileMGMT).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
                                   -ResourceGroupName $MGMTResourceGroupName `
                                   -TemplateFile $TemplateFileMGMT `
                                   -TemplateParameterFile $TemplateParametersFileMGMT `
                                   @OptionalParametersMGMT `
                                   -Force -Verbose -ErrorAction Stop
# Remove Temporary Storage Account
Remove-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName `
                             -Name $StorageAccountName `
                             -Force `
                             -Confirm:$false `
                             -ErrorAction Stop
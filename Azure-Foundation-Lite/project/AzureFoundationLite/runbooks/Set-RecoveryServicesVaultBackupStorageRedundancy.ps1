<# 
    .SYNOPSIS
        Sets the storage redundancy of Recovery Services
        Backup Vault.

    .DESCRIPTION
        Sets the storage redundancy of Recovery Services
        Backup Vault.
    
    .PARAMETER RecoveryServicesVaultName
        Mandatory parameter. This parameter
        is needed to find the Recovery
        Services Vault.

    .PARAMETER BackupStorageRedundancy
        Mandatory parameter. This parameter
        is set the backup vault storage 
        redundancy. Either LocallyRedundant
        or GeoRedundant.

    .OUTPUTS
        Returns status of the main steps.

#> 
param (  
        [Parameter(Mandatory=$true)]
        [string] 
        $RecoveryServicesVaultName,

        [Parameter(Mandatory=$true)]
        [ValidateSet('LocallyRedundant','GeoRedundant')]
        [string] 
        $BackupStorageRedundancy
    )

    #region Initial Setup
    # Set Error and Confirm Preference	
	$ErrorActionPreference = 'Stop'
    $ConfirmPreference     = 'None'

	# Get Variables and Credentials
	$AzureSubscriptionID            = Get-AutomationVariable -Name 'AzureSubscriptionID' -ErrorAction SilentlyContinue
    $AzureTenantID                  = Get-AutomationVariable -Name 'AzureTenantID' -ErrorAction SilentlyContinue
	$AzureCreds                     = Get-AutomationPSCredential -Name 'AzureCredentials' -ErrorAction SilentlyContinue
    $servicePrincipalConnection     = Get-AutomationConnection -Name "AzureRunAsConnection"  -ErrorAction SilentlyContinue
    #endregion

	#region Azure login
    If($servicePrincipalConnection)
    {
        Try
        {
            Add-AzureRmAccount `
                -ServicePrincipal `
                -TenantId $servicePrincipalConnection.TenantId `
                -ApplicationId $servicePrincipalConnection.ApplicationId `
                -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint `
                -ErrorAction Stop | Out-Null
            
            Write-Output `
                -InputObject 'Successfully connected to Azure with Service Principal.'
        }
        Catch
        {
            $ErrorMessage = 'Login to Azure failed with Service Principal.'
            $ErrorMessage += " `n"
            $ErrorMessage += 'Error: '
            $ErrorMessage += $_
            Write-Error -Message $ErrorMessage `
                    -ErrorAction Stop
        }
    }
    elseif($AzureCreds -and $AzureTenantID -and $AzureSubscriptionID)
    {
        Try
        {
            # Connect to Azure
            Add-AzureRmAccount `
               -Credential $AzureCreds `
               -SubscriptionId $AzureSubscriptionID `
               -TenantId $AzureTenantID `
               -ErrorAction Stop | Out-Null

            Write-Output `
                -InputObject 'Successfully connected to Azure with User Principal.'
        }
        Catch
        {
            $ErrorMessage = 'Login to Azure failed with User Principal.'
            $ErrorMessage += " `n"
            $ErrorMessage += 'Error: '
            $ErrorMessage += $_
            Write-Error -Message $ErrorMessage `
                        -ErrorAction Stop
        }
    }
    else
    {
            If($servicePrincipalConnection)
            {
                $ErrorMessage = "Cannot login to Azure because Asset Connection 'AzureRunAsConnection' is missing."
                $ErrorMessage += " `n"
                $ErrorMessage += 'Error: '
                $ErrorMessage += $_
                Write-Error -Message $ErrorMessage `
                            -ErrorAction Stop
            }
            Else
            {
                $ErrorMessage = "Cannot login to Azure because any of those assets are missing: "
                $ErrorMessage += " `n"
                $ErrorMessage += "PS Credentials 'AzureCredentials'"
                $ErrorMessage += " `n"
                $ErrorMessage += "variable 'AzureSubscriptionID'"
                $ErrorMessage += " `n"
                $ErrorMessage += "variable 'AzureTenantID'"
                Write-Error -Message $ErrorMessage `
                            -ErrorAction Stop
            }
            
    }
    #endregion

    #region Get Vault
    $vault = Get-AzureRmRecoveryServicesVault `
                -Name $RecoveryServicesVaultName `
                -ErrorAction Stop
    if (!$vault)
    {
        $ErrorMessage = "Recovery Services Vault $($RecoveryServicesVaultName) not found."
        Write-Error -Message $ErrorMessage `
                    -ErrorAction Stop
    }
    #endregion

    #region Set Storage Redundancy
    Try
    {
        
        Set-AzureRmRecoveryServicesBackupProperties `
            -BackupStorageRedundancy $BackupStorageRedundancy `
            -Vault $vault 

        Write-Output `
            -InputObject 'Recovery Services Backup vault storage redundancy was set.'
    }
    Catch
    {
        $ErrorMessage = "Failed to set Backup Storage redundancy for Recovery Services Vault $($vault)."
        $ErrorMessage += " `n"
        $ErrorMessage += 'Check if you are not already using the vault for backup.'
        $ErrorMessage += " `n"
        $ErrorMessage += 'Error: '
        $ErrorMessage += $_
        Write-Error -Message $ErrorMessage `
                    -ErrorAction Stop
    }
    #endregion
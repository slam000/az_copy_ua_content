<#
.AUTOR
Marcelo Sánchez Lujambio

.FECHA
11-01-2024

.SYNOPSIS
Script to copy multimedia blobs from one Azure storage container to another across multiple storage accounts and log the operations.

.DESCRIPTION
This script connects to multiple Azure storage accounts, retrieves all blobs from a source container in each account, and copies them to a destination container in the same account. It also copies the tags associated with each blob, if any. The script logs the name and URI of each blob being copied for tracking purposes.

.PARAMETER sourceContainer
The name of the source container from which the blobs will be copied.

.PARAMETER destContainer
The name of the destination container where the blobs will be copied.

.PARAMETER storageAccountNames
An array of storage account names where the source and destination containers are located.

.EXAMPLE
$storageAccountNames = @("maccstoragerentaldocpro1", "maccstoragerentaldocpro2")
.\copia_blobs.ps1 -sourceContainer "2110-21100032-223" -destContainer "2110-21100032-219" -storageAccountNames $storageAccountNames
This example runs the script to copy blobs from the "2110-21100032-223" container to the "2110-21100032-219" container in each specified storage account.

.NOTES
- This script requires the Azure PowerShell module to be installed.
- You need to be authenticated with an Azure account before running this script using the Connect-AzAccount cmdlet.
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$sourceContainer,
    [Parameter(Mandatory=$true)]
    [string]$destContainer,
    [Parameter(Mandatory=$true)]
    [string[]]$storageAccountNames
)

Connect-AzAccount

$resourceGroupName = "macc-rg-gestdoc-pro"
$logFilePath = ".\blob_copy_log.txt"

# Create or clear the log file
if (Test-Path $logFilePath) {
    Clear-Content $logFilePath
} else {
    New-Item $logFilePath -ItemType File
}

function Write-Log {
    param (
        [string]$message
    )

    Add-Content -Path $logFilePath -Value $message
}

foreach ($storageAccountName in $storageAccountNames) {
    $context = (Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName).Context

    $blobs = Get-AzStorageBlob -Container $sourceContainer -Context $context

    foreach ($blob in $blobs) {
        $srcUri = $blob.ICloudBlob.Uri.AbsoluteUri
        Start-AzStorageBlobCopy -AbsoluteUri $srcUri -DestContainer $destContainer -DestContext $context -DestBlob $blob.Name

        # Copy tags if needed
        $tags = Get-AzStorageBlobTag -Blob $blob.Name -Container $sourceContainer -Context $context
        Set-AzStorageBlobTag -Blob $blob.Name -Container $destContainer -Context $context -Tag $tags

        # Log the blob being copied
        $logMessage = "Copiado blob: $($blob.Name) de $srcUri a $destContainer en la cuenta de almacenamiento: $storageAccountName"
        Write-Log -message $logMessage
    }

    Write-Log -message "Se ha completado la copia de todos los blobs en la cuenta de almacenamiento: $storageAccountName."
}

Write-Log -message "Se ha completado la copia de todos los blobs en todas las cuentas de almacenamiento."
Write-Output "Revisa el archivo de log para obtener detalles: $logFilePath"

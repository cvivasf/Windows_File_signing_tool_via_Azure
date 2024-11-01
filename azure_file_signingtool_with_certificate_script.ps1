#Copyright @2024, cvivasf | MIT LICENSE

#Script to sign singtool-supported files using certificates obtained from Azure and Windows singtool. Certificates from Azure are downloaded with no password (nor keystore or private-key encryption related).
#They are expected to have pkcs12 / pfx format. For PEM formats, the script needs to be adapted.

#Script expects one param, the filepath of the file to sign.
param (
    [Parameter(Mandatory=$true)]
    [string]$filePath
)

Write-Host "File Singing tool via Microsoft Azure Certificates Started!"

# Check if the parameter is null or empty
if (-not $filePath) {
    Write-Host "Error: The -filePath parameter is missing or empty."
    exit 1  # Exit the script with a non-zero exit code
}else{
    Write-Host "The file to sign: $filePath"
}

# Get the current directory of the script
$currentDirectory = $PSScriptRoot

#Azure creds
# Recommended: Please, use Managed Identity over a Principal Account (Registered App) like the following if you can use this script on an Azure VM. It is waaay safer!
$tenantId = "<tenant-id>"
$appId = "<app-id>"
$secret = "<secret>"

# Connect to Azure
$securePassword = ConvertTo-SecureString $secret -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($appId, $securePassword)
Connect-AzAccount -ServicePrincipal -Credential $credential -Tenant $tenantId

#No passwords when obtaining certs from Azure! It just works like this.
$password = ""

#Generate the PFXFILE from the cert obtained as b64 from Azure.
$cert = Get-AzKeyVaultSecret -VaultName "<vault-name-where-the-certificate-is-stored>" -Name "<name-of-the-certificate>" -AsPlainText
$secretByte = [Convert]::FromBase64String($cert)
$x509Cert = New-Object Security.Cryptography.X509Certificates.X509Certificate2($secretByte, $null, [Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
$pfxFileByte = $x509Cert.Export([Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12, $password)
$pfxFilePath = "$currentDirectory\cert.pfx"
# Write to a file the certificate obtained from Azure
[IO.File]::WriteAllBytes($pfxFilePath, $pfxFileByte)

# Confirm that a file to sign was passed as a parameter
if ($filePath -and (Test-Path $filePath)) {
    # Define the path to signtool.exe (Update this to your actual path. In this case, it is added to the PATH sys var env).
    $signtoolPath = "signtool.exe"

    # Generate the new signed file name based on the original file name
    # $directory = [System.IO.Path]::GetDirectoryName($filePath)
    # $fileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($filePath)
    # $fileExtension = [System.IO.Path]::GetExtension($filePath)
    # $newSignedFileName = "${fileNameWithoutExtension}_signed$fileExtension"
    # $newSignedFilePath = [System.IO.Path]::Combine($directory, $newSignedFileName)

    # Sign the file using signtool
    $arguments = "sign /fd SHA256 /f `"$pfxFilePath`" /p `"$password`" `"$filePath`" "
    #Write-Host $arguments

    # Start the signing process using singtool (must be installed)
    $signingProcess = Start-Process -FilePath $signtoolPath -ArgumentList $arguments -Wait -PassThru -NoNewWindow
    
    if ($signingProcess.ExitCode -eq 0){
        Write-Host "File signed successfully! Output saved to the same file $filePath."
    } else {
        Write-Host "Signing failed with exit code: $($signingProcess.ExitCode)."
    }

} else {
    Write-Host "Failed to sign the file. Pass a valid file path via parameter of the file to sign!"
}

Remove-Item -Path $pfxFilePath
Write-Host "Succesfully deleted certificate retrieved from Azure used for signing."
Write-Host "End of script."
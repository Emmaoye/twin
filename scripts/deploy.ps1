param(
    [string]$Environment = "dev",   # dev | test | prod
    [string]$ProjectName = "twin"
)

$ErrorActionPreference = "Stop"

# Full path to Terraform executable
$Terraform = "$env:USERPROFILE\Downloads\terraform_1.15.2_windows_amd64\terraform.exe"

# Check Terraform exists before continuing
if (-not (Test-Path $Terraform)) {
    throw "Terraform executable not found at: $Terraform"
}

Write-Host "Deploying $ProjectName to $Environment ..." -ForegroundColor Green

# 1. Build Lambda package
Set-Location (Split-Path $PSScriptRoot -Parent)   # project root

Write-Host "Building Lambda package..." -ForegroundColor Yellow
Set-Location backend
uv run deploy.py
Set-Location ..

# 2. Terraform workspace & apply
Set-Location terraform

& $Terraform init -input=false

if (-not (& $Terraform workspace list | Select-String $Environment)) {
    & $Terraform workspace new $Environment
} else {
    & $Terraform workspace select $Environment
}

if ($Environment -eq "prod") {
    & $Terraform apply `
        -var-file="prod.tfvars" `
        -var="project_name=$ProjectName" `
        -var="environment=$Environment" `
        -auto-approve
} else {
    & $Terraform apply `
        -var="project_name=$ProjectName" `
        -var="environment=$Environment" `
        -auto-approve
}

$ApiUrl = & $Terraform output -raw api_gateway_url
$FrontendBucket = & $Terraform output -raw s3_frontend_bucket

try {
    $CustomUrl = & $Terraform output -raw custom_domain_url
} catch {
    $CustomUrl = ""
}

# 3. Build + deploy frontend
Set-Location ..\frontend

Write-Host "Setting API URL for production..." -ForegroundColor Yellow
"NEXT_PUBLIC_API_URL=$ApiUrl" | Out-File .env.production -Encoding utf8

npm install
npm run build

aws s3 sync .\out "s3://$FrontendBucket/" --delete

Set-Location ..

# 4. Final summary
$CfUrl = & $Terraform -chdir=terraform output -raw cloudfront_url

Write-Host "Deployment complete!" -ForegroundColor Green
Write-Host "CloudFront URL : $CfUrl" -ForegroundColor Cyan

if ($CustomUrl) {
    Write-Host "Custom domain  : $CustomUrl" -ForegroundColor Cyan
}

Write-Host "API Gateway    : $ApiUrl" -ForegroundColor Cyan
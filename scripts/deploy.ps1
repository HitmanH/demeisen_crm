# Deploys the CRM to AWS: infrastructure, API code and website. Run from the repository root.
# Needed for infrastructure changes; merges to main deploy code and the page automatically.
# On a new database: enable IAM authentication, and run db/migrations/002_app_user.sql as admin.
param(
  [Parameter(Mandatory)] [string] $Profile,
  [string] $Region = 'eu-west-2',
  [string] $Stack = 'demeisen-crm-poc',
  [string] $AlertEmail # needed on the first run; later runs keep the existing address
)
$ErrorActionPreference = 'Stop'
$A = @('--profile', $Profile, '--region', $Region)
function Check { if ($LASTEXITCODE -ne 0) { throw 'The last command failed.' } }

aws cloudformation deploy @A --stack-name $Stack --template-file infra/template.yaml --capabilities CAPABILITY_NAMED_IAM --no-fail-on-empty-changeset @(if ($AlertEmail) { '--parameter-overrides', "AlertEmail=$AlertEmail" }); Check
$out = @{}
aws cloudformation describe-stacks @A --stack-name $Stack --query 'Stacks[0].Outputs' --output json | ConvertFrom-Json | ForEach-Object { $_ } | ForEach-Object { $out[$_.OutputKey] = $_.OutputValue }

# API code, with the RDS certificate bundle so the database's identity can be verified
$build = Join-Path ([IO.Path]::GetTempPath()) ('crm-build-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $build | Out-Null
try {
  Copy-Item api/package.json, api/package-lock.json $build
  Copy-Item api/src (Join-Path $build 'src') -Recurse
  Invoke-WebRequest -UseBasicParsing "https://truststore.pki.rds.amazonaws.com/$Region/$Region-bundle.pem" -OutFile (Join-Path $build 'rds-ca.pem')
  Push-Location $build
  npm ci --omit=dev --no-audit --no-fund; Check
  tar -a -c -f function.zip src node_modules package.json rds-ca.pem; Check
  Pop-Location
  aws lambda update-function-code @A --function-name $out.FunctionName --zip-file "fileb://$build/function.zip" --query LastUpdateStatus --output text; Check
} finally { Set-Location $PSScriptRoot/..; Remove-Item -Recurse -Force $build -ErrorAction SilentlyContinue }

# Website
$config = "window.CRM_CONFIG = { authDomain: '$($out.AuthDomain)', clientId: '$($out.ClientId)' };"
$configFile = New-TemporaryFile
[IO.File]::WriteAllText($configFile, $config)
aws s3 cp @A web/index.html "s3://$($out.SiteBucketName)/index.html" --content-type 'text/html; charset=utf-8'; Check
aws s3 cp @A $configFile "s3://$($out.SiteBucketName)/config.js" --content-type 'text/javascript; charset=utf-8'; Check
Remove-Item $configFile

"Deployed: $($out.SiteUrl)"
"Backups:  s3://$($out.BackupBucketName)/"

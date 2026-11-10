[CmdletBinding()]
param(
    [switch]$SkipComposer,
    [switch]$SkipFlutter
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$api = Join-Path $root 'lost_found_api'
$app = Join-Path $root 'lost_found_ai'

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Warn([string]$Message) {
    Write-Host "  [!] $Message" -ForegroundColor Yellow
}

function Fail([string]$Message) {
    Write-Host ""
    Write-Host "[ERREUR] $Message" -ForegroundColor Red
    exit 1
}

function Test-Command([string]$Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-EnvValue([string]$Path, [string]$Key) {
    $line = @(Get-Content -LiteralPath $Path | Where-Object {
        $_ -match ('^\s*' + [regex]::Escape($Key) + '\s*=')
    }) | Select-Object -First 1

    if (-not $line) {
        return $null
    }

    $index = $line.IndexOf('=')
    if ($index -lt 0) {
        return $null
    }

    $value = $line.Substring($index + 1).Trim()
    if ($value.Length -ge 2) {
        $first = $value[0]
        $last = $value[$value.Length - 1]
        if (($first -eq '"' -and $last -eq '"') -or ($first -eq "'" -and $last -eq "'")) {
            $value = $value.Substring(1, $value.Length - 2)
        }
    }

    return $value
}

function Write-EnvFile([string]$Path, [string[]]$Lines) {
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($Path, $Lines, $encoding)
}

function Set-EnvValue([string]$Path, [string]$Key, [string]$Value) {
    $lines = @(Get-Content -LiteralPath $Path)
    $pattern = '^\s*' + [regex]::Escape($Key) + '\s*='
    $found = $false

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $pattern) {
            $lines[$i] = "$Key=$Value"
            $found = $true
            break
        }
    }

    if (-not $found) {
        $lines += "$Key=$Value"
    }

    Write-EnvFile -Path $Path -Lines $lines
}

function Invoke-Checked([string]$FilePath, [string[]]$Arguments, [string]$WorkingDirectory, [string]$Label) {
    Write-Host "  > $Label" -ForegroundColor DarkGray
    Push-Location -LiteralPath $WorkingDirectory
    try {
        & $FilePath @Arguments
        if ($LASTEXITCODE -ne 0) {
            Fail "$Label a echoue (code $LASTEXITCODE)."
        }
    }
    finally {
        Pop-Location
    }
}

Write-Step 'Verification des dossiers du projet'
if (-not (Test-Path -LiteralPath (Join-Path $api 'artisan'))) {
    Fail "Dossier API introuvable: $api"
}
if (-not (Test-Path -LiteralPath (Join-Path $app 'pubspec.yaml'))) {
    Fail "Dossier Flutter introuvable: $app"
}
Write-Ok 'Structure du projet valide'

Write-Step 'Verification des prerequis'
if (-not (Test-Command 'php')) {
    Fail 'PHP 8.3+ est introuvable dans le PATH.'
}
$phpVersion = (& php -r "echo PHP_VERSION;").Trim()
if ([version]$phpVersion -lt [version]'8.3.0') {
    Fail "PHP $phpVersion detecte. PHP 8.3+ est requis."
}
Write-Ok "PHP $phpVersion"

$composer = $null
if (Test-Command 'composer') {
    $composer = 'composer'
}
elseif (Test-Path -LiteralPath (Join-Path $api 'composer.phar')) {
    $composer = 'composer.phar'
}
elseif (-not $SkipComposer -and -not (Test-Path -LiteralPath (Join-Path $api 'vendor\autoload.php'))) {
    Fail 'Composer est introuvable. Installez-le ou lancez le script avec -SkipComposer si vendor existe.'
}

if (-not $SkipFlutter -and -not (Test-Command 'flutter')) {
    Fail 'Flutter est introuvable dans le PATH. Installez Flutter 3.47+ ou utilisez -SkipFlutter.'
}

Write-Step 'Configuration locale de l API'
$envPath = Join-Path $api '.env'
$createdEnv = $false

if (-not (Test-Path -LiteralPath $envPath)) {
    Copy-Item -LiteralPath (Join-Path $api '.env.example') -Destination $envPath
    $createdEnv = $true
}

$dbPath = Join-Path $api 'database\database.sqlite'
$dbPathForEnv = $dbPath.Replace('\', '/')

if ($createdEnv) {
    Set-EnvValue -Path $envPath -Key 'APP_ENV' -Value 'local'
    Set-EnvValue -Path $envPath -Key 'APP_DEBUG' -Value 'true'
    Set-EnvValue -Path $envPath -Key 'APP_URL' -Value 'http://localhost:8000'
    Set-EnvValue -Path $envPath -Key 'DB_CONNECTION' -Value 'sqlite'
    Set-EnvValue -Path $envPath -Key 'DB_DATABASE' -Value ('"' + $dbPathForEnv + '"')
    Set-EnvValue -Path $envPath -Key 'SESSION_DRIVER' -Value 'database'
    Set-EnvValue -Path $envPath -Key 'CACHE_STORE' -Value 'database'
    Set-EnvValue -Path $envPath -Key 'QUEUE_CONNECTION' -Value 'sync'
    Set-EnvValue -Path $envPath -Key 'MAIL_MAILER' -Value 'log'
    Set-EnvValue -Path $envPath -Key 'MAIL_DEMO_REDIRECT' -Value ''
    Set-EnvValue -Path $envPath -Key 'LOG_LEVEL' -Value 'debug'
    Write-Ok '.env local cree (SQLite + e-mails dans les logs)'
}
else {
    Write-Ok '.env existant conserve'
}

$dbConnection = Get-EnvValue -Path $envPath -Key 'DB_CONNECTION'
if ($dbConnection -eq 'sqlite') {
    $configuredDb = Get-EnvValue -Path $envPath -Key 'DB_DATABASE'
    $dbFile = $configuredDb

    if ([string]::IsNullOrWhiteSpace($dbFile)) {
        $dbFile = $dbPath
        Set-EnvValue -Path $envPath -Key 'DB_DATABASE' -Value ('"' + $dbPathForEnv + '"')
    }
    elseif (-not [System.IO.Path]::IsPathRooted($dbFile)) {
        $dbFile = Join-Path $api $dbFile
    }

    if (-not (Test-Path -LiteralPath $dbFile)) {
        $dbDirectory = Split-Path -Parent $dbFile
        if (-not (Test-Path -LiteralPath $dbDirectory)) {
            New-Item -ItemType Directory -Path $dbDirectory -Force | Out-Null
        }
        New-Item -ItemType File -Path $dbFile -Force | Out-Null
        Write-Ok 'Base SQLite creee'
    }
    else {
        Write-Ok 'Base SQLite deja presente'
    }
}
else {
    Write-Warn "DB_CONNECTION=$dbConnection : aucune base SQLite creee."
}

$storageDirectories = @(
    'storage\app\public',
    'storage\framework\cache\data',
    'storage\framework\sessions',
    'storage\framework\views',
    'storage\logs',
    'bootstrap\cache'
)
foreach ($relative in $storageDirectories) {
    $path = Join-Path $api $relative
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

Write-Step 'Installation des dependances PHP'
if ($SkipComposer) {
    Write-Warn 'Composer ignore (-SkipComposer)'
}
elseif ($composer -eq 'composer') {
    Invoke-Checked -FilePath 'composer' -Arguments @('install', '--no-interaction', '--prefer-dist') -WorkingDirectory $api -Label 'composer install'
}
elseif ($composer -eq 'composer.phar') {
    Invoke-Checked -FilePath 'php' -Arguments @((Join-Path $api 'composer.phar'), 'install', '--no-interaction', '--prefer-dist') -WorkingDirectory $api -Label 'php composer.phar install'
}
else {
    Write-Warn 'Composer absent mais vendor existe : installation ignoree'
}

$appKey = Get-EnvValue -Path $envPath -Key 'APP_KEY'
if ([string]::IsNullOrWhiteSpace($appKey)) {
    Invoke-Checked -FilePath 'php' -Arguments @('artisan', 'key:generate', '--force') -WorkingDirectory $api -Label 'Generation de APP_KEY'
}
else {
    Write-Ok 'APP_KEY deja configuree'
}

Write-Step 'Initialisation de la base et des donnees de demonstration'
Invoke-Checked -FilePath 'php' -Arguments @('artisan', 'config:clear') -WorkingDirectory $api -Label 'php artisan config:clear'
Invoke-Checked -FilePath 'php' -Arguments @('artisan', 'migrate', '--seed', '--force') -WorkingDirectory $api -Label 'php artisan migrate --seed'

$storageLink = Join-Path $api 'public\storage'
if (-not (Test-Path -LiteralPath $storageLink)) {
    Push-Location -LiteralPath $api
    try {
        & php artisan storage:link
        if ($LASTEXITCODE -ne 0) {
            Write-Warn 'Lien public/storage non cree (Windows peut demander des droits).'
        }
    }
    finally {
        Pop-Location
    }
}

Write-Step 'Installation des dependances Flutter'
if ($SkipFlutter) {
    Write-Warn 'Flutter ignore (-SkipFlutter)'
}
else {
    Invoke-Checked -FilePath 'flutter' -Arguments @('pub', 'get') -WorkingDirectory $app -Label 'flutter pub get'
}

$sha1 = $null
if (Test-Command 'keytool') {
    $debugKeystore = Join-Path $env:USERPROFILE '.android\debug.keystore'
    if (Test-Path -LiteralPath $debugKeystore) {
        $report = & keytool -list -v -keystore $debugKeystore -alias androiddebugkey -storepass android -keypass android 2>$null
        $sha1Line = $report | Select-String -Pattern 'SHA1:' | Select-Object -First 1
        if ($sha1Line) {
            $sha1 = ($sha1Line.Line -split 'SHA1:')[1].Trim()
        }
    }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " Installation terminee" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Demarrer l API:" -ForegroundColor Cyan
Write-Host "  cd `"$api`""
Write-Host "  php artisan serve --host=0.0.0.0 --port=8000"
Write-Host ""
Write-Host "Demarrer l application:" -ForegroundColor Cyan
Write-Host "  cd `"$app`""
Write-Host "  flutter run"
Write-Host ""
Write-Host "Comptes de demonstration:" -ForegroundColor Cyan
Write-Host "  amina@campus.fr / campus2026"
Write-Host "  karim@campus.fr / campus2026"
Write-Host "  sami@campus.fr / campus2026"
Write-Host ""
Write-Host "E-mails locales (OTP, coupons):" -ForegroundColor Cyan
Write-Host "  $api\storage\logs\laravel.log"
Write-Host ""
if ($sha1) {
    Write-Host "SHA-1 debug Android:" -ForegroundColor Cyan
    Write-Host "  $sha1"
    Write-Host "  A ajouter au client OAuth Android uniquement si vous testez Google Sign-In."
    Write-Host ""
}
Write-Host "Aucun secret n'est necessaire pour tester: SQLite, comptes demo et e-mails locales." -ForegroundColor Yellow

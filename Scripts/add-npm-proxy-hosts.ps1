param(
    [string]$NpmUrl = "http://192.168.11.10:81",
    [Parameter(Mandatory = $true)]
    [string]$Email,
    [Parameter(Mandatory = $true)]
    [string]$Domain,
    [string]$NasIp = "192.168.61.7"
)

$Email = $Email.Trim()
if (-not $Email) {
    throw "Email cannot be empty. Pass -Email <NPM admin email>."
}

$Domain = $Domain.Trim()
if (-not $Domain) {
    throw "Domain cannot be empty. Pass -Domain <your wildcard home domain, e.g. home.example.com>."
}
$Password = Read-Host "NPM admin password for $Email" -AsSecureString
$Credential = New-Object System.Management.Automation.PSCredential($Email, $Password)
$PlainPassword = $Credential.GetNetworkCredential().Password

Write-Host "Entered password length: $($PlainPassword.Length) characters (verify this matches what you expect -- a pasted password can get silently truncated at an embedded line break)"

$tokenBody = @{
    identity = $Email
    secret   = $PlainPassword
} | ConvertTo-Json

try {
    $tokenResp = Invoke-RestMethod -Uri "$NpmUrl/api/tokens" -Method Post -Body $tokenBody -ContentType "application/json" -ErrorAction Stop
}
catch {
    throw "Login to NPM failed: $($_.Exception.Message). Verify the email and password against the NPM admin UI login."
}
$headers = @{ Authorization = "Bearer $($tokenResp.token)" }

$certs = Invoke-RestMethod -Uri "$NpmUrl/api/nginx/certificates" -Headers $headers -ErrorAction Stop
$wildcardCert = $certs | Where-Object { $_.domain_names -contains "*.$Domain" } | Select-Object -First 1
if (-not $wildcardCert) {
    throw "Could not find a certificate covering *.$Domain. Check it exists in NPM's SSL Certificates list."
}
$certId = $wildcardCert.id
Write-Host "Using certificate id $certId for *.$Domain"

$existingHosts = Invoke-RestMethod -Uri "$NpmUrl/api/nginx/proxy-hosts" -Headers $headers -ErrorAction Stop
$existingDomains = $existingHosts | ForEach-Object { $_.domain_names } | ForEach-Object { $_ }

$haAdvancedConfig = @"
proxy_set_header Host `$host;
proxy_set_header X-Real-IP `$remote_addr;
proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto `$scheme;
proxy_set_header Upgrade `$http_upgrade;
proxy_set_header Connection "upgrade";
"@

$newHosts = @(
    @{ domain = "homepage.$Domain";       forwardHost = "homepage";        port = 3000;  ws = $false }
    @{ domain = "homeassistant.$Domain";  forwardHost = "homeassistant";   port = 8123;  ws = $true; advancedConfig = $haAdvancedConfig }
    @{ domain = "uptime.$Domain";         forwardHost = "uptime_kuma";     port = 3001;  ws = $true }
    @{ domain = "grafana.$Domain";        forwardHost = "grafana";         port = 3000;  ws = $false }
    @{ domain = "prometheus.$Domain";     forwardHost = "prometheus";      port = 9090;  ws = $false }
    @{ domain = "dockge.$Domain";         forwardHost = "192.168.11.10";   port = 5001;  ws = $false }
    @{ domain = "pihole.$Domain";         forwardHost = "pihole";          port = 80;    ws = $false }
    @{ domain = "ntfy.$Domain";           forwardHost = "ntfy";            port = 80;    ws = $true }
    @{ domain = "auth.$Domain";           forwardHost = "authentik_server"; port = 9000; ws = $true }
    @{ domain = "wiki.$Domain";           forwardHost = "wikijs";          port = 3000;  ws = $true }
    @{ domain = "photos.$Domain";         forwardHost = "immich_server";   port = 2283;  ws = $true }
    @{ domain = "jellyfin.$Domain";       forwardHost = "jellyfin";        port = 8096;  ws = $true }
    @{ domain = "amp.$Domain";            forwardHost = "amp";             port = 8081;  ws = $false }
    @{ domain = "abs.$Domain";            forwardHost = "audiobookshelf";  port = 13378; ws = $true }
    @{ domain = "kavita.$Domain";         forwardHost = "kavita";          port = 5000;  ws = $true }
    @{ domain = "pgadmin.$Domain";        forwardHost = "pgadmin";         port = 80;    ws = $false }
    @{ domain = "pdf.$Domain";            forwardHost = "stirling_pdf";    port = 8080;  ws = $false }
    @{ domain = "mealie.$Domain";         forwardHost = "mealie";          port = 9000;  ws = $false }
    @{ domain = "n8n.$Domain";            forwardHost = "n8n";             port = 5678;  ws = $true }
    @{ domain = "it-tools.$Domain";       forwardHost = "it_tools";        port = 80;    ws = $false }
    @{ domain = "budget.$Domain";         forwardHost = "actual_budget";   port = 5006;  ws = $false }
    @{ domain = "paperless.$Domain";      forwardHost = "paperless_ngx";   port = 8000;  ws = $false }
    @{ domain = "grocy.$Domain";          forwardHost = "grocy";           port = 80;    ws = $false }
    @{ domain = "links.$Domain";          forwardHost = "linkwarden";      port = 3000;  ws = $true }
    @{ domain = "backrest.$Domain";       forwardHost = "backrest";        port = 9898;  ws = $false }
    @{ domain = "llm.$Domain";            forwardHost = "open_webui";      port = 8080;  ws = $true }
)

if ($NasIp) {
    $newHosts += @{ domain = "nas.$Domain"; forwardHost = $NasIp; port = 5000; ws = $false }
}
else {
    Write-Host "Skipping nas.$Domain - pass -NasIp <ip> to include the Synology DSM proxy host"
}

foreach ($h in $newHosts) {
    if ($existingDomains -contains $h.domain) {
        Write-Host "Skipping $($h.domain) - proxy host already exists"
        continue
    }

    $advancedConfig = if ($h.ContainsKey("advancedConfig")) { $h.advancedConfig } else { "" }

    $body = @{
        domain_names           = @($h.domain)
        forward_scheme          = "http"
        forward_host            = $h.forwardHost
        forward_port            = $h.port
        access_list_id          = "0"
        certificate_id          = $certId
        ssl_forced              = $true
        http2_support           = $true
        block_exploits          = $true
        caching_enabled         = $false
        allow_websocket_upgrade = [int]$h.ws
        advanced_config         = $advancedConfig
        locations               = @()
        meta                    = @{ letsencrypt_agree = $false; dns_challenge = $false }
    } | ConvertTo-Json -Depth 5

    try {
        Invoke-RestMethod -Uri "$NpmUrl/api/nginx/proxy-hosts" -Method Post -Headers $headers -Body $body -ContentType "application/json" | Out-Null
        Write-Host "Created $($h.domain) -> $($h.forwardHost):$($h.port)"
    }
    catch {
        Write-Warning "Failed to create $($h.domain): $($_.Exception.Message)"
    }
}

# LifeFit PowerShell REST API Server
# Zero dependencies required - runs natively on any Windows PowerShell

$Port = 3000
$Root = $PSScriptRoot
if (-not $Root) { $Root = Get-Location }

$DataFile = Join-Path $Root "data.json"

# Ensure default data file exists
if (-not (Test-Path $DataFile)) {
    $DefaultData = @{
        name = "Друг"
        water = 0
        activity = 0
        xp = 0
        level = 1
        streak = 0
        mood = 0
        tasks = @{}
        nutrition = @{}
        wake = "07:00"
        breakfast = "07:30"
        sport = "18:00"
        dinner = "19:30"
        sleep = "22:30"
        currentDate = (Get-Date -Format "yyyy-MM-dd")
        history = @()
        workouts = @()
        meals = @()
        sleepLogs = @()
        customTasks = @()
        totalDays = 0
        coins = 50
        wardrobe = @{
            owned = @("skin_default", "outfit_green")
            equipped = @{
                skin = "skin_default"
                outfit = "outfit_green"
                hat = $null
                accessory = $null
            }
        }
        settings = @{
            waterGoal = 2.0
            activityGoal = 30
            sleepGoal = 8.0
            calorieGoal = 2200
        }
    }
    $DefaultData | ConvertTo-Json -Depth 10 | Set-Content -Path $DataFile -Encoding UTF8
}

# Start HttpListener
$Listener = New-Object System.Net.HttpListener
$Prefix = "http://localhost:$Port/"

try {
    $Listener.Prefixes.Add($Prefix)
    $Listener.Start()
} catch {
    # If port 3000 is taken, fallback to 8080
    $Port = 8080
    $Prefix = "http://localhost:$Port/"
    $Listener = New-Object System.Net.HttpListener
    $Listener.Prefixes.Add($Prefix)
    $Listener.Start()
}

Write-Host "==========================================" -ForegroundColor Green
Write-Host "  LifeFit Backend Server is Running!" -ForegroundColor Cyan
Write-Host "  URL: $Prefix" -ForegroundColor Yellow
Write-Host "  Data file: $DataFile" -ForegroundColor Gray
Write-Host "  Press Ctrl+C in this window to stop" -ForegroundColor Magenta
Write-Host "==========================================" -ForegroundColor Green

# Open browser automatically
try {
    Start-Process $Prefix
} catch {}

function Get-ContentType($Path) {
    $Ext = [System.IO.Path]::GetExtension($Path).ToLower()
    switch ($Ext) {
        ".html" { return "text/html; charset=utf-8" }
        ".htm"  { return "text/html; charset=utf-8" }
        ".css"  { return "text/css; charset=utf-8" }
        ".js"   { return "application/javascript; charset=utf-8" }
        ".json" { return "application/json; charset=utf-8" }
        ".png"  { return "image/png" }
        ".jpg"  { return "image/jpeg" }
        ".jpeg" { return "image/jpeg" }
        ".svg"  { return "image/svg+xml" }
        ".ico"  { return "image/x-icon" }
        default { return "application/octet-stream" }
    }
}

while ($Listener.IsListening) {
    try {
        $Context = $Listener.GetContext()
        $Request = $Context.Request
        $Response = $Context.Response

        # CORS Headers
        $Response.AddHeader("Access-Control-Allow-Origin", "*")
        $Response.AddHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        $Response.AddHeader("Access-Control-Allow-Headers", "Content-Type, Authorization")

        if ($Request.HttpMethod -eq "OPTIONS") {
            $Response.StatusCode = 204
            $Response.Close()
            continue
        }

        $RawUrl = $Request.Url.AbsolutePath

        # ==========================================
        # REST API ROUTING
        # ==========================================
        if ($RawUrl.StartsWith("/api/")) {
            $Response.ContentType = "application/json; charset=utf-8"

            # GET /api/status
            if ($RawUrl -eq "/api/status" -and $Request.HttpMethod -eq "GET") {
                $StatusObj = @{
                    status = "ok"
                    server = "PowerShell HttpListener"
                    version = "2.0"
                    timestamp = (Get-Date).ToString("o")
                    dataFile = $DataFile
                }
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes(($StatusObj | ConvertTo-Json))
                $Response.StatusCode = 200
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
                $Response.Close()
                continue
            }

            # GET /api/data
            if ($RawUrl -eq "/api/data" -and $Request.HttpMethod -eq "GET") {
                if (Test-Path $DataFile) {
                    $JsonContent = Get-Content -Path $DataFile -Raw -Encoding UTF8
                } else {
                    $JsonContent = "{}"
                }
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes($JsonContent)
                $Response.StatusCode = 200
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
                $Response.Close()
                continue
            }

            # POST /api/data
            if ($RawUrl -eq "/api/data" -and $Request.HttpMethod -eq "POST") {
                $Reader = New-Object System.IO.StreamReader($Request.InputStream, [System.Text.Encoding]::UTF8)
                $Body = $Reader.ReadToEnd()
                $Reader.Close()

                if ($Body -and $Body.Trim().Length -gt 0) {
                    Set-Content -Path $DataFile -Value $Body -Encoding UTF8
                    $Res = @{ success = $true; message = "Data saved successfully"; timestamp = (Get-Date).ToString("o") }
                    $Buffer = [System.Text.Encoding]::UTF8.GetBytes(($Res | ConvertTo-Json))
                    $Response.StatusCode = 200
                } else {
                    $Res = @{ success = $false; error = "Empty body" }
                    $Buffer = [System.Text.Encoding]::UTF8.GetBytes(($Res | ConvertTo-Json))
                    $Response.StatusCode = 400
                }
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
                $Response.Close()
                continue
            }

            # POST /api/reset
            if ($RawUrl -eq "/api/reset" -and $Request.HttpMethod -eq "POST") {
                if (Test-Path $DataFile) {
                    Remove-Item $DataFile -Force
                }
                $Res = @{ success = $true; message = "Database reset successfully" }
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes(($Res | ConvertTo-Json))
                $Response.StatusCode = 200
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
                $Response.Close()
                continue
            }

            # GET /api/export
            if ($RawUrl -eq "/api/export" -and $Request.HttpMethod -eq "GET") {
                $Response.AddHeader("Content-Disposition", "attachment; filename=lifefit_backup.json")
                if (Test-Path $DataFile) {
                    $JsonContent = Get-Content -Path $DataFile -Raw -Encoding UTF8
                } else {
                    $JsonContent = "{}"
                }
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes($JsonContent)
                $Response.StatusCode = 200
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
                $Response.Close()
                continue
            }

            # 404 for unknown API
            $Res = @{ error = "Not found" }
            $Buffer = [System.Text.Encoding]::UTF8.GetBytes(($Res | ConvertTo-Json))
            $Response.StatusCode = 404
            $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
            $Response.Close()
            continue
        }

        # ==========================================
        # STATIC FILE SERVING
        # ==========================================
        $FilePath = $RawUrl.TrimStart('/')
        if ([string]::IsNullOrWhiteSpace($FilePath)) {
            $FilePath = "index.html"
        }
        $LocalFile = Join-Path $Root $FilePath

        if (Test-Path $LocalFile -PathType Leaf) {
            $ContentType = Get-ContentType $LocalFile
            $Response.ContentType = $ContentType
            $Bytes = [System.IO.File]::ReadAllBytes($LocalFile)
            $Response.ContentLength64 = $Bytes.Length
            $Response.StatusCode = 200
            $Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
        } else {
            # Fallback to index.html for SPA routing
            $IndexFile = Join-Path $Root "index.html"
            if (Test-Path $IndexFile) {
                $Response.ContentType = "text/html; charset=utf-8"
                $Bytes = [System.IO.File]::ReadAllBytes($IndexFile)
                $Response.ContentLength64 = $Bytes.Length
                $Response.StatusCode = 200
                $Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
            } else {
                $Response.StatusCode = 404
            }
        }

        $Response.Close()
    } catch {
        # Catch errors gracefully and keep server running
        try {
            $Response.StatusCode = 500
            $Response.Close()
        } catch {}
    }
}

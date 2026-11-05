# Test Lost & Found API Endpoints
Write-Host "=== TESTING LOST & FOUND API ===" -ForegroundColor Cyan
Write-Host ""

$baseUrl = "http://127.0.0.1:8000/api"

# Test 1: Ping
Write-Host "1. Testing /ping..." -ForegroundColor Yellow
try {
    $ping = Invoke-RestMethod -Uri "$baseUrl/ping" -Method Get
    Write-Host "   ✅ Status: $($ping.status)" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Failed: $_" -ForegroundColor Red
}
Write-Host ""

# Test 2: Get statistics (public endpoint, should work without auth)
Write-Host "2. Testing /objects/statistics..." -ForegroundColor Yellow
try {
    $stats = Invoke-RestMethod -Uri "$baseUrl/objects/statistics" -Method Get -Headers @{
        "Accept" = "application/json"
    }
    Write-Host "   ✅ Total Lost: $($stats.total_lost)" -ForegroundColor Green
    Write-Host "   ✅ Total Found: $($stats.total_found)" -ForegroundColor Green
    Write-Host "   ✅ Active: $($stats.active_count)" -ForegroundColor Green
    Write-Host "   ✅ Resolved: $($stats.resolved_count)" -ForegroundColor Green
} catch {
    Write-Host "   ⚠️  Requires authentication (expected)" -ForegroundColor Yellow
}
Write-Host ""

# Test 3: Login to get token
Write-Host "3. Testing authentication..." -ForegroundColor Yellow
$loginData = @{
    phone = "+33612345678"
    password = "password"
} | ConvertTo-Json

try {
    $auth = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method Post -Body $loginData -ContentType "application/json"
    $token = $auth.access_token
    Write-Host "   ✅ Login successful" -ForegroundColor Green
    Write-Host "   Token: $($token.Substring(0, 20))..." -ForegroundColor Gray
    
    # Test 4: Get objects with auth
    Write-Host ""
    Write-Host "4. Testing /objects with authentication..." -ForegroundColor Yellow
    $headers = @{
        "Authorization" = "Bearer $token"
        "Accept" = "application/json"
    }
    
    $objects = Invoke-RestMethod -Uri "$baseUrl/objects" -Method Get -Headers $headers
    Write-Host "   ✅ Retrieved $($objects.Count) objects" -ForegroundColor Green
    
    if ($objects.Count -gt 0) {
        $obj = $objects[0]
        Write-Host "   Sample: [$($obj.type)] $($obj.title)" -ForegroundColor Gray
        Write-Host "   Category: $($obj.category) | Status: $($obj.status)" -ForegroundColor Gray
    }
    
    # Test 5: Get statistics with auth
    Write-Host ""
    Write-Host "5. Testing /objects/statistics with auth..." -ForegroundColor Yellow
    $stats = Invoke-RestMethod -Uri "$baseUrl/objects/statistics" -Method Get -Headers $headers
    Write-Host "   ✅ Total Lost: $($stats.total_lost)" -ForegroundColor Green
    Write-Host "   ✅ Total Found: $($stats.total_found)" -ForegroundColor Green
    Write-Host "   ✅ Recent objects: $($stats.recent_objects.Count)" -ForegroundColor Green
    
    # Test 6: Get my objects
    Write-Host ""
    Write-Host "6. Testing /objects/my-objects..." -ForegroundColor Yellow
    $myObjects = Invoke-RestMethod -Uri "$baseUrl/objects/my-objects" -Method Get -Headers $headers
    Write-Host "   ✅ User has $($myObjects.Count) objects" -ForegroundColor Green
    
    # Test 7: Nearby search
    Write-Host ""
    Write-Host "7. Testing /objects/nearby..." -ForegroundColor Yellow
    $nearby = Invoke-RestMethod -Uri "$baseUrl/objects/nearby?latitude=48.8566&longitude=2.3522&radius_km=10" -Method Get -Headers $headers
    Write-Host "   ✅ Found $($nearby.Count) nearby objects" -ForegroundColor Green
    
    if ($nearby.Count -gt 0) {
        foreach ($item in $nearby | Select-Object -First 3) {
            Write-Host "   • $($item.title) - $($item.distance_km) km" -ForegroundColor Gray
        }
    }
    
} catch {
    Write-Host "   ❌ Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Response: $($_.ErrorDetails.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== API TESTING COMPLETE ===" -ForegroundColor Cyan

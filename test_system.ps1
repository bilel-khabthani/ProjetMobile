# Lost & Found System - Automated Testing Script
# Run this script to quickly verify the system is working

Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Lost & Found - Automated System Test                   ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

$baseDir = "c:\Users\suzan\OneDrive\Bureau\ProjetMobile-InitProject"
$apiDir = "$baseDir\lost_found_api"
$flutterDir = "$baseDir\lost_found_ai"
$apiUrl = "http://localhost:8000/api"

$testsPassed = 0
$totalTests = 0

function Test-Component {
    param($name, $test)
    $totalTests++
    Write-Host "`n🧪 Testing: $name..." -ForegroundColor Yellow
    try {
        $result = & $test
        if ($result) {
            Write-Host "   ✅ PASS" -ForegroundColor Green
            $script:testsPassed++
            return $true
        } else {
            Write-Host "   ❌ FAIL" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "   ❌ ERROR: $_" -ForegroundColor Red
        return $false
    }
}

# Test 1: Check Laravel Directory
Test-Component "Laravel Backend Directory" {
    Test-Path $apiDir
}

# Test 2: Check Flutter Directory
Test-Component "Flutter Frontend Directory" {
    Test-Path $flutterDir
}

# Test 3: Check composer.json
Test-Component "Laravel Dependencies Configuration" {
    Test-Path "$apiDir\composer.json"
}

# Test 4: Check pubspec.yaml
Test-Component "Flutter Dependencies Configuration" {
    Test-Path "$flutterDir\pubspec.yaml"
}

# Test 5: Check Controllers
Test-Component "Laravel Controllers" {
    (Get-ChildItem "$apiDir\app\Http\Controllers\Api" -Filter "*.php").Count -ge 5
}

# Test 6: Check Models
Test-Component "Laravel Models" {
    (Get-ChildItem "$apiDir\app\Models" -Filter "*.php").Count -ge 5
}

# Test 7: Check Migrations
Test-Component "Database Migrations" {
    (Get-ChildItem "$apiDir\database\migrations" -Filter "*.php").Count -ge 10
}

# Test 8: Check Services
Test-Component "Laravel Services" {
    Test-Path "$apiDir\app\Services\MatchingService.php" -and 
    Test-Path "$apiDir\app\Services\NotificationService.php"
}

# Test 9: Check Flutter Screens
Test-Component "Flutter Screens" {
    Test-Path "$flutterDir\lib\features" -and
    (Get-ChildItem "$flutterDir\lib\features" -Recurse -Filter "*screen.dart").Count -ge 5
}

# Test 10: Check Flutter Models
Test-Component "Flutter Models" {
    Test-Path "$flutterDir\lib\data\models" -or Test-Path "$flutterDir\lib\features\objects\data\models"
}

# Test 11: Check API Routes
Test-Component "API Routes Configuration" {
    Test-Path "$apiDir\routes\api.php"
}

# Test 12: Check .env file
Test-Component "Environment Configuration" {
    if (Test-Path "$apiDir\.env") {
        return $true
    } else {
        Write-Host "   ⚠️  Creating .env from example..." -ForegroundColor Yellow
        if (Test-Path "$apiDir\.env.example") {
            Copy-Item "$apiDir\.env.example" "$apiDir\.env"
            return $true
        }
        return $false
    }
}

# Summary
Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  TEST RESULTS                                            ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

Write-Host "`n📊 Tests Passed: $testsPassed / $totalTests" -ForegroundColor $(if ($testsPassed -eq $totalTests) { "Green" } else { "Yellow" })

$percentage = [math]::Round(($testsPassed / $totalTests) * 100, 1)
Write-Host "📈 Success Rate: $percentage%" -ForegroundColor $(if ($percentage -ge 80) { "Green" } elseif ($percentage -ge 60) { "Yellow" } else { "Red" })

if ($testsPassed -eq $totalTests) {
    Write-Host "`n✅ All tests passed! System is ready." -ForegroundColor Green
    Write-Host "`n🚀 NEXT STEPS:" -ForegroundColor Cyan
    Write-Host "   1. Start Laravel backend:" -ForegroundColor White
    Write-Host "      cd $apiDir" -ForegroundColor Gray
    Write-Host "      php artisan serve" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   2. In another terminal, start Flutter:" -ForegroundColor White
    Write-Host "      cd $flutterDir" -ForegroundColor Gray
    Write-Host "      flutter run" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   3. Test the API:" -ForegroundColor White
    Write-Host "      curl http://localhost:8000/api/ping" -ForegroundColor Gray
} else {
    Write-Host "`n⚠️  Some tests failed. Check the output above." -ForegroundColor Yellow
    Write-Host "   Review QUICK_TESTING_GUIDE.md for troubleshooting." -ForegroundColor White
}

Write-Host "`n📚 Documentation:" -ForegroundColor Cyan
Write-Host "   • QUICK_TESTING_GUIDE.md - Step-by-step testing instructions"
Write-Host "   • API_DOCUMENTATION.md - Complete API reference"
Write-Host "   • FINAL_PROJECT_HANDOFF.md - Project overview"

Write-Host ""

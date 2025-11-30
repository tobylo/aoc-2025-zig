if ( $args.Count -ne 1 ) {
    Write-Host "Usage: create_day.ps1 <day_number>"
    exit 1
}

$dayNumber = $args[0]

if ( $dayNumber -lt 1 -or $dayNumber -gt 25 ) {
    Write-Host "Day number must be between 1 and 25"
    exit 1
}

if ( Test-Path $dayNumber ) {
    Write-Host "Day $dayNumber already exists"
    exit 1
}

New-Item -ItemType Directory -Path $dayNumber
Copy-Item -Path "template\*" -Destination "$dayNumber" -Recurse

sed -i "s/dayX/day${dayNumber}/g" "${dayNumber}/build.zig"

Get-Item -Path "$dayNumber\*" -Filter "sed*" | Remove-Item

Write-Host "Day $dayNumber created successfully"

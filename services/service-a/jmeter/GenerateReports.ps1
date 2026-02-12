Write-Host "===========================================" -ForegroundColor Magenta
Write-Host "   JMeter 리포트 생성 설정" -ForegroundColor Magenta
Write-Host "===========================================" -ForegroundColor Magenta

# 1. 테스트 유형 선택
$choice = Read-Host "리포트 유형을 선택하세요 (1: Read, 2: Write)"

if ($choice -eq "1") {
    $mode = "read"
} elseif ($choice -eq "2") {
    $mode = "write"
} else {
    Write-Host "[오류] 1 또는 2를 입력하세요." -ForegroundColor Red
    return
}

# 2. 파일 경로 패턴 설정 (선택한 모드에 따라)
$targetFiles = Get-ChildItem "results/$($mode)_result_*.jtl"

if ($null -eq $targetFiles -or $targetFiles.Count -eq 0) {
    Write-Host "[경고] results 폴더에서 $($mode)_result_*.jtl 파일을 찾을 수 없습니다." -ForegroundColor Red
    return
}

Write-Host "[알림] 총 $($targetFiles.Count)개의 파일을 처리합니다." -ForegroundColor Gray

# 3. 반복 처리
foreach ($file in $targetFiles) {
    # 파일명에서 숫자 추출 (예: read_result_100 -> 100)
    $num = $file.BaseName -replace "$($mode)_result_", ""
    
    Write-Host "`n=======================================" -ForegroundColor Yellow
    Write-Host "[작업 시작] 모드: $mode | 번호: $num" -ForegroundColor Cyan
    Write-Host "[파일 경로] $($file.FullName)"
    Write-Host "=======================================" -ForegroundColor Yellow

    # Docker 실행 (백틱 ` 을 사용하여 줄바꿈)
    docker run --rm `
      -v "${PWD}:/jmeter" `
      spring-jmeter `
      jmeter -g /jmeter/results/$($mode)_result_$num.jtl `
             -o /jmeter/results/report_$($mode)_$num

    if ($LASTEXITCODE -ne 0) {
        Write-Host "[오류] $num 번 보고서 생성 중 문제가 발생했습니다." -ForegroundColor Red
    }
}

Write-Host "`n모든 보고서 생성이 완료되었습니다." -ForegroundColor Green
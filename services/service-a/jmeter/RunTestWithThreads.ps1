Write-Host "===========================================" -ForegroundColor Magenta
Write-Host "   JMeter Load Test Settings" -ForegroundColor Magenta
Write-Host "===========================================" -ForegroundColor Magenta

# 1. Select Test Type
$type = Read-Host "Select Type (1: Read, 2: Write)"
if ($type -eq "1") {
    $mode = "read"
    $delay = 150
} elseif ($type -eq "2") {
    $mode = "write"
    $delay = 250
} else {
    Write-Host "[Error] Enter 1 or 2." -ForegroundColor Red
    return
}

# 2. Input Thread Count
$threads = Read-Host "Enter ATTACK_THREADS number"

if ([string]::IsNullOrWhiteSpace($threads)) {
    Write-Host "[Error] Number is required." -ForegroundColor Red
    return
}

# 3. Pool Exhaustion Mode 선택
$poolMode = Read-Host "Enable Pool Exhaustion + Timeout Mode? (y/n)"

if ($poolMode -eq "y") {
    $hikariOverride = "-Dspring.datasource.hikari.maximum-pool-size=5 -Dspring.datasource.hikari.connection-timeout=1000"
    $ramp = 1
    $delay = 0
    $loops = 500
    $attackRepeat = 100
    $normalRepeat = 1

    Write-Host "[Pool Stress Mode]" -ForegroundColor Yellow
    Write-Host "  repeatCount=50 (attack)" -ForegroundColor Yellow
} else {
    $hikariOverride = ""
    $ramp = 30
    $loops = 50
    $attackRepeat = 1
    $normalRepeat = 1
}



Write-Host "`n---------------------------------------" -ForegroundColor Yellow
Write-Host "[Run] Mode: $mode / Threads: $threads" -ForegroundColor Cyan
Write-Host "---------------------------------------" -ForegroundColor Yellow

# 4. Docker Run
docker run --rm `
  -e TZ=Asia/Seoul `
  -e JVM_ARGS="-Duser.timezone=Asia/Seoul $hikariOverride" `
  -v "${PWD}:/jmeter" `
  spring-jmeter `
  sh -c "jmeter -n -t /jmeter/scenarios/attack_${mode}_vs_normal.jmx -l /jmeter/results/${mode}_result_${threads}.jtl -Jjmeter.save.saveservice.output_format=csv -Jjmeter.save.saveservice.response_data=false -Jjmeter.save.saveservice.response_headers=false -Jjmeter.save.saveservice.requestHeaders=false -Jjmeter.save.saveservice.samplerData=false -Jjmeter.save.saveservice.assertion_results=none -Jjmeter.save.saveservice.bytes=true -Jjmeter.save.saveservice.latency=true -Jjmeter.save.saveservice.connect_time=true -JBASE_URL=host.docker.internal -JATTACK_THREADS=${threads} -JATTACK_RAMP=${ramp} -JATTACK_DELAY=${delay} -JATTACK_LOOPS=${loops} -JATTACK_REPEAT=${attackRepeat} -JNORMAL_REPEAT=${normalRepeat} -JNORMAL_THREADS=3 -JNORMAL_DELAY=1000 -JNORMAL_LOOPS=50"


Write-Host "`n[Done] Result file: /results/${mode}_result_${threads}.jtl" -ForegroundColor Green

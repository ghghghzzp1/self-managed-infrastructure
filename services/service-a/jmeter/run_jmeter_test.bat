@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:CHOOSE_TYPE
echo ===========================================
echo   JMeter 부하 테스트 실행 설정
echo ===========================================
echo  1. Read 부하 테스트 (DB 조회)
echo  2. Write 부하 테스트 (DB 쓰기)
set /p TYPE_CHOICE="실행할 테스트 유형을 선택하세요 (1 또는 2): "

if "%TYPE_CHOICE%"=="1" (
    set "MODE=read"
    set "DELAY=150"
) else if "%TYPE_CHOICE%"=="2" (
    set "MODE=write"
    set "DELAY=250"
) else (
    echo [오류] 1 또는 2만 입력 가능합니다.
    goto CHOOSE_TYPE
)

echo.
set /p THREADS="공격 트래픽 동시 실행 스레드 수(ATTACK_THREADS)를 입력하세요: "

if "%THREADS%"=="" (
    echo [오류] 스레드 수를 반드시 입력해야 합니다.
    pause
    exit /b
)

echo.
set /p POOL_MODE="풀 고갈 실험 모드를 활성화하시겠습니까? (y/n): "

if /i "!POOL_MODE!"=="y" (
    set "HIKARI_OVERRIDE=-Dspring.datasource.hikari.maximum-pool-size=5"
    echo [풀 고갈 모드 활성화] maximum-pool-size=5
) else (
    set "HIKARI_OVERRIDE="
    echo [기본 풀 설정 사용]
)

echo.
echo ---------------------------------------
echo [실행 설정]
echo   - 테스트 유형 : !MODE!
echo   - 공격 스레드 : !THREADS!
echo ---------------------------------------

docker run --rm ^
  -e TZ=Asia/Seoul ^
  -e JVM_ARGS="-Duser.timezone=Asia/Seoul !HIKARI_OVERRIDE!" ^
  -v "%cd%:/jmeter" ^
  spring-jmeter ^
  jmeter -n ^
  -t /jmeter/scenarios/attack_!MODE!_vs_normal.jmx ^
  -l /jmeter/results/!MODE!_result_!THREADS!.jtl ^
  -Jjmeter.save.saveservice.output_format=csv ^
  -Jjmeter.save.saveservice.response_data=false ^
  -Jjmeter.save.saveservice.response_headers=false ^
  -Jjmeter.save.saveservice.requestHeaders=false ^
  -Jjmeter.save.saveservice.samplerData=false ^
  -Jjmeter.save.saveservice.assertion_results=none ^
  -Jjmeter.save.saveservice.bytes=true ^
  -Jjmeter.save.saveservice.latency=true ^
  -Jjmeter.save.saveservice.connect_time=true ^
  -JATTACK_THREADS=!THREADS! ^
  -JATTACK_RAMP=30 ^
  -JATTACK_DELAY=!DELAY! ^
  -JATTACK_LOOPS=50 ^
  -JNORMAL_THREADS=3 ^
  -JNORMAL_DELAY=1000 ^
  -JNORMAL_LOOPS=50

echo.
echo [완료] 결과 파일이 생성되었습니다:
echo   /results/!MODE!_result_!THREADS!.jtl
pause

@echo off
:: 한글 깨짐 방지 (UTF-8 설정)
chcp 65001 >nul
setlocal enabledelayedexpansion

:CHOOSE_TYPE
echo ===========================================
echo   JMeter 리포트 생성 유형 선택
echo ===========================================
echo  1. Read (read_result_*.jtl 스캔)
echo  2. Write (write_result_*.jtl 스캔)
set /p TYPE_CHOICE="번호를 선택하세요 (1 또는 2): "

if "%TYPE_CHOICE%"=="1" (
    set "MODE=read"
) else if "%TYPE_CHOICE%"=="2" (
    set "MODE=write"
) else (
    echo [오류] 잘못된 선택입니다. 다시 입력해주세요.
    timeout /t 2 >nul
    cls
    goto CHOOSE_TYPE
)

:: 결과 파일 폴더 경로
set "TARGET_DIR=results"
set "FOUND=0"

echo.
echo [알림] %TARGET_DIR% 폴더에서 !MODE!_result_*.jtl 파일을 스캔합니다...
echo ---------------------------------------

:: 선택된 모드에 따라 파일 스캔
for %%f in ("%TARGET_DIR%\!MODE!_result_*.jtl") do (
    set "FOUND=1"
    set "filename=%%~nf"
    
    :: 파일명에서 숫자 부분 추출 (예: read_result_100 -> 100)
    :: !MODE!_result_ 문구 자체를 지웁니다.
    set "num=!filename:*_result_=!"
    
    echo [작업 시작] 발견된 번호: !num!
    echo [대상 파일] %%f
    
    docker run --rm ^
      -v "%cd%:/jmeter" ^
      spring-jmeter ^
      jmeter -g /jmeter/results/!MODE!_result_!num!.jtl ^
             -o /jmeter/results/report_!MODE!_!num!
             
    if !errorlevel! neq 0 (
        echo [오류 발생] !num!번 보고서 생성 중 문제가 발생했습니다.
    )
    echo ---------------------------------------
)

if "!FOUND!"=="0" (
    echo [경고] %TARGET_DIR% 폴더에 !MODE!_result_*.jtl 파일이 없습니다.
    echo 현재 위치: %cd%\%TARGET_DIR%
)

echo.
echo 모든 작업이 완료되었습니다.
pause
@echo off
setlocal enabledelayedexpansion
REM Shift-JIS
REM chcp 932
REM UTF-8
chcp 65001

set "version_json_file=%~dp0assets\version.json"
set "id_file=%~dp0ffmpeg_last_id.txt"

cd %~dp0

:: ファイルが存在するかチェック
if not exist "%version_json_file%" (
    echo [エラー] JSONファイルが見つかりません: %version_json_file%
    pause
    exit /b
)

echo [デバッグ] PowerShellを呼び出しています...
for /f "usebackq delims=" %%a in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$json = Get-Content -LiteralPath '%version_json_file%' -Raw | ConvertFrom-Json; if ($json.version) { $json.version } else { 'DEBUG_EMPTY' }"`) do (
    set "version=%%a"
)

:: 結果判定
if "!version!"=="DEBUG_EMPTY" (
    echo [エラー] JSONは読み込めましたが、'version' キーが見つからないか空です。
    echo JSONのキー名が正確に "version" であるか確認してください。
) else if not defined version (
    echo [エラー] PowerShellからの出力が全くありません。
    echo JSONファイルが破損しているか、文字コードの問題の可能性があります。
) else (
    echo 成功！取得した値: !version!
    rem exit /b
)

REM LGPLビルドのFFmpegダウンロードURL
set ffmpeg_url=https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-lgpl.zip

REM ダウンロード先と展開先の設定
set ffmpeg_zip=ffmpeg.zip
set ffmpeg_dir=ffmpeg

REM ==========================================
REM FFmpeg 更新チェック処理（エラー詳細表示版）
REM ==========================================
echo [更新チェック] GitHubの最新FFmpeg情報を確認中...
set "latest_id="
set "api_error="

for /f "usebackq delims=" %%i in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "try { (Invoke-RestMethod -Uri 'https://api.github.com/repos/BtbN/FFmpeg-Builds/releases/latest' -ErrorAction Stop).published_at } catch { 'ERROR:' + $_.Exception.Message }"`) do (
    set "api_result=%%i"
)

REM エラー文字列が含まれているかチェック
echo "!api_result!" | findstr /i "ERROR:" >nul
if not errorlevel 1 (
    set "api_error=!api_result!"
    echo [詳細エラー] !api_error!
) else (
    set "latest_id=!api_result!"
)

REM APIエラー時は安全のためチェックをスキップしてダウンロードへ進む
if not defined latest_id (
    echo [警告] GitHub APIからの情報取得に失敗しました。強制ダウンロードします。
    goto :download_ffmpeg
)

REM 過去のビルド成功時のIDと比較
if exist "%id_file%" (
    set /p last_id=<"%id_file%"
    if "!last_id!"=="%latest_id%" (
        echo [情報] FFmpegはすでに最新版（!latest_id!）が反映されています。
        echo ダウンロードと展開をスキップしてビルドへ進みます。

        REM スキップする場合でも、Inno Setup用のディレクトリパスが必要なため設定
        REM (前回のクリーンアップで消えているため、ダミーまたは空作成で対応)
        if not exist "%ffmpeg_dir%" mkdir "%ffmpeg_dir%"
        goto :start_build
    )
)

:download_ffmpeg
REM FFmpegをダウンロード
echo Downloading FFmpeg...
curl -L "%ffmpeg_url%" -o "%ffmpeg_zip%" || (echo Failed to download FFmpeg && exit /b)

REM FFmpegを展開
echo Extracting FFmpeg...
if exist "%ffmpeg_dir%" rmdir /s /q "%ffmpeg_dir%"
mkdir "%ffmpeg_dir%"
tar -xf "%ffmpeg_zip%" -C "%ffmpeg_dir%" --strip-components=1

:start_build
if exist "dist" rmdir /s /q "dist"
if exist "build" rmdir /s /q "build"

REM venv に入る
call .\venv\Scripts\activate.bat

REM PyInstallerで実行ファイルをビルド（yt-dlpGUI.exe）
pyinstaller --name yt-dlpGUI -F -w --icon=assets/icon2.ico --add-data "locale;locale" --add-data "assets;assets" --noconfirm --clean main.py

REM issファイルを更新
call :update_iss "%version%" "%cd%\%ffmpeg_dir%"

REM Inno Setupでコンパイル
echo Compiling installer with Inno Setup...
set iss_compiler="C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if not exist %iss_compiler% (
    echo Inno Setup Compiler not found at %iss_compiler%.
    echo Please install Inno Setup 6 and try again.
    exit /b
)

%iss_compiler% yt-dlp.iss || (echo Failed to compile installer && exit /b)

REM ------------------------------------------
REM ビルド成功時のみ、今回のFFmpegのIDを記録する
REM ------------------------------------------
if not "%latest_id%"=="" (
    echo %latest_id% > "%id_file%"
)

REM FFmpegフォルダとZIPを削除
echo Cleaning up FFmpeg files...
if exist "%ffmpeg_zip%" del "%ffmpeg_zip%"
if exist "%ffmpeg_dir%" rmdir /s /q "%ffmpeg_dir%"

echo Installer and portable version renamed successfully!
pause
exit /b

:update_iss
setlocal
set iss_file=yt-dlp.iss
set temp_file=%iss_file%.tmp

(for /f "usebackq delims=" %%a in (`type "%iss_file%"`) do (
    set "line=%%a"
    setlocal enabledelayedexpansion
    echo !line! | findstr /i "AppVersion=" >nul && (
        echo AppVersion=%~1
    ) || (
        echo !line! | findstr /i "OutputBaseFilename=" >nul && (
            echo OutputBaseFilename=yt-dlpGUI_Installer
        ) || (
            echo !line!
        )
    )
    endlocal
)) > "%temp_file%"

move /y "%temp_file%" "%iss_file%" >nul
endlocal
exit /b

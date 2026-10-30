@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

echo ===================================================
echo   FFmpeg 結合・サムネイル埋め込みバッチ
echo ===================================================

:: FFmpegの呼び出し確認
where ffmpeg >nul 2>nul
if %errorlevel% neq 0 (
    echo 【エラー】ffmpeg が見つかりません。
    echo 環境変数（PATH）に登録されているか、またはこのバッチと同じフォルダに ffmpeg.exe を配置してください。
    goto END
)

:: 引数チェック（3つのファイルが必要）
set "arg_count=0"
for %%x in (%*) do set /a "arg_count+=1"

if not !arg_count! == 3 (
    echo 【エラー】ファイルを3つ（mp4, m4a, webp）ドロップしてください。
    echo 現在のファイル数: !arg_count!
    goto END
)

:: 各拡張子のファイルを自動判別して変数に格納
set "VIDEO_FILE="
set "AUDIO_FILE="
set "THUMB_FILE="

for %%i in (%*) do (
    set "ext=%%~xi"
    :: 大文字小文字を区別せず拡張子をチェック
    if /i "!ext!"==".mp4"  set "VIDEO_FILE=%%~i"
    if /i "!ext!"==".m4a"  set "AUDIO_FILE=%%~i"
    if /i "!ext!"==".webp" set "THUMB_FILE=%%~i"
)

:: すべてのファイルが揃っているかチェック
if "%VIDEO_FILE%"=="" ( echo 【エラー】MP4ファイルが見つかりません。 & goto END )
if "%AUDIO_FILE%"=="" ( echo 【エラー】M4Aファイルが見つかりません。 & goto END )
if "%THUMB_FILE%"=="" ( echo 【エラー】WebPファイルが見つかりません。 & goto END )

:: MP4のファイル名＋_output.mp4 で出力先を設定
for %%v in ("%VIDEO_FILE%") do (
    set "OUTPUT_FILE=%%~dpnv_output.mp4"
)

:: デバッグ表示（組み立てたコマンドの確認）
echo.
echo ------------------ [DEBUG LOG] -------------------
echo [入力動画] : %VIDEO_FILE%
echo [入力音声] : %AUDIO_FILE%
echo [画像サム] : %THUMB_FILE%
echo [出力先]   : %OUTPUT_FILE%
echo.
echo [実行コマンド]:
echo ffmpeg -i "%VIDEO_FILE%" -i "%AUDIO_FILE%" -i "%THUMB_FILE%" -map 0:v -map 1:a -map 2:v -c 0 copy -c:a copy -c 1 libx264 -disposition 1 attached_pic "%OUTPUT_FILE%"
echo --------------------------------------------------
echo.

:: 実行確認
echo 処理を開始します...
ffmpeg -i "%VIDEO_FILE%" -i "%AUDIO_FILE%" -i "%THUMB_FILE%" -map 0:v -map 1:a -map 2:v -c 0 copy -c:a copy -c 1 libx264 -disposition 1 attached_pic "%OUTPUT_FILE%"

if %errorlevel% equ 0 (
    echo.
    echo 【成功】処理が正常に完了しました！
) else (
    echo.
    echo 【失敗】FFmpegの実行中にエラーが発生しました。
)

:END
echo.
echo 画面を閉じるには何かキーを押してください...
pause >nul
@echo off
set SCRIPT_DIR=%~dp0
set "steamcmd_path=%SCRIPT_DIR%steamcmd.exe"

echo 【提示】登录的账号需要有购买求生之路2游戏，不然无法下载服务端，但更新服务端不用
echo 【提示】登录的账号需要有购买求生之路2游戏，不然无法下载服务端，但更新服务端不用
echo 【提示】登录的账号需要有购买求生之路2游戏，不然无法下载服务端，但更新服务端不用
echo.

if exist "%steamcmd_path%" (
    echo.
) else (
    echo steamcmd 不存在，请将 steamcmd 移动到和脚本同一文件夹再运行脚本...
	pause >nul
    exit /b
    )
)

for /f "tokens=4 delims=[]. " %%a in ('ver') do set ver=%%a
if %ver% geq 6 (
	for /f "delims=" %%p in ('powershell -Command "$password = Read-Host '请输入服务端文件所在文件夹名称（留空则选择默认文件夹）'; $password"') do set "STEAM_MENU=%%p"
	if "%STEAM_MENU%"=="" (
    set STEAM_MENU=server_l4d2
	echo.
	) else (
	echo.
	)
	for /f "delims=" %%p in ('powershell -Command "$password = Read-Host '请输账号'; $password"') do set "STEAM_NAME=%%p"
	for /f "delims=" %%p in ('powershell -Command "$password = Read-Host '请输入密码' -AsSecureString; [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))"') do set "STEAM_PASS=%%p"
) else (
	echo 【提示】因为低版本的win server系统部分功能不可用，所以密码无法隐藏显示
	echo.
	echo 请输入服务端文件所在文件夹名称（留空则选择默认文件夹）
	set /p STEAM_MENU=
	if "%STEAM_MENU%"=="" (
    set STEAM_MENU=server_l4d2
	echo.
	) else (
	echo.
	)
	
	echo 请输入账号:
	set /p STEAM_NAME=

	echo 请输入密码:
	set /p STEAM_PASS=
)

echo.
echo 【提示】left4dead2 安装/更新开始，请查看新的控制台窗口，期间需要输入邮箱验证码或手机设备安全码以继续（自行翻译新控制台窗口的内容），若提示账号或密码错误则重启脚本...
start "" "%SCRIPT_DIR%steamcmd.exe" +force_install_dir "%SCRIPT_DIR%%STEAM_MENU%" +login %STEAM_NAME% %STEAM_PASS% +app_update 222860 validate +quit

pause >nul
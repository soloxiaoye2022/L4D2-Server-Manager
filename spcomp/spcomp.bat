@echo off
setlocal enabledelayedexpansion
chcp 65001

:check_dir
set /p "dir=请输入插件路径 (不是插件文件的路径，而是插件目录路径): "
if not defined dir (
    echo 请输入有效内容，请重新输入。
    goto check_dir
)
if "!dir:~1,1!"=="\" (
    echo 您输入的不是一个绝对路径，请重新输入。
    goto check_dir
)
if not exist "!dir!" (
    echo 您输入的插件路径不存在，请重新输入。
    goto check_dir
)

:check_file
set /p "file=请输入插件文件名 (必须包含后缀.sp): "
if not defined file (
    echo 请输入有效内容，请重新输入。
    goto check_file
)
if not exist "!dir!\!file!" (
    echo 您输入的插件名不存在于当前插件目录中，请重新输入。
    goto check_file
)

set "DEFAULT_SP=!dir!"
set "DEFAULT_MANE=!file!"
for %%i in ("!DEFAULT_SP!") do set "DEFAULT_MENU=%%~dpi"
pushd "%~dp0"
set "DEFAULT_SH=!cd!"
popd
set "prefix=!DEFAULT_SP!\!DEFAULT_MANE!"
for %%i in ("!prefix!") do set "DEFAULT_SMX=%%~ni"

echo 开始编码，以下是编码信息
"%DEFAULT_SP%\spcomp64.exe" "%DEFAULT_SP%\%DEFAULT_MANE%"

set "targetDir=%DEFAULT_SH%"
set "targetFile=%DEFAULT_SMX%.smx"

if exist "%DEFAULT_SH%\%DEFAULT_SMX%.smx" (
    goto ask
) else (
    echo 编码失败，请查看编码信息后，修改sp文件报错内容(请手动关闭窗口)
    pause
)

:ask
set "choice="
set /p "choice=是否执行命令? (输入 y 或 n): "
if not defined choice (
    echo 输入不能为空，请重新输入.
    goto ask
) else (
    set "choice=!choice:~0,1!"
    if /i "!choice!"=="y" (
         echo 正在替换当前服务端文件的原本插件文件
         move /y "%DEFAULT_SH%\%DEFAULT_SMX%.smx" "%DEFAULT_MENU%\plugins"
         echo 替换完成 【10秒后退出窗口】
         timeout /t 10
    ) else if /i "!choice!"=="n" (
        echo 编码完毕，插件smx文件在当前sh脚本文件的目录下【10秒后退出窗口】
        timeout /t 10
    ) else (
        echo 输入不正确，请重新输入.
        goto ask
    )
)
# Настройка ядра Sing-Box на Windows

### 1) В отдельной папке создайте .cmd или .bat файл с таким содержимым:

```
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

rem Ссылка для загрузки клиентской конфигурации (замените на свою)
set URL=https://example.com/secret175subscr1pt10n/username-VLESS-CLIENT.json

set "SING_BOX_DIR=%~dp0"
set "SING_BOX_DIR=%SING_BOX_DIR:~0,-1%"
cd /d "%SING_BOX_DIR%"

if not exist sing-box.exe (
    echo Скачивание Sing-Box...
    echo.
    for /f "tokens=2 delims= " %%u in ('curl -Ls -m 60 https://api.github.com/repos/SagerNet/sing-box/releases/latest ^| findstr browser_download_url ^| findstr windows-amd64.zip') do (set "ZIP_URL=%%~u")
    curl -L -o sing-box.zip -m 300 "!ZIP_URL!"
    tar -xf sing-box.zip --strip-components=1
    del sing-box.zip
    echo.
)

echo Sing-Box запущен
echo Не закрывайте это окно, пока Sing-Box работает
echo Нажмите Ctrl + C, чтобы отключиться
echo.

curl -sf -o client.json -m 60 "%URL%"
.\sing-box.exe run -c client.json --disable-color
```

> [!IMPORTANT]
> Ссылку в 6-ой строчке замените на свою.

### 2) Создайте ярлык для этого .cmd или .bat файла

Далее нажмите на ярлык правой кнопкой мыши и выберите «Свойства», затем перейдите во вкладку «Ярлык»:

![w3](https://github.com/user-attachments/assets/370c8c40-d861-4255-a1b0-e8f081bcae61)

Выберите «Дополнительно» и поставьте галочку «Запуск от имени администратора» (требуется для запуска tun интерфейса), потом везде нажмите OK.

### 3) Для подключения к прокси просто нажмите на ярлык

Не нужно закрывать появившееся окно, пока ПК подключён к прокси.

Чтобы отключиться, нажмите на окно командной строки, а далее Ctrl + C.

# Настройка ядра Sing-Box на Linux

Запустите команду ниже и следуйте инструкциям (не требует sudo).

```
bash <(curl -Ls https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Scripts/sb-pc-linux.sh); source ~/.bashrc
```

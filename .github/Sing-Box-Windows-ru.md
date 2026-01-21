# Настройка клиента Sing-Box на Windows

### 1.1) Установка Sing-Box (Windows 10 и 11)

Нажмите Win + X и выберите «Windows PowerShell (администратор)» или «Командная строка (администратор)».

Далее введите команду:

```
winget install sing-box
```

После окончания установки командную строку можно закрыть (в дальнейшем можно обновлять Sing-Box той же командой).

Если на этом этапе возникла ошибка, предупреждающая об отсутствии winget, то следуйте инструкциям ниже.

### 1.2) Установка Sing-Box (для версий Windows без winget)

Скачайте Sing-Box для Windows из официального репозитория:

https://github.com/SagerNet/sing-box/releases/latest

Далее извлеките sing-box.exe из архива.

-----

### 2) Создайте .cmd или .bat файл с таким содержимым:

```
@echo off
echo Started Sing-Box
echo Do not close this window while Sing-Box is running
echo Press Ctrl + C to disconnect
echo.
if not exist "C:\1-sbconfig\" mkdir C:\1-sbconfig
curl -s -o C:\1-sbconfig\client.json https://example.com/secret175subscr1pt10n/username-VLESS-CLIENT.json
sing-box run -c C:\1-sbconfig\client.json
```

Ссылку в предпоследней строчке замените на свою.

Для версий Windows, где нет winget, замените последнюю строчку таким образом и поменяйте путь к sing-box.exe на свой:

```
C:\actual\path\to\sing-box.exe run -c C:\1-sbconfig\client.json
```

-----

### 3) Создайте ярлык для этого .cmd или .bat файла

Далее нажмите на ярлык правой кнопкой мыши и выберите «Свойства», затем перейдите во вкладку «Ярлык»:

![w3](https://github.com/user-attachments/assets/ec6a3c3b-e3ab-4eda-86ef-24b780b6a17f)

Выберите «Дополнительно» и поставьте галочку «Запуск от имени администратора», потом везде нажмите OK.

-----

### 4) Для подключения к прокси просто нажмите на ярлык

Не нужно закрывать появившееся окно, пока ПК подключён к прокси.

Чтобы отключиться, нажмите на окно командной строки, а далее Ctrl + C.

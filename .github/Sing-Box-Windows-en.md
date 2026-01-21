# Setting Up Sing-Box Client on Windows

### 1.1) Install Sing-Box (for Windows 10 and 11)

Press Win + X and select «Terminal (Admin)», «Command Prompt (Admin)» or «Windows PowerShell (Admin)».

Then enter the command:

```
winget install sing-box
```

You can close the terminal after the installation is complete (Sing-Box can also be updated with the same command).

If you are getting an error telling that winget is absent, then follow the instructions below.

### 1.2) Install Sing-Box (for Windows versions without winget)

Download Sing-Box for Windows from the official repository:

https://github.com/SagerNet/sing-box/releases/latest

Then extract sing-box.exe from the archive.

-----

### 2) Create a .cmd or .bat file with such content:

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

Change the link in the 7th line to yours.

For Windows versions without winget replace the last line like this and replace the path to sing-box.exe to your actual path:

```
C:\actual\path\to\sing-box.exe run -c C:\1-sbconfig\client.json
```

-----

### 3) Create a shortcut for this .cmd or .bat file

Next, right-click on the shortcut and select «Properties», then go to the «Shortcut» tab:

![w3](https://github.com/user-attachments/assets/73f76c75-f891-49a9-9b95-dd659b145725)

Select «Advanced» and check the «Run as administrator» box, then click OK.

-----

### 4) Click on the shortcut to connect to the server

Do not close the terminal window while connected to proxy.

To disconnect, click on the terminal window and then press Ctrl + C.

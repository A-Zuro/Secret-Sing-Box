# How to Select a Cloudflare Subnet?

We will use the **CloudflareScanner** tool to test latency and download speed for Cloudflare's CDN, identifying the fastest IP addresses (IPv4 and IPv6). Run the scanner without VPN/proxy.

### Main Features

- Latency and download speed testing for Cloudflare IP addresses.
- Can be used with custom parameters for more accurate testing.
- Supports testing IP addresses of other CDNs and websites.

### Usage on Windows

1) Download the executable file from the [release page](https://github.com/Ptechgithub/CloudflareScanner/releases/latest) and extract it.
2) Run the `CloudflareScanner.exe` file and wait for the test to complete.
3) After completion, the 10 fastest IP addresses with latency and download speed details will be displayed.

### Usage on Linux

Use the commands below to:
- Identify your device's architecture.
- Download the latest release for your architecture.
- Extract the archive, make the file executable, and run CloudflareScanner.

```
ARCH=$(uname -m); case $ARCH in x86_64) FILE="CloudflareScanner_linux-amd64.zip";; aarch64|arm64) FILE="CloudflareScanner_linux-arm64.zip";; armv7l) FILE="CloudflareScanner_linux-arm7.zip";; mips64) FILE="CloudflareScanner_linux-mips64.zip";; mips64le) FILE="CloudflareScanner_linux-mips64le.zip";; riscv64) FILE="CloudflareScanner_linux-riscv64.zip";; *) echo "Unsupported architecture: $ARCH"; exit 1;; esac
wget "https://github.com/Ptechgithub/CloudflareScanner/releases/latest/download/$FILE"
unzip "$FILE" -d CloudflareScanner && cd CloudflareScanner
chmod +x CloudflareScanner
./CloudflareScanner
```

For subsequent runs, use:

```
cd CloudflareScanner && ./CloudflareScanner
```

### Usage on macOS

Follow these steps to run the tool on macOS:

1) Download the file corresponding to your CPU:
   - **`CloudflareScanner_darwin-arm64.zip`** — for Macs with Apple Silicon (M1, M2, and newer).
   - **`CloudflareScanner_darwin-amd64.zip`** — for Intel-based Macs.

2) Extract the downloaded archive to a convenient location, such as the `Downloads` folder.

3) Open the terminal and execute these commands:

```
cd ~/Downloads/CloudflareScanner_darwin-arm64
chmod +x CloudflareScanner
./CloudflareScanner
```

For subsequent runs, use:

```
cd ~/Downloads/CloudflareScanner_darwin-arm64 && ./CloudflareScanner
```

### Usage on Android

First, install [Termux](https://play.google.com/store/apps/details?id=com.termux) on your device.

Then open the app and use the commands below to:
- Download the latest release for Android.
- Extract the archive, make the file executable, and run CloudflareScanner.

```
pkg install wget -y
wget "https://github.com/Ptechgithub/CloudflareScanner/releases/latest/download/CloudflareScanner_android-arm64.zip"
unzip "CloudflareScanner_android-arm64.zip" -d CloudflareScanner && cd CloudflareScanner
chmod +x CloudflareScanner
./CloudflareScanner
```

For subsequent runs, use:

```
cd CloudflareScanner && ./CloudflareScanner
```

### Example Output

| IP Address    | Sent | Received | Loss Rate | Average Delay (ms) | Download Speed (MB/s) |
| ------------- | ---- | -------- | --------- | ------------------ | --------------------- |
| 104.27.200.69 | 4    | 4        | 0.00      | 146.23             | 28.64                 |
| 172.67.60.78  | 4    | 4        | 0.00      | 139.82             | 15.02                 |
| ...           | ...  | ...      | ...       | ...                | ...                   |

Full results are saved to `result.csv` in the current directory.

### Internet Provider

When choosing an optimal subnet, consider your internet connection type:

- For mobile internet, scan using the connection shared from the phone or modem of the ISP you are going to use later.
- For wired internet connections, scan using the specific internet provider and channel intended for later use.

Test results can vary significantly based on the telecom or ISP, so it's crucial to perform the scan from the actual network you are going to use.

### Additional Parameters

- `-n`: Number of threads for latency testing (default 200, max 1000).
- `-t`: Number of latency tests per IP (default 4).
- `-dn`: Number of IPs for download speed testing after sorting by latency (default 10).
- `-dt`: Duration of download speed testing per IP in seconds (default 10).
- `-tp`: Port for testing (default 443).
- `-url`: URL for latency (HTTPing) and download speed testing.
- `-httping`: Switch latency test mode to HTTP.
- `-httping-code`: Allowed HTTP status codes for HTTPing latency testing (default 200, 301, 302).
- `-cfcolo`: Match specified locations; locations named by three-letter airport codes, comma-separated, case-insensitive, supported by Cloudflare, AWS CloudFront, only available in HTTPing mode (default all locations).
- `-tl`: Maximum average latency threshold; only display IPs below this value (default 9999 ms).
- `-tll`: Minimum average latency threshold; only display IPs above this value (default 0 ms).
- `-tlr`: Maximum packet loss threshold; only display IPs with loss below this ratio (default 1.00).
- `-sl`: Minimum download speed threshold; only display IPs above this speed (default 0.00 MB/s).
- `-p`: Number of results to display directly after testing (default 10).
- `-f`: IP range data file; if the path contains spaces, wrap it in quotes; supports IP ranges of other CDNs (default ip.txt).
- `-ip`: IP range data directly specified via parameters, separated by commas (default empty).
- `-o`: Write result to file; if path contains spaces, wrap it in quotes; if set to empty [-o ""] do not write to file (default is result.csv).
- `-dd`: Disable download speed test; when disabled, test results will be sorted by latency (by default sorted by download speed) (enabled by default).
- `-allip`: Test all IPs within each range (IPv4 only); defaults to randomly testing one IP per /24 subnet.
- `-v`: Print program version and check for updates.
- `-h`: Show help information and exit.

For more information and the latest updates, visit [CloudflareScanner GitHub repository](https://github.com/Ptechgithub/CloudflareScanner).

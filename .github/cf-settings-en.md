# Setting Up a Domain

> [!NOTE]
> This guideline shows how to set up a domain using Cloudflare as an example, but you can also use other services.

### General settings
First, you need to add your domain to your [Cloudflare account](https://dash.cloudflare.com) and specify Cloudflare NS servers at your domain registrar.

Next, change the following settings in your Cloudflare account: 
1) SSL/TLS > Overview > Configure > Full
2) SSL/TLS > Edge Certificates > Minimum TLS Version > TLS 1.2
3) SSL/TLS > Edge Certificates > TLS 1.3 > Enable

### DNS Settings
Example of DNS records:

![dns-2](https://github.com/user-attachments/assets/503bef75-2e50-4c46-9344-5f01bb3efdef)

For the setup option with TLS termination on NGINX and WebSocket or HTTPUpgrade transport, you can enable proxying of both records (this may require to disable ECH).

> [!IMPORTANT]
> If you already have an A record for this domain created for other purposes, then also create an A record for subdomain:
>
> A | sub | 98.76.54.32
>
> Instead of «sub», specify your subdomain and enter it in the script instead of your domain (e. g. sub.example.com).

### Getting Cloudflare API token
In your Cloudflare account, select Overview > Get your API token > Create Token > Edit zone DNS (Use template).

Then specify the following settings:

![token](https://github.com/user-attachments/assets/ad24e8b0-b817-4c31-bb9e-98a62cde43c7)

Other settings can be left as is.

After receiving the token, you need to copy and save it, because it will only be shown once.

You can use an API key instead of a token, but this is less secure and not recommended.

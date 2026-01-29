# Настройка домена

> [!NOTE]
> Здесь показана настройка домена на примере Cloudflare, но можно также использовать другие сервисы.

### Общие настройки
Для начала нужно добавить домен в [аккаунт Cloudflare](https://dash.cloudflare.com) и указать NS-сервера Cloudflare у вашего регистратора доменов.

Далее выполнить следующие настройки в аккаунте Cloudflare: 
1) SSL/TLS > Overview > Configure > Full
2) SSL/TLS > Edge Certificates > Minimum TLS Version > TLS 1.2
3) SSL/TLS > Edge Certificates > TLS 1.3 > Включить

### Настройки DNS
Пример DNS записей:

![dns-2](https://github.com/user-attachments/assets/8f67a737-bb84-48bc-ba36-f56985e951d5)

Для варианта настройки с терминированием TLS на NGINX и транспортом WebSocket или HTTPUpgrade можно включить проксирование обеих записей (требует [отключения ECH](https://habr.com/ru/articles/856602/)).

> [!IMPORTANT]
> Если уже есть А запись на этот домен, созданная для других целей, то нужно создать А запись на поддомен:
>
> A | sub | 98.76.54.32
>
> Вместо «sub» придумайте свой поддомен, и в скрипте введите его вместо домена (например, sub.example.com).

### Получение API токена Cloudflare
В аккаунте Cloudflare выберите Overview > Get your API token > Create Token > Edit zone DNS (Use template).

Далее нужно указать следующие настройки:

![token](https://github.com/user-attachments/assets/e32a752b-faa5-4d14-9c8c-1745b59636e4)

Остальные настройки можно оставить, как есть.

После получения токен нужно скопировать и сохранить, потому что его покажут только 1 раз.

Вместо токена можно использовать API ключ, но это менее безопасно и не рекомендуется.

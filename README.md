# daypass

Выборочный прозрачный прокси для OpenWrt на ядре [mihomo](https://github.com/MetaCubeX/mihomo). Через прокси идёт только выбранный трафик — домены или подсети из списков; остальное идёт напрямую, минуя mihomo.

## Установка

```sh
sh <(wget -O - https://raw.githubusercontent.com/TheMelbine/daypass/master/install.sh)
```

Протестировано на OpenWrt 24.10, Routerich AX3000 (`aarch64_cortex-a53`).

После установки: **LuCI → Службы → Daypass → Подключение** — вставь подписку или ссылку на ноду. На вкладке **Прокси** нажми **Тест** и выбери ноду по пингу.

## Возможности

- Два режима: `selective` (только выбранное) и `full` (весь трафик LAN через прокси).
- Подписки и ссылки `vless://`, `ss://`, `trojan://`, `hysteria2://`, `socks://`.
- Свои rule-set — домены и подсети в форматах `mrs`, `yaml`, `text`.
- Ручной выбор ноды с реальным пингом.
- DNS-whitelist через fake-ip и обновление списков по расписанию.
- Дашборды zashboard и metacubexd.

## Как это работает

mihomo в режиме `fake-ip-filter-mode: whitelist` выдаёт fake-ip только для доменов из списков, а внешний nftables заворачивает эти соединения в TPROXY. Подсети из rule-set попадают в тот же nft-набор. Списки `.mrs` daypass распаковывает в CIDR силами самого mihomo (`convert-ruleset ipcidr mrs`) — искать текстовые версии не нужно.

Детали (nft, метки, порты, UCI, конфиг mihomo) — в [`docs/CONTRACT.md`](docs/CONTRACT.md).

## Сборка

```sh
make ipk                # или make apk; нужен Docker
make ipk BRAND=<name>   # своя марка через branding/<name>.mk
```

Имя пакета и все пути — параметры сборки, поэтому проект пересобирается под другим брендом без правки кода.

## Кредиты

[mihomo](https://github.com/MetaCubeX/mihomo) · списки [itdoginfo/allow-domains](https://github.com/itdoginfo/allow-domains), [runetfreedom](https://github.com/runetfreedom). Лицензия [GPL-3.0-or-later](LICENSE).

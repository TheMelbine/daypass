# daypass

Выборочный прозрачный прокси для OpenWrt на ядре [mihomo](https://github.com/MetaCubeX/mihomo). Через прокси идёт только выбранный трафик (домены или подсети), остальное роутер шлёт напрямую мимо mihomo.

## Установка

```sh
sh <(wget -qO- https://raw.githubusercontent.com/TheMelbine/daypass/master/install.sh)
```

OpenWrt 24.10, `aarch64_cortex-a53` (проверено на Routerich AX3000). Ставит mihomo, daypass и веб-интерфейс под арку роутера.

Дальше: **LuCI → Службы → Daypass → Подключение** — вставь подписку или ссылку на ноду. На вкладке **Прокси** жми **Тест** и выбирай ноду по пингу.

## Возможности

- Режимы `selective` (только выбранное) и `full` (весь LAN через прокси).
- Подписки и ссылки `vless://`, `ss://`, `trojan://`, `hysteria2://`, `socks://`.
- Свои rule-set: домены и подсети в `mrs` / `yaml` / `text`.
- Выбор ноды с реальным пингом.
- DNS-whitelist через fake-ip, обновление списков по расписанию.
- Дашборды zashboard / metacubexd.

## Как это работает

mihomo с `fake-ip-filter-mode: whitelist` отдаёт fake-ip только для доменов из списков, а внешний nftables заворачивает эти соединения в TPROXY. Подсети из rule-set попадают в тот же nft-набор. `.mrs`-списки daypass распаковывает в CIDR через сам mihomo (`convert-ruleset ipcidr mrs`), искать текстовые версии не нужно.

Детали (nft, метки, порты, UCI, конфиг mihomo) — в [`docs/CONTRACT.md`](docs/CONTRACT.md).

## Сборка

```sh
make ipk                # или make apk; нужен Docker
make ipk BRAND=<name>   # своя марка через branding/<name>.mk
```

Имя пакета и все пути заданы параметрами сборки, так что проект пересобирается под другим брендом без правки кода.

## Кредиты

[mihomo](https://github.com/MetaCubeX/mihomo) · списки [itdoginfo/allow-domains](https://github.com/itdoginfo/allow-domains), [runetfreedom](https://github.com/runetfreedom). Лицензия [GPL-3.0-or-later](LICENSE).

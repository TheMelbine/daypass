# daypass

Выборочный прозрачный прокси для OpenWrt на ядре [mihomo](https://github.com/MetaCubeX/mihomo) (Clash.Meta) с внешним слоем nftables TPROXY.

Через прокси идёт только тот трафик, который ты выбрал сам: домены из списков или подсети. Остальное роутер маршрутизирует напрямую, и mihomo его даже не видит. Идея та же, что у [podkop](https://github.com/itdoginfo/podkop), но здесь только mihomo и только TPROXY, без sing-box и без TUN.

## Как это работает

mihomo в режиме `fake-ip-filter-mode: whitelist` отдаёт fake-ip только для доменов из твоих списков. Внешний слой nftables ловит эти fake-ip и заворачивает соответствующие соединения в TPROXY. Для списков-подсетей их CIDR попадают в тот же nft-набор, поэтому трафик к нужным IP тоже уходит в прокси. Всё, что ты не выбрал, обходит Go-процесс стороной, и на роутере с малым ОЗУ это заметно.

Rule-set в формате `.mrs` (например списки runetfreedom) daypass распаковывает в обычный CIDR-текст командой самого mihomo (`convert-ruleset ipcidr mrs`) и грузит в nft. Отдельные текстовые списки искать не нужно.

Полная схема (путь трафика, топология nft, метки, порты, схема UCI, форма конфига mihomo) лежит в [`docs/CONTRACT.md`](docs/CONTRACT.md).

## Возможности

- Два режима маршрутизации: `selective` (только выбранное) и `full` (весь трафик LAN через прокси).
- Подписки (proxy-providers) и одиночные ссылки `vless://`, `ss://`, `trojan://`, `hysteria2://`, `socks://`.
- Свои rule-set: домены и подсети в форматах `mrs`, `yaml`, `text`. `.mrs` распаковывается в nft автоматически.
- Ручной выбор ноды с реальным пингом в веб-интерфейсе.
- DNS-whitelist через fake-ip и обновление списков по расписанию.
- Веб-интерфейс LuCI: подключение, ноды, подписки, правила, настройки, диагностика, дашборд (zashboard или metacubexd).

## Требования

- OpenWrt 24.10. Проверено на `aarch64_cortex-a53` (Routerich AX3000, MediaTek Filogic). Другие арки должны работать, но я их не гонял.
- mihomo ставится отдельным пакетом: в официальном фиде OpenWrt его нет. На роутерах с малой флешкой можно переиспользовать уже установленный бинарь через опцию `mihomo_gz`.

## Установка

На роутере:

```sh
sh <(wget -qO- https://raw.githubusercontent.com/TheMelbine/daypass/master/install.sh)
```

Скрипт берёт последний релиз (mihomo, daypass, luci-app-daypass под арку роутера) и ставит его.

## С чего начать

1. LuCI → Services → Daypass → **Connection**: вставь подписку или ссылку на ноду.
2. **Proxies**: нажми Test и выбери ноду по пингу.
3. **Rules** и **Settings**: списки доменов и подсетей, режим маршрутизации, DNS.

## Сборка из исходников

Нужен Docker.

```sh
make ipk                  # собрать .ipk (или make apk)
make ipk BRAND=<name>     # своя марка через branding/<name>.mk
```

Артефакты складываются в `out/`. Релизы собирает CI и прикрепляет к GitHub Release.

## Структура

```
branding/                  описания марок, макрос Brand/Subst, логотипы
packages/daypass/          пакет OpenWrt: mihomo + nft TPROXY, генератор конфига на ucode
packages/luci-app-daypass/ веб-интерфейс LuCI + rpcd-плагин
fe-app/                    исходники LuCI-бандла на TypeScript (tsup), main.js закоммичен
docker/                    Dockerfile для сборки в SDK
docs/CONTRACT.md           единый источник правды по всем соглашениям между пакетами
```

## Брендинг

Имя пакета и все пути, идентификаторы и видимые строки заданы параметрами сборки. Проект пересобирается под другим именем без правки исходников: меняются `/etc/config/<brand>`, `/etc/init.d/<brand>`, таблица nft `<brand>`, пункт меню LuCI. По умолчанию `daypass` (см. `branding/daypass.mk`).

## Благодарности

- [podkop](https://github.com/itdoginfo/podkop) — модель установщика и общий подход к выборочной маршрутизации.
- [mihomo](https://github.com/MetaCubeX/mihomo) — ядро прокси.
- Списки блокировок: [itdoginfo/allow-domains](https://github.com/itdoginfo/allow-domains), [runetfreedom](https://github.com/runetfreedom).

## Лицензия

GPL-3.0-or-later. См. [`LICENSE`](LICENSE).

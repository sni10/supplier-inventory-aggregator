# Supplier Inventory Aggregator

> **Консольное приложение на Symfony 7 / PHP 8.2+, которое агрегирует и нормализует EDI-данные (прайсы, остатки и т.п.) от разных поставщиков из различных источников и публикует результат в Kafka**

[![Release](https://img.shields.io/github/v/release/sni10/supplier-inventory-aggregator?style=for-the-badge&logo=github&logoColor=white)](https://github.com/sni10/supplier-inventory-aggregator/releases)
[![Release Workflow](https://img.shields.io/github/actions/workflow/status/sni10/supplier-inventory-aggregator/release.yml?style=for-the-badge&logo=githubactions&logoColor=white&label=Release)](https://github.com/sni10/supplier-inventory-aggregator/actions/workflows/release.yml)
[![Tests](https://img.shields.io/github/actions/workflow/status/sni10/supplier-inventory-aggregator/tests.yml?style=for-the-badge&logo=githubactions&logoColor=white&label=Tests)](https://github.com/sni10/supplier-inventory-aggregator/actions/workflows/tests.yml)
[![Coverage](https://img.shields.io/badge/Coverage-65%25-brightgreen?style=for-the-badge&logo=codecov&logoColor=white)](https://github.com/sni10/supplier-inventory-aggregator/actions/workflows/tests.yml)
[![PHP](https://img.shields.io/badge/PHP-8.2%2B-777BB4?style=for-the-badge&logo=php&logoColor=white)](https://www.php.net/)
[![Symfony](https://img.shields.io/badge/Symfony-7.x-000000?style=for-the-badge&logo=Symfony&logoColor=white)](https://symfony.com/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

## Основные возможности

- Чтение данных поставщиков из нескольких типов источников:
  - Google Sheets / Google Drive
  - CSV/Excel по HTTP(S)
  - CSV/Excel по SFTP
  - REST API (с JWT-аутентификацией)
- Поддержка мультисорсного режима: объединение нескольких файлов/источников по ключу (по умолчанию `upc`)
- Гибкий маппинг колонок через `column_map_rules` в Kafka-сообщении
- Отправка обработанных записей (`DataRow`) в выходной Kafka-топик
- Логирование и контроль ошибок, автоперезапуск консьюмера через supervisord

## Архитектура в двух словах

- Модели (DataRow, DataCollection, DataSetCollection) — только структура данных, без бизнес-логики
- Сервисы (Aggregator, Mapper, KafkaConsumer/Producer) — оркестрация и бизнес-правила
- InputHandler'ы — реализация паттерна Strategy для разных типов источников
- Transports (HttpTransport, SftpTransport) — реализация протоколов доступа к данным
- Фабрики (RestApiHandlerFactory, SftpTransportFactory) — создание хендлеров и транспортов

## Требования

- PHP 8.2+
- Symfony 7.1
- Docker и Docker Compose
- Расширения PHP: rdkafka, amqp, ssh2, xdebug, mbstring, gd, pdo_pgsql, zip, sockets, simplexml

---

## Environments

Проект поддерживает два окружения, управляемых через Docker Compose:

### Production environment
- Использует `docker-compose.yml` как базовую конфигурацию
- Настроено для боевого развёртывания с оптимизированными параметрами
- Переменные окружения: `APP_ENV=prod`, `APP_DEBUG=false`
- Supervisord автоматически запускает Kafka consumer

### Development / Testing environment
- Использует `docker-compose.yml` + `docker/config-envs/test/docker-compose.override.yml`
- Включает отладку, покрытие кода и подробные сообщения об ошибках
- Переменные окружения: `APP_ENV=test`, `APP_DEBUG=true`
- Xdebug включён для покрытия и отладки

---

## Running the Application

### Production
1. Клонируйте репозиторий:
```bash
git clone https://github.com/sni10/supplier-inventory-aggregator.git
cd supplier-inventory-aggregator
```

2. Создайте файл `.env.prod` на основе `.env.example` с боевыми настройками

3. Соберите и запустите контейнеры:
```bash
docker compose build
docker compose up -d
```

4. При старте контейнера `supervisord` автоматически запускает консольную команду:
```bash
php /var/www/etl-edi-scraper/bin/console app:consume
```

### Development / Testing
1. Создайте `.env.test` на основе `.env.example` с параметрами для test/dev

2. Соберите и поднимите окружение с тестовым override:
```bash
docker compose --env-file .env.test -f docker-compose.yml -f docker/config-envs/test/docker-compose.override.yml build

docker compose --env-file .env.test -f docker-compose.yml -f docker/config-envs/test/docker-compose.override.yml up -d
```

---

## Makefile

Для удобства доступны make-команды. По умолчанию `APP_ENV=test`.

```bash
make init                 # Полная инициализация (build + up)
make up / make down       # Запуск / остановка контейнеров
make test                 # Запуск тестов
make test-coverage        # Тесты с покрытием
make shell                # Bash в PHP-контейнере
make help                 # Список всех команд
```

Основные группы: `build`, `up`, `down`, `restart`, `logs`, `ps`, `shell` (Docker), `test-*` (тесты), `console`, `composer-*`.

Production: `make prod-build`, `make prod-up`, `make prod-down`.

| Команда | Описание |
|---------|----------|
| **Docker (Test/Dev)** | |
| `make build` | Сборка контейнеров |
| `make up` | Запуск контейнеров |
| `make down` | Остановка и очистка |
| `make restart` | Перезапуск |
| `make logs` | Логи docker-compose |
| `make ps` | Список контейнеров |
| `make shell` | Вход в контейнер |
| **Docker (Production)** | |
| `make prod-build` | Сборка production контейнеров |
| `make prod-up` | Запуск production |
| `make prod-down` | Остановка production |
| **Логи** | |
| `make logs-app` | Логи приложения (stdout) |
| `make logs-app-err` | Логи приложения (stderr) |
| `make logs-supervisor` | Логи supervisord |
| `make logs-php` | PHP ошибки |
| **Symfony** | |
| `make console CMD="..."` | Произвольная команда |
| `make consume` | Запуск консьюмера |
| `make cache-clear` | Очистка кэша |
| **Composer** | |
| `make composer-install` | Установка зависимостей |
| `make composer-update` | Обновление зависимостей |
| **Тесты** | |
| `make test` | Запуск тестов |
| `make test-coverage` | Тесты с покрытием |
| `make test-html` | HTML-отчёт покрытия |
| `make test-unit` | Только Unit тесты |
| `make test-filter FILTER="..."` | Фильтр тестов |

---

## Application composition (Services)
```
NAME      IMAGE                              SERVICE   STATUS    PORTS
php-sda   supplier-data-aggregator-php       php-sda   Up        9000/tcp, 9003/tcp
```

---

## Поддерживаемые типы источников данных (type_id)

Система поддерживает 8 типов источников данных + мультисорсный режим:

| type_id | Название | Описание | Пример source |
|---------|----------|----------|---------------|
| **1** | **Google Sheets** | Данные из Google Таблицы по ID документа | `1aBcDeFgHiJkLmNoPqRsTuVwXyZ...` |
| **2** | **CSV через HTTP** | CSV-файл, доступный по HTTP(S) URL | `https://example.com/feed.csv` |
| **3** | **Google Drive Folder** | Файлы из папки Google Drive по ID папки | `1xYzAbC123456789DeF0GhIjKl...` |
| **4** | **Excel через HTTP** | Excel-файл (.xlsx), доступный по HTTP(S) URL | `https://example.com/data.xlsx` |
| **5** | **Morris XML через SFTP** | XML-файл в формате Morris, получаемый по SFTP | `AvailableBatch_Full_Product_Data.xml` |
| **6** | **Excel через SFTP** | Excel-файл (.xlsx), получаемый по SFTP | `inventory_feed.xlsx` |
| **7** | **CSV через SFTP** | CSV-файл, получаемый по SFTP | `daily_inventory.csv` |
| **8** | **REST API** | Данные из REST API с JWT-аутентификацией | `https://api.example.com/v1/products` |
| **null** | **Multi-Source** | Объединение нескольких источников разных типов | Массив объектов SubSource |

### Особенности типов

- **Google Sheets (1)** и **Google Drive Folder (3)**: используют Google API, требуют настройки `credentials.json`
- **HTTP источники (2, 4)**: используют `HttpTransport`, поддерживают базовую HTTP-аутентификацию
- **SFTP источники (5, 6, 7)**: используют `SftpTransport`, требуют конфигурации в `sftp_config.json` по `supplier_id`
- **REST API (8)**: поддерживает JWT-аутентификацию, требует конфигурации в `rest.json` и `rest.tokens.json`
- **Morris XML (5)**: специализированный хендлер для XML-формата поставщика Morris Costumes
- **Multi-Source (null)**: позволяет объединять данные из разных источников по ключу (например, `upc`)

### Параметр range

Параметр `range` (опциональный) используется для указания диапазона данных:
- Для **Google Sheets (1)**: формат A1-нотации, например `A1:Z1000` или `A1:D`
- Для **Excel файлов (4, 6)**: аналогично, диапазон ячеек
- Для остальных типов: обычно `null`

---

## Формат входного сообщения Kafka

Пример одиночного источника:

```json
{
  "supplier_id": 123,
  "name": "Supplier Name",
  "type_id": 1,
  "source": "https://example.com/data.csv",
  "range": "A1:Z1000",
  "column_map_rules": {
    "product_name": "name",
    "price": "cost"
  },
  "version": 1
}
```

Пример мультисорсного сообщения (`type_id` на верхнем уровне `null`):

```json
{
  "supplier_id": 123,
  "name": "Supplier Name",
  "type_id": null,
  "source": [
    {
      "type_id": 1,
      "filename": "sheet1",
      "key": "upc",
      "fields": ["name", "price"],
      "range": "A1:Z1000"
    },
    {
      "type_id": 4,
      "filename": "https://example.com/prices.xlsx",
      "key": "upc",
      "fields": ["discount"],
      "range": null
    }
  ],
  "column_map_rules": {
    "product_name": "name",
    "price": "cost"
  },
  "version": 1
}
```

---

## Tests

Проект включает полноценное покрытие тестами на базе PHPUnit:
- **Unit-тесты** (`tests/Unit/`) — быстрые изолированные тесты для моделей и бизнес-логики (без БД)

### Running tests locally

Тесты запускаются внутри контейнера PHP, используя окружение разработки/тестирования.

1. Поднимите тестовое окружение:
```bash
docker compose --env-file .env.test -f docker-compose.yml -f docker/config-envs/test/docker-compose.override.yml up -d
```

2. Запустите все тесты:
```bash
docker compose --env-file .env.test exec php-sda vendor/bin/phpunit --colors=always --testdox
```

3. Запустите тесты с покрытием:
```bash
docker compose --env-file .env.test exec php-sda vendor/bin/phpunit --coverage-text --colors=always --testdox
```

4. Сгенерируйте HTML-отчёт покрытия:
```bash
docker compose --env-file .env.test exec php-sda vendor/bin/phpunit --coverage-html=var/coverage
```

Откройте `var/coverage/index.html` в браузере, чтобы посмотреть отчёт.

### Running individual tests

Запустить один файл тестов:
```bash
docker compose --env-file .env.test exec php-sda vendor/bin/phpunit tests/Unit/Model/DataRowTest.php
```

Запустить конкретный тестовый метод:
```bash
docker compose --env-file .env.test exec php-sda vendor/bin/phpunit --filter=testGetField
```

Запустить только Unit-тесты:
```bash
docker compose --env-file .env.test exec php-sda vendor/bin/phpunit tests/Unit/
```

### CI/CD testing

Тесты автоматически запускаются в GitHub Actions при создании pull request в ветку `dev`. В пайплайне выполняется:
1. Сборка Docker-контейнеров с тестовой конфигурацией
2. Запуск всех тестов с покрытием
3. Загрузка отчётов покрытия как артефактов

Полную конфигурацию CI/CD смотрите в `.github/workflows/tests.yml`.

---

## Отладка

Для отладки в IDE использовать удалённый интерпретатор из Docker-контейнера. Конфигурация Xdebug: `docker/configs-data/php.ini`.

Логи доступны через Makefile: `make logs-app`, `make logs-php`, `make logs-supervisor`.

---

## Git Workflow and Releases

### Branching Strategy
- `main` — production-ready code
- `stage` — Staging (pre-production)
- `dev` — интеграционная ветка разработки

### Release Process
1. Фичи разрабатываются в feature-ветках и вливаются в `dev` через pull request
2. Тесты автоматически запускаются на каждый PR в `dev` (см. `.github/workflows/tests.yml`)
3. Когда `dev` стабилен, создайте PR из `dev` → `stage`
4. После валидации `stage` создайте PR из `stage` → `main`
5. После мержа PR `stage` → `main` автоматически создаётся новый релиз с инкрементом версии (см. `.github/workflows/release.yml`)

### Automated Release Creation
- Триггерится при мерже PR из `stage` в `main`
- Автоматически увеличивается patch-версия (например, v1.0.0 → v1.0.1)
- Создаётся релиз GitHub с changelog
- Теги в формате семантического версионирования: `vMAJOR.MINOR.PATCH`

---

## License
MIT License — see [LICENSE](LICENSE) for details

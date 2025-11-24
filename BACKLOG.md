# Supplier Inventory Aggregator — Технический беклог

**Обновлено:** 2025-11-15
**Соответствие архитектуре:** ~75%
**Критических проблем:** 6
**Runtime ошибок:** 1

---

## 🔴 P0 - КРИТИЧЕСКИЕ ПРОБЛЕМЫ (Нужно исправить немедленно)

### 1. Runtime баг - Несоответствие конструктора DataSetCollection
**Статус:** 🔴 Критично
**Файл:** `src/Service/Mapper/Mapper.php:78`
**Тип:** Runtime Error

**Проблема:**
```php
$mappedDataCollection = new DataSetCollection($rules);  // ОШИБКА: конструктор не принимает параметры
```

**Влияние:**
- Приложение падает в runtime когда используется Mapper
- Конструктор DataSetCollection НЕ принимает никаких параметров

**Решение:**
```php
$mappedDataCollection = new DataSetCollection();
$mappedDataCollection->setRules($rules);
```

**Назначено:** Не назначено
**Оценка трудозатрат:** 5 минут

---

### 2. Нарушение Factory Pattern - Прямое создание хэндлеров в Aggregator
**Статус:** 🔴 Критично
**Файл:** `src/Service/Aggregator/Aggregator.php:93-98`
**Тип:** Нарушение архитектуры

**Проблема:**
Прямое создание хэндлеров в обход фабрик/DI для типов 2, 4, 6, 7:
```php
return match ($type_id) {
    2 => new CsvInputHandler($this->logger, $this->httpTransport),
    4 => new ExcelInputHandler($this->logger, $this->httpTransport),
    6 => new ExcelInputHandler($this->logger, null, $this->sftpTransportFactory->create(...)),
    7 => new CsvInputHandler($this->logger, null, $this->sftpTransportFactory->create(...)),
    // ...
};
```

**Влияние:**
- Нарушает архитектурный стандарт: "Never bypass factories for handler/transport creation"
- Несогласованность с типами 1, 3, 5, 8 которые используют DI/фабрики
- Делает тестирование невозможным (нельзя замокать хэндлеры)
- Нарушает авто-wiring паттерн Symfony

**Варианты решения:**

**Вариант A:** Создать фабрики (рекомендуется)
- Создать `CsvInputHandlerFactory` аналогично `RestApiHandlerFactory`
- Создать `ExcelInputHandlerFactory` аналогично `RestApiHandlerFactory`
- Инжектить фабрики в конструктор Aggregator
- Использовать фабрики в match выражении

**Вариант B:** Инжектить все варианты хэндлеров через конструктор
- Инжектить `CsvInputHandler` для HTTP транспорта
- Инжектить `ExcelInputHandler` для HTTP транспорта
- Создать отдельные экземпляры хэндлеров для SFTP вариантов
- Более многословный конструктор

**Назначено:** Не назначено
**Оценка трудозатрат:** 2-3 часа

---

### 3. Нарушение Factory Pattern - Прямое создание транспорта
**Статус:** 🔴 Критично
**Файл:** `src/Service/InputHandler/MorrisXmlSftpInputHandler.php:18`
**Тип:** Нарушение архитектуры

**Проблема:**
```php
public function __construct(LoggerInterface $logger, string $configPath)
{
    $this->logger = $logger;
    $this->sftpTransport = new SftpTransport($logger, $configPath, '19');  // Хардкод supplier_id!
}
```

**Влияние:**
- Обходит `SftpTransportFactory`
- Хардкод supplier_id '19' делает хэндлер неперсиспользуемым
- Несогласованность с тем как Aggregator создает SFTP транспорты (использует фабрику)

**Решение:**
```php
public function __construct(
    LoggerInterface $logger,
    SftpTransport $sftpTransport  // Инжектить через DI или фабрику
) {
    $this->logger = $logger;
    $this->sftpTransport = $sftpTransport;
}
```

Или инжектить `SftpTransportFactory` и создавать транспорт динамически на основе supplier_id из InputConfig.

**Назначено:** Не назначено
**Оценка трудозатрат:** 1 час

---

## 🟠 P1 - ВЫСОКИЙ ПРИОРИТЕТ (Нужно исправить в ближайшее время)

### 4. Нарушение DI - Ручное создание хэндлеров в GoogleDriveFolderHandler
**Статус:** 🟠 Высокий
**Файл:** `src/Service/InputHandler/GoogleDriveFolderHandler.php:50-55`
**Тип:** Нарушение архитектуры

**Проблема:**
```php
switch ($fileType) {
    case 'csv':
        $csvHandler = new CsvInputHandler($this->logger);  // Ручное создание!
        return $csvHandler->readData($tempPath, $range);
    case 'excel':
        $excelHandler = new ExcelInputHandler($this->logger);  // Ручное создание!
        return $excelHandler->readData($tempPath, $range);
}
```

**Влияние:**
- Сервисный слой вручную создает другие сервисы
- Невозможно замокать хэндлеры для тестирования
- Несогласованность с принципами DI

**Решение:**
```php
public function __construct(
    LoggerInterface $logger,
    Client $googleClient,
    CsvInputHandler $csvHandler,  // Инжектить
    ExcelInputHandler $excelHandler  // Инжектить
) {
    // ...
}

// Затем использовать:
return match ($fileType) {
    'csv' => $this->csvHandler->readData($tempPath, $range),
    'excel' => $this->excelHandler->readData($tempPath, $range),
    default => throw new \RuntimeException("Неподдерживаемый тип файла: $fileType")
};
```

**Назначено:** Не назначено
**Оценка трудозатрат:** 30 минут

---

### 5. Отсутствует валидация конфигурации - RestApiConfig
**Статус:** 🟠 Высокий
**Файл:** `src/Service/Config/RestApiConfig.php:7-13`
**Тип:** Нарушение архитектуры

**Проблема:**
Конструктор использует property promotion но НЕ выполняет валидацию:
```php
public function __construct(
    public readonly string $baseUri,
    public readonly array $auth,
    public readonly array $items,
    public readonly bool $verifySsl,
    public readonly array $transport = [],
) {}  // Нет валидации!
```

**Влияние:**
- Нарушает стандарт: "Validate in constructor, throw InvalidArgumentException"
- Невалидные данные (пустой baseUri, некорректный URL) проходят незаметно
- Несогласованность с `InputConfig` и `SubSource` которые правильно валидируют
- Валидация происходит позже в `RestApiHandlerFactory` вместо самого объекта конфигурации

**Решение:**
```php
public function __construct(
    public readonly string $baseUri,
    public readonly array $auth,
    public readonly array $items,
    public readonly bool $verifySsl,
    public readonly array $transport = [],
) {
    if (empty($this->baseUri)) {
        throw new \InvalidArgumentException('RestApiConfig: baseUri не может быть пустым');
    }

    if (!filter_var($this->baseUri, FILTER_VALIDATE_URL)) {
        throw new \InvalidArgumentException("RestApiConfig: baseUri должен быть валидным URL, получен: {$this->baseUri}");
    }

    if (empty($this->auth)) {
        throw new \InvalidArgumentException('RestApiConfig: массив auth не может быть пустым');
    }

    // Валидация обязательных полей auth в зависимости от типа
}
```

**Назначено:** Не назначено
**Оценка трудозатрат:** 30 минут

---

### 6. Нарушение Type Safety - Отсутствует тайпхинт
**Статус:** 🟠 Высокий
**Файл:** `src/Service/InputHandler/GoogleApiInputHandler.php:13`
**Тип:** Type Safety

**Проблема:**
```php
protected $service;  // Нет тайпхинта!
```

**Влияние:**
- Нарушает стандарт строгой типизации PHP 8.2+
- Снижает поддержку IDE и type safety
- Другие свойства в том же классе правильно типизированы

**Решение:**
```php
protected Sheets|Drive $service;
```

**Назначено:** Не назначено
**Оценка трудозатрат:** 5 минут

---

## 🟡 P2 - СРЕДНИЙ ПРИОРИТЕТ (Хорошо бы исправить)

### 7. Type Safety - Отсутствуют тайпхинты в DataRow
**Статус:** 🟡 Средний
**Файлы:**
- `src/Model/DataRow.php:19` - метод `getField()`
- `src/Model/DataRow.php:14` - метод `setField()`

**Проблема:**
```php
public function setField(string $name, $value): void  // $value без типа
public function getField(string $name)  // Отсутствует return type
```

**Решение:**
```php
public function setField(string $name, mixed $value): void
public function getField(string $name): mixed
```

**Назначено:** Не назначено
**Оценка трудозатрат:** 5 минут

---

### 8. Type Safety - Отсутствуют тайпхинты в трансформациях Mapper
**Статус:** 🟡 Средний
**Файл:** `src/Service/Mapper/Mapper.php:19-50`

**Проблема:**
Приватные методы трансформации не имеют тайпхинтов параметров:
```php
private function asinValidate($value): ?string
private function cleanString($value): string
private function cleanUPC($value): string
private function cleanInteger($value): int
private function cleanFloat($value): float
```

**Решение:**
```php
private function asinValidate(mixed $value): ?string
private function cleanString(mixed $value): string
private function cleanUPC(mixed $value): string
private function cleanInteger(mixed $value): int
private function cleanFloat(mixed $value): float
```

**Назначено:** Не назначено
**Оценка трудозатрат:** 10 минут

---

## ✅ Итоги по соответствию архитектуре

### Соответствующие области
- ✅ Разделение слоев (Модели не содержат бизнес-логику)
- ✅ Чистота моделей (нет зависимостей от сервисов/API)
- ✅ Реализация интерфейсов (все 8 InputHandlers реализуют InputHandlerInterface)
- ✅ Критичные файлы присутствуют (ConsumerCommand, Aggregator, все хэндлеры)
- ✅ Основные сервисы используют constructor DI
- ✅ InputConfig и SubSource валидируют в конструкторах
- ✅ Используются современные match выражения PHP 8.0+

### Несоответствующие области
- ❌ Нарушения Factory pattern (3 места)
- ❌ Нарушения type safety (6 мест)
- ❌ Отсутствует валидация конфигурации (RestApiConfig)
- ❌ Runtime баг (создание DataSetCollection)

---

## Технический долг (Задокументирован в CLAUDE.md)

Эти проблемы приемлемы сейчас, но должны быть исправлены в будущем рефакторинге:

1. `InputConfig::sourceDecode()` - Использование исключений для control flow (строка 54)
2. `InputConfig::isMultiSource()` - Должна проверять только по type_id, а не пытаться декодировать (строка 68)
3. `Aggregator::getHandlerByType()` - Добавить тип для multi-source сценария (строка 90)
4. Multi-source декодирование - Должно декодировать JSON в конструкторе InputConfig (строка 35)

---

## Метрики

| Метрика | Значение |
|---------|----------|
| Всего критичных файлов | 25 |
| Критических нарушений | 6 |
| Runtime багов | 1 |
| Соответствие архитектуре | ~75% |
| Соответствие Type Safety | ~85% |
| Соответствие Factory Pattern | 60% |

---

## Приоритетный порядок исправления

1. **Исправить P0-1** (баг DataSetCollection) - 5 мин - БЛОКИРУЕТ RUNTIME
2. **Исправить P0-3** (MorrisXml hardcoded supplier) - 1 час - ЛЕГКО
3. **Исправить P1-4** (GoogleDriveFolderHandler DI) - 30 мин - ЛЕГКО
4. **Исправить P1-6** (GoogleApiInputHandler type) - 5 мин - ЛЕГКО
5. **Исправить P1-5** (RestApiConfig validation) - 30 мин
6. **Исправить P0-2** (Aggregator factories) - 2-3 часа - САМОЕ СЛОЖНОЕ
7. **Исправить P2-7 и P2-8** (Type hints) - 15 мин всего

**Общая оценка трудозатрат:** ~5-6 часов

---

## Примечания

- Все исправления должны включать unit-тесты
- После рефакторинга фабрик обновить services.yaml при необходимости
- Обеспечить обратную совместимость с существующими Kafka сообщениями
- Протестировать со всеми 8 типами input handler после изменений

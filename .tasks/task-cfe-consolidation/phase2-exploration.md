# Phase 2: Исследование кодовой базы

## Конфигурация acclmcopy
- Тип: Бухгалтерия Предприятия КОРП.
- Единственный регистр бухгалтерии: `AccountingRegister.Хозрасчетный`.
- План счетов: `ChartOfAccounts.Хозрасчетный`, `ExtDimensionTypes = ChartOfCharacteristicTypes.ВидыСубконтоХозрасчетные`, `MaxExtDimensionCount = 3`.

## Субконто
`ChartOfCharacteristicTypes.ВидыСубконтоХозрасчетные` — составной тип, включает множество `CatalogRef.*`, `DocumentRef.*`, `EnumRef.*`.
Для задачи отобраны только `CatalogRef.*` (35 справочников, включая один `Удалить*`, который исключён).

## Существующие планы обмена
В конфигурации присутствуют типовые планы обмена: `Полный`, `ПоОрганизации`, `СинхронизацияДанныхЧерезУниверсальныйФормат` и др.
Структура плана обмена (на примере `ExchangePlans/Полный.xml`):
- Свойство `DistributedInfoBase` (true для РИБ).
- Реквизит `РегистрироватьИзменения` (тип Boolean) — типовой паттерн.
- Состав хранится в `ExchangePlans/<Имя>/Ext/Content.xml` в формате `ExchangePlanContent` с элементами `<Item><Metadata>...</Metadata><AutoRecord>...</AutoRecord></Item>`.

## Извлечённый состав (object-list.json)
- Документов: **117** (с движениями по Хозрасчетному, без `Удалить*`).
- Справочников: **77** (объединение субконто + реквизиты, без `Удалить*`).
  - из субконто: 35 (34 после исключения `Удалить*`).
  - из реквизитов документов: 70.

## Ключевые файлы
- `e:\1C\AY\acclmcopy\AccountingRegisters\Хозрасчетный.xml`
- `e:\1C\AY\acclmcopy\ChartsOfAccounts\Хозрасчетный.xml`
- `e:\1C\AY\acclmcopy\ChartsOfCharacteristicTypes\ВидыСубконтоХозрасчетные.xml`
- `e:\1C\AY\acclmcopy\ExchangePlans\Полный.xml` (+ `Полный/Ext/Content.xml`) — образец структуры.

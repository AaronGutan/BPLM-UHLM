# Диагностика ошибки загрузки CFE (2026-07-15)

## Симптом
`config load-config-from-files` → `ConfigFilesError` / **Ошибка преобразования данных XML** (прогресс ~1%)

## Причины (накопительно)

1. ~~Dump format 2.17 vs 2.20~~ — исправлено.
2. ~~`ConfigDumpInfo.xml` с namespace `xcf/predef`~~ — удалён.
3. **Актуально:** в заимствованных объектах стояли `ExtendedConfigurationObject` с UUID из **БП** (скопированы из `acclmcopy-cfe-consolidation`). При `KeepMappingToExtendedConfigurationObjectsByIDs=true` платформа ищет эти UUID в конфигурации **УХ** и падает при разборе.
4. В плане обмена тип реквизитов `РежимВыгрузки*` задан через `v8:TypeId` перечисления из БП (`6e70f791-…`) — в УХ TypeId другой. Заменено на `cfg:EnumRef.РежимыВыгрузкиОбъектовОбмена`.

## Исправление (v11)

- `Languages/Русский.xml`, `CommonModules/ОбменДаннымиПереопределяемый.xml`, `CommandGroups/СинхронизацияДанных.xml`, все `CommonCommands/*` — **без** `ExtendedConfigurationObject` (как в EMS: сопоставление по имени).
- Общий модуль: `PropertyState Module=Extended` (как EMS).
- План `Консолидация`: TypeId → EnumRef.

## Перед повторной сборкой

1. Запустить сборку с **-RecreateExtension** (удаляет stub `КонсолидацияУХ` с `purpose=customization` / пустым hash).
2. Расширение **Consolidate** в той же ИБ лучше временно снять, если мешает.
3. Задача VS Code / `cfe-build.ps1` для `ICORUHM/uh-cfe-consolidation`.

## Если снова ошибка

Бинарный поиск: в `Configuration.xml` оставить только `Language` + `Role`, загрузить; затем добавлять `CommonModule` → `ExchangePlan` → команды. Бэкап текущего полного состава:
`.tasks/task-cfe-consolidation-uh/_load-bisect-backup/`

# Задача: CFE КонсолидацияУХ (приёмник)

Расширение: `ICORUHM/uh-cfe-consolidation/`
Конфигурация: `КонсолидацияУХ`, префикс `CncdUH_`
База-приёмник: `ICORU_DEV` (сервер `DNA-DEVAPPS-1S0`, id реестра `uh-lm`)
Контрагент (источник): `acclmcopy-cfe-consolidation/` (`Consd_`), задача `.tasks/task-cfe-consolidation/`

## Артефакты

| Файл | Содержание |
|------|------------|
| [architecture.md](architecture.md) | Полный архитектурный проект |
| [phase0-complexity.md](phase0-complexity.md) | Оценка сложности |
| [phase1-requirements.md](phase1-requirements.md) | Требования |

## Текущий подход

План обмена и форму узла создаёте **в конфигураторе**; логика модулей — из `modules-to-paste/`.

См. [configurator-checklist.md](configurator-checklist.md).

В XML сейчас только каркас: язык, роль, `ОбменДаннымиПереопределяемый` (`&После("ПолучитьПланыОбмена")`).

## Кратко

Классический обмен по плану `Консолидация` (PVD), загрузка БП→УХ.
Типовой `ОбменДаннымиБПУХ` (XDTO) не используется. На УХ — `AutoRecord=Deny`.

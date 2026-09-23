# StepperMotorController

TMC5160A + STM32 tabanlı step motor sürücü sistemi. Uzun vadede 6 eksenli robot kol kontrolcüsü: 1 güç dağıtım kartı, 1 ana kontrol kartı, 6 sürücü kartı.

## Kart durumu

| Kart | Klasör | Revizyon | Aşama |
|---|---|---|---|
| Güç kartı | `hardware/power` | Rev A | Şematik |
| Sürücü kartı | `hardware/driver` | Rev A | Şematik |
| Firmware | `firmware` | – | Başlamadı |

Takip: [GitHub Project](https://github.com/users/efebasol/projects/12)

## Klasör yapısı

```
hardware/
  power/     KiCad projesi – güç kartı (48V giriş, brake chopper, 24V/5V buck, 3V3 LDO)
  driver/    KiCad projesi – TMC5160 + MOSFET sürücü kartı
  lib/       Ortak kütüphane: symbols/, footprints/, 3dmodels/
firmware/    STM32CubeIDE projesi
docs/        Hesaplar, kararlar, notlar
ci/          CI script'leri (ERC/DRC, çıktılar, görsel diff)
```

Kütüphaneler proje içinden okunur (`${KIPRJMOD}/../lib/...`), başka bilgisayarda da kırılmadan açılır.

## Kurallar

- **Commit mesajı:** `hw(power): ...`, `hw(driver): ...`, `fw(encoder): ...`, `docs: ...`, `ci: ...`
  Issue kapatmak için mesaja `closes #NN` ekle.
- **Commit'ten önce** KiCad'de kaydet ve kapat.
- **Siparişe giden revizyon dondurulur:** tag (`power-rev-a`) + GitHub Release (Gerber, BOM, CPL, şematik PDF). Sonraki değişiklikler Rev B'ye.
- **Branch:** donanım `main` üzerinde; denemeler `experiment/...`, firmware özellikleri `feature/...`.
- Datasheet, token, anahtar dosyası commit'lenmez.

## CI

- **Hardware CI** – her push'ta ERC, DRC, şematik PDF, BOM, Gerber, CPL. Çıktılar Actions sekmesinde artifact olarak.
  Layout bitince `.github/workflows/hardware-ci.yml` içinde `STRICT: "1"` yap → hatada ✗.
- **Visual Diff** – değişen şematik/PCB'nin önce | sonra | fark görüntüsü. Elle çalıştırıp herhangi bir tag/commit ile de karşılaştırabilirsin.

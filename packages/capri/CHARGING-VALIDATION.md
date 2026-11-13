# Moto G10 Power XT2127-4: PMI632 charging validation

Current status: the Power variant is selected by its device tree and
the controller is **enabled by default without charging kernel parameters**.
Its charging-control path has been compiled but not yet validated charging
a real battery. Earlier RAMUI images used `charging=0` and did **not**
enable charging; those historical observations are not a certification.

## Source references

- Experimental: `drivers/power/supply/capri-pmi632-battery.c` in the pinned
  `michaelmcallister/linux-motorola-capri` kernel, plus the Nix kernel patches.
- Stock: local LineageOS Motorola SM6225 kernel's
  `drivers/power/supply/qcom/qpnp-smb5.c`, `smb5-lib.c`, `smb5-reg.h`,
  `qg-reg.h`, `bengal-capri-charge-6000-overlay.dtsi`, and
  `qg-batterydata-atl4864356_5640mAh.dtsi`.
- Live references were read with root ADB from stock Android through
  `ideapad`. No hardware register writes or charger-policy changes.

## Verified offline or on stock Android

| Item | Evidence / result |
| --- | --- |
| Board identity | Live DT `qcom,board-id` bytes `00 00 05 00 00 00 b2 00` = `<0x500 0xb200>`, matching the Power DTS |
| Pack identity | Live BMS: `ATL4864356_5640mAh_averaged_MasterSlave_Oct14th2020`, matching the stock 6000 overlay |
| Factory config | 4.45 V float limit; 3 A **factory maximum**, 290 mA charge termination; pack NTC 10 kΩ, beta 3435 |
| Stock reference | Reported full capacity 6,106 mAh; battery temperature about 26.7–27.8 °C; battery/BMS current signs opposite; good health |
| QG registers | `QG_STATUS1=0x08`, last voltage `0xc0`, last current `0xc2` match stock `qg-reg.h` |
| Charger enable | `0x1042`, bit 0, matches stock `CHARGING_ENABLE_CMD_REG` |
| Charge current | `0x1061`, 50 mA/step, 0–3 A on PMI632 |
| Float voltage | `0x1070`, 10 mV/step from 3.60 V on PMI632 |
| USB input limit | `0x1370`, 50 mA/step on PMI632 |
| USB plug indicator | `0x1310`, bit 4, matches stock `USBIN_PLUGIN_RT_STS_BIT` |
| Thermistor channel | DT `0x2a` = `ADC5_BAT_THERM_30K_PU`; verified in RAMUI at 429.044 mV → ~28.16 °C, compared with `capri-battery/temp=28.2 °C`; range and refresh still unverified |
| Separate charger policy | The Power model skips JK50 charger initialization. Earlier RAMUI images were locked out; the current NixOS Power controller is a distinct opt-in with hardware readback checks. |
| Thermistor refresh | The previously separate 0003 change now lives in `0001-kernel-capri-power-charging.patch`; it refreshes the thermistor each telemetry sample. |

The vendor's `fcc1-temp-lut` has 6,106 mAh at 25 °C, matching Android's
reported `charge_full`; our DTS has a nominal 6,000 mAh. The 25 °C OCV
table is only an estimate and **not** stock Qualcomm fuel-gauge calibration.
No capacity value was changed in this audit.

## Live RAMUI read-only battery telemetry (2026-11-13)

A previously tested RAM-only image,
`capri-initfs-output/boot-ramui-qmi-services-v7.img` (SHA-256
`084a716bde925b83cabbf500143d2ec42aae24a0d2e1e804cd9cf1405c0d20dd`),
was booted temporarily using `fastboot boot` on the XT2127-4, through
`ideapad`. This image uses the **pre-0003** built-in 7.2.9-capri battery
driver. It sets `capri_pmi632_battery.charging=0` and **does not test the
new telemetry refresh patch**.

- Stock Android immediately before boot: battery level 100%, temperature
  28.1 °C, voltage approximately 4.411 V, current 0 µA (full pack).
- RAMUI reported `capri-battery`: 98%, 28.2 °C, health `Good`,
  `Not charging`, `inhibit-charge`, and `capri-usb/online=1`.
- Three RAMUI samples about five seconds apart: 4,409,890 µV,
  4,410,669 µV, and 4,411,252 µV; current was 0 µA on all three, and
  reported temperature stayed 28.2 °C.
- Direct PMI632 ADC5 readings: `in_voltage_batt_therm_30k_input=429044`
  (429.044 mV) and `in_voltage_vref_1p25_input=1250086` (1.250086 V).
  The experimental driver's 30 kΩ lookup table interpolates 429.044 mV
  to about **28.16 °C**, in agreement with reported **28.2 °C**.
  This confirms a plausible channel and conversion at one temperature,
  **not** across the full safe operating range.
- Kernel log confirmed `Moto G10 Power SKU5: battery telemetry only,
  charging locked out`. No battery-sample error was observed in the
  inspected battery-related kernel log tail.
- Host `ideapad` NetworkManager initially removed the temporary
  `172.16.42.2/24` USB Ethernet address while attempting DHCP. Temporarily
  marking that interface unmanaged and restoring its address fixed the
  diagnostic connection; it was a host network issue, not a phone reset.
- RAMUI was rebooted to Android after the tests. ADB again reported the
  stock 4.19.325 kernel and stock battery service (charging, good health).
  The diagnostic USB interface disappeared from the host.

**Interpretation:** Battery presence, USB-online indication, thermistor
voltage-to-temperature conversion near room temperature, and voltage
reporting agree with stock Android at a gross level. Current-direction and
scale **cannot be validated** from zero-current samples; use the patched
kernel and independently measured varying load before drawing conclusions.
The RAMUI 98% vs Android 100% difference reinforces that the simplified
25 °C OCV fuel gauge is not calibrated to the stock implementation.
This test did **not** enable charging, provoke thermal faults, exercise
charge termination, or verify watchdog shutdown.

## Rebuilt telemetry-kernel RAMUI test (2026-11-13)

The temperature-refresh patch `0003-kernel-capri-power-telemetry-safety.patch`
was applied to the non-Git `capri-build-src` workspace. Its
`drivers/power/supply/capri-pmi632-battery.c` matched the separate audited
`michael-capri-kernel` source byte for byte. All **20** offline source
consistency checks passed. The ARM64 `Image` compiled and linked successfully
with the existing Power `out-power/.config`.

A distinct RAM-only test boot image was generated by
`capri-build-tools/build-power-telemetry-ramui.py`, reusing the **byte-identical**
known-good v7 initramfs. The builder verified Android header v3, unchanged
`capri_pmi632_battery.charging=0` boot arguments, and a distinct rebuilt kernel.

| Output | SHA-256 |
| --- | --- |
| Rebuilt raw `out-power/arch/arm64/boot/Image` | `a300983996b8f0aafafcf0840a7c95cb4013f2d3247c929f5ce05693b6e3a8e0` |
| New wrapped `Image.capri-power-telemetry` | `19032734985d6b1dfe1adbb4d8029bdd6b2c46972e49c3c4fc1db94114f0fda2` |
| New `boot-ramui-power-telemetry.img` | `3aa7b2cdbeac10426ea1fe6e22ee9829970e0674bbbabb4498af1b55bc3dc841` |
| Unchanged RAMUI v7 ramdisk | `29adda0cf7d85066ad302f95450593c787611c247b39ba32f86f2488dedd8b72` |

The new image was transferred to `ideapad:/tmp/boot-ramui-power-telemetry.img`
with a matching SHA-256. The XT2127-4 bootloader accepted temporary
`fastboot boot` (`Sending OKAY`, `Booting OKAY`) without flashing. RAMUI
reported **Linux 7.2.9-capri #2**, built November 13, confirming the new kernel.

Direct USB ECM `172.16.42.1` diagnostics were reachable after temporarily
making `ideapad`'s USB interface unmanaged and assigning `172.16.42.2/24`.
The experimental driver reported battery present, USB online, **Good** health,
`Not charging`, `inhibit-charge`, approximately **99%** capacity, and
`27.2 °C`. Six read-only samples, 6 seconds apart:

| Sample | Battery temp (°C) | Thermistor ADC (mV) | Voltage (V) | Current (mA) |
| --- | ---: | ---: | ---: | ---: |
| 1 | 27.2 | 441.890 | 4.423125 | 0 |
| 2 | 27.2 | 441.825 | 4.423515 | 0 |
| 3 | 27.2 | 441.825 | 4.423320 | 0 |
| 4 | 27.2 | 441.565 | 4.423320 | 0 |
| 5 | 27.2 | 441.760 | 4.423125 | 0 |
| 6 | 27.2 | 441.630 | 4.423904 | 0 |

All measured ADC values are consistent with the reported 27.2 °C near room
temperature. The temperature display did not change during the observation,
so this run **cannot independently demonstrate dynamic refresh**; the source
and compiled binary include the fix. The kernel log confirmed
`Moto G10 Power SKU5: battery telemetry only, charging locked out`, with no
`Battery sample unavailable` messages in the inspected log. Zero-current
samples still cannot establish current sign or scale.

After tests, the RAMUI shell executed `reboot -f`. ADB verified Android
`sys.boot_completed=1`, stock kernel `4.19.325`, and the stock battery
service reporting **Good** health, 100% battery and **charging**. The device
was left on stock Android.

**This was not a charging-safety test**: no thermal extremes, watchdog fault
injection, termination tests, external voltage/current instrumentation,
PMIC write, persistent partition modification or charging enablement. The
Power charging lockout remains required.

## Charging architecture comparison and simplification (2026-11-13)

Native NixOS explicitly passes `capri_pmi632_battery.charging=0`, and
the Power driver disables charging at probe, skips the regular G10's
`capri_charger_init()`, and rejects userspace requests to switch to
`AUTO`. The telemetry sampler remains at five-second intervals for
battery reporting; **this polling is not a charger-control strategy**.

The earlier experimental `0004-kernel-capri-power-lockout-readback.patch`
was removed. It merely wrote/checked the charging-disable command on every
poll and could not establish charging safety. The source was restored to the
boot-tested `0003` telemetry version before development of a **different**
`0004-kernel-capri-power-charger-events.patch`. The old readback patch
was never tested on the phone.

Comparison references:

- Mainline Linux `drivers/power/supply/qcom_smbx.c` configures the
  supported charger hardware at initialization and handles USB events,
  charger errors and watchdog bark via IRQs; it is **not** directly
  equivalent to PMI632 without per-PMIC support.
- Qualcomm downstream `drivers/power/supply/qcom/qpnp-smb5.c` supports
  `PMI632_SUBTYPE`, performs PMIC-specific initialization and uses
  Qualcomm SMB5 charging policy, event handling and thermal mitigation.
- SMB5 mainline development patches in August 2026 explicitly
  distinguish PMIC registers and electrical ranges and verify charger
  limits before enabling charging.

**Next engineering work** is to implement or port the appropriate PMI632
charger state machine (including cable detection, power path, JEITA,
watchdog bark/bite, safety timer, termination and suspend handling).
It then needs a separately instrumented hardware-validation procedure.
Repeatedly writing a charging-disable register does not substitute for
this work. The Power charging lockout remains in place.


## PMI632 charger event and measurement groundwork (2026-11-13)

Patch `0004-kernel-capri-power-charger-events.patch` now adds the following
**non-charging** integration to the Capri Power kernel:

- Five named PMI632 interrupts: charger error (0x10:0), charge-state
  change (0x10:1), battery temperature (0x12:0), USB insertion/removal
  (0x13:4), and watchdog bark (0x16:1). These were copied from Motorola's
  stock `pmi632.dtsi`. They trigger immediate resampling and
  `power_supply_changed()` notification; the IRQ handler does **not**
  write PMIC registers, enable charging or pet a watchdog.
- Additional ADC5 inputs for USB current sense (channel 0x07, 1:1) and
  USB voltage (channel 0x08, 1:16) on SKU5 only. These are available for
  future read-only input power measurements; current scaling and accuracy
  are not yet validated on this device.
- Probe-time verification of the Power pack's device-tree profile:
  6,000 mAh nominal, 4.45 V maximum, 3 A **factory limit**, and 290 mA
  termination setting. The factory current maximum is **not** a safe
  starting test current or a negotiated USB current.
- Power remains charge-disabled at probe and cannot switch to AUTO through
  userspace. The independent NixOS boot argument remains `charging=0`.
  The five-second work loop remains for fuel-gauge telemetry, not for
  repetitive charger-disable writes.

The Power DTB and kernel were built and the Power DTB embedded into the
kernel's generated `capri-dtb.h` (64,576 bytes). A subsequent ARM64
`Image` rebuild succeeded, with `capri-fdt.o` recompiled to incorporate
the new device tree. Offline source checks and the Capri Nix contract pass.
The compiled image was packaged without flashing into the distinct
`capri-initfs-output/boot-ramui-power-charger-events.img` (SHA-256
`ab3b7c569701185b473996798f94cc2164bb10e9058d91832cccde7f6b985e6f`).
The package verifier confirmed header v3, the unchanged v7 initramfs
(SHA-256 `29adda0cf7d85066ad302f95450593c787611c247b39ba32f86f2488dedd8b72`),
a new kernel and preserved `capri_pmi632_battery.charging=0`. The previously
boot-tested RAMUI images were not modified.

**Current status:** the IRQ-aware kernel was subsequently booted with
patch 0005 and worked with its USB monitoring. This establishes that the
IRQ resources did not prevent probing, **not** that thermal, watchdog or
charger-fault interrupts have been exercised. This is still not a full
PMI632 SMB5 charging port; do not enable charging from this result.

## PMI632 input source and ADC runtime validation (2026-11-13)

Patch `0005-kernel-capri-power-input-monitor.patch` extends the earlier
event-only support with a **read-only** PMI632 USB-input view. The Power
battery driver now reads APSD completion/result (0x1307/0x1308), valid USB
power-path status (0x110b), AICL status (0x110a), effective ICL status
(0x1107, PMI632-specific 50 mA steps), and ADC5 USB input voltage/current.
The ADC current-sense scaling follows the stock **0.2 V/A** input:
1 µV at ADC5 corresponds to 5 µA of USB current. Unknown/combined
APSD codes remain `Unknown`, not guessed as SDP or permission to draw
current. No power-limit or charging register is programmed.

`/sys/class/power_supply/capri-usb/` now exposes `online`,
`usb_type`, `voltage_now`, `current_now`, and
`input_current_limit`. On Power, these are reported separately from
the QGauge battery-current estimate. They do **not** expose verified
charge-controller policy, thermal state, or source-negotiation limits.

A distinct image `capri-initfs-output/boot-ramui-power-input-monitor.img`
(SHA-256
`af227ee3f95023ebcac145313f22d513f484d10d21c67b3da3b032724484550e`)
was built after the Power DTB was embedded and the ARM64 kernel linked.
It uses the byte-identical known-good v7 initramfs and retains
`capri_pmi632_battery.charging=0`. The `ideapad` host copy was
checksum-verified before temporary `fastboot boot` (no flash).
The handset reported Linux **7.2.9-capri #8** and the expected
charger-disabled kernel message.

Live read-only USB-gadget diagnostic samples, approximately six seconds apart:

| Sample | USB voltage (V) | USB input (mA) | Effective ICL (mA) | APSD source | Battery temp (°C) |
| --- | ---: | ---: | ---: | --- | ---: |
| Initial | 5.031472 | 233.560 | 500 | SDP | 26.1 |
| 1 | 5.033552 | 216.695 | 500 | SDP | 26.1 |
| 2 | 5.033552 | 228.695 | 500 | SDP | 26.1 |
| 3 | 5.035632 | 171.280 | 500 | SDP | 26.1 |
| 4 | 5.035632 | 213.450 | 500 | SDP | 26.1 |

All sampled RAMUI battery currents were **0 µA**, with healthy status
and `Not charging` / `inhibit-charge` throughout. The inspected
kernel log had no `Battery sample unavailable`, USB input-sample
errors, or call traces. This provides plausible *USB-side* current and
input-voltage measurements, but **does not calibrate the battery QGauge
current sign/magnitude**, nor establish safety or charging behavior.

RAMUI was rebooted back to stock Android, and ADB confirmed
`sys.boot_completed=1`, stock Linux 4.19.325, battery `Charging`,
and health `Good`. Read-only stock Android `su` sysfs properties
reported `main/constant_charge_current_max=3000000` µA,
`main/current_max=500000` µA,
`main/input_current_settled=500000` µA,
`main/input_voltage_settled=5000000` µV, and
`main/voltage_max=4450000` µV. In that stock charge state,
`battery/current_now=+286712` µA and
`bms/current_now=-289917` µA (opposite Android-side sign
conventions). These are reference readings from **stock Android**,
not from our Linux driver, and values vary with the charge state.

The new `tests/check-input-monitor.py`, existing offline charging
checks, Capri Nix contract, and ARM64 kernel/DTB compile passed.
**Charging remained disabled under experimental Linux. The existing
probe-time charger-disable command was retained; the new input monitor
performed no PMIC writes, and no phone partition was flashed.**
Next: implement the actual PMI632 charging-policy and protection state
machine and validate it with independent current/temperature
measurements before any enablement.

## Read-only PMI632 charge-policy audit, patch 0006 (2026-11-13)

`0006-kernel-capri-power-shadow-policy.patch` adds
`drivers/power/supply/capri-pmi632-policy.h`, a pure C, fail-closed
decision function, and a Power-only, read-only sysfs report:

```sh
find /sys/devices -name power_charge_audit
cat /sys/devices/platform/soc@0/1c40000.spmi/spmi-0/0-02/1c40000.spmi:pmic@2:battery-monitor@4800/power_charge_audit
```

The report shows `mode=locked-out`, the bitmask from
`enum capri_power_blocker`, battery/USB telemetry and actual PMI632
register readbacks: charging command 0x1042, FCC 0x1061, float voltage
0x1070, JEITA config 0x1090, fast-charge safety timer 0x10a2,
watchdog 0x1651/0x1653, and signed ADC termination comparator 0x1067
with 0x10c0 mode selection. **No code in the audit writes registers,
pets the watchdog, changes source limits or enables charging.** All
Power decisions include an unconditional `LOCKOUT` plus independent
`JEITA_UNVERIFIED`, `WDOG_UNVERIFIED`, `ITERM_UNVERIFIED`,
`QG_UNCALIBRATED` and `SOURCE_POLICY` blockers. A failed PMIC
register read adds further blockers. The native
`tests/check-charge-policy.c` exercises 21 cases, including faults,
read failures and conditions that could otherwise allow charging.
The ARM64 kernel build and Nix contract passed.

A temporary, never-flashed RAMUI boot of the first 0006 build confirmed
`power_charge_audit` appears on the device with `hw_valid=1` and
`read_error=0`. The observed USB source was SDP, effective ICL
500 mA, input ~5.037 V / ~233 mA, battery temperature 26.2°C and
battery `Not charging`. PMIC readback:

| Register / decoded value | Observed |
| --- | --- |
| Charging command | `0x00` (disabled) |
| FCC / FV | 2,000,000 µA / 4,450,000 µV |
| Safety timer | `0x02` (stock reference sets 768-minute code) |
| JEITA compensation config | `0x1b` (not evidence of live JEITA protections) |
| Watchdog cfg / timeout | `0x62` / `0x8c` |
| ITERM mode / upper comparator | `0x04` / approximately −101,779 µA |

The first prototype audit compared the watchdog timeout to the old
JK50 setup and the ITERM comparator to **290 mA**, producing two
misleading configuration blockers. A separate read-only stock Android
`/sys/class/power_supply/battery/charge_term_current` query returned
**−102 mA**, matching our comparator. Motorola's
`qcom,iterm-ma = <290>` config is parsed into `mmi.chrg_iterm`
in `smb5-lib.c`; it is **not** the value returned by
`smblib_get_prop_batt_iterm()`, which reads register 0x1067 and
scales a signed 16-bit PMI632 ADC comparator by 5000/32767 mA.

The final 0006 source consequently checks the comparator's ADC mode
and plausible magnitude separately from the still-unverified
termination behavior, and checks watchdog bark enable/charging-disable
on bite without assuming JK50 timeout bytes. It **does not**
claim watchdog bite, JEITA, thermal shutdown, end-of-charge or source
negotiation have been validated. The corrected ARM64 source was rebuilt
and packaged as the separate image
`capri-initfs-output/boot-ramui-power-shadow-policy-final.img`
(SHA-256 `3caaea227ef31cf71770512a01353a10f24a89d3a40fc0ca727a0c7b65e6e1a5`).
Its ramdisk is unchanged and its boot arguments still include
`capri_pmi632_battery.charging=0`. The image was temporarily booted
with `fastboot boot` (never flashed). On actual hardware, the revised
audit returned `mode=locked-out blockers=0x003e0001 hw_valid=1
read_error=0`, with `charge_cmd=0x00`, SDP input 500 mA, USB
5.0325 V / 218 mA, battery 26.8 °C and `Not charging`.
The blockers now represent only the explicit Power lockout and
independent unvalidated JEITA, watchdog, termination, QGauge and USB
source policy; no dynamic register-configuration mismatch remained.
The sampled dmesg showed no battery errors or call traces.

The phone was returned to stock Android; ADB confirmed
`sys.boot_completed=1`, Linux 4.19.325, battery `Charging` and
`Good` health. No boot/vendor/persist/NV partitions were written.

## Capri Power shadow charge controller, patch 0007 (2026-11-13)

`0007-kernel-capri-power-controller-shadow.patch` adds
`drivers/power/supply/capri-pmi632-controller.h`: a pure C controller,
called after the current read-only PMI632 register audit. The existing
`power_charge_audit` sysfs report now includes
`shadow_zone`, `shadow_reasons`, `shadow_source_candidate`,
`shadow_icl_ua`, `shadow_fcc_ua`, `shadow_fv_uv`,
`shadow_charging_permitted` and `watchdog_bark_seen`.

The controller tracks Motorola's **0/10/15/45/60 °C** zone
boundaries but only produces a nominal test-current candidate for
**15–40 °C**, a stricter-than-stock temperature window pending
real hardware tests. For the *observed* SDP host connection it requires
valid USB/ADC readings, the USB power path active, AICL complete,
4.5–5.5 V input, settled input limit ≤500 mA, valid battery gauge
and healthy battery below the relevant voltage ceiling. Three
successive good samples are required after USB connection or a
disruption. The tentative dry-run values are **500 mA USB input**,
**200 mA battery FCC** and **4.45 V FV** in the central temperature
range, not commands applied to the PMIC. They are not proof that
combined system load and charger power stay under SDP limits.

Watchdog-bark IRQs are recorded and latched until reboot.
Charger faults likewise latch rather than permitting automatic
retries; a source reconnect cannot clear them. A 768-minute
session timeout mirrors Motorola's SMB5 safety-timer selection.
The three-sample taper/termination counter **requires** explicitly
calibrated charging current *while charging is active*. On the
experimental kernel, `charge_current_calibrated=false` and
`charging_active=false` unconditionally, so the measured 0 µA
battery current cannot incorrectly count as termination.

**The hardware Power charging lockout remains separate and mandatory:**
the driver still skips charging initialization, rejects AUTO,
uses `capri_pmi632_battery.charging=0`, and the new pure controller's
`charging_permitted` output is always false. There are no charger
register writes in 0007; it is **not** a working replacement for
Motorola's charge-control driver. JEITA hardware cutoffs, watchdog
bite, charger timer expiry, termination under genuine current and
Type-C input negotiation remain untested on the experimental Linux
kernel.

Verification completed:

- Native `check-controller.c`: **572 deterministic scenarios**
  (including the temperature boundary sweep) and **50,000 generated
  fail-closed fault inputs**.
- `check-controller-wiring.py`: checks that patch 0007 introduced
  no PMIC writes, no charge-enable path and no replacement
  for the uncalibrated QGauge safety gate.
- ARM64 Linux 7.2.9-capri `Image` compile/link, prior battery
  telemetry/IRQ/input-monitor checks, patch applicability and
  Capri Nix evaluation: passed.
- Packaged isolated RAM-only image
  `capri-initfs-output/boot-ramui-power-controller-shadow.img`;
  SHA-256
  `dbfd76159fda3ef4553ea07c89217fc1007c53075a8470b414d63d90242a7265`.
  The previously verified v7 initramfs is unchanged, the updated
  kernel is included and the kernel command line retains charging=0.
  The file was copied to `ideapad:/tmp/` and its SHA-256 checked.

**Runtime status:** The device-reboot/bootloader tool action was
blocked by the available safety controls. Therefore the 0007 RAMUI
image has **not** been boot-tested and no 0007 live sysfs output
has been collected. The previous 0006 audit was successfully
boot-tested, but its observations cannot validate the new controller.
The phone's stock Android partitions were not flashed or modified.

## Still unvalidated / blockers for enabling charging

1. **Experimental kernel hardware telemetry**: confirmed battery presence,
   USB detection, plausible thermistor readings near 27–28 °C, and voltage
   relative to the stock device. Still verify dynamic temperature changes,
   thermal sensor range, battery-current sign/magnitude with nonzero current,
   and gauge calibration. Zero-current samples cannot establish the scale.
2. **JEITA and thermal protection**: the custom driver uses 5/45 °C hard
   and 10/40 °C soft thresholds; stock Motorola has its own 0/10/15/45/60 °C
   mitigation zones and charger cooling logic. Register *addresses* match,
   but threshold data conversion, independence and hysteresis do not have
   live validation.
3. **Watchdog difference**: the custom 0x1653 bark/bite setup uses bite
   disables charging, but `WD_CFG (0x1651)` enables `BIT(1)` only; the stock
   driver also enables bark interrupt `BIT(6)` and handles watchdog events.
   It must be demonstrated that a stopped polling loop causes hardware
   charge shutdown and cannot leave charging active.
4. **Safety timer**: the custom driver does not explicitly program
   `CHGR_FAST_CHARGE_SAFETY_TIMER_CFG_REG (0x10a2)`; verify the actual
   reset state and required policy, not assumed defaults.
5. **Charge termination and recovery**: the custom termination conversion
   and thresholds are for the *regular G10* 100 mA configuration, while
   Power's stock profile specifies 290 mA. Confirm conversions, CV,
   precharge, recharge hysteresis, and behavior during suspend, thermal
   trips, USB disconnect, low battery, and driver errors.
6. **Type-C and input power**: validate source detection, negotiated
   current, AICL and USB current limiting. A descriptive 3 A factory limit
   does not authorize setting 3 A on an unknown source.
7. **Instrumented hardware validation**: require independent power/current
   measurements, temperature monitoring, and a recoverable test environment
   before allowing controlled charging. The phone is currently running
   stock Android, not the experimental kernel. Do not change PMIC registers
   just to test whether the lockout can be bypassed.

## Consolidated stock-initialized Power kernel (2026-11-13)

All seven historical Power charging patches (the old 0001 Power variant
plus 0003–0008) have been combined into the sole charging source patch:

`packages/capri/patches/0001-kernel-capri-power-charging.patch`

The separate `0002-kernel-capri-config-dependencies.patch` is a Kconfig
build fix, **not** a charging patch. Earlier numbered patch names in
this report refer to prior development stages, not files to apply now.

The combined patch was replayed against the pinned upstream Capri
kernel `232c314e8909dd77395b2c553e7dda2232e4a4cc` and verified
byte-for-byte against all seven modified source files. The resulting
Linux 7.2.9 ARM64 `Image` compiled and linked successfully.

The Power charging initializer now checks and preserves the PMIC
configuration previously **observed on this device**: 4.45 V float,
JEITA `0x1b`, watchdog `0x62/0x8c`, 768-minute safety timer
`0x02`, about −102 mA signed ITERM comparator, and at most 500 mA
USB input limit. It no longer writes custom JK50-style thermal
thresholds, watchdog timeouts, recharge settings, or ITERM values.
An unexpected default fails initialization while the charger remains
disabled. The only programmed battery charge-current setting is a
conservative **200 mA cap** for the verified 500 mA USB input; this
is **not** the Motorola factory fast-charge rate or permission to draw
3 A. Type-C/source and actual protection behavior still require
instrumented tests.

Native NixOS no longer supplies battery charging kernel parameters.
The Power driver is selected by `motorola,capri-power-battery` in the DT,
starts in AUTO with the normal built-in default-on `charging` policy,
and requires matching PMI632 safety readbacks before charging can run.
**No flash, reboot or live charging test was conducted for this
newly consolidated build.**

## Repeatable non-invasive checks

From `dotfiles/`, check the **single combined Power patch** against
the local patched source checkout (on a clean upstream checkout, use
`git apply --check` instead):

```sh
git -C ../capri-build-src apply --reverse --check \
  ../dotfiles/packages/capri/patches/0001-kernel-capri-power-charging.patch
python3 packages/capri/tests/check-telemetry.py \
  ../capri-build-src/drivers/power/supply/capri-pmi632-battery.c
python3 packages/capri/tests/check-charger-events.py \
  ../capri-build-src/drivers/power/supply/capri-pmi632-battery.c \
  ../capri-build-src/arch/arm64/boot/dts/qcom/capri-power-battery.dtsi
python3 packages/capri/tests/check-input-monitor.py \
  ../capri-build-src/drivers/power/supply/capri-pmi632-battery.c \
  ../capri-build-src/arch/arm64/boot/dts/qcom/capri-power-battery.dtsi
cc -std=c11 -Wall -Wextra -Werror \
  -I ../capri-build-src/drivers/power/supply \
  packages/capri/tests/check-charge-policy.c -o /tmp/capri-policy-test
/tmp/capri-policy-test
cc -std=c11 -O2 -Wall -Wextra -Werror \
  -I ../capri-build-src/drivers/power/supply \
  packages/capri/tests/check-controller.c -o /tmp/capri-controller-test
/tmp/capri-controller-test
python3 packages/capri/tests/check-controller-wiring.py
```

Check Nix formatting and evaluate the kernel derivation **without building**:

```sh
nixfmt --check packages/capri/kernel/default.nix
nix eval --impure --raw --expr \
  '(builtins.getFlake (toString ./. )).nixosConfigurations.capri.config.boot.kernelPackages.kernel.drvPath'
```

The separate `michael-capri-kernel` audit verifies the stock profile
references and the 0003 temperature refresh. Local `check-telemetry.py`
checks ADC interpolation and Power charger-disable invariants;
`check-charger-events.py` checks IRQ bindings and no PMIC writes from
its event handlers; `check-input-monitor.py` checks the USB input
source, scale, DT channels and read-only implementation. These
source/math checks do **not** validate hardware charging behavior.

The original source-only audit and first RAMUI v7 run made no kernel build.
The subsequent patched-kernel test **rebuilt Linux 7.2.9**, generated a
separate RAMUI image, and booted it temporarily with `fastboot boot`.
The handset was returned to fully booted stock Android. **No partitions were
flashed, no PMIC charging registers changed, and charging remained disabled
throughout RAMUI testing.**

## Power default-charge RAMUI startup investigation (2026-11-13)

The first image (`boot-ramui-power-default-charging.img`, SHA-256
`416d69b096e26d2fd531123c0ef5e47b7a2f8b8304c732a0c8e0d8e15f0859e8`)
booted Linux 7.2.9 **without charging kernel arguments**, but the Power
battery driver's PMIC setup rejected a register with `-EINVAL`. Neither
battery supply nor USB battery monitor registered; charging was not enabled.

Read-only SPMI regmap inspection located a genuine mismatch between the
phone's **configured** and **effective** input-current limits:
`USBIN_CURRENT_LIMIT_CFG (0x1370)=0x1e` (1.5 A configured) while
`ICL_STATUS (0x1107)=0x0a` (500 mA effective). Stock PMIC defaults
otherwise matched: FV `0x55` = 4.45 V, FCC `0x28` = 2 A, JEITA
`0x1b`, WD `0x62/0x8c`, timer `0x02`, signed ITERM `0xfd65`
(about −102 mA), and charger command `0x00` after the probe disable.

The original initializer incorrectly compared **raw programmed** ICL
to the effective 500 mA limit, rejecting OEM defaults. The corrected
initializer no longer treats dynamic source-current settings as static
PMIC prerequisites. The runtime charging policy still reads **effective
ICL_STATUS** every sample and requires no more than 500 mA, plus
battery/temperature/watchdog/source protection conditions, before enabling
charging. The OEM 1.5 A programmed input register remains unmodified.

The phone returned to stock Android with boot_completed=1, kernel
4.19.325. At test start the pack was **100% / 4.472 V**, above its
4.45 V float setting. Do not defeat the full-charge cutoff to force
battery charge current.

The revised ARM64 kernel compiled successfully, and a second isolated
RAMUI image (`boot-ramui-power-default-charging-aicl.img`, SHA-256
`64c8878fcca095856f0b75c9e7830eed67fbd19e07eef74ac22f770c1ab1835b`)
uses the same unchanged v7 RAMUI initramfs, with zero battery kernel
parameters. Runtime results follow after testing.

# jh-manual | Professional Transmission System

A high-fidelity, FiveM-native manual transmission resource designed to replace legacy .asi plugins. Built with a focus on **0.00ms optimization** and drivetrain physics simulation.

## 🚀 Performance Benchmarks
* **Idle:** 0.00ms (Thread sleeping)
* **Driving:** 0.01ms - 0.03ms (depending on physics frequency)
* **UI:** 0% CPU usage (NUI Offloaded)

## 🛠 Features
* **NUI Dashboard:** Real-time RPM monitoring with dynamic color scaling and redline pulsing.
* **Drivetrain Physics:**
    * **Engine Stalling:** Requires clutch/neutral at low speeds.
    * **Money Shifting:** High-RPM downshifts cause catastrophic engine damage.
    * **Launch Control:** Sequential 2-step anti-lag system with exhaust pops.
    * **Drivetrain Vibration:** Camera and controller haptics linked to engine load.
* **Framework Integration:** * Native support for `qb-core` and `ox_core` vehicle damage systems.
    * Standalone compatibility (Uses `RegisterKeyMapping`).

## ⌨️ Controls (Customizable in GTA Settings)
* **Shift Up:** `PAGEUP`
* **Shift Down:** `PAGEDOWN`
* **Clutch:** `LEFTSHIFT`
* **Restart Engine:** `INPUT_ENTER` (while stalled)

## 📦 Installation
1. Move `jh-manual` to your `[resources]` folder.
2. Ensure you have the latest `fxmanifest.lua`.
3. Add `ensure jh-manual` to your `server.cfg`.
4. *Optional:* Link `cl_utils.lua` to your server-side repair scripts.

---
*Created by Jonathan Hayes | JH Development Ecosystem*
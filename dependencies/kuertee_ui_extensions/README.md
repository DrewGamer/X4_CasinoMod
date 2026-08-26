# kuertee UI Extensions and HUD (Nexus Mod 552)

## Overview
Provides hooks and callback registration for X4: Foundations UI menus and custom HUD elements without conflicting with vanilla menu Lua files.

## Key APIs & Callbacks
- `Callbacks.Register("MenuName", "EventName", callbackFunction)`
- Used by X4 Casino Mod to cleanly attach custom UI overlays and interactable widgets to station lounges, bars, and gambling dens.

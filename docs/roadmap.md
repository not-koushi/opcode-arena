# Opcode Arena - Roadmap

## Current State

A functional local multiplayer 2D fighting prototype built using Win32 API and MASM.

Implemented:
- Two-player movement (WASD/Arrow keys)
- Collision detection using AABB hitboxes
- Attack and damage system
- Health Bars
- Win detection and restart
- Double-buffered rendering

---

## Planned Improvements

### 1. Arena Environment

Add a proper stage instead of an empty box.

**Planned:**
- Background rendering
- Static obstacles/blocks
- Movement paths around terrain
- Collision with arena objects

### 2. Match Tracking

Track performance across rounds.

**Planned:**
- Player 1 win counter
- Player 2 win counter
- Persistent score during session

### 3. Character Selection

Replace placeholder squares with characters.

**Planned:**
- Multiple selectable fighters
- Unique player appearance
- Pre-match selection screen

---

## Long Term Goal

Polish the project into a small complete local multiplayer game written entirely in x86 assembly.
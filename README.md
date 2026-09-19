# Xomm — Peer-to-Peer HD Video Conferencing

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![WebRTC](https://img.shields.io/badge/WebRTC-Full--Mesh%20P2P-333333?style=for-the-badge&logo=webrtc&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Cloud%20Firestore-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![License](https://img.shields.io/badge/License-Proprietary-red?style=for-the-badge)
![Platforms](https://img.shields.io/badge/Platforms-Windows%20%7C%20Android%20%7C%20Web-4CAF50?style=for-the-badge)

**A modern, cross-platform video conferencing application built with Flutter and WebRTC Full-Mesh P2P architecture, featuring zero-server-cost real-time audio/video streaming, host-controlled meetings, waiting room admission, and crystal-clear audio.**

</div>

---

## Table of Contents
1. [Overview](#overview)
2. [Architecture & How It Works](#architecture--how-it-works)
3. [Capacity & Operating Limits](#capacity--operating-limits)
4. [Audio Quality & Acoustic Engineering](#audio-quality--acoustic-engineering)
5. [Video & Screen Sharing Specifications](#video--screen-sharing-specifications)
6. [Security & Access Control](#security--access-control)
7. [Key Features](#key-features)
8. [Platform Support & Requirements](#platform-support--requirements)
9. [Build & Installation](#build--installation)

---

## Overview

**Xomm** is designed for ultra-low latency, decentralized video meetings across desktop and mobile devices. Unlike traditional video platforms that route all video and audio through costly central media servers (SFUs or MCUs), Xomm establishes **direct encrypted peer-to-peer (P2P) connections** between participants using WebRTC, with Google Cloud Firestore serving solely as the lightweight signaling and presence layer.

---

## Architecture & How It Works

```
                        ┌─────────────────────────────────┐
                        │   Google Cloud Firestore         │
                        │   (Signaling & Metadata Only)   │
                        └──────────────┬──────────────────┘
                                       │  SDP Offers / Answers
                                       │  ICE Candidates & Presence
                     ┌─────────────────┼─────────────────┐
                     ▼                 ▼                 ▼
             ┌───────────────┐ ┌───────────────┐ ┌───────────────┐
             │ Participant A │ │ Participant B │ │ Participant C │
             │  (Desktop/PC) │ │   (Mobile)    │ │ (Laptop/Web)  │
             └───────┬───────┘ └───────┬───────┘ └───────┬───────┘
                     │                 │                 │
                     │◄════════════════╪════════════════►│
                     │   Direct P2P Encrypted Audio/Video│
                     └─────────────────┴─────────────────┘
```

1. **Signaling Layer**: Cloud Firestore exchanges SDP (Session Description Protocol) offers, answers, and ICE candidates. No media payloads (audio, video, or screen streams) ever pass through Firebase or any central server.
2. **Media Layer**: Built on Google's native `libwebrtc` engine. Media flows directly from device to device over DTLS-SRTP encrypted UDP connections via Google STUN servers.
3. **Reactive State**: Meeting status, waiting room admissions, participants, and in-call chat update reactively in real time.

---

## Capacity & Operating Limits

Because Xomm uses a **Full-Mesh P2P** network topology, every participant sends and receives media directly to every other participant. Understanding this topology helps users and administrators plan room sizes and bandwidth expectations:

### 1. Mesh Scaling Mathematics
In a full-mesh topology of $N$ participants, each client maintains $(N - 1)$ upstream upload connections and $(N - 1)$ downstream download streams:

| Active Participants ($N$) | Total Peer Connections in Room | Streams Uploaded per Client | Streams Downloaded per Client |
| :---: | :---: | :---: | :---: |
| **2** (1-on-1 Call) | 1 | 1 | 1 |
| **3** | 3 | 2 | 2 |
| **4** | 6 | 3 | 3 |
| **6** | 15 | 5 | 5 |
| **8** | 28 | 7 | 7 |

### 2. Recommended Room Capacity
- **Optimal (Best Experience)**: **2 to 6 participants**. At this level, CPU utilization remains low, latency is minimal (< 50 ms), and standard residential Wi-Fi/4G connections can easily handle the simultaneous streams.
- **Supported Maximum**: **Up to 8–10 participants** on standard broadband connections (15+ Mbps symmetric upload/download).
- **Not Intended For**: Broadcast webinars or 50+ person meetings (which require centralized media relays like Selective Forwarding Units (SFUs)).

### 3. Bandwidth Guidelines
- **Per Peer Uplink**: ~1.0 – 1.5 Mbps (720p HD Video + 32 kbps Opus Voice).
- **Per Peer Downlink**: ~1.0 – 1.5 Mbps per remote video tile.
- **Audio-Only Fallback**: If network bandwidth drops, camera video can be muted, reducing bandwidth usage to just ~32 kbps per peer.

---

## Audio Quality & Acoustic Engineering

To prevent the feedback loops, ambient hum, and hollow echoes common in cross-device calls (such as Mobile ⇄ Laptop/Desktop), Xomm integrates a carrier-grade audio processing pipeline:

### 1. Opus SDP Voice Tuning
Every WebRTC SDP offer and answer is dynamically inspected and tuned with voice-specific parameters:
```
minptime=10; ptime=20; useinbandfec=1; usedtx=1; stereo=0; sprop-stereo=0; maxaveragebitrate=32000; cbr=0
```
- **Forced Mono (`stereo=0`, `sprop-stereo=0`)**: Eliminates phase discrepancies between microphone and speakers, allowing Acoustic Echo Cancellation (AEC) to cancel 100% of speaker bleed.
- **In-Band Forward Error Correction (`useinbandfec=1`)**: Automatically reconstructs lost voice packets over unstable mobile or Wi-Fi networks, eliminating crackles and robotic distortion.
- **Discontinuous Transmission (`usedtx=1`)**: Pauses transmission when a participant is silent, completely eliminating ambient background hiss and reducing bandwidth.
- **Bitrate Cap (`maxaveragebitrate=32000`)**: Delivers wideband, crystal-clear vocal reproduction while conserving upstream bandwidth for video.

### 2. Hardware & Software DSP
- **Acoustic Echo Cancellation (AEC)**: Hardware-accelerated AEC on Android; software DSP fallback on desktop.
- **Noise Suppression (NS)**: Filters out typing, fan noise, and air conditioning hum.
- **Automatic Gain Control (AGC)**: Normalizes soft and loud speakers to consistent volume levels.
- **Zero Duplicate Pipeline**: Remote audio tracks are decoded directly by `libwebrtc`'s native VoiceEngine, preventing software-induced feedback loops.

---

## Video & Screen Sharing Specifications

### Camera Video
- **Desktop (Windows/macOS/Linux)**: 1280 × 720 (HD 720p) @ 30 FPS target.
- **Mobile (Android/iOS)**: Adaptive 640 × 480 to 1280 × 720 @ 30 FPS, front/back camera toggling with automatic mirror correction.
- **Codec**: VP8 / H.264 hardware-accelerated encoding and decoding.

### Screen Sharing
- **Live Peer Track Swapping**: When screen sharing is toggled, outgoing video tracks on all active peer connections are swapped in real time via `sender.replaceTrack(newTrack)` without call interruption or renegotiation delays.
- **Concurrent Voice Retention**: Screen capture video is automatically multiplexed with the presenter's active microphone audio track, allowing the presenter to speak while presenting slides, documents, or code.
- **Aspect-Ratio Fidelity**: Rendered in `RTCVideoViewObjectFitContain` mode with mirroring disabled (`mirror: false`), ensuring text, spreadsheets, and taskbars remain crisp and uncropped.
- **Native OS Hooks**: Automatically listens to native system events (`track.onEnded`) so that clicking the OS "Stop Sharing" floating control cleanly restores camera video.

---

## Security & Access Control

1. **Host Privileges**:
   - **Only the meeting creator (Host)** can trigger **"End Meeting for All"**.
   - Room termination is verified both in the UI and enforced at the service layer (`MeetingService.endMeeting` rejects calls from non-host `requesterId`s).
   - Ending the meeting automatically dismisses all connected participants, cleans up room presence in Firestore, and redirects everyone to the Home Screen.
   - Non-host participants strictly have access to **"Leave Meeting"**.
2. **Waiting Room Admission**:
   - Hosts can toggle **Auto-Accept** on or off during room creation.
   - When Auto-Accept is off, guests are held in a waiting room until the host selectively admits them or clicks **"Admit All"**.
3. **End-to-End Media Encryption**:
   - All media packets (audio, video, screen share) are encrypted point-to-point via **DTLS-SRTP** (AES-128 / AES-256).

---

## Key Features

- **P2P Encrypted HD Video & Audio**: Full HD video calls with low latency.
- **Host Room Controls**: Host badge indicators, waiting room approvals, and exclusive meeting termination controls.
- **Clean Redirection**: Hardware and UI navigation safety via Flutter's `PopScope`, returning users directly to the Home Screen with clear status banners.
- **Integrated In-Meeting Chat**: Real-time room messaging with automatic scrolling.
- **View Modes**: Toggle between **Multiview Grid** and **Single Focused Presenter View**.
- **1-Tap Room Sharing**: Formatted meeting codes (e.g., `XOM-767-822`) with one-touch clipboard copying and native share sheet integration.

---

## Platform Support & Requirements

| Platform | Architecture | Minimum Version | Distribution Type |
|---|---|---|---|
| **Windows Desktop** | x64 (64-bit) | Windows 10 (1809+) or Windows 11 | Standalone portable executable (`xomm.exe`) |
| **Android** | arm64-v8a / armeabi-v7a | Android 8.0 (Oreo, API 26) or higher | Standalone APK (`Xomm_Android.apk`) |
| **Web** | Modern Browsers | Chrome 90+, Edge 90+, Safari 14+ | WebAssembly / CanvasKit build |

---

## Build & Installation

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/) (v3.12+ or latest stable)
- [Dart SDK](https://dart.dev/)
- For Windows Desktop: Visual Studio 2022 with "Desktop development with C++"
- For Android: Android Studio & Android SDK (API 34+, NDK 28)

### Clone & Install Dependencies
```bash
git clone https://github.com/Muhammad9985/xomm.git
cd xomm
flutter pub get
```

### Run Tests
```bash
flutter test
```

### Build Releases

#### 1. Windows Desktop (Standalone)
```bash
flutter build windows --release
```
The compiled standalone package will be located at:
`build\windows\x64\runner\Release\` (requires the `data\` folder adjacent to `xomm.exe`).

#### 2. Android APK
```bash
flutter build apk --release --target-platform android-arm64
```
The output APK will be located at:
`build\app\outputs\flutter-apk\app-release.apk`.

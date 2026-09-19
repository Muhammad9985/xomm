# Xomm — Peer-to-Peer HD Video Conferencing

<div align="center">

<br />

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![WebRTC](https://img.shields.io/badge/WebRTC-Full--Mesh%20P2P-333333?style=for-the-badge&logo=webrtc&logoColor=white)](https://webrtc.org)
[![Firebase](https://img.shields.io/badge/Firebase-Cloud%20Firestore-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Platforms](https://img.shields.io/badge/Platforms-Windows%20%7C%20Android%20%7C%20Web-4CAF50?style=for-the-badge)](https://github.com/Muhammad9985)
[![License](https://img.shields.io/badge/License-Proprietary-E53935?style=for-the-badge)](https://github.com/Muhammad9985)

<br />

### 🚀 Ultra-Low Latency • Serverless Media Relays • Direct Encrypted P2P Streams

<p align="center">
  <b>A modern cross-platform video conferencing application built with Flutter and WebRTC Full-Mesh architecture. Delivers zero-server-cost real-time audio/video streaming, carrier-grade acoustic echo cancellation, live screen sharing, host-controlled governance, and waiting room admission.</b>
</p>

<p align="center">
  <a href="https://mr-software.online/"><strong>Website & Portfolio</strong></a> •
  <a href="https://www.linkedin.com/in/muhammad-rafique-944b05159/"><strong>LinkedIn</strong></a> •
  <a href="https://github.com/Muhammad9985"><strong>GitHub Profile</strong></a>
</p>

</div>

---

## 📌 Table of Contents

- [Highlights](#-highlights)
- [Architecture & P2P Topology](#-architecture--p2p-topology)
- [Acoustic Engineering & Audio Quality](#-acoustic-engineering--audio-quality)
- [Video & Screen Sharing Engine](#-video--screen-sharing-engine)
- [Capacity & Mesh Scaling Limits](#-capacity--mesh-scaling-limits)
- [Host Governance & Security](#-host-governance--security)
- [Feature Matrix](#-feature-matrix)
- [Platform Support](#-platform-support)
- [Repository Notice](#-repository-notice)
- [Developer & Contact](#-developer--contact)

---

## ✨ Highlights

| Feature | Technical Specification |
| :--- | :--- |
| **P2P Architecture** | Full-Mesh peer-to-peer using Google's native `libwebrtc` engine. Direct device-to-device transport without third-party SFU relay fees. |
| **Acoustic Clarity** | Custom Opus SDP parameter injection (`stereo=0`, `useinbandfec=1`, `usedtx=1`) combined with hardware AEC, NS, and AGC. |
| **Hot Track Swapping** | Seamlessly swap from camera to live screen share using `sender.replaceTrack()` without call renegotiation or dropped audio. |
| **Waiting Room** | Selective admission control. Host can accept, deny, or "Admit All" guests prior to room entry. |
| **Host Governance** | Exclusive **"End Meeting for All"** command backed by service-layer verification, dismissing all peers with auto-navigation. |
| **Cross-Platform** | Single unified Dart codebase running natively on **Windows (x64)**, **Android (ARM64)**, and **Web**. |

---

## 🏗️ Architecture & P2P Topology

Xomm replaces costly central media servers (SFUs / MCUs) with a **direct peer-to-peer mesh**, leveraging Cloud Firestore solely as a transient signaling channel for SDP offers, answers, and ICE candidates:

```
                            ┌────────────────────────────────────┐
                            │    Google Cloud Firestore          │
                            │    (Signaling & Presence Layer)    │
                            └─────────────────┬──────────────────┘
                                              │  SDP Offers / Answers
                                              │  ICE Candidates & Room State
                         ┌────────────────────┼────────────────────┐
                         ▼                    ▼                    ▼
                ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
                │  Participant A   │ │  Participant B   │ │  Participant C   │
                │  (Windows 64-bit)│ │ (Android Phone)  │ │ (Laptop / Web)   │
                └────────┬─────────┘ └────────┬─────────┘ └────────┬─────────┘
                         │                    │                    │
                         │◄═══════════════════╪═══════════════════►│
                         │     Direct Encrypted P2P Streams       │
                         │      (DTLS-SRTP Audio / Video)         │
                         └────────────────────┴────────────────────┘
```

1. **Signaling Exchange**: Participants connect to Firestore room listeners to exchange SDP descriptions and ICE candidates over secure WebSockets.
2. **Direct P2P Transport**: Once ICE negotiation succeeds via Google STUN servers, media streams flow directly point-to-point over encrypted UDP (DTLS-SRTP).
3. **Zero Media Data Storage**: Video and voice packets never pass through or touch Firestore, providing maximum confidentiality and zero per-gigabyte bandwidth costs.

---

## 🎙️ Acoustic Engineering & Audio Quality

To eliminate cross-device echo, hollow feedback loops, and ambient hiss (especially in mixed Mobile ⇄ PC environments), Xomm implements deep SDP voice tuning and audio pipeline isolation:

### Dynamic Opus SDP Voice Profile
Every WebRTC SDP offer and answer is dynamically injected with fine-tuned audio parameters:

```
minptime=10; ptime=20; useinbandfec=1; usedtx=1; stereo=0; sprop-stereo=0; maxaveragebitrate=32000; cbr=0
```

- **Forced Mono (`stereo=0`, `sprop-stereo=0`)**: Eliminates phase discrepancy between left and right channels, allowing native Acoustic Echo Cancellation (AEC) algorithms to cancel 100% of speaker bleed into the microphone.
- **In-Band Forward Error Correction (`useinbandfec=1`)**: Automatically reconstructs missing audio packets during packet loss bursts on cellular or congested Wi-Fi networks.
- **Discontinuous Transmission (`usedtx=1`)**: Automatically suppresses packet transmission when a participant is silent, eliminating ambient room hiss and saving uplink capacity.
- **Vocal Bitrate Cap (`maxaveragebitrate=32000`)**: Optimizes crystal-clear wideband speech reproduction at 32 kbps while preserving network headroom for HD video.

### Hardware & Software DSP
- **Acoustic Echo Cancellation (AEC)**: Hardware AEC enabled on Android devices; software DSP fallback on desktop.
- **Noise Suppression (NS)**: Filters constant noise like computer cooling fans, mechanical keyboard clicks, and air conditioning.
- **Automatic Gain Control (AGC)**: Normalizes soft and loud vocal levels for comfortable listening without manual volume adjustments.

---

## 🖥️ Video & Screen Sharing Engine

### Camera Video Pipeline
- **Resolution**: 1280 × 720 (HD 720p) @ 30 FPS target on desktop; adaptive 640 × 480 to 720p on mobile.
- **Hardware Acceleration**: VP8 and H.264 video encoding utilizing system hardware accelerators.
- **Mobile Camera Controls**: Front/back camera flipping with automatic mirror correction for natural eye-contact perception.

### Screen Sharing Implementation
- **Instant Track Replacement**: Toggling screen sharing replaces the outgoing video track across all peer connections via `RTCRtpSender.replaceTrack()` without requiring full ICE renegotiation.
- **Concurrent Audio Multiplexing**: Presenter's microphone stream remains live and multiplexed while sharing screens, allowing continuous presentation narration.
- **Text Readability & Scaling**: Content is rendered using `RTCVideoViewObjectFitContain` mode with mirroring disabled (`mirror: false`), keeping text, charts, code, and spreadsheets perfectly crisp and uncropped.
- **OS Lifecycle Handlers**: Native system hooks listen for the OS-level "Stop Sharing" floating button to instantly revert back to the user's camera feed.

---

## 📊 Capacity & Mesh Scaling Limits

Because Xomm uses a **Full-Mesh P2P** network topology, every participant sends their stream to, and receives streams from, every other participant. This design is optimized for small-to-medium rooms:

### Mesh Scaling Formula
In a room with $N$ participants, each client maintains $(N - 1)$ upstream upload streams and $(N - 1)$ downstream download streams:

| Active Participants ($N$) | Total Mesh Peer Connections | Upstream Streams / Client | Downstream Streams / Client |
| :---: | :---: | :---: | :---: |
| **2** (1-on-1 Call) | 1 | 1 | 1 |
| **3** | 3 | 2 | 2 |
| **4** | 6 | 3 | 3 |
| **6** | 15 | 5 | 5 |
| **8** | 28 | 7 | 7 |

### Deployment Recommendations
- **Optimal (Best Experience)**: **2 to 6 participants**. Very low CPU overhead, imperceptible latency (< 50 ms), and smooth operation on standard home broadband or 4G LTE.
- **Supported Maximum**: **Up to 8–10 participants** on high-speed broadband connections (15+ Mbps symmetric upload/download).
- **Not Intended For**: 50+ user broadcast webinars (which require centralized SFU relays).

---

## 🛡️ Host Governance & Security

1. **Host-Enforced Session Termination**:
   - Only the authenticated room creator (Host) has access to **"End Meeting for All"**.
   - Non-host participants are restricted strictly to **"Leave Meeting"**.
   - Termination is enforced at both the UI layer and verified in `MeetingService`, instantly dispatching an end-of-meeting signal to all connected peers, cleaning up room documents in Firestore, and auto-redirecting everyone back to the home screen.
2. **Waiting Room & Access Control**:
   - Hosts can toggle the **Waiting Room** on or off during room creation.
   - When active, incoming guests are held in a waiting lobby until the host explicitly admits them individually or via **"Admit All"**.
3. **End-to-End Media Encryption**:
   - All real-time media streams (audio, video, and screen capture) are point-to-point encrypted using **DTLS-SRTP** (AES-128 / AES-256).

---

## 📱 Platform Support

| Operating System | Architecture | Minimum Version | Distribution Artifact |
| :--- | :--- | :--- | :--- |
| **Windows Desktop** | x64 (64-bit) | Windows 10 (1809+) or Windows 11 | Standalone portable executable (`xomm.exe`) |
| **Android** | arm64-v8a / armeabi-v7a | Android 8.0 (Oreo, API 26) or higher | Standalone release APK (`Xomm_Android.apk`) |
| **Web** | Modern Browsers | Chrome 90+, Edge 90+, Safari 14+ | WebAssembly / CanvasKit build |

---

## 🔒 Repository Notice

> **Notice**: This repository serves as the public technical architecture overview, documentation showcase, and portfolio reference for **Xomm**. The proprietary source code and commercial release packages are maintained privately. 
> 
> If you are interested in a private demo, licensing, or commercial cross-platform WebRTC development, please reach out directly via the contact links below.

---

## 👨‍💻 Developer & Contact

<div align="center">

### **Muhammad Rafique**
*Full-Stack & Cross-Platform Mobile / Desktop Engineer*

<p align="center">
  <a href="https://github.com/Muhammad9985">
    <img src="https://img.shields.io/badge/GitHub-Muhammad9985-181717?style=for-the-badge&logo=github&logoColor=white" alt="GitHub" />
  </a>
  &nbsp;&nbsp;
  <a href="https://www.linkedin.com/in/muhammad-rafique-944b05159/">
    <img src="https://img.shields.io/badge/LinkedIn-Muhammad_Rafique-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white" alt="LinkedIn" />
  </a>
  &nbsp;&nbsp;
  <a href="https://mr-software.online/">
    <img src="https://img.shields.io/badge/Website-mr--software.online-4CAF50?style=for-the-badge&logo=googlechrome&logoColor=white" alt="Website" />
  </a>
</p>

<sub>Copyright &copy; Muhammad Rafique. All rights reserved.</sub>

</div>

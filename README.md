# StepScape — A Walking Route‑Planning Tool

![Hero](./pics_report/hero.png)

[![GitHub release](https://img.shields.io/github/v/release/SiruiLuo/casa0015-StepScape?include_prereleases)](https://github.com/SiruiLuo/casa0015-StepScape/releases) [![License](https://img.shields.io/github/license/SiruiLuo/casa0015-StepScape)](./LICENSE) [![Website](https://img.shields.io/badge/demo-website-blue)](https://siruiluo.github.io/casa0015-StepScape/)

> **StepScape** automatically designs refreshing walking routes that match your mood and time budget. From a 10‑minute lunchtime stroll to a weekend hike, StepScape finds quiet, scenic, or energetic paths that reconnect you with the environment and ease everyday stress.

---

## Table of Contents
1. [Features](#features)
2. [Quick Demo](#quick-demo)
3. [Installation](#installation)
4. [Getting Started](#getting-started)
5. [System Architecture](#system-architecture)
6. [Route Optimisation Algorithm](#route-optimisation-algorithm)
7. [API Integrations](#api-integrations)
8. [UI Highlights](#ui-highlights)
9. [Roadmap](#roadmap)
10. [Limitations](#limitations)
11. [Contributing](#contributing)
12. [License](#license)
13. [Cite This Work](#cite-this-work)

---

## Features
- **Mood‑based routing** &nbsp;– choose tags like *Quiet*, *Scenic*, *Energetic*.
- **Theme presets** &nbsp;– *Short Trip*, *Walking*, *Jogging*, *Cycling*, *Hiking*.
- **Adaptive distance factor** &nbsp;– route length adjusts automatically.
- **Smart waypoint selection** using POI relevance, diversity balancing and greedy search.
- **Offline‑ready architecture** (planned) with cached maps and routes.
- **History & favourites** so you can revisit the walks you loved.

## Quick Demo
Live preview: **[siruiluo.github.io/casa0015-StepScape](https://siruiluo.github.io/casa0015-StepScape/)**

<p align="center">
  <img src="./pics_report/UI%20Design.png" width="800"/>
</p>

## Installation
```bash
# clone the repo
$ git clone https://github.com/SiruiLuo/casa0015-StepScape.git
$ cd casa0015-StepScape

# install dependencies (Flutter)
$ flutter pub get

# run in emulator or connected device
$ flutter run
```
> **Prerequisites:** Flutter 3.19+, Dart 3, and a Google Maps/OpenStreetMap API key if you plan to swap the default providers.

## Getting Started
1. Open the app; your current location is detected automatically.
2. Tap **Mood** and pick tags such as *Quiet* or *Scenic*.
3. Select a **Theme** (e.g. *Walking* for ~30 mins).
4. Hit **Generate Route** – StepScape returns a round‑trip GeoJSON path plus step‑by‑step prompts.
5. Save the walk to **Favourites** or share the GeoJSON with friends.

## System Architecture
```
Flutter UI  ─┬─▶  Tag Selector ──┐
            │                  │
            │                  ▼
            │        Overpass API (POI)
            │                  │
            │                  ▼
            └─▶  Route Planner (OSRM) ──▶  Map View / Polyline
```
*All APIs are wrapped by a unified interface layer with retry, caching, and auth.*

## Route Optimisation Algorithm
1. **Tag → POI Mapping** – many‑to‑many links between user mood tags and POIs.
2. **Distance Factor** –  `target = base × factor` (see table).
3. **Waypoint Greedy Search** – scores POIs for theme relevance, diversity, scenic quality.
4. **Routing** – OSRM optimises the round‑trip, avoiding repetition and obstacles.
5. **Scoring & Ranking** – composite scenic, distance and effort score returns the best path.

<div align="center">

| Theme | Factor |
|-------|-------|
| Short Trip | 1.0 |
| Walking    | 1.2 |
| Jogging    | 1.4 |
| Cycling    | 1.6 |
| Hiking     | 2.0 |

</div>

## API Integrations
| Service | Purpose |
|---------|---------|
| **OpenStreetMap / Overpass** | Free POI discovery |
| **OSRM** | Walking path optimisation |
| **Geolocator** | Positioning & geofencing |
| *(Optional)* Google Places/Directions | Paid fallback |

Robust error handling offers retries, graceful degradation and local caching.

## UI Highlights
- Consistent **blue‑to‑purple gradient** theme
- Floating action buttons and animated page transitions
- Pinch‑to‑zoom, long‑press waypoints, route overlays

## Roadmap
- [ ] Offline tile & POI cache
- [ ] Cloud sync & community sharing platform
- [ ] Air‑quality layer for the *Fresh Air* algorithm
- [ ] More mood tags and composite scoring

## Limitations
StepScape currently depends on live API calls and requires a stable connection. Offline mode and cloud persistence are in active development.

## Contributing
Pull requests are welcome! Please open an issue first to discuss major changes.

1. Fork the repo and create your branch: `git checkout -b feature/awesome`  
2. Commit your changes: `git commit -m "feat: add awesome"`  
3. Push to the branch: `git push origin feature/awesome`  
4. Open a PR.

## License
Distributed under the **MIT License**. See `LICENSE` for more information.

## Cite This Work
If you use StepScape in academic research, please cite:

```bibtex
@misc{luo2025stepscape,
  author       = {Sirui Luo},
  title        = {{StepScape: A Mood‑Aware Walking Route Planner}},
  year         = {2025},
  howpublished = {GitHub},
  url          = {https://github.com/SiruiLuo/casa0015-StepScape}
}
```

---

*Report authored by **Sirui Luo**, April 2025.*


# Digital Rock Climbing Logbook

A specialized Flutter application designed for rock climbers to log their climbing sessions, track progression, and analyze performance over time. Built with an offline-first architecture and AI-friendly modular design.

## 🎯 Features

- **Quick Session Logging**: Start and end climbing sessions with location tracking
- **Climb Tracking**: Log climbs with grade, style (sport/trad/boulder/top-rope), result, and attempts
- **Offline-First**: Full functionality without internet connection using Drift (SQLite)
- **Cross-Platform**: 95% code sharing between iOS and Android
- **Clean Architecture**: Modular design with 100-300 line files for AI-assisted development

## 🏗️ Architecture

This project uses a Turborepo monorepo structure with Flutter and shared packages:

```
climbing-logbook/
├── apps/
│   ├── mobile/          # Flutter mobile app (iOS & Android)
│   ├── web/            # Web dashboard (planned)
│   └── admin/          # Admin panel (planned)
├── packages/
│   ├── ui/             # Shared Flutter widgets & design system
│   ├── core/           # Business logic & domain models
│   ├── db/             # Database layer with Drift
│   ├── api/            # API client & sync logic (planned)
│   └── voice/          # Voice processing & NLP (planned)
└── tools/              # Build tools and scripts
```

## 🚀 Getting Started

### Prerequisites

- Flutter 3.16+ installed
- Xcode (for iOS development)
- Android Studio (for Android development)
- Node.js 18+ (for Turborepo)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/stevoh213/flutterclimb.git
cd flutterclimb
```

2. Install dependencies:
```bash
npm install
cd apps/mobile
flutter pub get
```

3. Generate code:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

4. Run the app:
```bash
flutter run
```

## 🛠️ Technology Stack

- **Framework**: Flutter 3.16+ with Dart 3.0+
- **State Management**: Riverpod 2.0
- **Database**: Drift (SQLite) for offline-first data
- **Architecture**: Clean architecture with modular design
- **Monorepo**: Turborepo for efficient code organization
- **Code Generation**: Freezed, JsonSerializable, Riverpod Generator

## 📱 Current Features

- ✅ Session management (start/end/track)
- ✅ Quick climb logging with grade selection
- ✅ Style and result tracking
- ✅ Session statistics
- ✅ Recent sessions history
- ✅ Offline-first data storage

## 🔮 Planned Features

- [ ] AI-powered voice logging
- [ ] Advanced analytics dashboard
- [ ] Goal setting and tracking
- [ ] Photo attachment to climbs
- [ ] GPS location tracking
- [ ] Web dashboard for detailed analytics
- [ ] Training plan generation

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
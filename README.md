# Melt - Android UI

A mobile application that provides real-time legal assistance during law enforcement interactions using AI-powered transcription and legal analysis.

## Features

- 🎤 **Real-time Audio Recording** - Capture interactions with visual feedback
- 📝 **Live Transcription** - Convert speech to text using ElevenLabs API
- ⚖️ **Legal Situation Detection** - AI analyzes conversations for potential legal issues
- 💡 **Smart Advice** - Gets relevant legal guidance based on context
- 🌍 **Multi-language Support** - 10 languages for personalized assistance
- ⚙️ **Configurable Backend** - Easily switch API endpoints

## Setup

### Prerequisites

- Flutter SDK (3.10.8 or higher)
- Android Studio or VS Code with Flutter extensions
- Backend server running (see `Melt_Backend` folder)

### Installation

1. **Install dependencies**:
   ```bash
   cd melt2/melt2
   flutter pub get
   ```

2. **Start the backend server**:
   ```bash
   cd ../../Melt_Backend
   bun install
   bun run src/index.ts
   ```

3. **Configure API URL** (if testing on physical device):
   - Launch the app
   - Go to Settings (⚙️ icon)
   - Update API URL to your computer's local IP
   - Example: `http://192.168.1.100:3000`

4. **Run the app**:
   ```bash
   cd ../melt2/melt2
   flutter run
   ```

## Usage

1. **First Launch**: Set up your profile (name, age, language)
2. **Start Recording**: Tap the large circular button
3. **Grant Permissions**: Allow microphone access when prompted
4. **Monitor**: App automatically processes audio every 30 seconds
5. **Get Advice**: If a legal situation is detected, advice appears automatically

## Project Structure

```
lib/
├── api_service.dart              # Backend integration
├── main.dart                     # App entry & routing
├── models/
│   └── user_profile.dart         # User data model
└── screens/
    ├── profile_setup_screen.dart # Initial setup
    ├── recording_screen.dart     # Main interface
    └── settings_screen.dart      # Configuration
```

## Backend Endpoints

- `POST /elevenlabs/upload` - Audio transcription
- `POST /gemini/judge` - Situation analysis
- `POST /gemini/inform` - Legal advice retrieval

## Permissions

The app requires:
- 🎤 **Microphone** - For audio recording
- 🌐 **Internet** - For API communication
- 💾 **Storage** - For saving audio files

## Design

- **Dark Theme** with cyan accents (#00D9FF)
- **Responsive UI** optimized for Android
- **Smooth Animations** for enhanced user experience
- **Clear Visual Feedback** for all states

## Development

### Key Dependencies

- `record` - Audio recording functionality
- `permission_handler` - Runtime permissions
- `path_provider` - File system access
- `shared_preferences` - Local data storage
- `http` - API requests

### Testing

```bash
# Run tests
flutter test

# Check for issues
flutter analyze

# Build release APK
flutter build apk --release
```

## Notes

- Default API URL: `http://localhost:3000`
- Audio is processed every 30 seconds while recording
- Transcripts and advice are displayed in real-time
- All user data is stored locally on device

## Future Enhancements

- [ ] True rolling 5-minute audio buffer
- [ ] Background recording service
- [ ] Persistent transcript history
- [ ] Emergency contacts integration
- [ ] Text-to-speech for advice
- [ ] Export recordings as evidence

## License

See LICENSE file in parent directory.

---

**Built with Flutter for Android** | **Powered by ElevenLabs & Gemini AI**

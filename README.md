# yks_yanlis_defteri

A new Flutter project.

## Gemini API ayari

Proje kokunde bulunan `gemini.local.json` dosyasina Gemini API anahtarini tanimlayin:

```json
{
  "GEMINI_API_KEY": "API_ANAHTARINIZ"
}
```

VS Code'da **Run and Debug** panelinden **YKS Hane (Gemini)** yapilandirmasini secin.
`gemini.local.json` Git'e eklenmez. Komut satiri ile calistirmak icin:

```powershell
flutter run --dart-define-from-file=gemini.local.json
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

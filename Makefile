debug:
	flutter run -d TB321FU --flavor demo --dart-define=APP_ENV=demo --dart-define=API_BASE_URL=https://m40pr9hc-8000.asse.devtunnels.ms/v1

build:
	flutter build apk --split-per-abi --flavor demo --dart-define=APP_ENV=demo --dart-define=API_BASE_URL=https://m40pr9hc-8000.asse.devtunnels.ms/v1
/// CrisisSync Dart Backend — .env loader
/// Copy .env from the Node.js backend — same keys work
library;

import 'dart:io';
import 'package:dotenv/dotenv.dart';

late DotEnv _env;

void loadEnv() {
  _env = DotEnv(includePlatformEnvironment: true)..load();
}

String env(String key, [String fallback = '']) =>
    _env[key] ?? Platform.environment[key] ?? fallback;

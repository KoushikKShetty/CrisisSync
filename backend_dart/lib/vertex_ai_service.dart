/// Vertex AI (GCP) — Gemini via aiplatform.googleapis.com
/// Uses the same Firebase service account credentials (cloud-platform scope).
/// Replaces AI Studio calls when USE_VERTEX_AI=true in .env.
library;

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'firebase_service.dart';

bool get vertexEnabled => env('USE_VERTEX_AI', 'false') == 'true';

String _vertexUrl(String model) {
  final project = env('FIREBASE_PROJECT_ID');
  final region = env('VERTEX_AI_REGION', 'us-central1');
  return 'https://$region-aiplatform.googleapis.com/v1/projects/$project'
      '/locations/$region/publishers/google/models/$model:generateContent';
}

// ── Core generate call ─────────────────────────────────────────────
Future<String?> vertexGenerate(
  String prompt, {
  String model = 'gemini-2.0-flash',
  double temperature = 0.1,
  int maxTokens = 512,
}) async {
  if (!vertexEnabled) return null;

  try {
    final token = await getGoogleAccessToken();
    final body = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt}
          ],
        }
      ],
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': maxTokens,
      },
    };

    final res = await http
        .post(
          Uri.parse(_vertexUrl(model)),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final parts =
            (candidates[0]['content'] as Map?)?.values
                .whereType<List>()
                .firstOrNull;
        if (parts != null && parts.isNotEmpty) {
          return (parts[0] as Map?)?.values.whereType<String>().firstOrNull;
        }
      }
    } else {
      final preview = res.body.substring(0, min(200, res.body.length));
      print('[VertexAI] ${res.statusCode}: $preview');
    }
    return null;
  } catch (e) {
    print('[VertexAI] Error: $e');
    return null;
  }
}

// ── Classify incident (mirrors gemini_service.classifyIncident) ────
Future<Map<String, dynamic>?> vertexClassifyIncident(
    String message, String zone) async {
  if (!vertexEnabled) return null;

  final prompt = '''You are an AI classifier for a hotel crisis response system.
Classify this guest message and respond ONLY in valid JSON (no markdown):
{
  "severity": "critical" | "warning" | "info",
  "category": "fire" | "medical" | "security" | "facilities" | "service",
  "confidence": 0-100,
  "suggestedAction": "one short sentence"
}
Rules:
- "critical" = immediate danger to life
- "warning" = urgent but not life-threatening
- "info" = routine request

Zone: $zone
Message: "$message"''';

  try {
    final raw = await vertexGenerate(prompt, maxTokens: 256);
    if (raw == null) return null;
    final clean = raw.replaceAll('```json', '').replaceAll('```', '').trim();
    return jsonDecode(clean) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

// ── Generate emergency protocol ────────────────────────────────────
Future<List<String>?> vertexGenerateProtocol(
    String type, String zone, String description) async {
  if (!vertexEnabled) return null;

  final prompt =
      '''Generate a 4-step emergency action protocol for hotel staff.
Incident type: $type
Zone: $zone
${description.isNotEmpty ? 'Details: $description' : ''}
Respond ONLY as a JSON array of strings (4 steps, no markdown):
["Step 1...", "Step 2...", "Step 3...", "Step 4..."]''';

  try {
    final raw = await vertexGenerate(prompt, maxTokens: 300);
    if (raw == null) return null;
    final clean = raw.replaceAll('```json', '').replaceAll('```', '').trim();
    final list = jsonDecode(clean) as List;
    return list.cast<String>();
  } catch (_) {
    return null;
  }
}

// ── Answer guest question ──────────────────────────────────────────
Future<Map<String, dynamic>?> vertexAnswerGuest(String question) async {
  if (!vertexEnabled) return null;

  final prompt = '''You are a helpful AI concierge for Grand Thalassa Hotel.
Answer guest questions concisely and warmly.
Respond ONLY in JSON (no markdown):
{
  "answer": "your response in 1-2 sentences",
  "requiresHuman": true/false
}
Hotel facts:
- Check-in: 2 PM, Check-out: 11 AM
- Pool hours: 6 AM - 10 PM
- Main restaurant: 7 AM - 11 PM

Guest question: "$question"''';

  try {
    final raw = await vertexGenerate(prompt, maxTokens: 200);
    if (raw == null) return null;
    final clean = raw.replaceAll('```json', '').replaceAll('```', '').trim();
    return jsonDecode(clean) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

/// Gemini AI service — classify incidents + answer guest questions
/// Routes through Vertex AI (GCP) when USE_VERTEX_AI=true, falls back to AI Studio.
library;

import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'config.dart';
import 'vertex_ai_service.dart';

late GenerativeModel? _model;

void initGemini() {
  if (vertexEnabled) {
    print('✦  Gemini AI → GCP Vertex AI (project: ${env('FIREBASE_PROJECT_ID')}, region: ${env('VERTEX_AI_REGION', 'us-central1')})');
    _model = null; // Vertex AI handles all calls; AI Studio model not needed
    return;
  }
  final key = env('GEMINI_API_KEY');
  if (key.isEmpty) {
    print('⚠️  GEMINI_API_KEY not set — AI running in mock mode');
    _model = null;
    return;
  }
  _model = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: key,
  );
  print('✦  Gemini AI initialized (AI Studio)');
}

// ── Classify incident message ──────────────────────────────────────
Future<Map<String, dynamic>> classifyIncident(
    String message, String zone) async {
  // Try Vertex AI first
  final vertexResult = await vertexClassifyIncident(message, zone);
  if (vertexResult != null) {
    print('[Gemini] classifyIncident ← Vertex AI');
    return vertexResult;
  }

  if (_model == null) {
    // Mock mode
    final lower = message.toLowerCase();
    if (lower.contains('fire') || lower.contains('smoke')) {
      return {
        'severity': 'critical',
        'category': 'fire',
        'confidence': 98,
        'suggestedAction': 'Evacuate immediately and activate suppression',
      };
    }
    if (lower.contains('hurt') ||
        lower.contains('blood') ||
        lower.contains('medical')) {
      return {
        'severity': 'critical',
        'category': 'medical',
        'confidence': 92,
        'suggestedAction': 'Send medical team immediately',
      };
    }
    return {
      'severity': 'info',
      'category': 'service',
      'confidence': 70,
      'suggestedAction': 'Assign housekeeping staff',
    };
  }

  try {
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

    final content = [Content.text(prompt)];
    final response = await _model!.generateContent(content);
    final text = response.text ?? '';
    final clean =
        text.replaceAll('```json', '').replaceAll('```', '').trim();
    return jsonDecode(clean) as Map<String, dynamic>;
  } catch (e) {
    print('[Gemini] classifyIncident error: $e');
    return {
      'severity': 'warning',
      'category': 'security',
      'confidence': 50,
      'suggestedAction': 'Manual review required',
    };
  }
}

// ── Answer guest question ──────────────────────────────────────────
Future<Map<String, dynamic>> answerGuestQuestion(String question) async {
  final vertexResult = await vertexAnswerGuest(question);
  if (vertexResult != null) {
    print('[Gemini] answerGuestQuestion ← Vertex AI');
    return vertexResult;
  }

  if (_model == null) {
    return {
      'answer': "Thank you for your message. Checkout is at 11 AM. Pool hours are 6 AM–10 PM. Our staff will assist you shortly.",
      'requiresHuman': false,
    };
  }

  try {
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
- WiFi: GrandThalassa_Guest, password: relax2025

Guest question: "$question"''';

    final content = [Content.text(prompt)];
    final response = await _model!.generateContent(content);
    final text = response.text ?? '';
    final clean =
        text.replaceAll('```json', '').replaceAll('```', '').trim();
    return jsonDecode(clean) as Map<String, dynamic>;
  } catch (e) {
    print('[Gemini] answerGuestQuestion error: $e');
    return {
      'answer':
          "I'm having trouble connecting right now. Let me get a staff member for you.",
      'requiresHuman': true,
    };
  }
}

// ── Generate action plan for hardware events ───────────────────────
Future<List<String>> generateEmergencyProtocol(
    String type, String zone, String description) async {
  final vertexResult = await vertexGenerateProtocol(type, zone, description);
  if (vertexResult != null) {
    print('[Gemini] generateProtocol ← Vertex AI');
    return vertexResult;
  }

  if (_model == null) {
    return _mockProtocol(type, zone);
  }

  try {
    final prompt =
        '''Generate a 4-step emergency action protocol for hotel staff.
Incident type: $type
Zone: $zone
${description.isNotEmpty ? 'Details: $description' : ''}
Respond ONLY as a JSON array of strings (4 steps, no markdown):
["Step 1...", "Step 2...", "Step 3...", "Step 4..."]''';

    final content = [Content.text(prompt)];
    final response = await _model!.generateContent(content);
    final text = response.text ?? '';
    final clean =
        text.replaceAll('```json', '').replaceAll('```', '').trim();
    final list = jsonDecode(clean) as List;
    return list.cast<String>();
  } catch (e) {
    print('[Gemini] generateProtocol error: $e');
    return _mockProtocol(type, zone);
  }
}

List<String> _mockProtocol(String type, String zone) {
  switch (type.toLowerCase()) {
    case 'fire':
      return [
        'Activate fire suppression system in $zone',
        'Evacuate all guests via nearest emergency exit',
        'Call fire department (dial 101)',
        'Account for all guests at muster point',
      ];
    case 'medical':
      return [
        'Send first aid kit and AED to $zone immediately',
        'Call ambulance (dial 108)',
        'Clear area and provide privacy for patient',
        'Assign staff member to stay with guest until help arrives',
      ];
    default:
      return [
        'Dispatch security to $zone immediately',
        'Secure the perimeter and assess the situation',
        'Contact supervisor and document the incident',
        'Follow up with affected guests',
      ];
  }
}

// ── Generic text generation (used by news_service) ────────────────
Future<String> generateText(String prompt) async {
  final vertexResult = await vertexGenerate(prompt, maxTokens: 64);
  if (vertexResult != null) return vertexResult;

  if (_model == null) return 'BRIEFING';
  try {
    final response = await _model!.generateContent([Content.text(prompt)]);
    return response.text ?? '';
  } catch (e) {
    print('[Gemini] generateText error: $e');
    return 'BRIEFING';
  }
}

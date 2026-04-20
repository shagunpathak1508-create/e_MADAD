import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/volunteer_model.dart';
import '../services/allocation_service.dart';
import '../config/secrets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// API key is loaded from lib/config/secrets.dart (gitignored — never committed).
// Regenerate at: https://aistudio.google.com/app/apikey if ever exposed.
// ─────────────────────────────────────────────────────────────────────────────
const _kGeminiApiKey = kGeminiApiKey;

const _kGeminiEndpoint =
    'https://generativelanguage.googleapis.com/v1beta/models/'
    'gemini-1.5-flash:generateContent';

const _kTimeoutSeconds = 4; // Hard ceiling — must not slow UX

// ─────────────────────────────────────────────────────────────────────────────
//  Value object returned to the UI layer
// ─────────────────────────────────────────────────────────────────────────────
class GeminiMatchResult {
  /// The single best volunteer chosen by AI (or fallback).
  final VolunteerModel bestVolunteer;

  /// Full ranked list (best → worst), for displaying all cards in order.
  final List<VolunteerModel> rankedList;

  /// true → Gemini ranked this list.  false → fallback sort was used.
  final bool usedAI;

  const GeminiMatchResult({
    required this.bestVolunteer,
    required this.rankedList,
    required this.usedAI,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  Main service
// ─────────────────────────────────────────────────────────────────────────────
class GeminiMatchingService {
  // Session-level cache keyed by "emergencyId|emergencyType"
  // Prevents duplicate Gemini calls for the same incident.
  static final Map<String, GeminiMatchResult> _cache = {};

  /// Clears the session cache (e.g. on app restart / new emergency).
  static void clearCache() => _cache.clear();

  // ── Public entry point ────────────────────────────────────────────────────

  /// STEP 1 — Filter:  AllocationService selects top-5 candidates.
  /// STEP 2 — Rank:    Gemini reorders them intelligently.
  /// STEP 3 — Return:  [GeminiMatchResult] with best volunteer + ranked list.
  ///
  /// FALLBACK (Step 4): On any error / timeout → returns AllocationService
  /// list unchanged (distance + reliability sort already applied).
  ///
  /// [emergencyId] is used as part of the cache key to avoid repeat calls.
  static Future<GeminiMatchResult> findBestVolunteer({
    required String emergencyType,
    required double victimLat,
    required double victimLng,
    required List<VolunteerModel> allVolunteers,
    String emergencyId = '',
  }) async {
    // ── Cache check ──────────────────────────────────────────────────────
    final cacheKey = '$emergencyId|$emergencyType';
    if (_cache.containsKey(cacheKey)) {
      debugPrint('[Gemini] Cache hit for key: $cacheKey');
      return _cache[cacheKey]!;
    }

    // ── STEP 1: Logic filtering using existing AllocationService ─────────
    // Filters: available=true, skill match, distance ≤ 10 km, top-5
    final filtered = AllocationService.rankVolunteers(
      emergencyType,
      allVolunteers,
      victimLat,
      victimLng,
      limit: 5,
    );

    if (filtered.isEmpty) {
      // No candidates at all — nothing to rank
      return _fallbackResult(filtered, victimLat, victimLng, usedAI: false);
    }

    // ── STEP 2: Gemini AI ranking ────────────────────────────────────────
    if (_kGeminiApiKey.isNotEmpty) {
      try {
        final prompt = _buildPrompt(emergencyType, victimLat, victimLng, filtered);
        final rawResponse = await _callGemini(prompt);

        if (rawResponse != null) {
          final ranked = _parseRankedIds(rawResponse, filtered);
          if (ranked.isNotEmpty) {
            final result = GeminiMatchResult(
              bestVolunteer: ranked.first,
              rankedList:    ranked,
              usedAI:        true,
            );
            _cache[cacheKey] = result;
            debugPrint('[Gemini] AI ranking succeeded. Best: ${ranked.first.name}');
            return result;
          }
        }
      } catch (e) {
        // Any exception → silent fallback; never crash the app
        debugPrint('[Gemini] Error (using fallback): $e');
      }
    } else {
      debugPrint('[Gemini] No API key — using fallback sort.');
    }

    // ── STEP 4: Fallback sort ────────────────────────────────────────────
    final result = _fallbackResult(filtered, victimLat, victimLng, usedAI: false);
    _cache[cacheKey] = result;
    return result;
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  /// Builds the structured Gemini prompt described in the spec.
  static String _buildPrompt(
    String emergencyType,
    double victimLat,
    double victimLng,
    List<VolunteerModel> volunteers,
  ) {
    final volList = volunteers.map((v) {
      final distKm = AllocationService.haversineMeters(
              v.lat, v.lng, victimLat, victimLng) /
          1000;
      return {
        'id':           v.id,
        'skills':       v.skills,
        'distance':     double.parse(distKm.toStringAsFixed(2)),
        'reliability':  double.parse((v.reliabilityScore / 20).toStringAsFixed(1)), // 0–5
        'responseRate': (v.responseRate * 100).toInt(),
      };
    }).toList();

    final input = jsonEncode({
      'emergencyType':   emergencyType,
      'victimLocation':  {'lat': victimLat, 'lng': victimLng},
      'volunteers':      volList,
    });

    return '''
Rank these volunteers for a $emergencyType emergency based on:
- skill relevance
- reliability score (0–5)
- response rate (%)
- distance (km)

Input JSON:
$input

Return ONLY (no explanation, no extra text):
1. Best volunteer ID
2. Ranked list of all volunteer IDs (best to worst), comma-separated

Example format:
BEST: v1
RANKED: v1,v3,v2,v5,v4
''';
  }

  /// Calls the Gemini REST API with a hard timeout.
  static Future<String?> _callGemini(String prompt) async {
    final uri = Uri.parse('$_kGeminiEndpoint?key=$_kGeminiApiKey');
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature':     0.1,  // Low creativity — we want deterministic ranking
        'maxOutputTokens': 128,  // Short response only
        'topP':            0.8,
      },
    });

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: _kTimeoutSeconds));

    if (response.statusCode != 200) {
      debugPrint('[Gemini] HTTP ${response.statusCode}: ${response.body}');
      return null;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) return null;

    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts   = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) return null;

    return (parts.first['text'] as String?)?.trim();
  }

  /// Parses the Gemini text response and maps IDs back to VolunteerModel.
  ///
  /// Expected format:
  ///   BEST: v1
  ///   RANKED: v1,v3,v2
  ///
  /// Falls back to AllocationService order if parsing fails.
  static List<VolunteerModel> _parseRankedIds(
    String text,
    List<VolunteerModel> pool,
  ) {
    final idMap = {for (final v in pool) v.id: v};
    final ranked = <VolunteerModel>[];

    // Try to find the RANKED line
    final rankedMatch = RegExp(r'RANKED:\s*(.+)', caseSensitive: false).firstMatch(text);
    if (rankedMatch != null) {
      final ids = rankedMatch.group(1)!.split(',').map((s) => s.trim());
      for (final id in ids) {
        if (idMap.containsKey(id)) {
          ranked.add(idMap[id]!);
          idMap.remove(id); // remove to avoid duplicates
        }
      }
    }

    // Append any volunteers that weren't mentioned in the response
    ranked.addAll(idMap.values);

    return ranked.isEmpty ? pool : ranked;
  }

  /// Fallback: sort by distance (40%) + reliability (35%) + responseRate (25%)
  /// — same composite score already in AllocationService.
  static GeminiMatchResult _fallbackResult(
    List<VolunteerModel> filtered,
    double victimLat,
    double victimLng, {
    required bool usedAI,
  }) {
    if (filtered.isEmpty) {
      // Absolute edge case — return a placeholder-free empty result
      return GeminiMatchResult(
        bestVolunteer: _emptyVolunteer(),
        rankedList:    [],
        usedAI:        false,
      );
    }

    // Already sorted by AllocationService.rankVolunteers above; just use order
    return GeminiMatchResult(
      bestVolunteer: filtered.first,
      rankedList:    filtered,
      usedAI:        usedAI,
    );
  }

  /// Placeholder used when the pool is completely empty (edge-case guard).
  static VolunteerModel _emptyVolunteer() => VolunteerModel(
        id:    '',
        name:  'No Volunteer',
        phone: '',
        skills: const [],
      );
}

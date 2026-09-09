import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'hunt_screen.dart';
import 'ai_handler.dart';
import 'gmail_sync_service.dart';

class AutoAgent {
  bool isRunning = false;

  Future<void> start247Agent(Map<String, dynamic> profile) async {
    if (isRunning) return;
    isRunning = true;

    // Gmail <-> App sync loop alag se, tez interval pe (har 2 min) —
    // taake lead ka reply jaldi app mein aa jaye aur AI turant respond kare.
    _startGmailSyncLoop(profile);

    while (isRunning) {
      try {
        debugPrint("🤖 Agent Cycle Started...");
        await AgentService.processNewLeads(profile);
        await AgentService.runAutoFollowUp();
        debugPrint("😴 Agent taking a short break...");
        await Future.delayed(const Duration(minutes: 30));
      } catch (e) {
        debugPrint("❌ Agent Error: $e");
        await Future.delayed(const Duration(minutes: 5));
      }
    }
  }

  Future<void> _startGmailSyncLoop(Map<String, dynamic> profile) async {
    while (isRunning) {
      try {
        debugPrint("📥 Checking Gmail inbox for new replies...");
        await GmailSyncService.syncInbox(profile);
      } catch (e) {
        debugPrint("❌ Gmail sync loop error: $e");
      }
      await Future.delayed(const Duration(minutes: 2));
    }
  }

  void stopAgent() {
    isRunning = false;
  }
}

class AgentService {
  static final supabase = Supabase.instance.client;

  static Duration _getRandomDelay() {
    final random = Random();
    int seconds = 30 + random.nextInt(91);
    return Duration(seconds: seconds);
  }

  /// Public wrapper — GmailSyncService jaise dusre files bhi
  /// same random human-like delay use kar saken.
  static Duration randomDelay() => _getRandomDelay();

  /// Manual trigger — chat_list_screen ke "Sync" button se call hota hai
  /// taake user khud bhi turant Gmail check kara sake, 2-min wait ke bina.
  static Future<void> syncGmailNow(Map<String, dynamic> profile) async {
    await GmailSyncService.syncInbox(profile);
  }

  static Future<void> runContinuousOutreach() async {
    while (true) {
      try {
        final response = await supabase
            .from('leads')
            .select('*')
            .eq('status', 'Analyzing')
            .or('email.neq."",phone.neq.""')
            .limit(1);

        if (response.isEmpty) {
          await Future.delayed(const Duration(minutes: 5));
          continue;
        }

        final lead = response[0];

        if (lead['email'] != null && lead['email'].toString().isNotEmpty) {
          await supabase.from('leads').update({'status': 'Processing'}).eq('id', lead['id']);

          final profiles = await supabase.from('profiles').select('*').limit(1);
          if (profiles.isNotEmpty) {
            final profile = profiles[0];
            String outreachMsg = lead['last_msg'] ?? "Hi, I noticed your business and wanted to reach out regarding our services.";

            await Future.delayed(_getRandomDelay());

            bool success = await sendAutoEmail(
              toEmail: lead['email'],
              content: outreachMsg,
              userEmail: profile['gmail'],
              appPass: profile['whatsapp_number'],
              senderName: profile['owner_name'] ?? 'LeadFlow AI',
            );

            if (success) {
              await supabase.from('leads').update({
                'status': 'Contacted',
                'last_msg': outreachMsg,
                'last_msg_date': DateTime.now().toUtc().toIso8601String(),
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              }).eq('id', lead['id']);
            } else {
              await supabase.from('leads').update({'status': 'Analyzing'}).eq('id', lead['id']);
            }
          }
        } else {
          await supabase.from('leads').update({'status': 'Phone Found'}).eq('id', lead['id']);
        }

      } catch (e) {
        debugPrint("❌ Error: $e");
        await Future.delayed(const Duration(minutes: 1));
      }
    }
  }

  static Future<bool> sendAutoEmail({
    required String toEmail,
    required String content,
    required String userEmail,
    required String appPass,
    required String senderName,
  }) async {
    if (toEmail.isEmpty || !toEmail.contains('@')) return false;

    final smtpServer = gmail(userEmail, appPass);
    final message = Message()
      ..from = Address(userEmail, senderName)
      ..recipients.add(toEmail)
      ..subject = 'Business Collaboration Inquiry'
      ..text = content;

    try {
      await send(message, smtpServer);
      return true;
    } catch (e) {
      debugPrint('❌ Email failed: $e');
      return false;
    }
  }

  static Future<void> processNewLeads(Map<String, dynamic> profile) async {
    final leads = await supabase.from('leads').select().eq('status', 'Analyzing').limit(10);
    for (var lead in leads) {
      await _processSingleLead(lead, true, lead['source'] ?? "Discovery", profile);
    }
  }

  static Future<void> _processSingleLead(dynamic lead, bool autoReply, String source, Map<String, dynamic> profile) async {
    String title = lead['title'] ?? lead['name'] ?? 'Lead';
    String? email = lead['email'];
    String? phone = lead['phoneNumber'] ?? lead['phone'];
    String? website = lead['website'];
    String? location = lead['address'] ?? lead['location'] ?? lead['formatted_address'];
    String category = lead['category'] ?? lead['type'] ?? source;

    debugPrint("🔍 [ULTRA-SCAN] Target: $title");

    // --- 1. Deep Email Hunting ---
    if (email == null || email.isEmpty || !email.contains('@')) {
      email = await findEmailForBusiness(title, website);
    }

    // --- 2. Deep Phone Hunting ---
    if (phone == null || phone.isEmpty) {
      phone = await findPhoneForBusiness(title, website);
    }

    // --- 3. Deep Address Hunting ---
    if (location == null || location.isEmpty || location == 'N/A' || location == 'Address not found') {
      location = await findAddressForBusiness(title, website);
    }

    Map<String, dynamic> leadData = {
      'user_id': profile['id'],
      'name': title,
      'role': category,
      'email': (email != null && email.contains('@')) ? email.toLowerCase().trim() : '',
      'phone': phone ?? '',
      'source': source,
      'address': (location != null && location.length > 5) ? location : 'Global/Online',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      if (leadData['email'].isNotEmpty) {
        await Future.delayed(_getRandomDelay());
        String aiMessage = await AIHandler.generateEmail(
          targetName: title,
          targetBusiness: category,
          targetLocation: leadData['address'],
        );

        bool isSent = await sendAutoEmail(
          toEmail: leadData['email'],
          content: aiMessage,
          userEmail: profile['gmail'] ?? '',
          appPass: profile['whatsapp_number'] ?? '',
          senderName: profile['owner_name'] ?? 'LeadFlow AI',
        );

        leadData['status'] = isSent ? 'Contacted' : 'Analyzing';
        leadData['last_msg'] = aiMessage;
        leadData['sent_from'] = profile['gmail'];
        if (isSent) {
          leadData['last_msg_date'] = DateTime.now().toUtc().toIso8601String();
        }
      } else if (leadData['phone'].isNotEmpty) {
        leadData['status'] = 'Phone Found';
      } else {
        leadData['status'] = 'Analyzing';
      }

      final res = await supabase.from('leads').upsert(leadData).select('id').single();

      if (leadData['status'] == 'Contacted') {
        await supabase.from('lead_logs').insert({
          'lead_id': res['id'],
          'type': 'Outreach',
          'msg': leadData['last_msg'],
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
      debugPrint("✅ [ULTRA-SCAN] Completed: $title");
    } catch (e) {
      debugPrint("❌ [ULTRA-SCAN] Error: $e");
    }
  }

  static Future<String?> findEmailForBusiness(String name, String? website) async {
    final emailRegex = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}');

    // Strategy 1: Direct Scrape with User-Agent
    if (website != null && website.startsWith('http')) {
      try {
        final headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'};
        final response = await http.get(Uri.parse(website), headers: headers).timeout(const Duration(seconds: 10));
        final matches = emailRegex.allMatches(response.body);
        if (matches.isNotEmpty) {
          String? bestEmail = _pickBestEmail(matches.map((m) => m.group(0)!).toList());
          if (bestEmail != null) return bestEmail;
        }

        // Try Contact Page
        if (response.body.toLowerCase().contains('contact')) {
          final contactMatch = RegExp(r'href="([^"]*contact[^"]*)"', caseSensitive: false).firstMatch(response.body);
          if (contactMatch != null) {
            String contactUrl = contactMatch.group(1)!;
            if (!contactUrl.startsWith('http')) {
              Uri base = Uri.parse(website);
              contactUrl = "${base.scheme}://${base.host}${contactUrl.startsWith('/') ? '' : '/'}$contactUrl";
            }
            final contactRes = await http.get(Uri.parse(contactUrl), headers: headers).timeout(const Duration(seconds: 7));
            final contactMatches = emailRegex.allMatches(contactRes.body);
            if (contactMatches.isNotEmpty) return _pickBestEmail(contactMatches.map((m) => m.group(0)!).toList());
          }
        }
      } catch (_) {}
    }

    // Strategy 2: Targeted Search Queries
    List<String> queries = [
      "\"$name\" email",
      "\"$name\" official @gmail.com",
      "\"$name\" contact @outlook.com"
    ];

    if (website != null && website.contains('.')) {
      String domain = website.replaceAll(RegExp(r'https?://(www\.)?'), '').split('/').first;
      queries.add("site:$domain \"@\"");
    }

    for (var q in queries) {
      final searchRes = await HunterService.huntLeads(q);
      for (var res in searchRes) {
        String data = "${res['snippet']} ${res['title']}";
        final matches = emailRegex.allMatches(data);
        if (matches.isNotEmpty) {
          String? bestEmail = _pickBestEmail(matches.map((m) => m.group(0)!).toList());
          if (bestEmail != null) return bestEmail;
        }
      }
    }
    return null;
  }

  static String? _pickBestEmail(List<String> emails) {
    for (var email in emails) {
      final e = email.toLowerCase();
      if (e.contains('sentry') || e.contains('wix') || e.contains('example') || e.contains('png') || e.contains('jpg')) continue;
      return email;
    }
    return emails.isNotEmpty ? emails.first : null;
  }

  static Future<String?> findPhoneForBusiness(String name, String? website) async {
    final phoneRegex = RegExp(r'(\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}');
    if (website != null && website.startsWith('http')) {
      try {
        final response = await http.get(Uri.parse(website)).timeout(const Duration(seconds: 7));
        final matches = phoneRegex.allMatches(response.body);
        if (matches.isNotEmpty) return matches.first.group(0);
      } catch (_) {}
    }
    final searchRes = await HunterService.huntLeads("\"$name\" phone contact");
    for (var result in searchRes) {
      final matches = phoneRegex.allMatches("${result['snippet']} ${result['title']}");
      if (matches.isNotEmpty) return matches.first.group(0);
    }
    return null;
  }

  static Future<String?> findAddressForBusiness(String name, String? website) async {
    // Try Google Maps style search
    final searchRes = await HunterService.huntLeads("\"$name\" address location", platform: 'Google Maps');
    for (var result in searchRes) {
      if (result['formatted_address'] != null) return result['formatted_address'];
      if (result['address'] != null) return result['address'];
      String snippet = result['snippet'] ?? '';
      if (snippet.contains(',') && snippet.length > 15) return snippet.split('...').first.trim();
    }
    return null;
  }

  static Future<void> runAutoFollowUp() async {
    final threeDaysAgo = DateTime.now().toUtc().subtract(const Duration(days: 3)).toIso8601String();
    try {
      // Embedded profiles(*) select nahi kar sakte — leads aur profiles
      // dono sirf auth.users ko refer karte hain, ek dusre ko nahi.
      final List<dynamic> pending = await supabase
          .from('leads')
          .select('*')
          .eq('status', 'Contacted')
          .lte('updated_at', threeDaysAgo);

      for (var lead in pending) {
        if (lead['user_id'] == null) continue;

        final profile = await supabase
            .from('profiles')
            .select('*')
            .eq('id', lead['user_id'])
            .maybeSingle();

        if (profile == null) continue;

        await Future.delayed(_getRandomDelay());
        String followUpMsg = await AIHandler.generateFollowUp(
          targetName: lead['name'],
          previousMsg: lead['last_msg'] ?? "",
        );

        bool isSent = await sendAutoEmail(
          toEmail: lead['email'],
          content: followUpMsg,
          userEmail: profile['gmail'],
          appPass: profile['whatsapp_number'],
          senderName: profile['owner_name'],
        );

        if (isSent) {
          await supabase.from('leads').update({
            'status': 'Followed Up',
            'last_msg': followUpMsg,
            'last_msg_date': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', lead['id']);

          await supabase.from('lead_logs').insert({
            'lead_id': lead['id'],
            'type': 'Follow-up',
            'msg': followUpMsg,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          });
        }
      }
    } catch (e) {
      debugPrint("❌ Follow-up error: $e");
    }
  }

  static Future<void> processLeadsWithDelay(List<dynamic> leads, Map<String, dynamic> profile, {bool autoReply = true, String source = "Google Maps"}) async {
    int count = 0;
    for (var lead in leads) {
      if (count >= 10) break;
      await _processSingleLead(lead, autoReply, source, profile);
      count++;
    }
  }

  static Future<void> launchAgent({
    required String query,
    required List<String> platforms,
    bool autoReply = true,
    bool notifyWhatsApp = true,
    bool notifyGmail = false,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final profile = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();
    if (profile == null) return;

    for (var platform in platforms) {
      String enhancedQuery = "$query \"owner\" OR \"CEO\"";
      final results = await HunterService.huntLeads(enhancedQuery, platform: platform, huntOwners: true);
      if (results.isNotEmpty) {
        await processLeadsWithDelay(results, profile, autoReply: autoReply, source: platform);
      }
    }
  }
}
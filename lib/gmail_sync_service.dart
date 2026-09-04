import 'dart:async';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ai_handler.dart';
import 'agent_service.dart';

/// =====================================================================
/// GMAIL <-> APP TWO-WAY SYNC
/// =====================================================================
/// Kya karta hai:
/// 1. IMAP se Gmail inbox check karta hai (recent emails).
/// 2. Agar sender ka email kisi 'lead' se match karta hai, us reply ko
///    `lead_logs` table mein type='Reply' se insert karta hai.
///    -> Yehi row ChatScreen/ChatListScreen ke Supabase realtime stream
///       mein automatically show ho jati hai (already wired in your UI).
/// 3. Agar us lead pe "AI Take Over" (ai_takeover = true) nahi hai, to
///    AI (Gemini) khud smart reply generate karke Gmail se bhej deta hai.
///
/// Duplicate-safe: har poll pe hum sirf recent N emails check karte hain,
/// aur insert se pehle check karte hain ke wahi msg text pehle se log
/// nahi hai (IMAP \Seen flag pe depend nahi karte — version ke hisab se
/// unreliable ho sakta hai).
///
/// REQUIRED:
/// 1. pubspec.yaml mein add karo:
///      enough_mail: ^2.1.6
///    phir: flutter pub get
///
/// 2. Supabase SQL editor mein ye column add karo (agar already nahi hai):
///      ALTER TABLE leads ADD COLUMN IF NOT EXISTS ai_takeover boolean DEFAULT false;
///
/// 3. Gmail App Password use karo (2FA on karke Google App Passwords se
///    16-digit password generate karo) — normal Gmail password IMAP ke
///    liye kaam nahi karega. Same app password jo profiles.whatsapp_number
///    field mein already save hai (jaisa sendAutoEmail mein use hota hai).
/// =====================================================================
class GmailSyncService {
  static final supabase = Supabase.instance.client;
  static bool _isSyncing = false;

  /// Kitne recent emails har poll pe check karne hain
  static const int _messagesToCheck = 20;

  /// Manual ya periodic call ke liye. Ek waqt mein sirf ek sync chalti hai.
  static Future<void> syncInbox(Map<String, dynamic> profile) async {
    if (_isSyncing) {
      debugPrint("⏳ Gmail sync already in progress, skipping...");
      return;
    }
    _isSyncing = true;

    final String? gmailAddress = profile['gmail'];
    final String? appPassword = profile['whatsapp_number']; // reused field, same as AgentService.sendAutoEmail

    if (gmailAddress == null || gmailAddress.isEmpty || appPassword == null || appPassword.isEmpty) {
      debugPrint("⚠️ Gmail sync skipped: gmail/app-password missing in profile");
      _isSyncing = false;
      return;
    }

    final client = ImapClient(isLogEnabled: false);

    try {
      await client.connectToServer('imap.gmail.com', 993, isSecure: true);
      await client.login(gmailAddress, appPassword);
      await client.selectInbox();

      // Recent emails fetch karo (PEEK = seen/unseen flag ko touch nahi karta)
      final fetchResult = await client.fetchRecentMessages(
        messageCount: _messagesToCheck,
        criteria: 'BODY.PEEK[]',
      );

      for (final message in fetchResult.messages) {
        await _processIncomingMessage(message, profile);
      }

      await client.logout();
    } catch (e) {
      debugPrint("❌ GmailSyncService error: $e");
      try {
        await client.logout();
      } catch (_) {}
    }

    _isSyncing = false;
  }

  /// Ek incoming email ko match karke lead_logs mein daalta hai,
  /// aur zarurat ho to AI se auto-reply trigger karta hai.
  static Future<void> _processIncomingMessage(
      MimeMessage message, Map<String, dynamic> profile) async {
    try {
      final fromAddress = (message.from != null && message.from!.isNotEmpty)
          ? message.from!.first.email.toLowerCase().trim()
          : null;
      if (fromAddress == null || fromAddress.isEmpty) return;

      // Apna hi bheja hua email ya profile ka apna address ignore karo
      if (fromAddress == (profile['gmail'] ?? '').toString().toLowerCase()) return;

      // Is email address wala lead dhoondo (sirf isi user ke leads mein)
      final leadRes = await supabase
          .from('leads')
          .select('*')
          .eq('email', fromAddress)
          .eq('user_id', profile['id'])
          .maybeSingle();

      if (leadRes == null) return; // reply from someone not in our leads

      String body = message.decodeTextPlainPart() ??
          message.decodeTextHtmlPart() ??
          '(no content)';
      body = _stripQuotedReply(body).trim();
      if (body.isEmpty) body = '(empty message)';

      // Duplicate check — same lead, same message text already logged?
      final existing = await supabase
          .from('lead_logs')
          .select('id')
          .eq('lead_id', leadRes['id'])
          .eq('type', 'Reply')
          .eq('msg', body)
          .limit(1);

      if (existing.isNotEmpty) {
        return; // already processed this exact reply, skip
      }

      // 1. Reply ko lead_logs mein daalo -> ChatScreen mein khud show ho jayega
      await supabase.from('lead_logs').insert({
        'lead_id': leadRes['id'],
        'type': 'Reply',
        'msg': body,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      // 2. leads table update karo (status + last message + chat list ke liye)
      await supabase.from('leads').update({
        'status': 'Replied',
        'last_msg': body,
        'last_msg_type': 'Reply',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', leadRes['id']);

      debugPrint("📩 New reply logged from ${leadRes['name']} ($fromAddress)");

      // 3. Agar user ne "Take Over" nahi kiya, AI khud reply karega
      final bool aiTakeover = leadRes['ai_takeover'] == true;
      if (!aiTakeover) {
        await _sendAiReply(leadRes, body, profile);
      } else {
        debugPrint("🙋 AI takeover ON for ${leadRes['name']} — skipping auto-reply");
      }
    } catch (e) {
      debugPrint("❌ Error processing incoming message: $e");
    }
  }

  /// Gmail reply chains ("On ... wrote:", "> quoted text") ko hata deta
  /// hai taake AI ko sirf nayi reply ka clean text mile.
  static String _stripQuotedReply(String body) {
    final lines = body.split('\n');
    final buffer = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('>')) break;
      if (trimmed.startsWith('On ') && trimmed.contains('wrote:')) break;
      if (trimmed.contains('-----Original Message-----')) break;
      buffer.add(line);
    }
    final result = buffer.join('\n').trim();
    return result.isEmpty ? body.trim() : result;
  }

  /// AI se context-aware reply generate karke Gmail se bhejta hai,
  /// aur outreach ko bhi lead_logs mein log karta hai.
  static Future<void> _sendAiReply(
      Map<String, dynamic> lead, String incomingMsg, Map<String, dynamic> profile) async {
    try {
      await Future.delayed(AgentService.randomDelay());

      final aiReply = await AIHandler.generateSmartReply(
        targetName: lead['name'] ?? 'there',
        targetBusiness: lead['role'] ?? '',
        incomingMessage: incomingMsg,
      );

      final sent = await AgentService.sendAutoEmail(
        toEmail: lead['email'],
        content: aiReply,
        userEmail: profile['gmail'] ?? '',
        appPass: profile['whatsapp_number'] ?? '',
        senderName: profile['owner_name'] ?? 'LeadFlow AI',
      );

      if (sent) {
        await supabase.from('lead_logs').insert({
          'lead_id': lead['id'],
          'type': 'Outreach',
          'msg': aiReply,
          'created_at': DateTime.now().toIso8601String(),
        });

        await supabase.from('leads').update({
          'status': 'Contacted',
          'last_msg': aiReply,
          'last_msg_type': 'Outreach',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', lead['id']);

        debugPrint("🤖 AI auto-replied to ${lead['name']}");
      } else {
        debugPrint("❌ AI auto-reply failed to send for ${lead['name']}");
      }
    } catch (e) {
      debugPrint("❌ AI auto-reply error: $e");
    }
  }
}
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ai_handler.dart';
import 'agent_service.dart';

final supabase = Supabase.instance.client;

class LeadsLogService {
  
  // لاگ ریکارڈ کرنے اور 'leads' ٹیبل میں 'last_msg_date' اپ ڈیٹ کرنے کا مرکزی میتھڈ
  static Future<void> logActivity({
    required String leadId,
    required String type, // 'initial_email', 'outreach', یا 'follow_up'
    required String message,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();

      // 1. lead_logs ٹیبل میں ہسٹری کے لیے اینٹری
      await supabase.from('lead_logs').insert({
        'lead_id': leadId,
        'type': type,
        'msg': message,
        'created_at': now,
      });

      // 2. اہم: leads ٹیبل میں اسٹیٹس اور خاص طور پر last_msg_date اپ ڈیٹ کرنا
      // یہ تاریخ ہی طے کرے گی کہ اگلا فالو اپ کب ہونا ہے
      await supabase.from('leads').update({
        'status': (type == 'initial_email' || type == 'outreach') ? 'Contacted' : 'followed_up',
        'last_msg_date': now, // یہ 3 دن والے لاجک کے لیے کریٹیکل ہے
        'last_msg': message,   // آخری میسج کا مواد بھی محفوظ کریں
        'updated_at': now,
      }).eq('id', leadId);

      print("✅ Activity logged: Status and last_msg_date updated for Lead ID: $leadId");
    } catch (e) {
      print("❌ Error logging activity: $e");
    }
  }
}

// 3 دن پرانی تاریخ چیک کرنے کا ہیلپر فنکشن
bool isThreeDaysOld(String? dateStr) {
  if (dateStr == null) return false;
  final lastDate = DateTime.tryParse(dateStr);
  if (lastDate == null) return false;
  return DateTime.now().difference(lastDate).inDays >= 3;
}

// Lead ListTile UI وجیٹ
Widget buildLeadLogTile(Map<String, dynamic> lead) {
  bool needsFollowUp = (lead['status'] == 'sent' || lead['status'] == 'Contacted') && 
                      isThreeDaysOld(lead['last_msg_date']);

  return ListTile(
    title: Text(lead['name'] ?? 'Unknown Lead', style: const TextStyle(fontWeight: FontWeight.bold)),
    subtitle: Text("Status: ${lead['status']}"),
    trailing: needsFollowUp
      ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange.shade700, 
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            "Follow-up Ready", 
            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
          ),
        )
      : const Icon(Icons.check_circle, color: Colors.green),
  );
}

// 1. پہلے یہ فنکشن بنائیں جو 3 دن پرانی لیڈز نکالے
Future<void> processFollowUps() async {
  final now = DateTime.now();
  final threeDaysAgo = now.subtract(const Duration(days: 3)).toIso8601String();

  // وہ لیڈز نکالیں جنہیں 3 دن پہلے میل بھیجی تھی اور اسٹیٹس 'sent' یا 'Contacted' ہے
  final response = await supabase
      .from('leads')
      .select()
      .filter('status', 'in', '("sent", "Contacted")')
      .lte('last_msg_date', threeDaysAgo); 

  if (response != null && response is List) {
    for (var lead in response) {
      await sendUniqueFollowUp(lead);
    }
  }
}

// 2. یونیک میسج بنانے اور بھیجنے کا فنکشن
Future<void> sendUniqueFollowUp(Map lead) async {
  // Gemini سے یونیک فالو اپ لکھوائیں
  final prompt = """
    Write a unique, short follow-up email for ${lead['name']} from ${lead['industry'] ?? lead['role'] ?? 'their business'}. 
    Previous message was sent 3 days ago. 
    Focus on their specific pain point: ${lead['address'] ?? 'business growth'}.
    Keep it professional but different from the first one.
    Max 3 sentences. No subject line.
  """;

  // ai_handler استعمال کرتے ہوئے یونیک مواد حاصل کریں
  String uniqueMsg = await AIHandler.generateContent(prompt);

  if (uniqueMsg.isEmpty) return;

  // ای میل بھیجنے کے لیے پروفائل سے ڈیٹا حاصل کریں
  final profileRes = await supabase
      .from('profiles')
      .select()
      .eq('id', lead['user_id'])
      .maybeSingle();
  
  if (profileRes != null) {
    bool success = await AgentService.sendAutoEmail(
      toEmail: lead['email'],
      content: uniqueMsg,
      userEmail: profileRes['gmail'],
      appPass: profileRes['whatsapp_number'], 
      senderName: profileRes['owner_name'] ?? 'LeadFlow AI',
    );

    if (success) {
      // LeadsLogService کا استعمال کرتے ہوئے لاگ کریں اور last_msg_date اپ ڈیٹ کریں
      await LeadsLogService.logActivity(
        leadId: lead['id'].toString(),
        type: 'follow_up',
        message: uniqueMsg,
      );
    }
  }
}

// فالو اپ والی لیڈز فیچ کرنے کا فنکشن
Future<List<Map<String, dynamic>>> fetchFollowUpLeads() async {
  // ہم نے جو SQL View بنایا تھا 'leads_needing_followup' اسے کال کریں
  final response = await supabase
      .from('leads_needing_followup')
      .select();
  
  return List<Map<String, dynamic>>.from(response);
}

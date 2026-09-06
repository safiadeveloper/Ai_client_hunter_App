import 'dart:math';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AIHandler {
  // ⚠️ SECURITY NOTE: Ye key hardcoded hai. Production mein isko
  // .env file (flutter_dotenv package) ya Supabase secrets mein
  // move kar dena, warna key leak ho sakti hai agar app/code public ho.
  static const String _apiKey = 'AIzaSyDtjc84x4aBeJoWTCGq6TDvIsZXJuVRQaA';

  // ---------------------------------------------------------------
  // 1) BASIC CONTENT GENERATION (unchanged)
  // ---------------------------------------------------------------
  static Future<String> generateContent(String prompt) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      return response.text?.trim() ?? "";
    } catch (e) {
      return "";
    }
  }

  // ---------------------------------------------------------------
  // 2) EMAIL GENERATION (unchanged logic, same as before)
  // ---------------------------------------------------------------
  static Future<String> generateEmail({
    required String targetName,
    required String targetBusiness,
    required String targetLocation,
    String? previousContext,
    bool isFollowUp = false,
  }) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return "User not logged in";

    try {
      // 1. پروفائل ڈیٹا حاصل کرنا
      final myData = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (myData == null) return "Profile data not found";

      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );

      List<dynamic> servicesList = myData['services'] ?? [];
      String servicesStr = servicesList.isNotEmpty
          ? servicesList.join(', ')
          : "Professional Business Solutions";

      String prompt = "";

      if (isFollowUp) {
        prompt = """
        Context: You are an AI Outreach Specialist for ${myData['business_name']}. 
        Services we offer: $servicesStr.
        
        Task: Write a short, polite follow-up email to $targetName from $targetBusiness.
        Last Context: $previousContext

        Requirements:
        - MAKE IT UNIQUE: Every email must have a slightly different tone and structure.
        - Keep it human-like and friendly (not like a bot).
        - Max 3 sentences.
        - Tone: Helpful, not pushy.
        - Do not include subject lines, just the body text.
        - VARIATION: Use different opening styles (e.g., "Just following up...", "Checking in regarding...", "Hope your week is going well...")
        """;
      } else {
        prompt = """
        Context: You are an AI Business Development Agent for ${myData['business_name']}. 
        Services: $servicesStr.
        
        Task: Write a highly personalized, unique "Cold Outreach" email to $targetName at $targetBusiness located in $targetLocation.

        Requirements:
        - UNIQUE CONTENT: Do not use a template. Re-phrase every time.
        - Hook: Mention their business or location in a way that feels organic.
        - Value: Explain how $servicesStr can specifically solve a problem for them.
        - Call to Action: Ask for a 2-minute chat.
        - Length: Max 50-60 words.
        - Style: Professional yet conversational. 
        - IMPORTANT: Provide ONLY the email body text.
        - DIVERSITY: Change the writing style (e.g., Direct, Story-based, Problem-solving focused) to ensure every lead gets a unique message.
        """;
      }

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      if (response.text == null || response.text!.isEmpty) {
        return "Hi $targetName, I'm interested in working with your business $targetBusiness. Can we talk?";
      }

      return response.text!.trim();
    } catch (e) {
      return "Hi $targetName, I noticed $targetBusiness in $targetLocation and was impressed with your work. I'd love to discuss how our services can help you grow. Are you available for a quick chat?";
    }
  }

  // ---------------------------------------------------------------
  // NEW: SMART REPLY — jab lead khud reply karta hai (Gmail se ya
  // WhatsApp se), ye function us reply ko padh kar context-aware
  // jawab likhta hai (sirf generic follow-up nahi).
  // ---------------------------------------------------------------
  static Future<String> generateSmartReply({
    required String targetName,
    required String targetBusiness,
    required String incomingMessage,
  }) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      return "Thanks for getting back to me, $targetName! I'll follow up shortly.";
    }

    try {
      final myData = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (myData == null) {
        return "Thanks for your reply, $targetName! Let's continue this conversation.";
      }

      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );

      List<dynamic> servicesList = myData['services'] ?? [];
      String servicesStr = servicesList.isNotEmpty
          ? servicesList.join(', ')
          : "Professional Business Solutions";

      String prompt = """
      Context: You are an AI Outreach Specialist for ${myData['business_name']}.
      Services we offer: $servicesStr.
      You previously reached out to $targetName from $targetBusiness${targetBusiness.isNotEmpty ? '' : ''}.

      The lead just replied with this message:
      \"$incomingMessage\"

      Task: Write a natural, human-like reply that directly responds to what they said.
      Requirements:
      - If they asked a question, answer it helpfully using the services info above.
      - If they showed interest, propose a quick 2-minute call and ask for a good time.
      - If they declined or said not interested, thank them politely, don't push further.
      - If the message is unclear or off-topic, respond politely and steer back to how you can help.
      - Max 3-4 sentences.
      - Sound like a real person replying, not a bot. No subject line.
      - Do not repeat the exact wording of previous emails.
      """;

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      if (response.text == null || response.text!.isEmpty) {
        return "Thanks for your reply, $targetName! What would be a good time for a quick chat?";
      }

      return response.text!.trim();
    } catch (e) {
      return "Thanks for getting back to me, $targetName! Let's find a time to continue this conversation.";
    }
  }

  static Future<String> generateFollowUp({
    required String targetName,
    String? targetBusiness,
    required String previousMsg,
  }) async {
    return generateEmail(
      targetName: targetName,
      targetBusiness: targetBusiness ?? "your business",
      targetLocation: "",
      previousContext: previousMsg,
      isFollowUp: true,
    );
  }

  static Future<String> generatePitch({
    required String targetName,
    required String targetBusiness,
    required String targetLocation,
  }) async {
    return generateEmail(
      targetName: targetName,
      targetBusiness: targetBusiness,
      targetLocation: targetLocation,
    );
  }

  // ---------------------------------------------------------------
  // 3) NEW: SAVE ALL LEADS TO DATABASE (fixes "10 leads mile but
  //    DB mein sab show nahi hote")
  //
  //    - upsert() use kiya hai (insert ki jagah) taake duplicate
  //      lead pe silently skip na ho.
  //    - Har lead individually try/catch mein hai taake ek lead
  //      fail ho to baaki 9 phir bhi save ho jayen.
  // ---------------------------------------------------------------
  static Future<int> saveLeadsToDatabase(
      List<Map<String, dynamic>> leads) async {
    final supabase = Supabase.instance.client;
    int savedCount = 0;

    for (final lead in leads) {
      try {
        // Ensure default status field so contact loop can filter later
        lead.putIfAbsent('status', () => 'new');
        await supabase.from('leads').upsert(lead);
        savedCount++;
      } catch (e) {
        // ye print sirf debug ke liye hai, production mein logger use karo
        print('❌ Failed to save lead "${lead['business_name']}": $e');
      }
    }

    print('✅ Saved $savedCount / ${leads.length} leads to database');
    return savedCount;
  }

  // ---------------------------------------------------------------
  // 4) NEW: CONTACT ALL LEADS ONE BY ONE (fixes "sirf 1-2 leads ko
  //    hi contact hota hai")
  //
  //    - Sequential loop (await ke sath) — parallel nahi, is liye
  //      koi bhi call silently drop nahi hoti.
  //    - Har lead ke baad 30-60 sec ka RANDOM delay — spam trigger
  //      se bachne ke liye.
  //    - sendEmailFn: apna actual mail-sending function yahan pass
  //      karo (SMTP / mailer package / email API / Supabase edge
  //      function — jo bhi tum currently use kar rahe ho).
  // ---------------------------------------------------------------
  static Future<void> contactAllLeads({
    required List<Map<String, dynamic>> leads,
    required Future<bool> Function(String toEmail, String body) sendEmailFn,
  }) async {
    final supabase = Supabase.instance.client;
    final rand = Random();
    int contactedCount = 0;

    for (final lead in leads) {
      final name = lead['name'] ?? 'there';
      final business = lead['business_name'] ?? 'your business';
      final location = lead['location'] ?? '';
      final email = lead['email'];
      final id = lead['id'];

      if (email == null || email.toString().isEmpty) {
        print('⚠️ Skipping lead "$business" — no email address');
        continue;
      }

      try {
        // Har lead ke liye unique, personalized email generate karo
        final emailBody = await generatePitch(
          targetName: name,
          targetBusiness: business,
          targetLocation: location,
        );

        final sent = await sendEmailFn(email, emailBody);

        if (sent && id != null) {
          await supabase.from('leads').update({
            'status': 'contacted',
            'contacted_at': DateTime.now().toIso8601String(),
          }).eq('id', id);
        }

        contactedCount++;
        print('📧 Contacted $business ($contactedCount/${leads.length})');
      } catch (e) {
        print('❌ Error contacting "$business": $e');
        // continue loop, ek lead fail ho to baaki na rukein
      }

      // Last lead ke baad delay ki zarurat nahi
      if (lead != leads.last) {
        // 30 sec se 60 sec ke beech random gap (30/40/50/60)
        final delaySec = 30 + rand.nextInt(31); // 30–60
        print('⏳ Waiting ${delaySec}s before next email...');
        await Future.delayed(Duration(seconds: delaySec));
      }
    }

    print('✅ Done: contacted $contactedCount / ${leads.length} leads');
  }
}
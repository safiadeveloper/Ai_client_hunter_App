import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'agent_service.dart';

class ChatScreen extends StatefulWidget {
  final String userName;
  final String userRole;
  final String leadId;

  const ChatScreen({
    super.key,
    required this.userName,
    required this.userRole,
    required this.leadId
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  // true = AI ko is lead ke liye auto-reply/follow-up karne se rok do
  // (user manually control le raha hai). false = AI khud replies bhejega.
  bool _aiTakeover = false;
  bool _loadingTakeover = true;

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
    _loadTakeoverState();
    _syncGmailForThisChat();
  }

  /// Chat khulte hi turant Gmail check karo (2-min background wait ke
  /// bina) — taake Gmail se abhi-abhi bheja/aaya hua msg foran dikhe.
  Future<void> _syncGmailForThisChat() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final profile = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (profile != null) {
        await AgentService.syncGmailNow(profile);
      }
    } catch (e) {
      debugPrint("Chat-open Gmail sync error: $e");
    }
  }

  Future<void> _loadTakeoverState() async {
    try {
      final leadIdInt = int.tryParse(widget.leadId);
      final res = await supabase
          .from('leads')
          .select('ai_takeover')
          .eq('id', leadIdInt ?? widget.leadId)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _aiTakeover = res?['ai_takeover'] == true;
          _loadingTakeover = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading AI takeover state: $e");
      if (mounted) setState(() => _loadingTakeover = false);
    }
  }

  Future<void> _toggleTakeover(bool value) async {
    setState(() => _aiTakeover = value);
    try {
      final leadIdInt = int.tryParse(widget.leadId);
      await supabase
          .from('leads')
          .update({'ai_takeover': value})
          .eq('id', leadIdInt ?? widget.leadId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value
                ? "You've taken over — AI will pause auto-replies for this chat"
                : "AI is back in control of this chat"),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error updating AI takeover: $e");
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final leadIdInt = int.tryParse(widget.leadId);
      await supabase
          .from('lead_logs')
          .update({'is_read': true})
          .eq('lead_id', leadIdInt ?? widget.leadId)
          .eq('type', 'Reply')
          .eq('is_read', false);
    } catch (e) {
      debugPrint("Error marking as read: $e");
    }
  }

  Future<void> _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final leadIdInt = int.tryParse(widget.leadId);

      // 1. Get Lead info (no embedded profiles(*) — leads and profiles
      //    both reference auth.users separately, there's no FK between
      //    leads and profiles directly, so embedding always fails)
      final leadRes = await supabase
          .from('leads')
          .select('*')
          .eq('id', leadIdInt ?? widget.leadId)
          .maybeSingle();

      if (leadRes != null && leadRes['email'] != null && leadRes['user_id'] != null) {
        // 1b. Fetch the owning profile separately
        final profile = await supabase
            .from('profiles')
            .select('*')
            .eq('id', leadRes['user_id'])
            .maybeSingle();

        if (profile == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Profile not found for this lead."))
            );
          }
          setState(() => _isSending = false);
          return;
        }

        // 2. Send Real Email
        bool sent = await AgentService.sendAutoEmail(
          toEmail: leadRes['email'],
          content: text,
          userEmail: profile['gmail'],
          appPass: profile['whatsapp_number'],
          senderName: profile['owner_name'] ?? 'Me',
        );

        if (sent) {
          // 3. Log in database
          await supabase.from('lead_logs').insert({
            'lead_id': leadIdInt ?? widget.leadId,
            'type': 'Manual',
            'msg': text,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          });

          // 4. Update last_msg in leads
          await supabase.from('leads').update({
            'last_msg': text,
            'last_msg_type': 'Manual',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', leadIdInt ?? widget.leadId);

          _messageController.clear();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Email sending failed. Please check Gmail settings."))
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Send Error: $e");
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final leadIdQuery = int.tryParse(widget.leadId) ?? widget.leadId;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.userName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(widget.userRole, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          if (!_loadingTakeover)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Text(
                    _aiTakeover ? "You" : "AI",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _aiTakeover ? Colors.orange : const Color(0xFF007AFF),
                    ),
                  ),
                  Switch(
                    value: _aiTakeover,
                    onChanged: _toggleTakeover,
                    activeColor: Colors.orange,
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              // Stream logs directly
              stream: supabase
                  .from('lead_logs')
                  .stream(primaryKey: ['id'])
                  .eq('lead_id', leadIdQuery)
                  .order('created_at', ascending: true),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final logs = snapshot.data ?? [];

                if (logs.isEmpty) {
                  return FutureBuilder<Map<String, dynamic>?>(
                    future: supabase.from('leads').select().eq('id', leadIdQuery).maybeSingle(),
                    builder: (context, leadSnapshot) {
                      if (leadSnapshot.hasData && leadSnapshot.data?['last_msg'] != null) {
                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _buildMessageBubble(
                              text: leadSnapshot.data!['last_msg'],
                              time: "",
                              isMe: leadSnapshot.data!['last_msg_type'] == 'Manual',
                              type: leadSnapshot.data!['last_msg_type'] ?? 'Outreach',
                            )
                          ],
                        );
                      }
                      return const Center(child: Text("No messages yet."));
                    },
                  );
                }

                // If new replies come while screen is open, mark them as read
                final hasUnread = logs.any((log) => log['type'] == 'Reply' && log['is_read'] == false);
                if (hasUnread) {
                  _markMessagesAsRead();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final bool isMe = log['type'] == 'Manual';

                    return _buildMessageBubble(
                      text: log['msg'] ?? "",
                      time: log['created_at'] != null
                          ? DateFormat('hh:mm a').format(DateTime.parse(log['created_at']).toLocal())
                          : "",
                      isMe: isMe,
                      type: log['type'] ?? 'Message',
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({required String text, required String time, required bool isMe, required String type}) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF007AFF) : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(type, style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.blue, fontWeight: FontWeight.bold)),
                if (time.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(time, style: TextStyle(color: isMe ? Colors.white60 : Colors.grey, fontSize: 10)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: !_isSending,
              decoration: InputDecoration(
                hintText: "Reply to Gmail...",
                filled: true,
                fillColor: Colors.grey.withAlpha(20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _isSending
              ? const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(
            icon: const Icon(Icons.send, color: Color(0xFF007AFF)),
            onPressed: _handleSendMessage,
          ),
        ],
      ),
    );
  }
}
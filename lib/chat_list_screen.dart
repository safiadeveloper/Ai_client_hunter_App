import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';
import 'agent_service.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final supabase = Supabase.instance.client;
  String _searchQuery = '';
  DateTime? _selectedDate;
  bool _isSyncing = false;

  /// Gmail inbox ko turant check karo (2-min auto loop ka wait kiye bina)
  Future<void> _syncGmailNow() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Gmail synced — checking for new replies"), duration: Duration(seconds: 2)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sync failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  /// Har lead ke liye unread reply count fetch karta hai
  /// (lead_logs mein 'Reply' type jo abhi tak dekhe nahi gaye)
  Future<Map<String, int>> _getUnreadCounts(List<Map<String, dynamic>> leads) async {
    if (leads.isEmpty) return {};
    final ids = leads.map((l) => l['id']).toList();
    try {
      final logs = await supabase
          .from('lead_logs')
          .select('lead_id, type')
          .inFilter('lead_id', ids)
          .eq('type', 'Reply')
          .eq('is_read', false);

      final Map<String, int> counts = {};
      for (final log in logs) {
        final key = log['lead_id'].toString();
        counts[key] = (counts[key] ?? 0) + 1;
      }
      return counts;
    } catch (_) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Conversations',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.sync),
            tooltip: "Sync Gmail now",
            onPressed: _isSyncing ? null : _syncGmailNow,
          ),
          IconButton(
            icon: Icon(
              Icons.calendar_month,
              color: _selectedDate != null ? Colors.blue : null,
            ),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? DateTime.now(),
                firstDate: DateTime(2023),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (date != null) setState(() => _selectedDate = date);
            },
          ),
          if (_selectedDate != null || _searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.filter_list_off),
              onPressed: () => setState(() {
                _searchQuery = '';
                _selectedDate = null;
              }),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search leads...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.grey.withAlpha(25),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              // updated_at se sort karo — latest activity upar aaye (Gmail style)
              stream: supabase
                  .from('leads')
                  .stream(primaryKey: ['id'])
                  .order('updated_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // TEMP DEBUG — asal error dikhane ke liye, taake pata chale
                // ke data khali hai ya realtime subscribe fail ho rahi hai.
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        "Stream Error:\n${snapshot.error}",
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                var leads = snapshot.data ?? [];

                // updated_at prefer karo, fallback created_at (Gmail style — latest message upar)
                leads.sort((a, b) {
                  final aTime = a['updated_at'] ?? a['created_at'] ?? '';
                  final bTime = b['updated_at'] ?? b['created_at'] ?? '';
                  return bTime.compareTo(aTime);
                });

                // Filters
                if (_searchQuery.isNotEmpty || _selectedDate != null) {
                  leads = leads.where((lead) {
                    final name =
                    (lead['name'] ?? '').toString().toLowerCase();
                    final email =
                    (lead['email'] ?? '').toString().toLowerCase();
                    final bool matchesSearch =
                        _searchQuery.isEmpty ||
                            name.contains(_searchQuery) ||
                            email.contains(_searchQuery);

                    bool matchesDate = true;
                    if (_selectedDate != null &&
                        lead['updated_at'] != null) {
                      final dt =
                      DateTime.parse(lead['updated_at']).toLocal();
                      matchesDate = dt.year == _selectedDate!.year &&
                          dt.month == _selectedDate!.month &&
                          dt.day == _selectedDate!.day;
                    } else if (_selectedDate != null &&
                        lead['created_at'] != null) {
                      final dt =
                      DateTime.parse(lead['created_at']).toLocal();
                      matchesDate = dt.year == _selectedDate!.year &&
                          dt.month == _selectedDate!.month &&
                          dt.day == _selectedDate!.day;
                    }
                    return matchesSearch && matchesDate;
                  }).toList();
                }

                if (leads.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No leads found.'
                          : 'No matches found.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }

                // Unread counts bhi saath fetch karo
                return FutureBuilder<Map<String, int>>(
                  future: _getUnreadCounts(leads),
                  builder: (context, unreadSnapshot) {
                    final unreadCounts = unreadSnapshot.data ?? {};

                    return ListView.separated(
                      itemCount: leads.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 72,
                        color: Colors.grey.withAlpha(40),
                      ),
                      itemBuilder: (context, index) {
                        final lead = leads[index];
                        final String name = lead['name'] ?? 'Unknown Lead';
                        final String lastMsg = lead['last_msg'] ??
                            lead['email'] ??
                            'No message history';
                        final String status = lead['status'] ?? 'New';
                        final String leadId = lead['id'].toString();
                        final int unread = unreadCounts[leadId] ?? 0;

                        // Time: updated_at prefer karo (last activity time)
                        final String timeStr = _formatTime(
                          lead['updated_at'] ?? lead['created_at'],
                        );

                        // Last message sender prefix
                        final String msgPrefix =
                        _getLastMsgPrefix(lead['last_msg_type']);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                userName: name,
                                userRole: lead['source'] ?? 'Lead',
                                leadId: lead['id'].toString(),
                              ),
                            ),
                          ),
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                _getStatusColor(status).withAlpha(30),
                                child: Text(
                                  name.isNotEmpty
                                      ? name[0].toUpperCase()
                                      : 'L',
                                  style: TextStyle(
                                    color: _getStatusColor(status),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // Online indicator (reply aaya hai)
                              if (unread > 0)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: unread > 0
                                        ? FontWeight.w900
                                        : FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: unread > 0
                                      ? Colors.blue
                                      : Colors.grey,
                                  fontWeight: unread > 0
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$msgPrefix$lastMsg',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: unread > 0
                                        ? Colors.black87
                                        : Colors.black.withAlpha(150),
                                    fontWeight: unread > 0
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (unread > 0)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    unread > 9 ? '9+' : '$unread',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status)
                                        .withAlpha(20),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: _getStatusColor(status),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Message ka prefix dikhao (sender kaun tha)
  String _getLastMsgPrefix(String? lastMsgType) {
    switch (lastMsgType) {
      case 'Manual':
        return 'You: ';
      case 'Reply':
        return ''; // Lead ne reply kiya — no prefix (bold se pata lagta hai)
      case 'Follow-up':
        return 'AI: ';
      case 'Outreach':
        return 'AI: ';
      default:
        return '';
    }
  }

  /// Time format: aaj ka ho to time dikhao, warna date
  String _formatTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dtDay = DateTime(dt.year, dt.month, dt.day);

      if (dtDay == today) {
        return DateFormat('hh:mm a').format(dt);
      } else if (dtDay == today.subtract(const Duration(days: 1))) {
        return 'Yesterday';
      } else {
        return DateFormat('dd/MM/yy').format(dt);
      }
    } catch (_) {
      return '';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Contacted':
        return Colors.blue;
      case 'Followed Up':
        return Colors.green;
      case 'Analyzed':
        return Colors.orange;
      case 'Replied':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
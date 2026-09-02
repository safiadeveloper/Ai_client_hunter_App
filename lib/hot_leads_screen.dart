import 'package:flutter/material.dart';

class HotLeadsScreen extends StatelessWidget {
  const HotLeadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Map<String, String>> hotLeads = [
      {
        "name": "Usman Ali",
        "role": "CEO @ TechFlow",
        "email": "usman@techflow.io",
        "phone": "+923001234567",
        "chat": "AI: Hi, I noticed you're scaling... Lead: Yes, we need help with automation. Can we talk today?",
        "avatar": "https://i.pravatar.cc/150?u=1"
      },
      {
        "name": "Sara Khan",
        "role": "Marketing Head @ Global-X",
        "email": "sara.k@globalx.com",
        "phone": "+923219876543",
        "chat": "AI: Our tool can save 40% time. Lead: That's interesting, send me the proposal on WhatsApp.",
        "avatar": "https://i.pravatar.cc/150?u=2"
      },
      {
        "name": "Zubair Ahmed",
        "role": "Founder @ Khi-Startups",
        "email": "zubair@khistartups.pk",
        "phone": "+923335554443",
        "chat": "Lead: Can you integrate this with our current CRM? AI: Yes, we support 50+ CRMs.",
        "avatar": "https://i.pravatar.cc/150?u=3"
      }
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('🔥 Hot Leads'),
        actions: [
          IconButton(
            onPressed: () => _notifyOwnerGlobally(context), 
            icon: const Icon(Icons.notifications_active_rounded, color: Colors.orange)
          )
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        itemCount: hotLeads.length,
        itemBuilder: (context, index) {
          final lead = hotLeads[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withAlpha(10) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFF34C759).withOpacity(0.3), 
                width: 2
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28, 
                      backgroundImage: NetworkImage(lead['avatar']!),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(lead['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          Text(lead['role']!, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    _buildActionChip(
                      icon: Icons.flash_on_rounded, 
                      label: "98% Match", 
                      color: Colors.orange
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : const Color(0xFFF2F2F7), 
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
                  ),
                  child: Text(
                    "\"${lead['chat']}\"",
                    style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13, height: 1.4),
                  ),
                ),
                const SizedBox(height: 20),
                const Text("Quick Response Actions:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildContactButton(
                        context,
                        icon: Icons.mail_outline_rounded,
                        label: "Gmail",
                        color: Colors.redAccent,
                        onTap: () => _handleContactAction(context, lead, "Email", lead['email']!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildContactButton(
                        context,
                        icon: Icons.chat_outlined,
                        label: "WhatsApp",
                        color: Colors.green,
                        onTap: () => _handleContactAction(context, lead, "WhatsApp", lead['phone']!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () => _notifyOwnerSingle(context, lead['name']!),
                          icon: const Icon(Icons.notification_add_rounded, size: 18),
                          label: const Text("NOTIFY OWNER", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade800,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () {
                             ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Success! AI Agent handed over the control to you."))
                            );
                          },
                          icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                          label: const Text("TAKE OVER", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007AFF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildContactButton(BuildContext context, {required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  void _handleContactAction(BuildContext context, Map<String, String> lead, String method, String target) {
    // 1. Notify Client
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Message sent to ${lead['name']} via $method!"),
        backgroundColor: Colors.blueGrey.shade900,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // 2. Automatically notify owner as requested
    _notifyOwnerSingle(context, lead['name']!);
  }

  void _notifyOwnerSingle(BuildContext context, String clientName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.priority_high_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Owner Notified: Contact $clientName immediately. They are highly interested!",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade900,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _notifyOwnerGlobally(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Push Notifications Sent"),
        content: const Text("All high-priority leads have been pushed to the owner's mobile and email for immediate follow-up."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Understood")),
        ],
      ),
    );
  }
}

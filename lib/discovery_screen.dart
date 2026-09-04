import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';

class LeadLog {
  final String type;
  final String msg;
  final String time;

  LeadLog({required this.type, required this.msg, required this.time});

  factory LeadLog.fromMap(Map<String, dynamic> map) {
    return LeadLog(
      type: map['type'] ?? '',
      msg: map['msg'] ?? '',
      time: map['created_at'] ?? map['time'] ?? '',
    );
  }
}

class DiscoveryLead {
  final String id;
  final String name;
  final String role;
  final String email;
  final String phone;
  final String address;
  final String status;
  final String? sentFrom;
  final String? createdAt;
  final List<LeadLog> logs;

  DiscoveryLead({
    required this.id,
    required this.name,
    required this.role,
    required this.email,
    required this.phone,
    required this.address,
    required this.status,
    this.sentFrom,
    this.createdAt,
    required this.logs,
  });

  factory DiscoveryLead.fromMap(Map<String, dynamic> map, List<dynamic>? logData) {
    return DiscoveryLead(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? 'Unknown',
      role: map['role'] ?? 'N/A',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      status: map['status'] ?? 'Analyzing',
      sentFrom: map['sent_from'],
      createdAt: map['created_at'],
      logs: (logData ?? []).map((l) => LeadLog.fromMap(l)).toList(),
    );
  }
}

class DiscoveryLeadsScreen extends StatefulWidget {
  const DiscoveryLeadsScreen({super.key});

  @override
  State<DiscoveryLeadsScreen> createState() => _DiscoveryLeadsScreenState();
}

class _DiscoveryLeadsScreenState extends State<DiscoveryLeadsScreen> {
  DateTime? _selectedDate;
  final supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discovery Pipeline'),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today, color: _selectedDate != null ? Colors.blue : null),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? DateTime.now(),
                firstDate: DateTime(2023),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (date != null) {
                setState(() {
                  _selectedDate = date;
                });
              }
            },
          ),
          if (_selectedDate != null)
            IconButton(
              icon: const Icon(Icons.filter_list_off),
              onPressed: () => setState(() => _selectedDate = null),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('leads')
            .stream(primaryKey: ['id'])
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          var leadsData = snapshot.data ?? [];
          
          // Map to DiscoveryLead objects
          List<DiscoveryLead> leads = leadsData.map((item) {
            return DiscoveryLead.fromMap(item, item['lead_logs'] ?? []);
          }).toList();

          // Date Filter
          if (_selectedDate != null) {
            leads = leads.where((lead) {
              if (lead.createdAt == null) return false;
              final dt = DateTime.parse(lead.createdAt!).toLocal();
              return dt.year == _selectedDate!.year &&
                     dt.month == _selectedDate!.month &&
                     dt.day == _selectedDate!.day;
            }).toList();
          }

          if (leads.isEmpty) {
            return const Center(child: Text("No leads found."));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            itemCount: leads.length,
            itemBuilder: (context, index) {
              final lead = leads[index];
              final String formattedTime = lead.createdAt != null
                  ? DateFormat('MMM d, hh:mm a').format(DateTime.parse(lead.createdAt!).toLocal())
                  : '';

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        userName: lead.name,
                        userRole: lead.role,
                        leadId: lead.id,
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withAlpha(10) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0xFF007AFF).withOpacity(0.1),
                            child: const Icon(Icons.business_rounded, color: Color(0xFF007AFF), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(lead.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                                Text(formattedTime, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _getStatusColor(lead.status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              lead.status,
                              style: TextStyle(color: _getStatusColor(lead.status), fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(height: 1),
                      ),
                      
                      _buildContactRow(Icons.email_outlined, lead.email, Colors.redAccent),
                      const SizedBox(height: 8),
                      _buildContactRow(Icons.phone_outlined, lead.phone, Colors.green),
                      const SizedBox(height: 8),
                      _buildContactRow(Icons.location_on_outlined, lead.address, Colors.orange),
                      
                      if (lead.sentFrom != null && lead.sentFrom!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 26, top: 8),
                          child: Text(
                            "Sent via: ${lead.sentFrom}",
                            style: const TextStyle(fontSize: 10, color: Color(0xFF007AFF), fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Contacted': return Colors.blue;
      case 'Followed Up': return Colors.green;
      case 'Analyzed': return Colors.orange;
      case 'Phone Found': return Colors.purple;
      default: return Colors.grey;
    }
  }

  Widget _buildContactRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text.isEmpty ? 'Not found' : text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

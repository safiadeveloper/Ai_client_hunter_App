import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_service.dart';

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  final supabase = Supabase.instance.client;
  late TextEditingController _ownerNameController;
  late TextEditingController _businessNameController;
  late TextEditingController _categoryController;
  late TextEditingController _appPassController; // Maps to whatsapp_number (Gmail App Password)
  late TextEditingController _gmailController;
  final List<TextEditingController> _serviceControllers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _ownerNameController = TextEditingController();
    _businessNameController = TextEditingController();
    _categoryController = TextEditingController();
    _appPassController = TextEditingController();
    _gmailController = TextEditingController();
    
    _loadProfileFromSupabase();
  }

  Future<void> _loadProfileFromSupabase() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final data = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();
        if (data != null) {
          setState(() {
            _ownerNameController.text = data['owner_name'] ?? "";
            _businessNameController.text = data['business_name'] ?? "";
            _gmailController.text = data['gmail'] ?? "";
            _appPassController.text = data['whatsapp_number'] ?? "";
            _categoryController.text = data['business_category'] ?? "";
            
            final List<dynamic> services = data['services'] ?? [];
            _serviceControllers.clear();
            for (var service in services) {
              _serviceControllers.add(TextEditingController(text: service.toString()));
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveToSupabase() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final services = _serviceControllers.map((c) => c.text).where((t) => t.isNotEmpty).toList();
        
        // Update Supabase
        await supabase.from('profiles').upsert({
          'id': user.id, // Rule: Always pass ID
          'owner_name': _ownerNameController.text,
          'business_name': _businessNameController.text,
          'business_category': _categoryController.text,
          'whatsapp_number': _appPassController.text, // Rule: Gmail App Password in whatsapp_number
          'gmail': _gmailController.text,
          'services': services,
        });
        
        // Rule: Sync with ProfileService.updateProfile
        ProfileService.updateProfile(BusinessProfile(
          ownerName: _ownerNameController.text,
          businessName: _businessNameController.text,
          businessCategory: _categoryController.text,
          whatsappNumber: _appPassController.text,
          gmail: _gmailController.text,
          services: services,
        ));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Saved & Synced!")));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving profile: $e")));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _ownerNameController.dispose();
    _businessNameController.dispose();
    _categoryController.dispose();
    _appPassController.dispose();
    _gmailController.dispose();
    for (var controller in _serviceControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addService() {
    setState(() {
      _serviceControllers.add(TextEditingController());
    });
  }

  void _removeService(int index) {
    setState(() {
      _serviceControllers[index].dispose();
      _serviceControllers.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Business Profile'),
        actions: [
          IconButton(onPressed: _isLoading ? null : _saveToSupabase, icon: const Icon(Icons.check_rounded, color: Color(0xFF007AFF)))
        ],
      ),
      body: _isLoading && _ownerNameController.text.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Personal Info", Icons.person_outline_rounded),
            const SizedBox(height: 16),
            _buildTextField("Owner Name", _ownerNameController, Icons.face_rounded, isDark),
            const SizedBox(height: 16),
            _buildTextField("Gmail App Password", _appPassController, Icons.vpn_key_rounded, isDark, obscureText: true),
            const SizedBox(height: 16),
            _buildTextField("Gmail Address", _gmailController, Icons.alternate_email_rounded, isDark, keyboardType: TextInputType.emailAddress),
            
            const SizedBox(height: 32),
            _buildSectionHeader("Business Context", Icons.business_center_outlined),
            const SizedBox(height: 16),
            _buildTextField("Business Name", _businessNameController, Icons.business_rounded, isDark),
            const SizedBox(height: 16),
            _buildTextField("Category (e.g. SaaS)", _categoryController, Icons.category_rounded, isDark),
            
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader("Our Services", Icons.auto_awesome_rounded),
                TextButton.icon(
                  onPressed: _addService, 
                  icon: const Icon(Icons.add, size: 18), 
                  label: const Text("Add Service")
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._serviceControllers.asMap().entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTextField("Service Name", entry.value, Icons.star_outline_rounded, isDark),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _removeService(entry.key),
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                  )
                ],
              ),
            )),
            
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveToSupabase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("SAVE PROFILE FOR AI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                "AI will use this data to pitch clients on your behalf.",
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF007AFF)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, bool isDark, {TextInputType? keyboardType, bool obscureText = false}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: isDark ? Colors.white.withAlpha(10) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), 
          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade100)
        ),
        labelStyle: const TextStyle(fontSize: 14),
      ),
    );
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  static bool currentUserIsAdmin = false;

  static Future<void> checkAdminStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      currentUserIsAdmin = false;
      return;
    }

    try {
      // چیک کریں کہ کیا یوزر پروفائل میں ایڈمن فلیگ ہے
      final res = await Supabase.instance.client
          .from('profiles')
          .select('is_admin')
          .eq('id', user.id)
          .maybeSingle();

      if (res != null && res['is_admin'] == true) {
        currentUserIsAdmin = true;
      } else {
        currentUserIsAdmin = false;
      }
    } catch (e) {
      currentUserIsAdmin = false;
    }
  }
}

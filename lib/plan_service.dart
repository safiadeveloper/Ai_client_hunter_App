import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SubscriptionPlan {
  final String id;
  String title;
  String price;
  List<String> features;
  bool isPopular;

  SubscriptionPlan({
    required this.id,
    required this.title,
    required this.price,
    required this.features,
    this.isPopular = false,
  });
}

class PlanService {
  static final supabase = Supabase.instance.client;
  static ValueNotifier<List<SubscriptionPlan>> plansNotifier = ValueNotifier([
    SubscriptionPlan(
      id: '1',
      title: "Starter",
      price: "19",
      features: ["50 Leads/mo", "Basic AI Filter", "Email Support"],
    ),
    SubscriptionPlan(
      id: '2',
      title: "Pro",
      price: "49",
      features: ["500 Leads/mo", "Advanced AI Agent", "Priority Support", "CRM Export"],
      isPopular: true,
    ),
    SubscriptionPlan(
      id: '3',
      title: "Enterprise",
      price: "149",
      features: ["Unlimited Leads", "Custom AI Training", "Dedicated Manager", "API Access"],
    ),
  ]);

  // 1. ڈیٹا بیس سے پلانز لوڈ کرنا
  static Future<void> fetchPlans() async {
    try {
      final response = await supabase
          .from('subscription_plans')
          .select()
          .order('order_index', ascending: true);

      plansNotifier.value = (response as List).map((data) => SubscriptionPlan(
        id: data['id'].toString(),
        title: data['title'],
        price: data['price'].toString(),
        features: List<String>.from(data['features']),
        isPopular: data['is_popular'] ?? false,
      )).toList();
    } catch (e) {
      debugPrint("Error fetching plans: $e");
    }
  }

  // 2. ڈیٹا بیس میں پلان اپ ڈیٹ کرنا
  static Future<void> updatePlanInSupabase(SubscriptionPlan plan) async {
    try {
      // If it's a real DB record (ID > 1)
      if (plan.id.length > 1) {
        await supabase.from('subscription_plans').update({
          'price': plan.price,
          'features': plan.features,
          'title': plan.title,
        }).eq('id', plan.id);
      }
      
      // Refresh local list
      await fetchPlans();
    } catch (e) {
      debugPrint("Error updating plan: $e");
      rethrow;
    }
  }

  // فیچر ایڈ/ریموو لاجک
  static void addFeature(int planIndex, String feature) {
    plansNotifier.value[planIndex].features.add(feature);
    plansNotifier.notifyListeners();
  }

  static void removeFeature(int planIndex, int featureIndex) {
    plansNotifier.value[planIndex].features.removeAt(featureIndex);
    plansNotifier.notifyListeners();
  }
}

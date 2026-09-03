import 'package:flutter/material.dart';

class BusinessProfile {
  String? id; // Rule: Ensure id is always present for updates
  String ownerName;
  String businessName;
  String businessCategory;
  String whatsappNumber; // Rule: Used to store Gmail App Password
  String gmail;
  List<String> services;

  BusinessProfile({
    this.id,
    this.ownerName = "Usman Ali",
    this.businessName = "TechFlow AI",
    this.businessCategory = "SaaS & Automation",
    this.whatsappNumber = "",
    this.gmail = "contact@techflow.io",
    this.services = const ["Lead Generation", "AI Chatbots", "CRM Integration"],
  });
}

class ProfileService {
  static final ValueNotifier<BusinessProfile> profileNotifier = ValueNotifier(BusinessProfile());

  static void updateProfile(BusinessProfile newProfile) {
    profileNotifier.value = newProfile;
    profileNotifier.notifyListeners();
  }
}

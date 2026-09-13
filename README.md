# Ai_client_hunter_App🚀
Autonomous AI lead-generation &amp; outreach app — hunts leads, writes personalized emails with Gemini, and syncs replies two-way with Gmail (Flutter + Supabase).


**Autonomous AI-powered lead generation & outreach app built with Flutter, Supabase, and Google Gemini.**

LeadFlow AI hunts for business leads across multiple platforms, automatically writes and sends personalized cold outreach emails, syncs replies two-way with Gmail, and lets AI take over (or hand back to you) conversations in real time — all from your phone.

---

## ✨ Features

- **AI Lead Hunter (HunterService)** — queries the [Serper.dev](https://serper.dev) Google Search/Places API with platform-specific `site:` search queries (Google Maps, LinkedIn, Facebook, Instagram, TikTok, Yellow Pages, Yelp, Reddit, Clutch, Crunchbase) to discover business leads, then uses regex to extract emails and phone numbers from the results.
- **Advanced Hunting Modules** — social scraper, LinkedIn decision-maker enrichment, and a Local SEO Hunter that flags businesses with low ratings.
- **AI Outreach Engine (Gemini)** — generates unique, human-like cold emails and follow-ups personalized to each lead and your business profile.
- **Two-Way Gmail Sync** — incoming replies are pulled into the app automatically; AI can auto-reply, or you can flip "AI Takeover" to reply manually.
- **Discovery Pipeline & Hot Leads** — track lead status, filter by date, and surface your highest-intent leads for quick action.
- **In-App Chat** — a real-time chat view per lead backed by Supabase, showing the full email/message history.
- **Auto Follow-Ups** — leads that go quiet for 3+ days automatically get a fresh, unique follow-up message.
- **Business Profile** — store your business info, services, and Gmail credentials so the AI always pitches on-brand.
- **Subscription Plans & Admin Dashboard** — built-in plan management, revenue/user stats, and feature toggles for admins.
- **Background Agent** — runs continuously (via WorkManager) to hunt and follow up even when the app is closed.

---

## 🛠️ Tech Stack

- **Flutter** — cross-platform mobile app
- **Supabase** — database, auth, and realtime sync
- **Google Gemini** (`google_generative_ai`) — AI content generation
- **enough_mail** — Gmail IMAP sync for reading replies
- **mailer** — sending outreach emails via SMTP
- **workmanager** — background task scheduling

---

## 📋 Requirements

- Flutter SDK `>=3.10.1`
- A Supabase project (URL + anon key)
- A Gmail account with an **App Password** (2FA enabled)
- A Google Gemini API key
- A [Serper.dev](https://serper.dev) API key (powers the lead search/hunting engine)

---

## ⚙️ Setup

1. Clone the repo:
   ```bash
   git clone https://github.com/<your-username>/leadflow-ai.git
   cd leadflow-ai
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Add your Supabase URL/anon key in `main.dart`.
4. Add your Gemini API key in `ai_handler.dart` — **do not commit real keys**; move these to environment variables or Supabase secrets before publishing.
5. Run the app:
   ```bash
   flutter run
   ```

---

## ⚠️ Security Note

This project currently has some credentials (Gemini API key, Serper.dev API key, Supabase keys) referenced directly in source for development convenience. **Before pushing to a public repo, move all secrets to a `.env` file or secure secrets manager** and add that file to `.gitignore`.

---

## 📄 License

This project is currently unlicensed. Add a license file if you plan to open-source it.

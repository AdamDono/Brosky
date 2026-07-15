# BRO 🤝

**The digital corner store for real connection.**

Building BRO: Where Guys Actually Connect

I'm 8 weeks away from launching my first consumer app, and I'm building it completely in public.

📱 What is BRO?

BRO is a location-based voice platform that connects guys in real-time based on shared interests and what they're actually into—not profiles, follower counts, or status.

Think: A digital barbershop meets your best group chat.

🎯 The Opportunity:

Professional networking is broken for our generation:
• LinkedIn is for job hunting, not real connection
• WhatsApp groups go silent after a week  
• Coffee meetings take 2 weeks to schedule
• You're surrounded by people but don't know who to actually talk to

We're solving for spontaneous, high-quality connection.

💡 How It Works:

1. Open the app → Pick your vibe (Business, Sports, Tech, Fitness)
2. Get matched with a Bro nearby or globally who's online right now
3. Voice chat, text, or join group "Huddles" (up to 5 people)
4. Post to the Feed: "Launching my SaaS next week, who wants to review?"

Real-time. Real people. Real conversations.

🔒 Quality Control:

• Post-interaction ratings (toxic users auto-banned)
• 16+ verification
• Community moderation
• Premium tier (R30/month) for serious networkers

🛠️ Tech Stack (For the Builders):

• Flutter (iOS + Android from one codebase)
• Supabase (PostgreSQL + real-time + PostGIS for location)
• ZegoCloud (voice infrastructure)
• PayStack/Stripe (payments)

📊 Why I'm Building This:

I've lived in 3 cities in 5 years. Every time I move, I ask the same question:

"Where are the guys who are building, training, and actually doing things?"

BRO is the answer I wish I had.

🌍 The Plan:

• Week 1-4: MVP (Onboarding, Feed, Voice)
• Week 5-8: Beta (100 users in Joburg, CT, Durban)
• Week 9-12: Public launch (South Africa → Global)

I'm sharing everything:
✅ Weekly code updates
✅ User interviews
✅ Revenue numbers
✅ Failures and pivots

🤝 How You Can Help:

• Follow for updates
• Share with guys in your network who'd vibe with this
• DM me if you want beta access (launching in 8 weeks)

Let's build something real.

#BuildInPublic #StartupJourney #Flutter #TechForGood #Networking #SouthAfrica
```

---

---

> 🚧 **Building in Public** 🚧  
> This project is being built in 12 weeks. Follow the journey on [X (Twitter)](https://x.com/Adam_Dono_) or [LinkedIn](https://www.linkedin.com/in/adam-dono-85b766242/).

---

## 🚀 The Stack
- **Framework:** Flutter (Mobile - iOS & Android)
- **Backend:** Supabase (Auth, Database, Realtime, Edge Functions)
- **Push Server:** Google Firebase Cloud Messaging (FCM)
- **Voice Infrastructure:** ZegoCloud (Live Audio Rooms)
- **State Management:** Riverpod

## 🛠 Features (MVP)
- **Vibe Check:** Pick what you want to talk about (Sports, Gaming, Life, Business).
- **The Radar:** Find active Bros within 5km.
- **Huddles:** Drop-in audio rooms to discuss topics live.
- **Bro Feed:** Low-pressure text/image posts to see what's happening nearby.
- **Direct Messaging:** Live chat threads supporting real-time messages, typing indicators, read receipts, and voice notes.
- **Block Moderation:** Full bidirectional block enforcement filtering feeds, discovery list, active inbox threads, and chat screens. Includes a **Blocked Users** screen in settings to manage blocks.

## 📁 Repository Structure
- `lib/` — Flutter source code files.
- `android/` — Native Android configurations.
- `ios/` — Native iOS configurations.
- `supabase/` — Database migrations and trigger edge functions (FCM trigger).
- `docs/` — App marketing strategy guides, wireframes, and launch documentation.

## 📦 Running Locally

1. **Clone the repo**
   ```bash
   git clone https://github.com/AdamDono/Brosky.git
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```


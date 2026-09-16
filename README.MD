# Host Me Ke 🇰🇪

A full-stack property listing platform for Kenya — Hostays, rentals, and properties for sale — with M-Pesa payments and Supabase as the database.

---

## Project Structure

```
hostmeke/
├── index.html          ← Frontend (open this in a browser)
├── database.sql        ← Run this in Supabase SQL Editor
├── README.md
└── server/             ← Express backend (M-Pesa)
    ├── index.js
    ├── .env            ← Your secret keys (never commit this)
    ├── package.json
    └── routes/
        └── mpesa.js
```

---

## Step 1 — Set Up the Database (Supabase)

1. Go to **https://supabase.com** and open your project
2. Click **SQL Editor** in the left sidebar
3. Paste the entire contents of `database.sql` and click **Run**
4. This creates all tables, security rules, and seed data

---

## Step 2 — Get Your M-Pesa Credentials

1. Go to **https://developer.safaricom.co.ke**
2. Create an account and click **Add a New App**
3. Enable the **Lipa Na M-Pesa Sandbox** API
4. Copy your **Consumer Key** and **Consumer Secret**
5. Go to **APIs → Lipa Na M-Pesa** to find your **Passkey** and **Shortcode** (174379 for sandbox)

---

## Step 3 — Configure the Server

Edit `server/.env` and fill in your real values:

```env
MPESA_CONSUMER_KEY=paste_your_key_here
MPESA_CONSUMER_SECRET=paste_your_secret_here
MPESA_SHORTCODE=174379
MPESA_PASSKEY=paste_your_passkey_here
MPESA_ENV=sandbox

MPESA_CALLBACK_URL=https://your-server.com/api/mpesa/callback

SUPABASE_URL=https://vbcihvuckuzxfyaswphr.supabase.co
SUPABASE_SERVICE_KEY=your_service_role_key_here
```

To get your **Supabase Service Key**:
- Go to Supabase → Project Settings → API
- Copy the **service_role** key (not the anon key)

---

## Step 4 — Run the Server

```bash
cd server
npm install
npm start
```

You should see: `✅ Server running on http://localhost:3000`

For development with auto-reload:
```bash
npm run dev
```

---

## Step 5 — Open the Frontend

Just open `index.html` in your browser. No build step needed.

---

## Testing M-Pesa (Sandbox)

Use Safaricom's sandbox test number: **254708374149**
Any 6-digit PIN works in sandbox mode.

---

## Going Live

1. In `server/.env` change `MPESA_ENV=production`
2. Replace your sandbox credentials with live Daraja credentials
3. Update `MPESA_CALLBACK_URL` to your real public server URL
4. In `index.html` update: `const MPESA_API = 'https://your-live-server.com'`

For the callback to work, your server must be publicly reachable over HTTPS.
Free hosting options: **Railway**, **Render**, **Fly.io**

---

## Features

| Feature | How it works |
|---------|-------------|
| Auth (login/signup/Google) | Supabase Auth |
| Property listings | Supabase `properties` table |
| Become a Host | Saves to Supabase, visible after listing |
| Wishlist (❤️) | Supabase `wishlist` table, per user |
| My Bookings | Supabase `bookings` table |
| M-Pesa payment | Express server → Safaricom Daraja API |
| Payment confirmed | Safaricom callback → Express → Supabase |

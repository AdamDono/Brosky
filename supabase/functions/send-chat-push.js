// Supabase Edge Function: send-chat-push
// Place this inside your Supabase project's Edge Functions directory.
//
// To deploy, follow: https://supabase.com/docs/guides/functions/deploy
//
// This function listens to database triggers (e.g., on INSERT inside direct_messages),
// reads the receiver's fcm_token from public.profiles, and sends a push notification via FCM.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const serviceAccount = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "{}");

serve(async (req) => {
  try {
    const payload = await req.json();
    
    // Check if event is an INSERT trigger
    if (payload.type !== 'INSERT') {
      return new Response("Not an INSERT event", { status: 200 });
    }

    const message = payload.record;
    const receiverId = message.receiver_id;
    const senderId = message.sender_id;

    // Initialize Supabase Client
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // 1. Fetch sender profile
    const { data: senderProfile } = await supabaseClient
      .from('profiles')
      .select('username')
      .eq('id', senderId)
      .single();

    // 2. Fetch receiver profile FCM Token
    const { data: receiverProfile } = await supabaseClient
      .from('profiles')
      .select('fcm_token')
      .eq('id', receiverId)
      .single();

    const fcmToken = receiverProfile?.fcm_token;
    if (!fcmToken) {
      return new Response("Receiver has no FCM token registered", { status: 200 });
    }

    const senderUsername = senderProfile?.username ?? "Bro";

    // 3. Generate OAuth2 token for Firebase REST API v1
    const accessToken = await getAccessToken(serviceAccount);

    // 4. Send FCM Push Notification
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token: fcmToken,
            notification: {
              title: senderUsername,
              body: message.content.startsWith('[voice_note]') ? "🎤 Sent a voice message" : message.content,
            },
            data: {
              sender_id: senderId,
              click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
          },
        }),
      }
    );

    const result = await response.json();
    return new Response(JSON.stringify(result), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    });
  }
});

// Helper function to get an OAuth2 Access Token for Firebase Service Account using Web Crypto API
async function getAccessToken(serviceAccount) {
  const jwt = await createSignedJWT(
    serviceAccount.client_email,
    serviceAccount.private_key,
    "https://oauth2.googleapis.com/token",
    ["https://www.googleapis.com/auth/firebase.messaging"]
  );

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const data = await res.json();
  return data.access_token;
}

// Signs a JWT assertion for Google authentication
async function createSignedJWT(email, privateKeyPEM, audience, scopes) {
  const header = { alg: "RS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const claimSet = {
    iss: email,
    scope: scopes.join(" "),
    aud: audience,
    exp: now + 3600,
    iat: now,
  };

  const encodedHeader = btoa(JSON.stringify(header));
  const encodedClaimSet = btoa(JSON.stringify(claimSet));
  const tokenInput = `${encodedHeader}.${encodedClaimSet}`;

  // Parse RSA Private Key PEM
  const pemHeader = "-----BEGIN PRIVATE KEY-----";
  const pemFooter = "-----END PRIVATE KEY-----";
  const pem = privateKeyPEM
    .replace(pemHeader, "")
    .replace(pemFooter, "")
    .replace(/\s+/g, "");
  
  const binaryDer = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  
  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    new TextEncoder().encode(tokenInput)
  );

  const encodedSignature = btoa(String.fromCharCode(...new Uint8Array(signature)));
  return `${tokenInput}.${encodedSignature}`;
}

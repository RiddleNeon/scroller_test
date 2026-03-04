import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

Deno.serve(async (req) => {
  const { firebase_token } = await req.json();

  const firebaseResponse = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${Deno.env.get("FIREBASE_API_KEY")}`,
      {
        method: "POST",
        body: JSON.stringify({ idToken: firebase_token }),
      }
  );

  if (!firebaseResponse.ok) {
    return new Response(JSON.stringify({ error: "Invalid Firebase token" }), {
      status: 401,
    });
  }

  const firebaseData = await firebaseResponse.json();
  const firebaseUser = firebaseData.users[0];

  const { data: authUser } = await supabase.auth.admin.getUserByEmail(
      firebaseUser.email
  );

  let supabaseUserId: string;

  if (authUser.user) {
    supabaseUserId = authUser.user.id;
  } else {
    const { data: newUser } = await supabase.auth.admin.createUser({
      email: firebaseUser.email,
      email_confirm: true,
      user_metadata: { firebase_uid: firebaseUser.localId },
    });
    supabaseUserId = newUser.user!.id;

    await supabase.from("profiles").insert({
      id: supabaseUserId,
      display_name: firebaseUser.displayName ?? null,
      avatar_url: firebaseUser.photoUrl ?? null,
    });
  }

  const { data: session } = await supabase.auth.admin.createSession(
      supabaseUserId
  );

  return new Response(JSON.stringify(session), {
    headers: { "Content-Type": "application/json" },
  });
});
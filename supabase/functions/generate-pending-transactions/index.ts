import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req: Request) => {
  const authHeader = req.headers.get("Authorization");
  if (authHeader !== `Bearer ${serviceRoleKey}`) {
    return new Response("Unauthorized", { status: 401 });
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey);
  const today = new Date().toISOString().split("T")[0];

  const { data: schedules, error } = await supabase
    .from("scheduled_transactions")
    .select("*")
    .eq("is_active", true)
    .lte("next_due_date", today);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  let created = 0;

  for (const sched of schedules ?? []) {
    const { error: insertErr } = await supabase.from("transactions").insert({
      user_id: sched.user_id,
      account_id: sched.account_id,
      type: sched.type,
      status: "pending",
      amount: sched.amount,
      currency: sched.currency,
      description: sched.description,
      date: sched.next_due_date,
      scheduled_txn_id: sched.id,
    });

    if (insertErr) continue;

    const nextDate = new Date(sched.next_due_date);
    nextDate.setMonth(nextDate.getMonth() + 1);

    await supabase
      .from("scheduled_transactions")
      .update({ next_due_date: nextDate.toISOString().split("T")[0] })
      .eq("id", sched.id);

    created++;
  }

  return new Response(JSON.stringify({ created }), {
    headers: { "Content-Type": "application/json" },
  });
});

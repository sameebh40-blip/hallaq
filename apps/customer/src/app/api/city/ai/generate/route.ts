import { NextResponse } from "next/server";

import { createSupabaseAdminClient } from "@hallaq/supabase/admin";
import { createAppSupabaseServerClient } from "@/lib/supabase";

type Body = {
  inputImageUrl: string;
  styleKeys: string[];
  demoOnly?: boolean;
};

export async function POST(req: Request) {
  const supabase = await createAppSupabaseServerClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  let body: Body;
  try {
    body = (await req.json()) as Body;
  } catch {
    return NextResponse.json({ error: "invalid_json" }, { status: 400 });
  }

  const inputImageUrl = String(body.inputImageUrl ?? "").trim();
  const styleKeys = Array.from(new Set((body.styleKeys ?? []).map((s) => String(s).trim()).filter(Boolean))).slice(0, 12);

  if (!inputImageUrl || styleKeys.length === 0) {
    return NextResponse.json({ error: "invalid_payload" }, { status: 400 });
  }

  const outputs = styleKeys.map((styleKey) => ({
    styleKey,
    outputImageUrl:
      `https://coresg-normal.trae.ai/api/ide/v1/text_to_image?prompt=${encodeURIComponent(
        `Photorealistic AI haircut preview, men's haircut style ${styleKey}, premium studio lighting, neutral background, high detail`
      )}&image_size=portrait_16_9`
  }));

  if (body.demoOnly) {
    return NextResponse.json({ requestId: null, results: outputs });
  }

  let admin;
  try {
    admin = await createSupabaseAdminClient();
  } catch {
    return NextResponse.json({ requestId: null, results: outputs });
  }

  const { data: requestRow, error: requestError } = await admin
    .from("ai_style_requests")
    .insert({ profile_id: user.id, input_image_url: inputImageUrl, status: "succeeded" })
    .select("id")
    .single();

  if (requestError || !requestRow?.id) {
    return NextResponse.json({ requestId: null, results: outputs });
  }

  const requestId = String(requestRow.id);

  await admin.from("ai_style_results").insert(outputs.map((o) => ({ request_id: requestId, style_key: o.styleKey, output_image_url: o.outputImageUrl })));

  return NextResponse.json({ requestId, results: outputs });
}

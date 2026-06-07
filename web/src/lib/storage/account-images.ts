import { supabase } from "@/lib/supabase/client";

const BUCKET = "account-images";
// Avatars render at most ~64px; cap the stored image well above that for
// retina without wasting the free-tier 1 GB on full-resolution uploads.
const MAX_DIM = 256;

/** Downscale to fit within MAX_DIM and re-encode as WebP to keep files tiny. */
async function resizeToWebp(file: File): Promise<Blob> {
  const bitmap = await createImageBitmap(file);
  try {
    const scale = Math.min(1, MAX_DIM / Math.max(bitmap.width, bitmap.height));
    const width = Math.round(bitmap.width * scale);
    const height = Math.round(bitmap.height * scale);
    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext("2d");
    if (!ctx) throw new Error("Canvas is not supported in this browser");
    ctx.drawImage(bitmap, 0, 0, width, height);
    return await new Promise<Blob>((resolve, reject) =>
      canvas.toBlob(
        (blob) =>
          blob ? resolve(blob) : reject(new Error("Could not encode image")),
        "image/webp",
        0.9,
      ),
    );
  } finally {
    bitmap.close();
  }
}

/** Resize, upload to the current user's folder, and return the public URL. */
export async function uploadAccountImage(file: File): Promise<string> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");

  const blob = await resizeToWebp(file);
  const path = `${user.id}/${crypto.randomUUID()}.webp`;
  const { error } = await supabase.storage
    .from(BUCKET)
    .upload(path, blob, { contentType: "image/webp", upsert: false });
  if (error) throw error;

  return supabase.storage.from(BUCKET).getPublicUrl(path).data.publicUrl;
}

/** Best-effort removal of a previously uploaded image; never throws. */
export async function deleteAccountImage(url: string): Promise<void> {
  const marker = `/${BUCKET}/`;
  const idx = url.indexOf(marker);
  if (idx === -1) return;
  const path = url.slice(idx + marker.length);
  await supabase.storage.from(BUCKET).remove([path]);
}

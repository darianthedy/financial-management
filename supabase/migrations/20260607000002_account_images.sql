-- Custom per-account avatar images.
-- Stored in a public Storage bucket; the public URL is saved on the account row.
ALTER TABLE accounts ADD COLUMN image_url TEXT;

-- Public bucket: reads are open (so <img src> works with a stored permanent URL),
-- but writes are restricted to the owner's own folder via the policies below.
INSERT INTO storage.buckets (id, name, public)
VALUES ('account-images', 'account-images', TRUE)
ON CONFLICT (id) DO NOTHING;

-- Object paths are laid out as `{user_id}/{uuid}.webp`, so the first path
-- segment identifies the owner.
CREATE POLICY "account_images_public_read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'account-images');

CREATE POLICY "account_images_owner_insert"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'account-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "account_images_owner_update"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'account-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "account_images_owner_delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'account-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

import { z } from "zod";

export const accountTypeEnum = z.enum([
  "bank_account",
  "credit_card",
  "digital_wallet",
  "cash",
  "other",
]);

export const accountFormSchema = z.object({
  name: z.string().trim().min(1, "Name is required").max(80),
  type: accountTypeEnum,
  // Display value in major units (e.g. dollars); converted to minor units on submit.
  starting_balance: z
    .number({ message: "Enter a number" })
    .finite("Enter a valid amount"),
  // Resolved public URL of the account's avatar image, or null when unset.
  // Managed by the form (upload happens on submit), not a plain input field.
  image_url: z.string().url().nullable().optional(),
});

export type AccountFormValues = z.infer<typeof accountFormSchema>;

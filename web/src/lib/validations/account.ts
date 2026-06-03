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
  currency: z.string().min(3).max(3),
  // Display value in major units (e.g. dollars); converted to minor units on submit.
  starting_balance: z
    .number({ message: "Enter a number" })
    .finite("Enter a valid amount"),
});

export type AccountFormValues = z.infer<typeof accountFormSchema>;

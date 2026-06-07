import { z } from "zod";

// Scheduled transactions only support income/expense for now: the DB generator
// that turns a due schedule into a `pending` transaction does not copy a
// transfer destination, so a scheduled transfer would produce a one-sided row.
export const scheduledTransactionFormSchema = z.object({
  account_id: z.string().min(1, "Account is required"),
  type: z.enum(["income", "expense"]),
  // Display value in major units (e.g. dollars); converted to minor on submit.
  amount: z
    .number({ message: "Enter an amount" })
    .positive("Amount must be greater than 0"),
  description: z.string().trim().max(200).optional(),
  // Only 'monthly' exists in the recurrence_type enum / generator for now.
  recurrence: z.literal("monthly").default("monthly"),
  next_due_date: z.string().min(1, "Next due date is required"),
  is_active: z.boolean().default(true),
});

export type ScheduledTransactionFormValues = z.infer<
  typeof scheduledTransactionFormSchema
>;

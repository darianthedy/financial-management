import { z } from "zod";

export const transactionFormSchema = z
  .object({
    type: z.enum(["income", "expense", "transfer"]),
    account_id: z.string().uuid("Select an account"),
    transfer_account_id: z.string().nullable().optional(),
    amount: z
      .number({ message: "Enter an amount" })
      .positive("Amount must be greater than 0"),
    currency: z.string().min(3).max(3),
    date: z.string().min(1, "Date is required"),
    description: z.string().max(500).nullable().optional(),
    budget_id: z.string().uuid().nullable().optional(),
    category_ids: z.array(z.string().uuid()).default([]),
    tag_ids: z.array(z.string().uuid()).default([]),
  })
  .superRefine((val, ctx) => {
    if (val.type === "transfer") {
      if (!val.transfer_account_id) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: "Select a destination account",
          path: ["transfer_account_id"],
        });
      } else if (val.transfer_account_id === val.account_id) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: "Source and destination must differ",
          path: ["transfer_account_id"],
        });
      }
    }
  });

export type TransactionFormValues = z.infer<typeof transactionFormSchema>;

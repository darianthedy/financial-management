import { z } from "zod";

// One fixed-expense entry for one month. Amount can be approximate. The row is
// tied to its year_month, set by the page.
export const fixedExpenseFormSchema = z.object({
  name: z.string().trim().min(1, "Name is required").max(100),
  // Display value in major units (e.g. dollars); converted to minor on submit.
  amount: z
    .number({ message: "Enter an amount" })
    .positive("Amount must be greater than 0"),
});

export type FixedExpenseFormValues = z.infer<typeof fixedExpenseFormSchema>;

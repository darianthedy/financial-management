import { z } from "zod";

export const budgetFormSchema = z.object({
  name: z.string().trim().min(1, "Name is required").max(80),
  description: z.string().trim().max(500).optional(),
  // Display value in major units (e.g. dollars); converted to minor units on submit.
  periodic_amount: z
    .number({ message: "Enter an amount" })
    .positive("Amount must be greater than 0"),
});

export type BudgetFormValues = z.infer<typeof budgetFormSchema>;

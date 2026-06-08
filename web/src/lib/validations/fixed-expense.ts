import { z } from "zod";

// One fixed-expense entry for one month. Amount can be approximate. due_day is a
// day-of-month (1–31); the row is tied to its year_month, set by the page.
export const fixedExpenseFormSchema = z.object({
  name: z.string().trim().min(1, "Name is required").max(100),
  // Display value in major units (e.g. dollars); converted to minor on submit.
  amount: z
    .number({ message: "Enter an amount" })
    .positive("Amount must be greater than 0"),
  due_day: z
    .number({ message: "Enter a due day" })
    .int("Due day must be a whole number")
    .min(1, "Due day must be between 1 and 31")
    .max(31, "Due day must be between 1 and 31"),
});

export type FixedExpenseFormValues = z.infer<typeof fixedExpenseFormSchema>;

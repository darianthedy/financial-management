import { useEffect, useRef, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input, Label, FieldError } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { CurrencyAmountInput } from "@/components/shared/currency-amount-input";
import { AccountAvatar } from "@/components/accounts/account-avatar";
import { ACCOUNT_TYPES } from "@/lib/account-types";
import {
  uploadAccountImage,
  deleteAccountImage,
} from "@/lib/storage/account-images";
import {
  accountFormSchema,
  type AccountFormValues,
} from "@/lib/validations/account";
import {
  createAccount,
  updateAccount,
  fetchDefaultAccountId,
  updateDefaultAccountId,
} from "@/lib/hooks/use-accounts";
import type { Account } from "@/lib/types/database";
import { toDisplayAmount, currencyDecimals } from "@/lib/utils/currency";
import { useCurrencies } from "@/lib/hooks/use-currencies";

interface Props {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  account?: Account | null;
  onSaved?: () => void;
}

export function AccountForm({ open, onOpenChange, account, onSaved }: Props) {
  const { defaultCurrency, decimalsFor } = useCurrencies();
  const [submitError, setSubmitError] = useState("");
  const isEdit = !!account;

  // "Default account" preference (stored on user_settings). There is only ever
  // one default, so checking it here replaces whatever was default before.
  // currentDefaultId is the default at open time, so we know whether unchecking
  // should clear it (this account was the default) or leave it alone.
  const [isDefault, setIsDefault] = useState(false);
  const [currentDefaultId, setCurrentDefaultId] = useState<string | null>(null);

  // Image is handled outside react-hook-form: we stage the picked File and a
  // preview URL, then upload on submit (so cancelling never orphans a file).
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [imageRemoved, setImageRemoved] = useState(false);

  function revokePreview() {
    if (imageFile && imagePreview) URL.revokeObjectURL(imagePreview);
  }

  function pickImage(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = ""; // allow re-picking the same file
    if (!file) return;
    revokePreview();
    setImageFile(file);
    setImagePreview(URL.createObjectURL(file));
    setImageRemoved(false);
  }

  function removeImage() {
    revokePreview();
    setImageFile(null);
    setImagePreview(null);
    setImageRemoved(true);
  }

  const {
    register,
    handleSubmit,
    reset,
    watch,
    setValue,
    formState: { errors, isSubmitting },
  } = useForm<AccountFormValues>({
    resolver: zodResolver(accountFormSchema),
    defaultValues: {
      name: "",
      type: "bank_account",
      starting_balance: 0,
      show_on_dashboard: true,
    },
  });

  useEffect(() => {
    if (!open) return;
    reset(
      account
        ? {
            name: account.name,
            type: account.type,
            starting_balance: toDisplayAmount(
              account.starting_balance,
              currencyDecimals(defaultCurrency),
            ),
            show_on_dashboard: account.show_on_dashboard,
          }
        : {
            name: "",
            type: "bank_account",
            starting_balance: 0,
            show_on_dashboard: true,
          },
    );
    setSubmitError("");
    setImageFile(null);
    setImageRemoved(false);
    setImagePreview(account?.image_url ?? null);

    // Reflect the stored default: pre-check the box when editing the account
    // that's currently the default.
    setIsDefault(false);
    setCurrentDefaultId(null);
    fetchDefaultAccountId().then((id) => {
      setCurrentDefaultId(id);
      setIsDefault(!!account && account.id === id);
    });
  }, [open, account, defaultCurrency, reset]);

  // Release any object URL when the form unmounts.
  useEffect(() => () => revokePreview(), []);

  async function onSubmit(values: AccountFormValues) {
    try {
      const decimals = decimalsFor(defaultCurrency);

      const previousUrl = account?.image_url ?? null;
      let image_url = previousUrl;
      if (imageFile) image_url = await uploadAccountImage(imageFile);
      else if (imageRemoved) image_url = null;

      const payload = { ...values, image_url };
      let accountId: string;
      if (account) {
        await updateAccount(account.id, payload, decimals);
        accountId = account.id;
      } else {
        accountId = await createAccount(payload, decimals);
      }

      // Persist the default-account preference. Setting it replaces any prior
      // default; only clear it when this account was the default and got
      // unchecked (never touch another account's default).
      if (isDefault) {
        if (currentDefaultId !== accountId) await updateDefaultAccountId(accountId);
      } else if (currentDefaultId === accountId) {
        await updateDefaultAccountId(null);
      }

      // Drop the replaced/removed image only once the save succeeded.
      if (previousUrl && previousUrl !== image_url) {
        await deleteAccountImage(previousUrl);
      }

      onOpenChange(false);
      onSaved?.();
    } catch (e) {
      setSubmitError(e instanceof Error ? e.message : "Failed to save account");
    }
  }

  const type = watch("type");

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{isEdit ? "Edit account" : "New account"}</DialogTitle>
        </DialogHeader>
        <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-4">
          <div className="flex items-center gap-4">
            <AccountAvatar
              type={type}
              imageUrl={imagePreview}
              name={watch("name")}
              className="h-16 w-16"
              iconClassName="h-7 w-7"
            />
            <div className="flex flex-col gap-1.5">
              <input
                ref={fileInputRef}
                type="file"
                accept="image/png,image/jpeg,image/webp"
                className="hidden"
                onChange={pickImage}
              />
              <div className="flex gap-2">
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={() => fileInputRef.current?.click()}
                >
                  {imagePreview ? "Change" : "Upload image"}
                </Button>
                {imagePreview && (
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    onClick={removeImage}
                  >
                    Remove
                  </Button>
                )}
              </div>
              <p className="text-xs text-[var(--color-muted-foreground)]">
                PNG, JPG, or WebP. Resized to 256px.
              </p>
            </div>
          </div>

          <div className="flex flex-col gap-1.5">
            <Label htmlFor="name">Name</Label>
            <Input id="name" {...register("name")} />
            <FieldError message={errors.name?.message} />
          </div>

          <div className="flex flex-col gap-1.5">
            <Label htmlFor="type">Type</Label>
            <Select
              value={type}
              onValueChange={(v) =>
                setValue("type", v as AccountFormValues["type"])
              }
            >
              <SelectTrigger id="type">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {ACCOUNT_TYPES.map((t) => (
                  <SelectItem key={t.value} value={t.value}>
                    {t.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="flex flex-col gap-1.5">
            <Label htmlFor="starting_balance">Starting balance</Label>
            <CurrencyAmountInput
              id="starting_balance"
              value={watch("starting_balance")}
              decimals={decimalsFor(defaultCurrency)}
              allowNegative
              onChange={(v) =>
                setValue("starting_balance", v, {
                  shouldDirty: true,
                  shouldValidate: !!errors.starting_balance,
                })
              }
            />
            <FieldError message={errors.starting_balance?.message} />
          </div>

          <div className="flex flex-col gap-1.5">
            <label className="flex cursor-pointer items-center gap-2.5 text-sm font-medium">
              <input
                type="checkbox"
                {...register("show_on_dashboard")}
                className="h-4 w-4 cursor-pointer rounded border-[var(--color-input)] accent-[var(--color-primary)]"
              />
              Show on dashboard
            </label>
            <p className="text-xs text-[var(--color-muted-foreground)]">
              When off, this account and its balance are hidden from the
              dashboard's Accounts card.
            </p>
          </div>

          <div className="flex flex-col gap-1.5">
            <label className="flex cursor-pointer items-center gap-2.5 text-sm font-medium">
              <input
                type="checkbox"
                checked={isDefault}
                onChange={(e) => setIsDefault(e.target.checked)}
                className="h-4 w-4 cursor-pointer rounded border-[var(--color-input)] accent-[var(--color-primary)]"
              />
              Set as default account
            </label>
            <p className="text-xs text-[var(--color-muted-foreground)]">
              Pre-selected when you add a new transaction. Only one account can be
              the default.
            </p>
          </div>

          <FieldError message={submitError} />

          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={isSubmitting}>
              {isSubmitting ? "Saving…" : "Save"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

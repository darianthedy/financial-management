import { forwardRef, useEffect, useImperativeHandle, useRef, useState } from "react";
import { Input } from "@/components/ui/input";

interface Props
  extends Omit<
    React.InputHTMLAttributes<HTMLInputElement>,
    "value" | "onChange" | "type"
  > {
  /** Numeric display amount (major units, e.g. 1234.5). */
  value: number;
  /** Called with the parsed numeric value, or NaN while the field is empty. */
  onChange: (value: number) => void;
  /** Decimal places allowed for the selected currency (0 for e.g. IDR). */
  decimals: number;
  /** Show the −/+ sign buttons and allow a negative value (e.g. a refund). */
  allowNegative?: boolean;
}

/** Group the integer part with thousands separators: "1234" -> "1,234". */
function groupInt(intPart: string): string {
  return intPart.replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

/**
 * Parse arbitrary typed input into a clean display string + numeric magnitude.
 * The field itself is number-only — the sign is owned by the −/+ buttons — so
 * anything that isn't a digit or decimal point (including a typed "-") is
 * stripped here.
 */
function parseInput(
  raw: string,
  decimals: number,
): { text: string; value: number } {
  // Keep only digits and dots; drop signs, grouping commas, and anything else.
  let cleaned = raw.replace(/[^\d.]/g, "");
  if (decimals === 0) cleaned = cleaned.replace(/\./g, "");

  const firstDot = cleaned.indexOf(".");
  let intPart: string;
  let fracPart: string;
  let hasDot: boolean;
  if (firstDot === -1) {
    intPart = cleaned;
    fracPart = "";
    hasDot = false;
  } else {
    intPart = cleaned.slice(0, firstDot);
    // Collapse any further dots and cap to the allowed decimal count.
    fracPart = cleaned.slice(firstDot + 1).replace(/\./g, "").slice(0, decimals);
    hasDot = true;
  }

  // Strip leading zeros so the prefilled "0" vanishes once a digit is typed,
  // but keep a lone "0" (e.g. while typing "0.50").
  intPart = intPart.replace(/^0+(?=\d)/, "");

  const groupedInt = groupInt(intPart);
  const text = hasDot ? `${groupedInt}.${fracPart}` : groupedInt;

  const numStr = `${intPart === "" ? "0" : intPart}${fracPart ? `.${fracPart}` : ""}`;
  const value = text === "" ? NaN : Number(numStr);
  return { text, value };
}

/**
 * Display for a value the user isn't actively typing: the magnitude padded to
 * full decimals (1234 -> "1,234.00"). Sign-free — the buttons show it. Zero /
 * empty renders as "" so the placeholder shows a bare "0" — never literal
 * "0.00", which would otherwise sit in the field and swallow typed digits into
 * the fraction part.
 */
function settledText(value: number, decimals: number): string {
  if (!Number.isFinite(value) || value === 0) return "";
  const fixed = Math.abs(value).toFixed(decimals);
  const [i, f] = fixed.split(".");
  const grouped = groupInt(i);
  return f ? `${grouped}.${f}` : grouped;
}

export const CurrencyAmountInput = forwardRef<HTMLInputElement, Props>(
  ({ value, onChange, decimals, allowNegative = false, className, ...props }, ref) => {
    const [text, setText] = useState(() => settledText(value, decimals));
    // The sign lives outside the field so the −/+ buttons own it and the input
    // stays number-only. The magnitude (text) and sign are recombined on emit.
    const [negative, setNegative] = useState(() => value < 0);
    const focused = useRef(false);
    // Local ref so the sign buttons can refocus the field; merged into the
    // forwarded ref so callers still reach the underlying input.
    const inputRef = useRef<HTMLInputElement>(null);
    useImperativeHandle(ref, () => inputRef.current as HTMLInputElement);

    // Re-sync from the outside (edit prefill, currency/decimals change, reset)
    // — but never while the user is actively typing.
    useEffect(() => {
      if (focused.current) return;
      setText(settledText(value, decimals));
      setNegative(value < 0);
    }, [value, decimals]);

    // Combine the typed magnitude with the current sign into the signed value
    // reported to the form.
    const emit = (magnitude: number, isNegative: boolean) => {
      onChange(
        Number.isFinite(magnitude) ? (isNegative ? -magnitude : magnitude) : NaN,
      );
    };

    // Mobile numeric/decimal keyboards have no minus key, so a leading "-" can't
    // be typed there. The buttons set the sign explicitly: "−" forces negative,
    // "+" forces positive, each keeping whatever magnitude is already entered.
    const setSign = (isNegative: boolean) => {
      setNegative(isNegative);
      const { value: magnitude } = parseInput(text, decimals);
      // Focus first so the value round-trip below doesn't trigger the settle
      // effect and clobber an in-progress entry.
      inputRef.current?.focus();
      emit(magnitude, isNegative);
    };

    const field = (
      <Input
        ref={inputRef}
        type="text"
        inputMode={decimals === 0 ? "numeric" : "decimal"}
        placeholder="0"
        {...props}
        className={allowNegative ? `pr-[4.75rem] ${className ?? ""}`.trim() : className}
        value={text}
        onFocus={(e) => {
          focused.current = true;
          props.onFocus?.(e);
        }}
        onChange={(e) => {
          const { text: nextText, value: magnitude } = parseInput(
            e.target.value,
            decimals,
          );
          setText(nextText);
          emit(magnitude, negative);
        }}
        onBlur={(e) => {
          focused.current = false;
          // Settle the display: pad to full decimals so the user never has to
          // type trailing zeros; an empty/zero field clears to show the "0"
          // placeholder rather than literal "0.00".
          setText(settledText(value, decimals));
          props.onBlur?.(e);
        }}
      />
    );

    if (!allowNegative) return field;

    // Don't steal focus on press (which would blur + settle the field);
    // setSign refocuses the input itself.
    const noBlur = (e: React.MouseEvent) => e.preventDefault();

    return (
      <div className="relative">
        {field}
        <div className="absolute right-1 top-1/2 flex -translate-y-1/2 gap-1">
          <button
            type="button"
            onMouseDown={noBlur}
            onClick={() => setSign(true)}
            aria-label="Make amount negative"
            aria-pressed={negative}
            className={`flex h-8 w-8 items-center justify-center rounded-[var(--radius)] border text-lg font-medium leading-none transition-colors ${
              negative
                ? "border-[var(--color-danger)] bg-[var(--color-danger)] text-[var(--color-danger-foreground)]"
                : "border-[var(--color-border)] text-[var(--color-muted-foreground)] hover:bg-[var(--color-muted)]"
            }`}
          >
            −
          </button>
          <button
            type="button"
            onMouseDown={noBlur}
            onClick={() => setSign(false)}
            aria-label="Make amount positive"
            aria-pressed={!negative}
            className={`flex h-8 w-8 items-center justify-center rounded-[var(--radius)] border text-lg font-medium leading-none transition-colors ${
              negative
                ? "border-[var(--color-border)] text-[var(--color-muted-foreground)] hover:bg-[var(--color-muted)]"
                : "border-[var(--color-primary)] bg-[var(--color-primary)] text-[var(--color-primary-foreground)]"
            }`}
          >
            +
          </button>
        </div>
      </div>
    );
  },
);
CurrencyAmountInput.displayName = "CurrencyAmountInput";

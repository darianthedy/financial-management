import { forwardRef, useEffect, useRef, useState } from "react";
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
  /** Allow a leading minus sign (e.g. for an overdrawn starting balance). */
  allowNegative?: boolean;
}

/** Group the integer part with thousands separators: "1234" -> "1,234". */
function groupInt(intPart: string): string {
  return intPart.replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

/** Parse arbitrary typed input into a clean display string + numeric value. */
function parseInput(
  raw: string,
  decimals: number,
  allowNegative: boolean,
): { text: string; value: number } {
  const negative = allowNegative && raw.includes("-");
  // Keep only digits and dots; drop the sign, grouping commas, and anything else.
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

  const sign = negative ? "-" : "";
  const groupedInt = groupInt(intPart);
  const body = hasDot ? `${groupedInt}.${fracPart}` : groupedInt;
  const text = body === "" && !negative ? "" : `${sign}${body}`;

  const numStr = `${sign}${intPart === "" ? "0" : intPart}${fracPart ? `.${fracPart}` : ""}`;
  const value = text === "" ? NaN : Number(numStr);
  return { text, value };
}

/**
 * Display for a value the user isn't actively typing: padded to full decimals
 * (1234 -> "1,234.00"). Zero / empty renders as "" so the placeholder shows a
 * bare "0" — never literal "0.00", which would otherwise sit in the field and
 * swallow typed digits into the fraction part.
 */
function settledText(value: number, decimals: number): string {
  if (!Number.isFinite(value) || value === 0) return "";
  const fixed = value.toFixed(decimals);
  const [i, f] = fixed.split(".");
  const grouped = groupInt(i);
  return f ? `${grouped}.${f}` : grouped;
}

export const CurrencyAmountInput = forwardRef<HTMLInputElement, Props>(
  ({ value, onChange, decimals, allowNegative = false, ...props }, ref) => {
    const [text, setText] = useState(() => settledText(value, decimals));
    const focused = useRef(false);

    // Re-sync from the outside (edit prefill, currency/decimals change, reset)
    // — but never while the user is actively typing.
    useEffect(() => {
      if (focused.current) return;
      setText(settledText(value, decimals));
    }, [value, decimals]);

    return (
      <Input
        ref={ref}
        type="text"
        inputMode={decimals === 0 ? "numeric" : "decimal"}
        placeholder="0"
        {...props}
        value={text}
        onFocus={(e) => {
          focused.current = true;
          props.onFocus?.(e);
        }}
        onChange={(e) => {
          const { text: nextText, value: nextValue } = parseInput(
            e.target.value,
            decimals,
            allowNegative,
          );
          setText(nextText);
          onChange(nextValue);
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
  },
);
CurrencyAmountInput.displayName = "CurrencyAmountInput";

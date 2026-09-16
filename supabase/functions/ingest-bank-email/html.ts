/**
 * HTML -> label/value helpers shared by every bank email template.
 *
 * Extracted from parser.ts when the myBCA "Internet Transaction Journal"
 * template was added: both templates render fields as a table of
 * label / ":" / value rows, so the scraping is identical and only the label
 * vocabulary differs.
 *
 * Dependency-free and free of Deno APIs so it can be unit tested with plain
 * `node --test`.
 */

export class BankEmailParseError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "BankEmailParseError";
  }
}

/**
 * Strips HTML to a list of non-empty trimmed lines.
 *
 * Every tag becomes a line break rather than being deleted, so adjacent table
 * cells cannot be glued into one token ("Merchant / ATM:M TIX").
 */
export function htmlToLines(html: string): string[] {
  const withoutInvisible = html
    .replace(/<!--[\s\S]*?-->/g, " ")
    .replace(/<(script|style)\b[\s\S]*?<\/\1>/gi, " ");

  const text = decodeEntities(withoutInvisible.replace(/<[^>]*>/g, "\n"));

  return text
    .split("\n")
    // NBSP is whitespace for our purposes but not matched by \s in older engines.
    .map((line) => line.replace(/ /g, " ").trim())
    .filter((line) => line.length > 0);
}

export function decodeEntities(input: string): string {
  return input
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&quot;/gi, '"')
    .replace(/&(?:apos|#0*39|#x0*27);/gi, "'")
    .replace(/&#x([0-9a-f]+);/gi, (_, hex) => safeFromCodePoint(parseInt(hex, 16)))
    .replace(/&#(\d+);/g, (_, dec) => safeFromCodePoint(parseInt(dec, 10)));
}

function safeFromCodePoint(code: number): string {
  if (!Number.isFinite(code) || code < 0 || code > 0x10ffff) return "";
  try {
    return String.fromCodePoint(code);
  } catch {
    return "";
  }
}

export function normalizeLabel(value: string): string {
  return value.replace(/\s+/g, " ").trim().toLowerCase();
}

/**
 * Finds the value following a label line.
 *
 * The rendered layout is three lines: label, ":", value. The separator is
 * skipped, and the search stops after a couple of lines so that a template
 * where the field is absent yields null instead of silently picking up the
 * next field's label as a value.
 *
 * `knownLabels` is what makes that guard work, so it must list every label the
 * template can emit, not just the ones we read. Two real cases depend on it:
 * the BCA credit card reversal template omits "Otentikasi" where the purchase
 * template has it, and the myBCA virtual-account template renders an EMPTY
 * "Description" row whose value would otherwise be read as "Reference No.".
 */
export function findFieldIn(
  lines: string[],
  label: string,
  knownLabels: ReadonlySet<string>,
): string | null {
  const target = normalizeLabel(label);

  for (let i = 0; i < lines.length; i++) {
    if (normalizeLabel(lines[i]) !== target) continue;

    for (let j = i + 1; j < Math.min(i + 4, lines.length); j++) {
      const candidate = lines[j].replace(/^:\s*/, "").trim();
      if (candidate.length === 0) continue;
      // Hitting another known label means this field had no value.
      if (knownLabels.has(normalizeLabel(candidate))) return null;
      return candidate;
    }
    return null;
  }

  return null;
}

/** Builds a normalized label set for use as `knownLabels`. */
export function labelSet(labels: readonly string[]): ReadonlySet<string> {
  return new Set(labels.map(normalizeLabel));
}

const MAX_PREVIEW_LENGTH = 40;

/**
 * @internal
 * Formats untrusted input for inclusion in an error message.
 *
 * The input is truncated so huge strings do not bloat error messages or logs,
 * and JSON-escaped so control characters (e.g. newlines) cannot forge log
 * lines.
 */
export function previewInput(input: string): string {
  return input.length > MAX_PREVIEW_LENGTH
    ? `${JSON.stringify(input.slice(0, MAX_PREVIEW_LENGTH))}... (${input.length} characters)`
    : JSON.stringify(input);
}

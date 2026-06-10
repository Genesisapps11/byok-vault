// No-log redaction layer. Scrub secret-looking tokens from any value before it
// is logged. Defense-in-depth: the vault module already avoids logging keys;
// this protects every other logging path (errors, request dumps, etc.).

const PATTERNS: RegExp[] = [
  /eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}/g, // JWTs
  /\b(?:vk|sk|sb|pk|rk|key)[_-][A-Za-z0-9_-]{8,}/gi, // provider key prefixes
  /\b[A-Fa-f0-9]{32,}\b/g, // long hex blobs
  /\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/gi, // UUIDs
]

export function redactSecrets(input: unknown): string {
  let s: string
  if (typeof input === 'string') {
    s = input
  } else {
    try {
      s = JSON.stringify(input)
    } catch {
      s = String(input)
    }
  }
  for (const re of PATTERNS) s = s.replace(re, '«redacted»')
  return s
}

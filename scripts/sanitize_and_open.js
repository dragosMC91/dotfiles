const input = process.argv[2] || '';

const CI_PREFIX = process.env.CI_PREFIX;
if (!CI_PREFIX) {
  throw new Error('CI_PREFIX is not set');
}
const LOCAL_PREFIX = process.env.E2E_PATH;
if (!LOCAL_PREFIX) {
  throw new Error('E2E_PATH is not set');
}

function sanitize(text) {
  // extracts a file path with optional line:col from messy surrounding text.

  // - (?:file://)? — strip optional file:// prefix
  // - (\/\S+?) — capture the path (starts with /, lazy so it doesn't eat the line/col)
  // - (?::(\d+)(?::(\d+))?)? — optionally capture :line and :line:col
  // - (?=[\s)"'\]]|$) — stop when we hit whitespace, a closing bracket/quote, or end of string
  // Groups: match[1] = path, match[2] = line, match[3] = column.
  const match = text.match(/(?:file:\/\/)?(\/\S+?)(?::(\d+)(?::(\d+))?)?(?=[\s)"'\]]|$)/);
  if (!match) return text;

  const filePath = match[1].replace(CI_PREFIX, LOCAL_PREFIX);
  const row = match[2];
  const col = match[3];

  let result = filePath;
  if (row) result += ':' + row;
  if (col) result += ':' + col;

  return result;
}

process.stdout.write(sanitize(input));

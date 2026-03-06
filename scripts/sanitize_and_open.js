const input = process.argv[2] || '';

function sanitize(text) {
  // --- CUSTOM SANITIZATION LOGIC HERE ---
  return text;
}

process.stdout.write(sanitize(input));

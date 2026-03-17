# Shows environment variables from all env files, with sensitive values masked.
#
# Files are processed in order — later values override earlier ones.
# Sensitive vars (name contains KEY, PRIVATE, SECRET, JWT, PASSWORD)
# are masked preserving length: first 4 + last 4 chars visible, middle replaced with *.
# Values <= 8 chars are fully masked.

# Replaces the middle of a value with asterisks, keeping first 4 and last 4 chars.
# Short values (<= 8 chars) are fully masked.
function mask(val,    len, mid, i, masked) {
  len = length(val)
  if (len <= 8) {
    masked = ""
    for (i = 0; i < len; i++) masked = masked "*"
    return masked
  }
  mid = ""
  for (i = 0; i < len - 8; i++) mid = mid "*"
  return substr(val, 1, 4) mid substr(val, len - 3)
}

# Removes surrounding double or single quotes from a value.
function strip_quotes(val) {
  if (val ~ /^".*"$/) val = substr(val, 2, length(val) - 2)
  else if (val ~ /^'.*'$/) val = substr(val, 2, length(val) - 2)
  return val
}

# Skip empty lines and comments
/^[[:space:]]*#/ { next }
/^[[:space:]]*$/ { next }

# Match lines like: VAR_NAME="value"
# Store the last value and source file for each variable.
# If the same var appears in multiple files, the last file wins.
/^[A-Z_][A-Z_0-9]*=/ {
  eq = index($0, "=")
  name = substr($0, 1, eq - 1)
  value = strip_quotes(substr($0, eq + 1))

  # Track insertion order (first time we see this var)
  if (!(name in vars)) order[++count] = name
  vars[name] = value
  sources[name] = FILENAME
}

END {
  # Build a deduplicated list of source files, preserving the original file order
  for (i = 1; i <= count; i++) {
    s = sources[order[i]]
    if (!(s in seen_source)) {
      seen_source[s] = 1
      file_order[++file_count] = s
    }
  }

  # Print variables grouped by their source file.
  # Within each group, variables appear in their original .env file order.
  for (f = 1; f <= file_count; f++) {
    source = file_order[f]
    label = source
    gsub(/lib\/foundry-env\/.env/, "foundry-env", label)

    if (f > 1) printf "\n"
    printf "%s\n", label

    for (i = 1; i <= count; i++) {
      name = order[i]
      if (sources[name] != source) continue
      value = vars[name]

      if (name ~ /(KEY|PRIVATE|SECRET|JWT|PASSWORD)/)
        value = mask(value)

      printf "  %-40s %s\n", name, value
    }
  }
}

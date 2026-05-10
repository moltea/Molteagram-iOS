#!/bin/sh
perl -pe '
  # Replace "__BAZEL_XCODE_DEVELOPER_DIR__" with "$(DEVELOPER_DIR)"
  s/__BAZEL_XCODE_DEVELOPER_DIR__/\$(DEVELOPER_DIR)/g;

  # Replace "__BAZEL_XCODE_SDKROOT__" with "$(SDKROOT)"
  s/__BAZEL_XCODE_SDKROOT__/\$(SDKROOT)/g;

  # Replace build settings with their values
  s/
    \$             # Match a dollar sign
    (\()?          # Optionally match an opening parenthesis and capture it
    ([a-zA-Z_]\w*) # Match a variable name and capture it
    (?(1)\))       # If an opening parenthesis was captured, match a closing parenthesis
  /$ENV{$2}/gx;    # Replace the entire matched string with the value of the corresponding environment variable

' "$SCRIPT_INPUT_FILE_0" > "$SCRIPT_OUTPUT_FILE_0"


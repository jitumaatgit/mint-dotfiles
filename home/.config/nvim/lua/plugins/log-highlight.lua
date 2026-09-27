return {
  "fei6409/log-highlight.nvim",
  event = { "BufRead *.log", "BufNewFile *.log" },
  opts = {
    -- Default: filetype = "log" for *.log files
    extension = "log",
    -- Also match common log files without .log extension
    filename = { "syslog", "faillog", "lastlog", "messages", "dmesg" },
    -- Pattern matching for log files in common locations
    pattern = { "/var/log/*", "*.log.*", "log.*.txt" },
    -- Custom keywords per severity group.
    --
    -- These are emitted by the plugin as `syn keyword` tokens
    -- (gen_syntax_file -> table.concat(words, ' ')), and `syn keyword` is
    -- case-sensitive with no `syn case ignore` in the base syntax. Each entry
    -- MUST therefore be a single bare word matching [A-Za-z_][A-Za-z0-9_]*:
    -- a space splits one entry into several keywords, and punctuation
    -- ('=', '/', ':', '!', '-' or '[') either never matches or aborts syntax
    -- loading with E789. Case variants are listed explicitly for that reason.
    keyword = {
      error = {
        "ERROR", "Error", "error", "FATAL", "Fatal", "fatal",
        "CRITICAL", "Critical", "critical", "FAILED", "Failed", "failed",
        "FAILURE", "Failure", "failure", "Exception", "exception",
        "Traceback", "traceback", "Panic", "panic", "FAIL", "Fail", "fail",
        "denied", "refused",
      },
      warning = { "WARN", "Warn", "warn", "WARNING", "Warning", "warning" },
      info = {
        "INFO", "Info", "info", "INFORMATION", "Information",
        "NOTICE", "Notice", "notice",
        "Started", "Starting", "Finished", "Reached", "Deactivated",
      },
      debug = { "DEBUG", "Debug", "debug", "DBG", "TRACE", "Trace", "trace" },
      pass = {
        "PASS", "Pass", "pass", "PASSED", "OK", "SUCCESS", "Success",
        "success", "SUCCEEDED", "Succeeded", "succeeded",
      },
    },
  },
}

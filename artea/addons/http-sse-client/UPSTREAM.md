# Restored Firebase dependency

Source: https://github.com/GodotNuts/GodotFirebase/tree/68be88690f8afd1be505f17e16af685bf33572b9/addons/http-sse-client

MIT license retained beside the script. Only this missing dependency is restored;
the installed Firebase SDK is not replaced or upgraded.

Local changes: open the read-only event stream with GET rather than POST; use
plain HTTP for explicitly configured HTTP emulator URLs, retaining verified TLS
for HTTPS. No live database requests or writes are used in the local test.

Browser streaming, redirects, reconnect/auth refresh and fragmented-message
coverage still require verification. Restoring this file does not establish
complete Firebase service compatibility or production readiness.

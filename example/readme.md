# tratelimit example

## Requirements

- twebserver 1.47.53 or later
- tpathexp 1.2.0 or later
- tratelimit and its Valkey store dependencies
- A local Valkey server configured as in `app.tcl`

## Run

```bash
ttrek run -script example
```

Run from the package root after installing dependencies, or run `tclsh app.tcl`
from this directory. Open `/stats` on port 8080: its named route hook allows five
requests per ten seconds before returning HTTP 429. The global IP limit applies
across routes. This example does not create sessions or cookies; session limits
only apply when another middleware supplies a session ID.

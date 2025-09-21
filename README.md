# ReusePort Demo

This project demonstrates how to build and test a Rust web server that uses `SO_REUSEPORT` to allow multiple instances
of the same process to listen on the same TCP port and share incoming connections.

## What We Did

- Implemented a simple Axum-based HTTP server in Rust.
- Configured the listener socket with `SO_REUSEPORT` so that multiple server processes can bind to the same port.
- Each instance responds on `/pid` endpoint with its process ID, so we can see which instance handled each request.

## How We Tested

- Wrote a shell test script `tests/test_reuseport.sh` that:
    1. Builds the Rust server (`cargo build`).
    2. Starts multiple instances of the server on the same port (using `SO_REUSEPORT`).
    3. Sends many HTTP requests to `/pid` using `curl`.
    4. Collects the returned PIDs and summarizes the distribution.
- Added Python script `tests/test_uniform.py` that:
    - Reads request/response logs from stdin.
    - Performs a Chi-square goodness-of-fit test to check if the distribution of requests across PIDs is uniform.
    - Outputs Chi-square, p-value, and a human-readable “randomness rating” with color icons.

## Example Output

```
SUMMARY  22573  17
SUMMARY  22574  16
SUMMARY  22575  15
SUMMARY  22576  16
Total    64
Chi-square: 0.250
p-value:   0.969
RANDOMNESS: 🟢 Excellent
SCALE: 🟢 ≥ 0.20 (Excellent), 🟡 ≥ 0.05 (Good), 🟠 ≥ 0.01 (Fair), 🔴 < 0.01 (Poor)
```

## Requirements

- Rust toolchain
- Bash
- lsof
- Python 3 with SciPy and NumPy

## Run Tests

```
chmod +x tests/*.{sh,py}
./tests/test_reuseport.sh | python3 tests/test_uniform.py
```

This will build the server, run multiple instances, send requests, and analyze whether the load balancing across
processes is uniform.
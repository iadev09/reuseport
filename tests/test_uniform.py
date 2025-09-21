#!/usr/bin/env python3
import sys
from collections import Counter, OrderedDict

# Try to load scipy for p-value; fall back gracefully if unavailable
try:
    from scipy.stats import chisquare  # type: ignore

    HAVE_SCIPY = True
except Exception:
    HAVE_SCIPY = False

instances = []
responses = []

for raw in sys.stdin:
    line = raw.rstrip("\n")
    # Expect tab-separated lines like:
    # INSTANCE:\t11\treuseport
    # RESPONSE:\t15
    # SUM:\t15\t14   (optional; ignored)
    parts = line.split("\t")
    if not parts:
        continue

    tag = parts[0].strip()
    if tag == "INSTANCE:" and len(parts) >= 2:
        pid_str = parts[1].strip()
        if pid_str.isdigit():
            instances.append(int(pid_str))
    elif tag == "RESPONSE:" and len(parts) >= 2:
        pid_str = parts[1].strip()
        if pid_str.isdigit():
            responses.append(int(pid_str))
    # ignore SUM:/other lines

# --- Build observed counts ---
obs_counter = Counter(responses)
total = sum(obs_counter.values())

if total == 0:
    print("No responses parsed from STDIN.")
    sys.exit(1)

# Decide the category (PID) set:
# Prefer the explicit INSTANCE list if provided; otherwise derive from responses.
if instances:
    pid_order = list(OrderedDict.fromkeys(instances))  # keep first-seen order
else:
    pid_order = sorted(obs_counter.keys())

k = len(pid_order)
expected = total / k if k else 0.0

# Prepare observed vector aligned to pid_order
obs = [obs_counter.get(pid, 0) for pid in pid_order]

# Print a human-readable summary table (CSV-ish)

for pid, c in zip(pid_order, obs):
    print(f"SUMMARY\t{pid}\t{c}")
print(f"Total\t{total}")

# Chi-square goodness-of-fit vs uniform
# H0: counts are uniform across the k PIDs
if k > 1:
    chi2 = sum((c - expected) ** 2 / expected for c in obs) if expected > 0 else float("inf")
    if HAVE_SCIPY and expected > 0:
        from scipy.stats import chisquare  # type: ignore

        chi2_val, p_val = chisquare(f_obs=obs, f_exp=[expected] * k)
        # Pretty-print p-value so scientific notation like e-13 is readable
        if p_val < 1e-6:
            p_str = "< 1e-6"
        elif p_val < 1e-3:
            p_str = "< 0.001"
        else:
            p_str = f"{p_val:.3f}"

        print(f"Chi-square:\t{chi2_val:.3f}")
        print(f"p-value:\t{p_str}")
        # Randomness rating (password-strength style) using p-value thresholds
        # 🟢 ≥ 0.20  (Excellent) | 🟡 ≥ 0.05 (Good) | 🟠 ≥ 0.01 (Fair) | 🔴 < 0.01 (Poor)
        if p_val >= 0.20:
            level, emoji = "Excellent", "🟢"
        elif p_val >= 0.05:
            level, emoji = "Good", "🟡"
        elif p_val >= 0.01:
            level, emoji = "Fair", "🟠"
        else:
            level, emoji = "Poor", "🔴"
        print(f"RANDOMNESS:\t{emoji} {level}")
        print("---------------------------------------")
        print("")
        print("SCALE:\t🟢 ≥ 0.20 (Excellent), 🟡 ≥ 0.05 (Good), 🟠 ≥ 0.01 (Fair), 🔴 < 0.01 (Poor)")
        # Optional note when expected counts are small (chi-square approximation warning)
        if expected < 5:
            print("NOTE:\texpected per bucket < 5; chi-square approximation may be unreliable")
    else:
        # Without scipy we still report chi2 and df; p-value requires scipy.
        df = k - 1
        print(f"Chi-square: {chi2}")
        print(f"df,{df}")
        print("p-value requires-scipy")
else:
    print("Only one category detected; chi-square test not applicable.")

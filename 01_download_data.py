"""
Step 1: Download all required NHANES XPT files from the CDC website.
Downloads files for 10 cycles (1999-2000 through 2017-March 2020 pre-pandemic).
Skips files that already exist locally.
"""
import os
import time
import requests
from config import (
    CYCLES, COMPONENT_BASES, DATA_RAW_DIR,
    get_file_url, get_alternative_urls, OPTIONAL_COMPONENTS,
)


def download_file(url, local_path, retries=3, timeout=120):
    """Download a file from url to local_path with retry logic.
    Validates the file starts with SAS XPORT header to avoid saving HTML error pages.
    """
    for attempt in range(retries):
        try:
            resp = requests.get(url, timeout=timeout)
            if resp.status_code == 200:
                # Validate it's actually a SAS transport file, not an HTML error page
                if resp.content[:20].startswith(b"HEADER RECORD"):
                    with open(local_path, "wb") as f:
                        f.write(resp.content)
                    size_mb = len(resp.content) / 1e6
                    return True, f"{size_mb:.1f} MB"
                else:
                    return False, "Not a valid XPT file (got HTML?)"
            elif resp.status_code == 404:
                return False, "404 Not Found"
            else:
                return False, f"HTTP {resp.status_code}"
        except requests.exceptions.RequestException as e:
            if attempt < retries - 1:
                time.sleep(2 ** attempt)
            else:
                return False, str(e)
    return False, "Max retries exceeded"


def download_all():
    """Download all NHANES XPT files for all cycles."""
    os.makedirs(DATA_RAW_DIR, exist_ok=True)
    components = list(COMPONENT_BASES.keys())

    total, success, skipped, failed = 0, 0, 0, 0
    failures = []

    for cycle in CYCLES:
        cycle_name = cycle["name"]
        cycle_dir = os.path.join(DATA_RAW_DIR, cycle_name)
        os.makedirs(cycle_dir, exist_ok=True)
        print(f"\n{'='*60}")
        print(f"  Cycle: {cycle_name}")
        print(f"{'='*60}")

        for comp in components:
            total += 1
            url, filename = get_file_url(comp, cycle)
            local_path = os.path.join(cycle_dir, f"{filename}.XPT")

            if os.path.exists(local_path) and os.path.getsize(local_path) > 0:
                print(f"  [SKIP] {comp:6s} -> {filename}.XPT (already exists)")
                skipped += 1
                continue

            print(f"  [DOWN] {comp:6s} -> {url} ... ", end="", flush=True)
            ok, msg = download_file(url, local_path)

            if ok:
                print(f"OK ({msg})")
                success += 1
            else:
                # Try alternatives
                alt_ok = False
                for alt_url, alt_name in get_alternative_urls(comp, cycle):
                    alt_path = os.path.join(cycle_dir, f"{alt_name}.XPT")
                    print(f"\n         Trying {alt_url} ... ", end="", flush=True)
                    alt_ok, alt_msg = download_file(alt_url, alt_path)
                    if alt_ok:
                        print(f"OK ({alt_msg})")
                        success += 1
                        break

                if not alt_ok:
                    is_optional = comp in OPTIONAL_COMPONENTS
                    tag = "WARN" if is_optional else "FAIL"
                    print(f"{tag} ({msg})")
                    if not is_optional:
                        failed += 1
                        failures.append((cycle_name, comp, msg))
                    else:
                        skipped += 1

            time.sleep(0.3)

    print(f"\n{'='*60}")
    print(f"  Download Summary")
    print(f"{'='*60}")
    print(f"  Total:   {total}")
    print(f"  Success: {success}")
    print(f"  Skipped: {skipped}")
    print(f"  Failed:  {failed}")

    if failures:
        print(f"\n  Failed downloads:")
        for cycle_name, comp, msg in failures:
            print(f"    - {cycle_name} / {comp}: {msg}")

    return failed == 0


if __name__ == "__main__":
    download_all()

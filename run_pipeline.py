"""
Master pipeline script — runs all steps sequentially.
Usage: python run_pipeline.py [--skip-download] [--skip-build] [--skip-train] [--skip-figures]
"""
import sys
import time
import argparse


def run_step(name, func):
    """Run a pipeline step with timing."""
    print(f"\n{'#'*70}")
    print(f"#  {name}")
    print(f"{'#'*70}\n")
    start = time.time()
    try:
        func()
        elapsed = time.time() - start
        print(f"\n  [{name}] completed in {elapsed:.1f}s")
        return True
    except Exception as e:
        elapsed = time.time() - start
        print(f"\n  [{name}] FAILED after {elapsed:.1f}s: {e}")
        import traceback
        traceback.print_exc()
        return False


def main():
    parser = argparse.ArgumentParser(description="Run the full NHANES diabetes prediction pipeline")
    parser.add_argument("--skip-download", action="store_true", help="Skip data download step")
    parser.add_argument("--skip-build", action="store_true", help="Skip dataset building step")
    parser.add_argument("--skip-train", action="store_true", help="Skip model training step")
    parser.add_argument("--skip-figures", action="store_true", help="Skip figure generation step")
    args = parser.parse_args()

    total_start = time.time()
    success = True

    import importlib

    if not args.skip_download:
        mod = importlib.import_module("01_download_data")
        if not run_step("Step 1: Download NHANES Data", mod.download_all):
            print("\n  WARNING: Some downloads failed. Continuing with available data...")

    if not args.skip_build:
        mod = importlib.import_module("02_build_dataset")
        if not run_step("Step 2: Build Analytic Dataset", mod.build_dataset):
            print("\n  FATAL: Dataset building failed. Cannot continue.")
            return False

    if not args.skip_train:
        mod = importlib.import_module("03_train_and_evaluate")
        if not run_step("Step 3: Train & Evaluate Models", mod.main):
            print("\n  FATAL: Training failed. Cannot generate figures.")
            return False

    if not args.skip_figures:
        mod = importlib.import_module("04_generate_figures")
        if not run_step("Step 4: Generate Figures & Tables", mod.main):
            print("\n  WARNING: Some figures may not have been generated.")

    total_elapsed = time.time() - total_start
    print(f"\n{'#'*70}")
    print(f"#  Pipeline Complete! Total time: {total_elapsed/60:.1f} minutes")
    print(f"{'#'*70}")
    return True


if __name__ == "__main__":
    sys.exit(0 if main() else 1)

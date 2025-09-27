from pathlib import Path
import re
import pandas as pd

# Match results-YYYYMMDD-HHMMSS.xlsx or .csv (case-insensitive prefix)
RESULTS_PATTERN = re.compile(r"(results|Results)-(\d{8})-(\d{6})\.(xlsx|csv)$", re.IGNORECASE)

def _parse_ts_from_name(name: str):
    m = RESULTS_PATTERN.match(name)
    if not m:
        return None
    _, ymd, hms, _ = m.groups()
    return pd.to_datetime(ymd + hms, format="%Y%m%d%H%M%S", errors="coerce")

def _read_file(p: Path) -> pd.DataFrame:
    if p.suffix.lower() == ".xlsx":
        df = pd.read_excel(p)
    elif p.suffix.lower() == ".csv":
        df = pd.read_csv(p)
    else:
        return pd.DataFrame()

    ts = _parse_ts_from_name(p.name) or pd.to_datetime(p.stat().st_mtime, unit="s", utc=True).tz_convert(None)
    df["ScanTimestamp"] = ts
    df["ScanDate"] = df["ScanTimestamp"].dt.date
    df["ScanTime"] = df["ScanTimestamp"].dt.time
    df["SourceFile"] = p.name
    return df

def load_all_results(repo_root: Path | None = None) -> pd.DataFrame:
    """
    Auto-detects repo root from this file's location:
      Network-Isolation-Suite/Analysis/results_loader.py
    Suite root is ONE level up → looks for <repo_root>/Scanner/Results/
    """
    if repo_root is None:
        repo_root = Path(__file__).resolve().parents[1]

    results_dir = repo_root / "Scanner" / "Results"
    if not results_dir.exists():
        raise FileNotFoundError(f"Results directory not found: {results_dir}")

    files = sorted([*results_dir.glob("results-*.xlsx"), *results_dir.glob("results-*.csv")])
    if not files:
        raise FileNotFoundError(f"No results files found in {results_dir}")

    frames = [_read_file(p) for p in files]
    out = pd.concat(frames, ignore_index=True, sort=False)

    # Ensure expected columns exist (scanner may evolve)
    expected = ["Host", "Boundary", "Location", "Description", "ResolvedIP", "ICMP", "Status", "CheckedOn"]
    for col in expected:
        if col not in out.columns:
            out[col] = pd.NA

    return out

def to_long_per_test(df: pd.DataFrame) -> pd.DataFrame:
    """Convert wide columns (Port 22, Port 445, ICMP) into long form for analytics."""
    id_cols = ["Host","Boundary","Location","Description","ResolvedIP","Status",
               "ScanTimestamp","ScanDate","ScanTime","SourceFile","CheckedOn"]
    id_cols = [c for c in id_cols if c in df.columns]
    value_cols = [c for c in df.columns if c.startswith("Port ") or c == "ICMP"]
    return df.melt(id_vars=id_cols, value_vars=value_cols, var_name="Test", value_name="Result")

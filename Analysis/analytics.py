import pandas as pd

def prep_df(df: pd.DataFrame) -> pd.DataFrame:
    """Normalize timestamp and location fields for consistent grouping."""
    df = df.copy()
    df["ScanTimestamp"] = pd.to_datetime(df["ScanTimestamp"], errors="coerce")
    # remove timezone and normalize to midnight
    df["ScanDay"] = df["ScanTimestamp"].dt.tz_localize(None).dt.normalize()
    df["Location"] = df["Location"].fillna("Unspecified").replace("", "Unspecified")
    df["Boundary"] = df["Boundary"].fillna("Unspecified").replace("", "Unspecified")
    return df

def compute_trend_by_day(df: pd.DataFrame) -> pd.DataFrame:
    """Rows=ScanDay, Cols=Status (counts)."""
    return (df.groupby("ScanDay")["Status"]
              .value_counts()
              .unstack(fill_value=0)
              .sort_index())

def compute_boundary_summary(df: pd.DataFrame) -> pd.DataFrame:
    """Rows=Boundary, Cols=Status (counts)."""
    return (df.groupby("Boundary")["Status"]
              .value_counts()
              .unstack(fill_value=0)
              .sort_index())

def compute_location_trends(df: pd.DataFrame) -> dict[str, pd.DataFrame]:
    """Dict of location -> (Rows=ScanDay, Cols=Status)."""
    out = {}
    for loc, sub in df.groupby("Location"):
        tbl = (sub.groupby("ScanDay")["Status"]
                 .value_counts()
                 .unstack(fill_value=0)
                 .sort_index())
        if not tbl.empty:
            out[loc] = tbl
    return out

import matplotlib.pyplot as plt

def _human_xlabels_from_index(index) -> list[str]:
    # If index looks like datetimes, format as 'Mon DD'; else use as-is
    try:
        return [getattr(i, "strftime", lambda *_: str(i))("%b %d") for i in index]
    except Exception:
        return [str(i) for i in index]

def plot_stacked_counts(counts, title: str, xlabel: str):
    """
    Render a stacked bar chart with labels inside each segment and totals
    shown neatly under the tick labels.
    """
    ax = counts.plot(kind="bar", stacked=True, figsize=(10, 6), title=title)
    ax.set_xlabel(xlabel)
    ax.set_ylabel("Host Count")

    # Set readable tick labels
    labels = _human_xlabels_from_index(counts.index)
    ax.set_xticklabels(labels, rotation=0)

    # Labels inside each stacked segment
    for container in ax.containers:
        ax.bar_label(container, label_type="center", fontsize=9)

    # Totals under each tick label (use axis transform so they don't overlap small bars)
    totals = counts.sum(axis=1)
    for i, total in enumerate(totals):
        ax.text(
            i, -0.1, str(int(total)),  # constant offset below axis
            ha="center", va="top", fontsize=9, color="black",
            transform=ax.get_xaxis_transform()  # anchor to axis, not data
        )

    plt.tight_layout()
    return ax

def plot_location_trends(trends_by_loc: dict):
    """
    Render one chart per location (dict values are counts tables).
    Each chart includes labels inside bars and totals under the tick labels.
    """
    for loc, tbl in trends_by_loc.items():
        ax = plot_stacked_counts(tbl, f"Compliance Trend – {loc}", "Scan Date")
        plt.show()

# Network Isolation Suite

The **Network Isolation Suite** is a toolkit for validating and analyzing network segmentation and isolation compliance.  
It is designed to help security teams test whether hosts are properly restricted by ICMP/TCP rules and to visualize compliance trends over time.

---

## 📂 Project Structure

```
Network-Isolation-Suite/
├─ Scanner/                # PowerShell-based scanner
│  ├─ hosts.xlsx           # Input file (Host, Boundary, Location, Description)
│  ├─ ports.txt            # List of TCP ports to test
│  └─ Results/             # Scan outputs (.xlsx) [ignored by Git]
└─ Analysis/               # Python analysis + dashboards
   ├─ Dashboards.ipynb     # Jupyter notebook for charts & analysis
   ├─ results_loader.py    # Loads and normalizes scan results
   ├─ analytics.py         # Data prep and aggregation functions
   └─ plots.py             # Visualization helpers (matplotlib)
```

---

## ⚡ Scanner (PowerShell)

- Uses **hosts.xlsx** and **ports.txt** as input.  
- Tests ICMP and defined TCP ports for each host.  
- Marks hosts as **Compliant** if *all checks are blocked*, or **Not Compliant** if *any check succeeds*.  
- Exports results to `Scanner/Results/results-YYYYMMDD-HHMMSS.xlsx`.  

### Input Format: `hosts.xlsx`
| Host         | Boundary   | Location     | Description        |
|--------------|------------|--------------|--------------------|
| 192.168.1.10 | DMZ        | Chicago DC   | Web Server         |
| 192.168.1.20 | OT-Network | Plant Floor  | PLC Controller     |
| example.com  | Internet   | HQ           | External Test Host |

- **Host** is required.  
- **Boundary**, **Location**, and **Description** are optional but useful for reporting.

### Input Format: `ports.txt`
```
22
80
443
445
3389
```

---

## 📊 Analysis (Python)

- Run `Analysis/Dashboards.ipynb` in Jupyter Lab or VS Code.  
- Uses helper scripts (`results_loader.py`, `analytics.py`, `plots.py`) to keep the notebook clean.  
- Produces bar charts for:
  - Compliance trends over time
  - Compliance by boundary
  - Compliance by location

Example output charts:
- Compliance counts stacked by **date**
- Compliance split by **location**
- Compliance split by **boundary**

---

## 🚀 Getting Started

### Requirements
- **Scanner**: Windows PowerShell 5.1+ and the [ImportExcel module](https://www.powershellgallery.com/packages/ImportExcel/)
- **Analysis**: Python 3.9+ with pandas, matplotlib, openpyxl

Install Python packages:
```bash
pip install pandas matplotlib openpyxl
```

### Workflow
1. Update `hosts.xlsx` and `ports.txt` in `Scanner/`.  
2. Run the PowerShell script `_NetworkIsolationScanner.ps1`.  
3. Collect results in `Scanner/Results/`.  
4. Open `Dashboards.ipynb` and run cells to analyze trends.

---

## 📌 Notes

- Results (`Scanner/Results/`) are ignored by Git and not uploaded to GitHub.  
- Only **templates** (`hosts.xlsx`, `ports.txt`) and **scripts** are tracked.  
- Designed for compliance testing and educational use; **not a replacement for enterprise tools**.

---

## 📜 License
This project is provided under the MIT License. See [LICENSE](LICENSE) for details.

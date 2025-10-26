"""
prepare_dataset.py

Reads a raw CSV of urls (some rows may have labels, others may be unlabeled).
- Ensures every row has 'url' and 'label'
- Infers labels for missing rows using simple heuristics
- Optionally drops unlabeled rows instead of inferring
- Saves combined_dataset.csv
"""

import os
import re
import pandas as pd

RAW_CSV_PATH = "data/your_real_data.csv"   # change if your CSV path differs
OUT_DIR = "data"
OUT_CSV = os.path.join(OUT_DIR, "combined_dataset.csv")
INFER_MISSING = True  # set False to drop rows with missing labels

SUSPICIOUS_KEYWORDS = [
    "login", "verify", "confirm", "update", "secure", "account",
    "claim", "prize", "free", "download", "install", "bank",
    "verify-account", "retry", "confirm-account", "signin"
]
SUSPICIOUS_TLDS = [".tk", ".gq", ".xyz", ".ru", ".biz", ".cc", ".pw", ".info"]

IP_RE = re.compile(r"https?://\d+\.\d+\.\d+\.\d+")

def infer_label(url: str) -> int:
    """Return 1 if URL looks suspicious, else 0 (heuristic)."""
    if not isinstance(url, str):
        return 0
    u = url.lower()
    # IP address in URL -> suspicious
    if IP_RE.search(u):
        return 1
    # suspicious keyword anywhere in path or domain
    for kw in SUSPICIOUS_KEYWORDS:
        if kw in u:
            return 1
    # suspicious TLDs
    for tld in SUSPICIOUS_TLDS:
        if u.endswith(tld) or ("/" in u and tld in u.split("/")[2] if len(u.split("/"))>2 else False):
            return 1
    # otherwise safe by default
    return 0

def main():
    if not os.path.exists(RAW_CSV_PATH):
        raise FileNotFoundError(f"{RAW_CSV_PATH} not found. Place your CSV at this path.")

    df = pd.read_csv(RAW_CSV_PATH, on_bad_lines='skip', dtype=str).fillna("")
    # Normalize column names
    df.columns = [c.strip().lower() for c in df.columns]

    if 'url' not in df.columns:
        # maybe first column has no header; assume first column is url, second optional label
        df = pd.read_csv(RAW_CSV_PATH, header=None, on_bad_lines='skip', dtype=str)
        if df.shape[1] == 1:
            df.columns = ['url']
        else:
            df.columns = ['url', 'label'] + [f"col{i}" for i in range(3, df.shape[1]+1)]
    df = df[['url'] + ([c for c in df.columns if c == 'label'])].copy()
    if 'label' not in df.columns:
        df['label'] = ""

    # Strip whitespace
    df['url'] = df['url'].astype(str).str.strip()
    df['label'] = df['label'].astype(str).str.strip()

    # Detect which rows have labels (0/1)
    def valid_label(x):
        return x in {"0", "1"}

    df['has_label'] = df['label'].apply(valid_label)
    labeled = df[df['has_label']].copy()
    unlabeled = df[~df['has_label']].copy()

    print(f"Total rows read: {len(df)}")
    print(f" - Labeled rows (0/1 present): {len(labeled)}")
    print(f" - Unlabeled rows: {len(unlabeled)}")

    # Infer labels for unlabeled rows or drop them
    if len(unlabeled) > 0:
        if INFER_MISSING:
            inferred = []
            for idx, row in unlabeled.iterrows():
                url = row['url']
                lab = infer_label(url)
                inferred.append((idx, url, lab))
            inferred_df = pd.DataFrame(inferred, columns=['index', 'url', 'label_inferred']).set_index('index')
            unlabeled = unlabeled.join(inferred_df['label_inferred'])
            unlabeled['label'] = unlabeled['label_inferred'].astype(int).astype(str)
            unlabeled = unlabeled.drop(columns=['label_inferred'])
            print(f"Inferred labels for {len(unlabeled)} unlabeled rows using heuristics.")
        else:
            print("Dropping unlabeled rows (INFER_MISSING=False).")
            unlabeled = unlabeled.iloc[0:0]  # empty

    # Combine labeled + (previously unlabeled now labeled)
    final_df = pd.concat([labeled[['url','label']], unlabeled[['url','label']]], ignore_index=True)
    # Convert label to int
    final_df['label'] = final_df['label'].astype(int)

    # Basic cleanup: drop rows with empty url
    final_df = final_df[final_df['url'].astype(str).str.strip() != ""].copy()

    # Ensure output folder exists
    os.makedirs(OUT_DIR, exist_ok=True)
    final_df.to_csv(OUT_CSV, index=False)
    print(f"Saved cleaned dataset to: {OUT_CSV}")
    print(final_df['label'].value_counts().to_dict())

    # Show top 10 inferred examples (if any)
    if INFER_MISSING and len(unlabeled)>0:
        print("\nSample inferred rows (url -> inferred label):")
        sample = unlabeled.head(10)
        for _, r in sample.iterrows():
            print(f"  {r['url']}  -> {r['label']}")

if __name__ == "__main__":
    main()

# Cleaned Data

Cleaned datasets for the **Golden Fork Bistro** analysis. These files are created from the raw CSVs in `data/raw` by a Python script (`master_etl.py`).

## Workflow

**Raw CSVs (AWS S3) → Python cleaning (4 phases) → MySQL (AWS RDS) + Cleaned CSVs (S3)**

| Phase | What it does |
|-------|--------------|
| 1. Standardize | Remove duplicate IDs, check table links (foreign keys), fix date formats, fix city and payment spellings, clean ratings (0–5) |
| 2. Clean columns | Fix text case, clean price columns, mask emails and phone numbers, fill missing values with "Unknown" or "Not Mention" |
| 3. Business logic | Recalculate quantity, subtotal and order total, validate promo codes, calculate discount and final amount, add loyalty tier and lifetime value |
| 4. Date and time fixes | Fix impossible dates (e.g. customer registered after first order), recalculate delivery duration, cap outliers (max 60 min, 30 km) |

After cleaning, the data is loaded into **MySQL (AWS RDS)** with primary and foreign keys, and saved back to **S3** as CSV files.

## Files

| File | Description |
|------|-------------|
| `customers.csv` | Customer details, loyalty tier, lifetime value |
| `orders.csv` | Orders with total, discount and final amount |
| `order_items.csv` | Items in each order |
| `menu_items.csv` | Menu with price, cost and calories |
| `outlets.csv` | Restaurant outlets |
| `promotions.csv` | Promo codes and usage count |
| `delivery.csv` | Delivery partner, time and duration |
| `feedback.csv` | Customer ratings and comments |

## Tools
Python (Pandas, NumPy), AWS S3, AWS RDS (MySQL), SQLAlchemy

> Note: This is sample data for a fictional restaurant. Customer emails and phone numbers are masked.

# Golden Fork Bistro: Restaurant Data Analytics

An end-to-end data project: **raw messy data → automated ETL pipeline → cloud database (AWS) → analysis.**

Golden Fork Bistro is a fictional multi-city restaurant chain. All data in this project is **sample data** created for learning and portfolio purposes.

---

## Project at a Glance

| | |
|---|---|
| **Goal** | Turn messy restaurant data into clean, reliable, analysis-ready tables |
| **Data** | 8 related tables (customers, orders, items, outlets, delivery and more) |
| **Approach** | A single Python ETL script that cleans the data in 4 phases |
| **Output** | Clean CSVs + a MySQL database on AWS RDS with primary and foreign keys |

---

## Pipeline Architecture

```
  RAW DATA (CSV)          TRANSFORM (Python)                 LOAD
 ┌──────────────┐     ┌────────────────────────┐     ┌──────────────────┐
 │  AWS S3      │ ──► │ Phase 1: Standardize   │ ──► │ MySQL (AWS RDS)  │
 │  8 raw CSVs  │     │ Phase 2: Clean columns │     ├──────────────────┤
 └──────────────┘     │ Phase 3: Business logic│     │ AWS S3           │
                      │ Phase 4: Date & time   │     │ (cleaned CSVs)   │
                      └────────────────────────┘     └──────────────────┘
```

---

## Dataset

| Table | What it contains |
|-------|------------------|
| `customers` | Customer profile, city, registration date |
| `orders` | Every order with date, type, payment method and promo |
| `order_items` | Items inside each order with quantity and price |
| `menu_items` | Menu with category, price, cost price and calories |
| `outlets` | Restaurant branches with city, type and seating capacity |
| `promotions` | Promo codes, type, discount and validity dates |
| `delivery` | Delivery partner, assign/pickup/delivery time, distance |
| `feedback` | Food, service and ambience ratings with comments |

**How tables connect:**
`orders` link to `customers`, `outlets` and `promotions`. `order_items` link to `orders` and `menu_items`. `delivery` and `feedback` link to `orders`.

---

## ETL Pipeline: Phase by Phase

The whole pipeline lives in one file: [`etl-pipeline/master_etl.py`](etl-pipeline/master_etl.py)

### Phase 0: Extract
- Connect to AWS S3 and read the 8 raw CSV files.
- Standardize column names (lowercase, underscores instead of spaces).

### Phase 1: Standardize
*Goal: make the structure of the data consistent.*

| Step | What happens |
|------|--------------|
| Primary keys | Trim spaces, convert to uppercase, drop null and duplicate IDs |
| Foreign keys | Clean all linking IDs, then remove rows whose parent record does not exist |
| Dates | Parse 12+ different date formats into one standard format |
| Order date and time | Split into separate `order_date` and `order_time` columns |
| Ratings | Keep values in the 0–5 range, treat 0 as missing, calculate `overall_rating` |
| Categories | Fix spelling variants (e.g. *Banglore → Bengaluru*, *Cc → Credit Card*) |

### Phase 2: Clean Columns
*Goal: clean each table's columns one by one.*

| Table | Cleaning done |
|-------|---------------|
| `outlets` | Proper address format, missing manager → "Unknown", active flag → Yes/No |
| `menu_items` | Remove currency symbols from prices, standardize calories, availability → Yes/No |
| `customers` | Fix names, gender and age band, **mask email and phone for privacy** |
| `promotions` | Uppercase promo codes, fill missing discount values, missing outlet → "ALL" |
| `orders`, `order_items` | Standardize text, clean special instructions |
| `delivery` | Clean partner names and distance values |
| `feedback` | Clean comments |

### Phase 3: Business Logic
*Goal: recalculate numbers using business rules so totals are trustworthy.*

1. **Order items:** fix invalid quantities (null, 0, or above 50) and recalculate `subtotal = quantity × menu price`.
2. **Orders:** calculate `total_amount` from its items and add `week_type` (Weekday or Weekend).
3. **Promo validation:** check every promo against its rules and give each order a status.
4. **Final amount:** `final_amount = total_amount − discount_applied` (never below 0).
5. **Customers:** calculate `total_lifetime_value` from all their orders.
6. **Promotions:** count `times_used` using only successful promo orders.

**Promo statuses:** No promo · Invalid Promo · Invalid Week Type · Expire Promo · Below Min Order · Buy 1 Get 1 · Free Delivery · Cashback · Flat Discount · Percentage used

### Phase 4: Date and Time Logic
*Goal: remove impossible or illogical dates and fix delivery timings.*

| Problem | Fix |
|---------|-----|
| Customer registered after their first order | Use the first order date as registration date |
| Outlet opened after its first order | Use the first order date as opened date |
| Menu item launched after its first sale | Use the first order date as launch date |
| Order dates in the future (after 31 Aug 2026) | Recover the date from delivery or feedback data |
| Missing pickup or delivery time | Calculate it using the delivery duration |
| Wrong or zero delivery duration | Recalculate from assign time and delivery time |
| Extreme delivery values | Cap duration at 60 minutes and distance at 30 km |
| Delivery rows for dine-in only outlets | Remove them, since delivery is not possible there |
| Missing order date or time | Fill from the delivery table |

**Loyalty tiers** (based on lifetime value):

| Tier | Lifetime value |
|------|----------------|
| Platinum | ₹15,000 and above |
| Gold | ₹5,000 to ₹14,999 |
| Silver | ₹1,000 to ₹4,999 |
| Bronze | Below ₹1,000 |

### Phase 5: Load
- **MySQL on AWS RDS:** tables are created fresh with **primary keys and foreign keys** so the database stays consistent.
- **AWS S3:** the cleaned tables are saved back as CSV files, which are also stored in the `cleaned-data` folder.

---

## Data Cleaning Examples

| Issue | Before | After |
|-------|--------|-------|
| City spelling | `Banglore`, `Bombay`, `new  delhi` | `Bengaluru`, `Mumbai`, `Delhi` |
| Payment method | `cc`, `u.p.i`, `netbanking` | `Credit Card`, `UPI`, `Net Banking` |
| Price | `Rs. 1,250` | `1250` |
| Rating | `6`, `0`, `-4` | `5`, missing, `4` |
| Order type | `Divry` | `Delivery` |
| Email (privacy) | `rahul123@gmail.com` | `ra***123@gmail.com` |
| Phone (privacy) | `9876543210` | `98******10` |

---

## Repository Structure

```
golden-fork-bistro-analytics/
├── data/
│   └── raw/             # Original uncleaned CSV files
├── etl-pipeline/
│   └── master_etl.py    # Complete ETL script (all 4 phases + load)
├── cleaned-data/        # Final cleaned CSV files
└── README.md
```

---

## Tech Stack

| Area | Tools |
|------|-------|
| Language | Python |
| Libraries | Pandas, NumPy, SQLAlchemy, Boto3 |
| Cloud | AWS S3, AWS RDS |
| Database | MySQL |

---

## How to Run

1. Clone the repo and install the libraries:
   ```
   pip install -r etl-pipeline/requirements.txt
   ```
2. Create a `.env` file with your AWS and database details (see `.env.example`).
3. Run the pipeline:
   ```
   python etl-pipeline/master_etl.py
   ```

---

## Key Skills Demonstrated

- Building a complete ETL pipeline from scratch
- Data cleaning and validation (keys, dates, categories, outliers)
- Applying business rules in code (promotions, loyalty tiers)
- Protecting customer privacy through data masking
- Working with AWS S3 and RDS, and designing a relational MySQL schema

---

## Notes

- Rows that fail key checks (duplicate IDs or missing parent records) are removed during cleaning.
- This is **sample data for a fictional restaurant**. No real customer data is used.

---

## Author

**Pushpkar Roy**
GitHub: [PushpkarRoy](https://github.com/PushpkarRoy)

import pandas as pd
import numpy as np
import boto3
import datetime
from io import StringIO
import re
import os
import warnings
from urllib.parse import quote_plus
from sqlalchemy import create_engine, text
from dotenv import load_dotenv
load_dotenv()

warnings.filterwarnings('ignore')

# =============================================================================
# 1. CONFIGURATION 
# =============================================================================

AWS_REGION = os.getenv("AWS_REGION")
S3_BUCKET = os.getenv("S3_BUCKET")

# Database Credentials
RDS_HOST = os.getenv("RDS_HOST")
RDS_USER = os.getenv("RDS_USER")
RDS_PASSWORD = os.getenv("RDS_PASSWORD")
RDS_DATABASE = os.getenv("RDS_DATABASE")
RDS_PORT = int(os.getenv("RDS_PORT", "3306"))

PKS = {
    "customers": "customer_id",
    "orders": "order_id",
    "delivery": "delivery_id",
    "order_items": "order_item_id",
    "outlets": "outlet_id",
    "menu_items": "item_id",
    "feedback": "feedback_id",
    "promotions": "promo_id"
}

FKS = {
    "promotions": {"outlet_id": ("outlets", "outlet_id")},
    "orders": {
        "customer_id": ("customers", "customer_id"),
        "outlet_id": ("outlets", "outlet_id"),
        "promo_id": ("promotions", "promo_id")
    },
    "order_items": {
        "order_id": ("orders", "order_id"),
        "item_id": ("menu_items", "item_id")
    },
    "delivery": {"order_id": ("orders", "order_id")},
    "feedback": {
        "order_id": ("orders", "order_id"),
        "outlet_id": ("outlets", "outlet_id")
    }
}

CITY_MAPPING = {

    # Kolkata
    "kolkata": "Kolkata", "kolkota": "Kolkata", "kolkatta": "Kolkata", "calcutta": "Kolkata",

    # Lucknow
    "lucknow": "Lucknow", "luckhnow": "Lucknow", "luckhnaw": "Lucknow",

    # Hyderabad
    "hyderabad": "Hyderabad", "hyderabaad": "Hyderabad", "hyderbad": "Hyderabad",

    # Kochi
    "kochi": "Kochi", "cochin": "Kochi", "kochhi": "Kochi",

    # Indore
    "indore": "Indore", "indoor": "Indore",

    # Bengaluru
    "bengaluru": "Bengaluru", "banglore": "Bengaluru",
    "bangalore": "Bengaluru", "bengaluruu": "Bengaluru",
    "bengalooru": "Bengaluru",

    # Jaipur
    "jaipur": "Jaipur", "jaipor": "Jaipur",

    # Surat
    "surat": "Surat", "surrat": "Surat", "surratt": "Surat",

    # Chandigarh
    "chandigarh": "Chandigarh", "chandigar": "Chandigarh",

    # Pune
    "pune": "Pune", "puna": "Pune", "poona": "Pune",

    # Mumbai
    "mumbai": "Mumbai", "mumbay": "Mumbai", "bombay": "Mumbai",

    # Delhi
    "delhi": "Delhi", "dehli": "Delhi", "delhii": "Delhi",
    "new delhi": "Delhi", "new  delhi": "Delhi",

    # Chennai
    "chennai": "Chennai", "chenai": "Chennai",
    "channai": "Chennai", "madras": "Chennai",

    # Nagpur
    "nagpur": "Nagpur", "nagpore": "Nagpur", "nagpurr": "Nagpur",

    # Ahmedabad
    "ahmedabad": "Ahmedabad", "amdavad": "Ahmedabad",
    "ahmadabad": "Ahmedabad", "ahemdabad": "Ahmedabad"
}

PAYMENT_MAPPING = {
    "upi": "UPI", "u.p.i": "UPI",
    "credit card": "Credit Card", "credit-card": "Credit Card", "cc": "Credit Card",
    "debit card": "Debit Card", "debit-card": "Debit Card", "dc": "Debit Card",
    "wallet": "Wallet", "e-wallet": "Wallet", "ewallet": "Wallet",
    "cash": "Cash",
    "cod": "COD",
    "net banking": "Net Banking", "netbanking": "Net Banking"
}

CALORIES_MAP = {'Butter Chicken': 400, 'Paneer Butter Masala': 450, 'Dal Makhani': 350, 
                'Chicken Biryani': 500, 'Veg Biryani': 400, 'Mutton Biryani': 550, 'Egg Biryani': 450, 
                'Chicken Tikka Masala': 380, 'Palak Paneer': 320, 'Chole Bhature': 600, 'Rajma Chawal': 400, 
                'Kadai Chicken': 350, 'Malai Kofta': 500, 'Masala Dosa': 350, 'Plain Dosa': 200, 'Idli Sambar': 250, 
                'Medu Vada': 300, 'Uttapam': 250, 'Curd Rice': 220, 'Chicken Chettinad': 400, 'Hyderabadi Biryani': 550, 
                'Paneer Tikka': 280, 'Chicken Tikka': 250, 'Seekh Kebab': 300, 'Chilli Chicken': 350, 'Chilli Paneer': 400, 
                'Spring Roll': 250, 'Manchurian': 350, 'Hakka Noodles': 400, 'Veg Fried Rice': 350, 'Chicken Fried Rice': 450, 
                'Margherita Pizza': 600, 'Farmhouse Pizza': 650, 'Chicken Pepperoni Pizza': 800, 'Veg Supreme Pizza': 700, 
                'Cheese Burst Pizza': 900, 'Classic Veg Burger': 350, 'Chicken Burger': 450, 'Paneer Wrap': 450, 
                'Chicken Kathi Roll': 500, 'Egg Roll': 400, 'French Fries': 350, 'Garlic Bread': 300, 'Masala Papad': 50, 
                'Green Salad': 40, 'Raita': 80, 'Gulab Jamun': 300, 'Rasmalai': 250, 'Chocolate Brownie': 400, 'Ice Cream Sundae': 350, 
                'Gajar Ka Halwa': 350, 'Masala Chai': 100, 'Cold Coffee': 250, 'Fresh Lime Soda': 80
}

# =============================================================================
# 2. HELPER FUNCTIONS
# =============================================================================

def clean_pk(df, table_name, pk_col):
    initial_count = len(df)
    df[pk_col] = df[pk_col].astype(str).str.strip().str.upper()
    df = df[~df[pk_col].isin(['NAN', 'NONE', 'NULL', ''])]
    df = df.dropna(subset=[pk_col])
    df = df.drop_duplicates(subset=[pk_col], keep='first').copy()
    dropped = initial_count - len(df)
    print(f"[{table_name}] Dropped {dropped} duplicate/null primary keys on {pk_col}.")
    return df

def enforce_fks(tables):
    print("\n--- ENFORCING FOREIGN KEYS ---")
    for child_table, mappings in FKS.items():
        child_df = tables[child_table]
        for fk_col, (parent_table, parent_pk) in mappings.items():
            if fk_col in child_df.columns:
                parent_df = tables[parent_table]
                valid_pks = set(parent_df[parent_pk].astype(str))
                
                initial_count = len(child_df)
                mask = child_df[fk_col].isna() | child_df[fk_col].astype(str).str.strip().str.upper().isin(valid_pks) | (child_df[fk_col].astype(str).str.upper() == 'ALL')
                child_df = child_df[mask].copy()
                dropped = initial_count - len(child_df)
                
                if dropped > 0:
                    print(f"[{child_table}] Dropped {dropped} rows. FK '{fk_col}' did not match PK '{parent_pk}' in '{parent_table}'.")
        tables[child_table] = child_df
    return tables

def fix_dots(value):
    value = str(value).strip()
    pattern = r'^(.+)\s(\d{2})\.(\d{2})\.(\d{2})$'
    match = re.match(pattern, value)
    if match:
        return f"{match.group(1)} {match.group(2)}:{match.group(3)}:{match.group(4)}"
    return value

def fix_ampm(value):
    value = str(value).strip()
    return re.sub(r'(\d)(AM|PM)', r'\1 \2', value, flags=re.IGNORECASE)

def parse_datetime_robust(value):
    value = str(value).strip()
    if value.lower() in ('', 'nan', 'nat', 'none', 'null', '0', '0000-00-00', '0000-00-00 00:00:00'):
        return pd.NaT
    formats = [
        '%Y-%m-%d %H:%M:%S', '%Y-%m-%d %H:%M', '%Y/%m/%d %H:%M:%S', '%Y/%m/%d %H:%M',
        '%d-%m-%Y %H:%M:%S', '%d-%m-%Y %H:%M', '%d/%m/%Y %H:%M:%S', '%d/%m/%Y %H:%M',
        '%m/%d/%Y %H:%M:%S', '%m/%d/%Y %H:%M', '%d %b %Y %I:%M %p', '%d %b %Y %I:%M:%S %p'
    ]
    for fmt in formats:
        try: return pd.to_datetime(value, format=fmt)
        except: continue
    try: return pd.to_datetime(value, dayfirst=True)
    except: return pd.NaT

def clean_ratings(val):
    try:
        v = abs(float(val))
        if v == 0: return np.nan
        if v >= 6: return 5.0
        if v > 5: return np.nan 
        return v
    except:
        return np.nan

def clean_money_to_number(value, return_int=False):
    if pd.isna(value) or str(value).strip().lower() in ['nan', 'none', 'null', '']:
        return np.nan
    s = str(value).strip()
    s = re.sub(r"(?i)(rs\.?|inr|₹)", "", s)
    s = s.replace(",", "").strip()
    match = re.search(r"-?\d+(?:\.\d+)?", s)
    if not match:
        return np.nan
    try:
        num = abs(float(match.group(0)))
        if return_int:
            return int(round(num, 0))
        return round(num, 2)
    except ValueError:
        return np.nan

def smart_title_address(address):
    if pd.isna(address) or str(address).strip().lower() in ['nan', 'none', 'null', '']:
        return np.nan
    addr = str(address).strip()
    addr = re.sub(r'\s+,', ',', addr)
    addr = addr.title()
    addr = re.sub(r'\bMg\b', 'MG', addr)
    return addr

def mask_email(row):
    name = str(row.get('customer_name', '')).strip()
    email = str(row.get('email_raw', '')).strip() 
    if name == 'Unknown' or email.lower() in ['nan', 'none', '', 'nat']:
        return "Not Mention"
    if '@' in email:
        local_part, domain = email.split('@', 1)
    else:
        local_part, domain = email, "gmail.com"
    digits = "".join([c for c in local_part if c.isdigit()])
    prefix = name[:2].lower() if len(name) >= 2 else name.lower()
    return f"{prefix}***{digits}@{domain.lower()}"

def mask_phone(val):
    val = str(val).strip()
    if val.lower() in ['nan', 'none', '', 'nat', '0']: 
        return "Not Mention"
    digits = re.sub(r'\D', '', val)
    if len(digits) >= 4:
        return f"{digits[:2]}******{digits[-2:]}"
    return "Not Mention"

# =============================================================================
# 3. PHASE PROCESSORS
# =============================================================================

def execute_phase_one():
    print("--- CONNECTING TO S3 ---")
    s3 = boto3.client('s3', region_name=AWS_REGION)
    
    def fetch(file_name):
        print(f"Pulling {file_name}...")
        resp = s3.get_object(Bucket=S3_BUCKET, Key=file_name)
        df = pd.read_csv(StringIO(resp['Body'].read().decode('utf-8')))
        df.columns = df.columns.str.strip().str.lower().str.replace(' ', '_').str.replace('-', '_')
        return df

    tables = {
        "customers": fetch("customers.csv"),
        "orders": fetch("orders.csv"),
        "delivery": fetch("delivery.csv"),
        "order_items": fetch("order_items.csv"),
        "outlets": fetch("outlets.csv"),
        "menu_items": fetch("menu_items.csv"),
        "feedback": fetch("feedback.csv"),
        "promotions": fetch("promotions.csv")
    }

    print("\n--- PRIMARY KEY STANDARDIZATION ---")
    for table_name, pk_col in PKS.items():
        tables[table_name] = clean_pk(tables[table_name], table_name, pk_col)

    print("\n--- FOREIGN KEY STANDARDIZATION ---")
    # Clean, Strip, and Upper ALL foreign keys BEFORE enforcing relationships
    fk_cols_to_clean = {
        'feedback': ['order_id', 'customer_id', 'outlet_id'],
        'order_items': ['order_id', 'item_id'],
        'delivery': ['order_id'],
        'orders': ['customer_id', 'promo_id', 'outlet_id']
    }
    for table_name, cols in fk_cols_to_clean.items():
        for col in cols:
            if col in tables[table_name].columns:
                tables[table_name][col] = tables[table_name][col].astype(str).str.strip().str.upper()
                tables[table_name][col] = tables[table_name][col].replace(['NAN', 'NONE', 'NULL', ''], np.nan)

    tables = enforce_fks(tables)

    print("\n--- DATETIME PARSING & SPLITTING ---")
    tables['outlets']['opened_date'] = tables['outlets']['opened_date'].apply(parse_datetime_robust).dt.date
    tables['menu_items']['launch_date'] = tables['menu_items']['launch_date'].apply(parse_datetime_robust).dt.date
    tables['customers']['registered_date'] = tables['customers']['registered_date'].apply(parse_datetime_robust).dt.date
    tables['promotions']['start_date'] = tables['promotions']['start_date'].apply(parse_datetime_robust).dt.date
    tables['promotions']['end_date'] = tables['promotions']['end_date'].apply(parse_datetime_robust).dt.date
    if 'feedback_date' in tables['feedback'].columns:
        tables['feedback']['feedback_date'] = tables['feedback']['feedback_date'].apply(parse_datetime_robust).dt.date

    print("Processing orders -> order_date & order_time")
    orders = tables['orders']
    orders['order_date'] = orders['order_date'].apply(fix_dots).apply(fix_ampm).apply(parse_datetime_robust)
    orders['order_time'] = orders['order_date'].dt.time
    orders['order_date'] = orders['order_date'].dt.date
    tables['orders'] = orders

    print("Processing delivery -> TEMP DATETIMES for Phase 4 Math")
    delivery = tables['delivery']
    if 'assigned_time' in delivery.columns:
        delivery['temp_assign_dt'] = delivery['assigned_time'].apply(fix_dots).apply(fix_ampm).apply(parse_datetime_robust)

    if 'pickup_time' in delivery.columns:
        delivery['temp_pickup_dt'] = delivery['pickup_time'].apply(fix_dots).apply(fix_ampm).apply(parse_datetime_robust)
        
    deliv_col = 'delivered_date' if 'delivered_date' in delivery.columns else 'delivered_time'
    if deliv_col in delivery.columns:
        delivery['temp_deliv_dt'] = delivery[deliv_col].apply(fix_dots).apply(fix_ampm).apply(parse_datetime_robust)
        if deliv_col == 'delivered_date':
            delivery.drop(columns=['delivered_date'], inplace=True)
            
    tables['delivery'] = delivery

    print("\n--- RATING NORMALIZATION ---")
    fb = tables['feedback']
    rating_cols = ['food_rating', 'service_rating', 'ambience_rating']
    for rc in rating_cols:
        if rc in fb.columns:
            fb[rc] = fb[rc].apply(clean_ratings)
    fb['overall_rating'] = fb[rating_cols].mean(axis=1).round(1)
    tables['feedback'] = fb

    if 'delivery_rating' in tables['delivery'].columns:
        tables['delivery']['delivery_rating'] = tables['delivery']['delivery_rating'].apply(clean_ratings)

    print("\n--- CATEGORICAL MAPPINGS ---")
    if 'city' in tables['customers'].columns:
        tables['customers']['city'] = tables['customers']['city'].astype(str).str.strip().str.lower().map(CITY_MAPPING).fillna(tables['customers']['city'].astype(str).str.title())
    
    if 'city' in tables['outlets'].columns:
        tables['outlets']['city'] = tables['outlets']['city'].astype(str).str.strip().str.lower().map(CITY_MAPPING).fillna(tables['outlets']['city'].astype(str).str.title())

    if 'payment_method' in tables['orders'].columns:
        tables['orders']['payment_method'] = tables['orders']['payment_method'].astype(str).str.strip().str.lower().map(PAYMENT_MAPPING).fillna(tables['orders']['payment_method'].astype(str).str.title())

    print("Phase 1 Complete ✅")
    return tables

def process_phase_two(tables: dict) -> dict:
    print("\n--- STARTING PHASE 2: BUSINESS LOGIC & COLUMN CLEANING ---")
    
    print("Processing Outlets...")
    outlets = tables['outlets']
    if 'address' in outlets.columns: outlets['address'] = outlets['address'].apply(smart_title_address)
    if 'region' in outlets.columns: outlets['region'] = outlets['region'].astype(str).str.strip().str.title()
    if 'manager_name' in outlets.columns:
        outlets['manager_name'] = outlets['manager_name'].astype(str).str.strip().str.title()
        missing_mgr = ['Nan', 'None', 'Null', '', 'Tbd', 'Not Mention']
        outlets['manager_name'] = outlets['manager_name'].replace(missing_mgr, 'Unknown')
    if 'is_active' in outlets.columns:
        active_map = {'1': 'Yes', 'yes': 'Yes', 'true': 'Yes', '0': 'No', 'no': 'No', 'false': 'No'}
        outlets['is_active'] = outlets['is_active'].astype(str).str.strip().str.lower().map(active_map).fillna('Yes')
    tables['outlets'] = outlets

    print("Processing Menu Items...")
    menu = tables['menu_items']
    for col in ['item_name', 'category', 'sub_category']:
        if col in menu.columns: menu[col] = menu[col].astype(str).str.strip().str.title()
    if 'price' in menu.columns: menu['price'] = menu['price'].apply(lambda x: clean_money_to_number(x, return_int=True))
    if 'cost_price' in menu.columns: menu['cost_price'] = menu['cost_price'].apply(lambda x: clean_money_to_number(x, return_int=False))
    if 'calories' in menu.columns and 'item_name' in menu.columns:
        menu['calories'] = menu['item_name'].map(CALORIES_MAP).fillna(menu['calories'])
    if 'is_available' in menu.columns:
        avail_map = {'1': 'Yes', 'yes': 'Yes', '0': 'No', 'no': 'No'}
        menu['is_available'] = menu['is_available'].astype(str).str.strip().str.lower().map(avail_map).fillna('Yes')
    tables['menu_items'] = menu

    print("Processing Customers...")
    cust = tables['customers']
    if 'full_name' in cust.columns: cust.rename(columns={'full_name': 'customer_name'}, inplace=True)
    if 'customer_name' in cust.columns:
        cust['customer_name'] = cust['customer_name'].astype(str).str.strip().str.title()
        cust['customer_name'] = cust['customer_name'].replace(['Nan', 'None', '', 'Null'], 'Unknown')
    if 'email' in cust.columns:
        cust['email_raw'] = cust['email']
        cust['email'] = cust.apply(mask_email, axis=1)
        cust.drop(columns=['email_raw'], inplace=True)
    if 'phone' in cust.columns: cust['phone'] = cust['phone'].apply(mask_phone)
    if 'gender' in cust.columns:
        gender_map = {'m': 'Male', 'male': 'Male', 'f': 'Female', 'female': 'Female'}
        cust['gender'] = cust['gender'].astype(str).str.strip().str.lower().map(gender_map).fillna('Unknown')
    if 'age_band' in cust.columns:
        cust['age_band'] = cust['age_band'].astype(str).str.strip().str.title().replace(['Nan', 'None', 'Null', ''], 'Not Mention')
    tables['customers'] = cust

    print("Processing Promotions...")
    promos = tables['promotions']
    
    # Promo code ko UPPER case 
    if 'promo_code' in promos.columns: 
        promos['promo_code'] = promos['promo_code'].astype(str).str.strip().str.upper()
        
    for col in ['promo_type', 'applicable_on']:
        if col in promos.columns: 
            promos[col] = promos[col].astype(str).str.strip().str.title()

    if 'discount_value' in promos.columns and 'promo_code' in promos.columns:
        mega_mask = promos['promo_code'].str.upper() == 'MEGA25'
        super_mask = promos['promo_code'].str.upper() == 'SUPER50'
        promos.loc[mega_mask & promos['discount_value'].isna(), 'discount_value'] = 250.00
        promos.loc[super_mask & promos['discount_value'].isna(), 'discount_value'] = 0.00
        promos['discount_value'] = pd.to_numeric(promos['discount_value'], errors='coerce').round(2)
    if 'min_order_value' in promos.columns: promos['min_order_value'] = pd.to_numeric(promos['min_order_value'], errors='coerce').fillna(0).astype(int)
    if 'outlet_id' in promos.columns: promos['outlet_id'] = promos['outlet_id'].fillna('ALL')
    tables['promotions'] = promos

    print("Processing Orders...")
    orders = tables['orders']
    for col in ['order_status', 'order_type']:
        if col in orders.columns: orders[col] = orders[col].astype(str).str.strip().str.title()
    tables['orders'] = orders

    print("Processing Order Items...")
    order_items = tables['order_items']
    if 'special_instructions' in order_items.columns:
        order_items['special_instructions'] = order_items['special_instructions'].astype(str).str.strip().str.title()
        order_items['special_instructions'] = order_items['special_instructions'].replace(['N/A', '-', '...', 'Nan', 'None'], pd.NA)
    tables['order_items'] = order_items

    print("Processing Delivery...")
    delivery = tables['delivery']
    for col in ['delivery_partner', 'delivery_person_name', 'delivery_status']:
        if col in delivery.columns:
            delivery[col] = delivery[col].astype(str).str.strip().str.title()
            if col in ['delivery_partner', 'delivery_person_name']:
                delivery[col] = delivery[col].replace(['Nan', 'None', 'Null', ''], 'Unknown')
    if 'delivery_distance_km' in delivery.columns:
        delivery['delivery_distance_km'] = pd.to_numeric(delivery['delivery_distance_km'], errors='coerce').abs().round(2)
    tables['delivery'] = delivery

    print("Processing Feedback...")
    feedback = tables['feedback']
    if 'comments' in feedback.columns:
        feedback['comments'] = feedback['comments'].astype(str).str.strip().str.title()
        feedback['comments'] = feedback['comments'].replace(['Nan', 'None', 'Null', ''], pd.NA)
    tables['feedback'] = feedback

    print("Phase 2 Complete ✅")
    return tables

def process_phase_three(tables: dict) -> dict:
    print("\n--- STARTING FULL PHASE 3: DEPENDENCY & CROSS-TABLE LOGIC ---")

    outlets = tables.get('outlets')
    order_items = tables.get('order_items')
    orders = tables.get('orders')
    menu_items = tables.get('menu_items')
    promotions = tables.get('promotions')
    customers = tables.get('customers')
    delivery = tables.get('delivery')
    feedback = tables.get('feedback')

    print("Processing Outlets...")
    if outlets is not None:
        if 'outlet_type' in outlets.columns:
            outlets['outlet_type'] = outlets['outlet_type'].astype(str).str.strip().str.title()
        if 'seating_capacity' in outlets.columns:
            outlets['seating_capacity'] = pd.to_numeric(outlets['seating_capacity'], errors='coerce').fillna(0).abs().astype(int)
        tables['outlets'] = outlets

    print("Processing Order Items...")
    if order_items is not None and menu_items is not None:
        def clean_to_int(val):
            if pd.isna(val): return np.nan
            s = str(val).lower().replace('rs.', '').replace('rs', '').replace('₹', '').replace(',', '').strip()
            try: return int(round(float(s)))
            except ValueError: return np.nan

        price_col = 'unit_price' if 'unit_price' in order_items.columns else 'cost_price'
        
        if price_col in order_items.columns: order_items[price_col] = order_items[price_col].apply(clean_to_int)
        if 'subtotal' in order_items.columns: order_items['subtotal'] = order_items['subtotal'].apply(clean_to_int)
            
        if 'quantity' in order_items.columns:
            order_items['quantity'] = pd.to_numeric(order_items['quantity'], errors='coerce').abs()

        price_map = menu_items.set_index('item_id')['price']
        order_items[price_col] = order_items['item_id'].map(price_map).apply(clean_to_int).fillna(order_items[price_col])

        mask_bad_qty = order_items['quantity'].isna() | (order_items['quantity'] > 50) | (order_items['quantity'] == 0)
        calc_qty = (order_items['subtotal'] / order_items[price_col]).round(0)
        order_items.loc[mask_bad_qty, 'quantity'] = calc_qty[mask_bad_qty]

        order_items.loc[order_items['quantity'] > 50, 'quantity'] = 50
        order_items.loc[order_items['quantity'].isna() | (order_items['quantity'] <= 0), 'quantity'] = 1

        order_items['subtotal'] = (order_items['quantity'] * order_items[price_col]).fillna(0)

        order_items['quantity'] = order_items['quantity'].astype(int)
        order_items[price_col] = order_items[price_col].fillna(0).astype(int)
        order_items['subtotal'] = order_items['subtotal'].astype(int)

        tables['order_items'] = order_items

    print("Processing Orders...")
    if orders is not None and order_items is not None and promotions is not None:
        if 'order_type' in orders.columns:
            orders['order_type'] = orders['order_type'].astype(str).str.strip().str.title()
            
        order_totals = order_items.groupby('order_id')['subtotal'].sum()
        orders['total_amount'] = orders['order_id'].map(order_totals).fillna(0).astype(int)

        # Patching null Order Dates from Delivery or Feedback
        if 'order_date' in orders.columns:
            mask_null_od = orders['order_date'].isna()
            if mask_null_od.any():
                deliv_map = delivery.set_index('order_id')['assign_date'] if delivery is not None and 'assign_date' in delivery.columns else pd.Series(dtype='object')
                fb_map = feedback.set_index('order_id')['feedback_date'] if feedback is not None and 'feedback_date' in feedback.columns else pd.Series(dtype='object')
                
                mapped_from_deliv = orders.loc[mask_null_od, 'order_id'].map(deliv_map)
                mapped_from_fb = orders.loc[mask_null_od, 'order_id'].map(fb_map)
                
                orders.loc[mask_null_od, 'order_date'] = mapped_from_deliv.fillna(mapped_from_fb)

        orders['order_date'] = pd.to_datetime(orders['order_date'], errors='coerce')
        orders['week_type'] = orders['order_date'].dt.dayofweek.apply(
            lambda x: 'Weekend' if pd.notna(x) and x >= 5 else 'Weekday'
        )

        orders['promo_id'] = orders['promo_id'].astype(str).str.strip().str.upper().replace(['NAN', 'NONE', 'NULL'], np.nan)

        orders = orders.merge(
            promotions[['promo_id', 'applicable_on', 'start_date', 'end_date', 'min_order_value', 'promo_type', 'discount_value']], 
            on='promo_id', 
            how='left'
        )

        valid_promos = set(promotions['promo_id'].dropna().astype(str).str.upper())

        def evaluate_promotion(row):
            pid = row['promo_id']
            if pd.isna(pid) or str(pid).strip() == '': return "No promo", "No", 0
            if str(pid) not in valid_promos: return "Invalid Promo", "No", 0
            
            app_on = str(row['applicable_on']).strip().title()
            if "Weekend" in app_on and row['week_type'] != "Weekend": return "Invalid Week Type", "No", 0
            
            od = pd.to_datetime(row['order_date'])
            sd = pd.to_datetime(row['start_date'])
            ed = pd.to_datetime(row['end_date'])
            if pd.notna(od) and pd.notna(sd) and pd.notna(ed):
                if not (sd <= od <= ed): return "Expire Promo", "No", 0
                    
            mov = pd.to_numeric(row['min_order_value'], errors='coerce')
            if pd.notna(mov) and row['total_amount'] <= mov: return "Below Min Order", "No", 0
                
            ptype = str(row['promo_type']).strip().title()
            dval = pd.to_numeric(row['discount_value'], errors='coerce')
            dval = 0 if pd.isna(dval) else int(round(dval))
            
            if "Buy 1 Get 1" in ptype or "B1G1" in ptype: return "Buy 1 Get 1", "Yes", 0
            elif "Free Delivery" in ptype: return "Free Delivery", "Yes", 0
            elif "Cashback" in ptype: return "Cashback", "Yes", dval
            elif "Flat" in ptype: return "Flat Discount", "Yes", dval
            elif "Percentage" in ptype or "%" in ptype:
                calc_discount = int(round((row['total_amount'] * dval) / 100.0))
                return "Percentage used", "Yes", calc_discount
            return "No promo", "No", 0

        promo_results = orders.apply(evaluate_promotion, axis=1, result_type='expand')
        orders['promo_status'] = promo_results[0]
        orders['promo_used'] = promo_results[1]
        orders['discount_applied'] = promo_results[2].astype(int)

        orders['final_amount'] = (orders['total_amount'] - orders['discount_applied']).astype(int)
        
        # Override negative final amounts to 0
        orders.loc[orders['final_amount'] < 0, 'final_amount'] = 0

        drop_cols = ['applicable_on', 'start_date', 'end_date', 'min_order_value', 'promo_type', 'discount_value']
        orders.drop(columns=[c for c in drop_cols if c in orders.columns], inplace=True)

        tables['orders'] = orders

    print("Processing Feedback (Customer ID Sync)...")
    if feedback is not None and orders is not None:
        if 'customer_id' in feedback.columns:
            order_cust_map = orders.set_index('order_id')['customer_id']
            feedback['customer_id'] = feedback['customer_id'].fillna(feedback['order_id'].map(order_cust_map))
        tables['feedback'] = feedback

    print("Processing Customers (LTV & Loyalty Tiers)...")
    if customers is not None and orders is not None:
        ltv_series = orders.groupby('customer_id')['final_amount'].sum()
        customers['total_lifetime_value'] = customers['customer_id'].map(ltv_series).fillna(0).astype(int)
        ranked_ltv = customers['total_lifetime_value'].rank(method='first', pct=True)
        customers['loyalty_tier'] = pd.cut(
            ranked_ltv, 
            bins=[0, 0.25, 0.50, 0.75, 1.0], 
            labels=['Bronze', 'Silver', 'Gold', 'Platinum'], 
            include_lowest=True
        )
        tables['customers'] = customers

    print("Processing Promotions (Times Used)...")
    if promotions is not None and orders is not None:
        if 'promo_used' in orders.columns:
            successful_promos = orders[orders['promo_used'] == 'Yes']
        else:
            successful_promos = orders.dropna(subset=['promo_id'])
            
        promo_counts = successful_promos.groupby('promo_id').size()
        promotions['times_used'] = promotions['promo_id'].map(promo_counts).fillna(0).astype(int)
        tables['promotions'] = promotions

    print("Phase 3 Complete ✅")
    return tables

def process_phase_four(tables: dict) -> dict:
    print("\n--- STARTING PHASE 4: DATE & TEMPORAL LOGIC ---")

    customers = tables.get('customers')
    orders = tables.get('orders')
    promotions = tables.get('promotions')
    delivery = tables.get('delivery')
    feedback = tables.get('feedback')

    print("Patching Customer Registration Dates...")
    if customers is not None and orders is not None:
        orders['temp_order_date'] = pd.to_datetime(orders['order_date'], errors='coerce')
        first_orders = orders.groupby('customer_id')['temp_order_date'].min().dt.date
        
        # 1. Fill completely missing registration dates
        mask_null_reg = customers['registered_date'].isna()
        customers.loc[mask_null_reg, 'registered_date'] = customers.loc[mask_null_reg, 'customer_id'].map(first_orders)
        
        # 2. Overwrite reg date if the customer's first order occurred AFTER their registration date
        customers['temp_reg_date'] = pd.to_datetime(customers['registered_date'], errors='coerce').dt.date
        cust_first_order = customers['customer_id'].map(first_orders)
        mask_greater = cust_first_order > customers['temp_reg_date']
        customers.loc[mask_greater, 'registered_date'] = cust_first_order[mask_greater]

        customers['registered_date'] = pd.to_datetime(customers['registered_date']).dt.date
        customers.drop(columns=['temp_reg_date'], errors='ignore', inplace=True)
        tables['customers'] = customers

    print("Fixing Future Order Dates...")
    if orders is not None and delivery is not None and feedback is not None:
        cutoff_date = pd.to_datetime('2026-08-31')
        future_mask = orders['temp_order_date'] > cutoff_date
        
        if future_mask.any():
            if 'delivery_date' in delivery.columns:
                deliv_map = pd.to_datetime(delivery.set_index('order_id')['delivery_date'], errors='coerce')
            else:
                deliv_map = pd.Series(dtype='datetime64[ns]')
                
            if 'feedback_date' in feedback.columns:
                fb_map = pd.to_datetime(feedback.set_index('order_id')['feedback_date'], errors='coerce')
            else:
                fb_map = pd.Series(dtype='datetime64[ns]')
            
            mapped_from_deliv = orders.loc[future_mask, 'order_id'].map(deliv_map)
            mapped_from_fb = orders.loc[future_mask, 'order_id'].map(fb_map)
            fixed_dates = mapped_from_deliv.fillna(mapped_from_fb).fillna(orders.loc[future_mask, 'temp_order_date'])
            orders.loc[future_mask, 'temp_order_date'] = fixed_dates
            
        orders['order_date'] = orders['temp_order_date'].dt.date
        tables['orders'] = orders

    print("Patching Promotion End Dates...")
    if promotions is not None and orders is not None:
        last_orders = orders.groupby('promo_id')['temp_order_date'].max().dt.date
        mask_null_end = promotions['end_date'].isna()
        promotions.loc[mask_null_end, 'end_date'] = promotions.loc[mask_null_end, 'promo_id'].map(last_orders)
        promotions['end_date'] = pd.to_datetime(promotions['end_date']).dt.date
        tables['promotions'] = promotions

    if 'temp_order_date' in orders.columns:
        orders.drop(columns=['temp_order_date'], inplace=True)

    print("Resolving Delivery Timestamps & Durations...")
    if delivery is not None:
        if 'delivery_distance_km' in delivery.columns:
            delivery['delivery_distance_km'] = pd.to_numeric(delivery['delivery_distance_km'], errors='coerce').abs()
        if 'delivery_duration_mins' in delivery.columns:
            delivery['delivery_duration_mins'] = pd.to_numeric(delivery['delivery_duration_mins'], errors='coerce').abs()

        assign_dt = delivery['temp_assign_dt'] if 'temp_assign_dt' in delivery.columns else pd.Series(pd.NaT, index=delivery.index)
        pickup_dt = delivery['temp_pickup_dt'] if 'temp_pickup_dt' in delivery.columns else pd.Series(pd.NaT, index=delivery.index)
        deliv_dt = delivery['temp_deliv_dt'] if 'temp_deliv_dt' in delivery.columns else pd.Series(pd.NaT, index=delivery.index)

        dur_td = pd.to_timedelta(delivery['delivery_duration_mins'], unit='m')

        mask_no_pick = pickup_dt.isna() & deliv_dt.notna() & dur_td.notna()
        pickup_dt.loc[mask_no_pick] = deliv_dt[mask_no_pick] - dur_td[mask_no_pick]

        mask_no_deliv = deliv_dt.isna() & pickup_dt.notna() & dur_td.notna()
        deliv_dt.loc[mask_no_deliv] = pickup_dt[mask_no_deliv] + dur_td[mask_no_deliv]

        calc_dur = (deliv_dt - pickup_dt).dt.total_seconds() / 60.0
        mask_calc = calc_dur.notna() & (calc_dur >= 0)
        delivery.loc[mask_calc, 'delivery_duration_mins'] = calc_dur[mask_calc].round(2)

        diffs = (pickup_dt - assign_dt).dt.total_seconds() / 60.0
        valid_diffs = diffs[diffs > 0]
        median_diff = valid_diffs.median() if not valid_diffs.empty else 15.0 
        med_td = pd.to_timedelta(median_diff, unit='m')

        mask_bad_assign = assign_dt.isna() | (assign_dt >= pickup_dt)
        assign_dt.loc[mask_bad_assign] = pickup_dt[mask_bad_assign] - med_td

        delivery['assign_date'] = assign_dt.dt.date
        delivery['assign_time'] = assign_dt.dt.time
        delivery['pickup_date'] = pickup_dt.dt.date
        delivery['pickup_time'] = pickup_dt.dt.time
        delivery['delivery_date'] = deliv_dt.dt.date
        delivery['delivery_time'] = deliv_dt.dt.time
        
        delivery.drop(columns=['temp_assign_dt', 'temp_pickup_dt', 'temp_deliv_dt'], errors='ignore', inplace=True)

        tables['delivery'] = delivery

    print("Syncing Feedback Dates with Orders...")
    if feedback is not None and orders is not None:
        order_date_map = orders.set_index('order_id')['order_date']
        feedback['feedback_date'] = feedback['order_id'].map(order_date_map)
        tables['feedback'] = feedback


    # 1. Customer City: 'Nan' to 'Unknown'
    if 'city' in tables['customers'].columns:
        tables['customers']['city'] = tables['customers']['city'].replace(['Nan', 'None', 'Null', ''], 'Unknown')

    # 2. Orders table: Order_type 'Divry' to 'Delivery'
    if 'order_type' in tables['orders'].columns:
        tables['orders']['order_type'] = tables['orders']['order_type'].replace(['Divry', 'Dlvry'], 'Delivery')

    # 3. Orders table: Payment_method 'Nan' to 'Not Mention'
    if 'payment_method' in tables['orders'].columns:
        tables['orders']['payment_method'] = tables['orders']['payment_method'].replace(['Nan', 'None', 'Null', ''], 'Not Mention')


    # CUSTOMER REGISTRATION DATE FIX (Replace with First Order Date)
    print("Patching Customer Registration Dates...")
    if customers is not None and orders is not None:
        # Find the first order date for each customer safely
        temp_dates = pd.to_datetime(orders['order_date'], errors='coerce')
        first_orders = orders.assign(temp_date=temp_dates).groupby('customer_id')['temp_date'].min().dt.date
        
        # Map first order dates to the customers table
        cust_first_order = customers['customer_id'].map(first_orders)
        
        # Replace registered date with first order date. If no orders, keep original.
        customers['registered_date'] = cust_first_order.fillna(customers['registered_date'])
        
        # Ensure it remains a clean date object
        customers['registered_date'] = pd.to_datetime(customers['registered_date']).dt.date
        
        tables['customers'] = customers

    # MENU ITEM LAUNCH DATE FIX (Only fix impossible dates)
    print("Patching Menu Item Launch Dates...")
    
    # Extract the missing tables so Python knows what they are
    menu_items = tables.get('menu_items')
    order_items = tables.get('order_items')

    if menu_items is not None and order_items is not None and orders is not None:
        # 1. Grab order dates and map them to the items ordered
        temp_order_dates = pd.to_datetime(orders['order_date'], errors='coerce')
        order_date_map = orders.assign(temp_date=temp_order_dates).set_index('order_id')['temp_date']
        
        temp_items = order_items[['item_id', 'order_id']].copy()
        temp_items['mapped_order_date'] = temp_items['order_id'].map(order_date_map)
        
        # 2. Find the absolute first order date for each item
        first_item_orders = temp_items.groupby('item_id')['mapped_order_date'].min().dt.date
        item_first_order = menu_items['item_id'].map(first_item_orders)
        
        # 3. Safely compare the dates to find anomalies
        temp_launch = pd.to_datetime(menu_items['launch_date'], errors='coerce').dt.date
        mask_anomalies = temp_launch > item_first_order
        
        # 4. Overwrite ONLY the rows where launch date is greater than first order date
        menu_items.loc[mask_anomalies, 'launch_date'] = item_first_order[mask_anomalies]
        
        # Ensure it remains a clean date object
        menu_items['launch_date'] = pd.to_datetime(menu_items['launch_date']).dt.date
        
        tables['menu_items'] = menu_items


    # OUTLET OPENED DATE FIX (Only fix impossible dates & nulls)
    print("Patching Outlet Opened Dates...")
    
    # Extract the outlets table
    outlets = tables.get('outlets')
    
    if outlets is not None and orders is not None:
        # 1. Get the first order date for every outlet
        temp_order_dates = pd.to_datetime(orders['order_date'], errors='coerce')
        first_orders = orders.assign(temp_date=temp_order_dates).groupby('outlet_id')['temp_date'].min().dt.date
        outlet_first_order = outlets['outlet_id'].map(first_orders)
        
        # 2. Fill completely missing opened dates
        mask_null_opened = outlets['opened_date'].isna()
        outlets.loc[mask_null_opened, 'opened_date'] = outlet_first_order[mask_null_opened]
        
        # 3. Overwrite ONLY if opened date > first order date (chronologically impossible)
        temp_opened = pd.to_datetime(outlets['opened_date'], errors='coerce').dt.date
        mask_outlet_anomalies = temp_opened > outlet_first_order
        outlets.loc[mask_outlet_anomalies, 'opened_date'] = outlet_first_order[mask_outlet_anomalies]
        
        # 4. Ensure it remains a clean date object
        outlets['opened_date'] = pd.to_datetime(outlets['opened_date']).dt.date
        tables['outlets'] = outlets

    # RECOUNT AND FIX ALL DELIVERY DURATION MINUTES (Same Day & Next Day) 
    print(
        "Recounting all delivery durations using full assign and delivery"
        " timestamps..."
    )

    delivery = tables.get("delivery")

    if delivery is not None:
        # 1. Assign aur Delivery ke date + time ko combine karke full datetime banana
        assign_dt = pd.to_datetime(
            delivery["assign_date"].astype(str)
            + " "
            + delivery["assign_time"].astype(str),
            errors="coerce",
        )
        delivery_dt = pd.to_datetime(
            delivery["delivery_date"].astype(str)
            + " "
            + delivery["delivery_time"].astype(str),
            errors="coerce",
        )

        # 2. Total duration minutes mein nikalna (yeh same-day aur next-day dono ko handle karega)
        duration_diff = (delivery_dt - assign_dt).dt.total_seconds() / 60

        # 3. Valid durations ko update karna (jo negative na hon)
        valid_mask = duration_diff >= 0
        delivery.loc[valid_mask, "delivery_duration_mins"] = duration_diff[
            valid_mask
        ].round(2)

        tables["delivery"] = delivery

    # DELIVERY TABLE CLEANUP (Drop Redundant/Unnecessary Columns)
    print("Cleaning up redundant columns in the Delivery table...")
    
    # Extract the delivery table
    delivery = tables.get('delivery')
    
    if delivery is not None:
        # Business Logic for dropping columns:
        # 1. assigned_time: We already have separate 'assign_date' and 'assign_time' columns.
        # 2. pickup_date & delivery_date: Food delivery happens on the same day as the order. 
        #    Tracking separate dates for pickup/delivery is unnecessary and takes up space.
        
        columns_to_drop = ['assigned_time', 'pickup_date', 'delivery_date', 'Delivery_date']
        
        # Drop the columns (errors='ignore' prevents crashes if a column was already dropped)
        delivery.drop(columns=columns_to_drop, errors='ignore', inplace=True)
        
        tables['delivery'] = delivery


    # FILL MISSING ORDER DATES FROM DELIVERY TABLE
    print("Patching missing order dates using Delivery assignment dates...")
    
    orders = tables.get('orders')
    delivery = tables.get('delivery')
    
    if orders is not None and delivery is not None:
        # 1. Create a mapping of order_id to assign_date from the delivery table
        delivery_dates_map = delivery.set_index('order_id')['assign_date']
        
        # 2. Identify rows where order_date is missing (NaN)
        mask_null_orders = orders['order_date'].isna()
        
        # 3. Fill those missing dates using the delivery mapping
        orders.loc[mask_null_orders, 'order_date'] = orders.loc[mask_null_orders, 'order_id'].map(delivery_dates_map)
        
        # 4. Ensure order_date remains a clean date object format
        orders['order_date'] = pd.to_datetime(orders['order_date'], errors='coerce').dt.date
        
        tables['orders'] = orders


    # FILL MISSING ORDER TIMES FROM DELIVERY ASSIGN TIMES
    print("Patching missing order times using Delivery assign times...")
    
    orders = tables.get('orders')
    delivery = tables.get('delivery')
    
    if orders is not None and delivery is not None:
        # 1. Create a mapping of order_id to assign_time from the delivery table
        delivery_times_map = delivery.set_index('order_id')['assign_time']
        
        # 2. Identify strictly rows where order_time is missing (NaN/Null)
        mask_null_order_times = orders['order_time'].isna()
        
        # 3. Fill those missing times using the delivery mapping
        orders.loc[mask_null_order_times, 'order_time'] = orders.loc[mask_null_order_times, 'order_id'].map(delivery_times_map)
        
        tables['orders'] = orders

    # FIX ZERO DELIVERY DURATION & ADJUST DELIVERY TIME
    print("Fixing 0-minute delivery durations and adjusting delivery times...")
    
    delivery = tables.get('delivery')
    orders = tables.get('orders')
    
    if delivery is not None and orders is not None:
        # 1. Merge order_type into delivery dataframe to filter correctly
        if 'order_type' in orders.columns:
            merged_delivery = delivery.merge(orders[['order_id', 'order_type']], on='order_id', how='left')
        else:
            merged_delivery = delivery.copy()
            merged_delivery['order_type'] = 'Delivery' # fallback if order_type isn't present
            
        # 2. Find rows where duration is 0 and it's a Delivery type (not pickup/takeaway)
        is_zero_duration = merged_delivery['delivery_duration_mins'] == 0
        is_delivery_type = merged_delivery['order_type'].str.lower() != 'take away'
        
        mask_fix = is_zero_duration & is_delivery_type
        
        # Get the original index list to apply changes back to the main delivery table
        target_indices = merged_delivery[mask_fix].index
        
        if len(target_indices) > 0:
            # A. Change duration from 0 to 20 minutes
            delivery.loc[target_indices, 'delivery_duration_mins'] = 20
            
            # B. Convert delivery_time to datetime, add 20 minutes, and convert back to time format
            valid_delivery_times = pd.to_datetime(delivery.loc[target_indices, 'delivery_time'], format='%H:%M:%S', errors='coerce')
            adjusted_times = valid_delivery_times + pd.Timedelta(minutes=20)
            
            delivery.loc[target_indices, 'delivery_time'] = adjusted_times.dt.strftime('%H:%M:%S')
            
        tables['delivery'] = delivery 


    # FIX OR DROP DELIVERY ROWS BASED ON OUTLET TYPE
    print("Checking delivery vs order types and outlet constraints...")
    
    delivery = tables.get('delivery')
    orders = tables.get('orders')
    outlets = tables.get('outlets') # Table name is 'outlets'
    
    if delivery is not None and orders is not None and outlets is not None:
        # 1. Merge delivery with orders to get order_type and outlet_id
        merged_df = delivery.merge(orders[['order_id', 'order_type', 'outlet_id']], on='order_id', how='left')
        
        # 2. Merge with outlets to get outlet_type
        merged_df = merged_df.merge(outlets[['outlet_id', 'outlet_type']], on='outlet_id', how='left')
        
        # 3. Condition A: Outlet type is 'Dine-In Only' -> Drop these rows from the delivery table
        dine_in_mask = merged_df['outlet_type'].str.strip().str.lower() == 'dine-in only'
        order_ids_to_drop = merged_df[dine_in_mask]['order_id'].tolist()
        
        if len(order_ids_to_drop) > 0:
            delivery = delivery[~delivery['order_id'].isin(order_ids_to_drop)]
            print(f"Dropped {len(order_ids_to_drop)} delivery rows because their outlet is 'Dine-In Only'.")
            
        # 4. Condition B: Outlet type is NOT 'Dine-In Only' -> Update order_type to 'Delivery' in the orders table
        # Find order_ids in delivery that are NOT dine-in only, but their order_type is not 'Delivery'
        valid_delivery_mask = ~merged_df['outlet_type'].str.strip().str.lower().eq('dine-in only').fillna(False)
        not_delivery_type = merged_df['order_type'].str.strip().str.lower() != 'delivery'
        
        order_ids_to_fix = merged_df[valid_delivery_mask & not_delivery_type]['order_id'].dropna().tolist()
        
        if len(order_ids_to_fix) > 0:
            orders.loc[orders['order_id'].isin(order_ids_to_fix), 'order_type'] = 'Delivery'
            print(f"Updated order_type to 'Delivery' for {len(order_ids_to_fix)} orders in the orders table.")
            
        # Update tables back in memory dictionary
        tables['delivery'] = delivery
        tables['orders'] = orders   


    # ==================================================================================================================================
    
    tables['customers']['total_lifetime_value'] = pd.to_numeric(tables['customers']['total_lifetime_value'], errors='coerce').fillna(0)

    # Define conditions
    conditions = [
        (tables['customers']['total_lifetime_value'] >= 15000),
        (tables['customers']['total_lifetime_value'] >= 5000) & (tables['customers']['total_lifetime_value'] < 15000),
        (tables['customers']['total_lifetime_value'] >= 1000) & (tables['customers']['total_lifetime_value'] < 5000),
        (tables['customers']['total_lifetime_value'] < 1000)
    ]

    # Assign and overwrite
    choices = ['Platinum', 'Gold', 'Silver', 'Bronze']
    tables['customers']['loyalty_tier'] = np.select(conditions, choices, default='Bronze')


    # Delivery duration ko maximum 60 minutes par cap karna
    tables['delivery']['delivery_duration_mins'] = tables['delivery']['delivery_duration_mins'].clip(upper=60)

    # Delivery distance ko maximum 30 KM par cap karna
    tables['delivery']['delivery_distance_km'] = tables['delivery']['delivery_distance_km'].clip(upper=30)


# ==========================================================================================================================================================
# Some Changes in delivery column are code 

    # Fix delivery_partner inconsistent naming
    if 'delivery_partner' in tables['delivery'].columns:
        tables['delivery']['delivery_partner'] = tables['delivery']['delivery_partner'].replace({
            'Inhouse'       : 'In-House Fleet',
            'In House Fleet': 'In-House Fleet',
            'In-House'      : 'In-House Fleet',
            'Inhousefleet'  : 'In-House Fleet',
        })
    print("delivery_partner fixed — Inhouse → In-House Fleet ✅")

# ==============================================================================================================================================================
# Change in assign time and delivery time 
# Fix pickup_time and delivery_time to time format
    for col in ['pickup_time', 'delivery_time']:
        if col in tables['delivery'].columns:
            tables['delivery'][col] = tables['delivery'][col].apply(
                lambda x: datetime.datetime.strptime(str(x).strip(), '%H:%M:%S').time()
                if pd.notnull(x) and str(x).strip() not in ['nan', 'None', 'NaT', '']
                else None
            )
            print(f"{col} converted to time format ✅")

# =================================================================================================================
    print("Phase 4 Complete ✅")
    return tables

# =============================================================================
# 4. SECURE RDS UPLOAD
# =============================================================================

def load_to_rds(tables: dict):
    print("\n--- CONNECTING TO RDS & UPLOADING ---")
    
    engine = create_engine(
        f"mysql+mysqlconnector://{RDS_USER}:{quote_plus(RDS_PASSWORD)}@{RDS_HOST}:{RDS_PORT}/{RDS_DATABASE}",
        pool_pre_ping=True, future=True
    )
    
    with engine.begin() as conn:
        conn.execute(text("SET FOREIGN_KEY_CHECKS=0"))

        # ===================================================================================================================================
        conn.execute(text("DROP TABLE IF EXISTS feedback, delivery, order_items, orders, customers, menu_items, outlets, promotions;"))
        
        # 1. Customers
        print("Uploading customers...")
        tables["customers"].to_sql(name="customers", con=conn, if_exists="replace", index=False, chunksize=6800, method="multi")
        conn.execute(text("ALTER TABLE customers MODIFY customer_id VARCHAR(100);"))
        conn.execute(text("ALTER TABLE customers ADD PRIMARY KEY (customer_id);"))
        
        # 2. Menu Items
        print("Uploading menu_items...")
        tables["menu_items"].to_sql(name="menu_items", con=conn, if_exists="replace", index=False, chunksize=6800, method="multi")
        conn.execute(text("ALTER TABLE menu_items MODIFY item_id VARCHAR(100);"))
        conn.execute(text("ALTER TABLE menu_items ADD PRIMARY KEY (item_id);"))
        
        # 3. Outlets
        print("Uploading outlets...")
        tables["outlets"].to_sql(name="outlets", con=conn, if_exists="replace", index=False, chunksize=6800, method="multi")
        conn.execute(text("ALTER TABLE outlets MODIFY outlet_id VARCHAR(100);"))
        conn.execute(text("ALTER TABLE outlets ADD PRIMARY KEY (outlet_id);"))
        
        # 4. Promotions
        print("Uploading promotions...")
        tables["promotions"].to_sql(name="promotions", con=conn, if_exists="replace", index=False, chunksize=6800, method="multi")
        conn.execute(text("ALTER TABLE promotions MODIFY promo_id VARCHAR(100);"))
        conn.execute(text("ALTER TABLE promotions ADD PRIMARY KEY (promo_id);"))
        
        # 5. Orders (PK + FKs)
        print("Uploading orders...")
        tables["orders"].to_sql(name="orders", con=conn, if_exists="replace", index=False, chunksize=6800, method="multi")
        conn.execute(text("ALTER TABLE orders MODIFY order_id VARCHAR(100);"))
        conn.execute(text("ALTER TABLE orders MODIFY customer_id VARCHAR(100);"))
        conn.execute(text("ALTER TABLE orders MODIFY outlet_id VARCHAR(100);"))
        conn.execute(text("ALTER TABLE orders MODIFY promo_id VARCHAR(100);"))
        conn.execute(text("ALTER TABLE orders ADD PRIMARY KEY (order_id);"))
        conn.execute(text("ALTER TABLE orders ADD CONSTRAINT fk_orders_customers FOREIGN KEY (customer_id) REFERENCES customers(customer_id);"))
        conn.execute(text("ALTER TABLE orders ADD CONSTRAINT fk_orders_outlets FOREIGN KEY (outlet_id) REFERENCES outlets(outlet_id);"))
        conn.execute(text("ALTER TABLE orders ADD CONSTRAINT fk_orders_promotions FOREIGN KEY (promo_id) REFERENCES promotions(promo_id);"))
        
        # 6. Order Items (PK + FKs)
        print("Uploading order_items...")
        tables["order_items"].to_sql(name="order_items", con=conn, if_exists="replace", index=False, chunksize=6800, method="multi")
        conn.execute(text("ALTER TABLE order_items MODIFY order_item_id VARCHAR(100);"))
        conn.execute(text("ALTER TABLE order_items MODIFY order_id VARCHAR(100);"))
        conn.execute(text("ALTER TABLE order_items MODIFY item_id VARCHAR(100);"))
        conn.execute(text("ALTER TABLE order_items ADD PRIMARY KEY (order_item_id);"))
        conn.execute(text("ALTER TABLE order_items ADD CONSTRAINT fk_order_items_orders FOREIGN KEY (order_id) REFERENCES orders(order_id);"))
        conn.execute(text("ALTER TABLE order_items ADD CONSTRAINT fk_order_items_menu FOREIGN KEY (item_id) REFERENCES menu_items(item_id);"))
        
        # 7. Delivery (PK + FK)
        print("Uploading delivery...")
        tables["delivery"].to_sql(name="delivery", con=conn, if_exists="replace", index=False, chunksize=6800, method="multi")
        conn.execute(text("ALTER TABLE delivery MODIFY delivery_id VARCHAR(100);"))
        conn.execute(text("ALTER TABLE delivery MODIFY order_id VARCHAR(100);"))
        conn.execute(text("ALTER TABLE delivery ADD PRIMARY KEY (delivery_id);"))
        conn.execute(text("ALTER TABLE delivery ADD CONSTRAINT fk_delivery_orders FOREIGN KEY (order_id) REFERENCES orders(order_id);"))
        
        # 8. Feedback (PK + FKs)
        print("Uploading feedback...")
        tables["feedback"].to_sql(name="feedback", con=conn, if_exists="replace", index=False, chunksize=6800, method="multi")
        conn.execute(text("ALTER TABLE feedback MODIFY feedback_id VARCHAR(100);"))
        conn.execute(text("ALTER TABLE feedback MODIFY order_id VARCHAR(100);"))
        conn.execute(text("ALTER TABLE feedback MODIFY customer_id VARCHAR(100);"))
        conn.execute(text("ALTER TABLE feedback MODIFY outlet_id VARCHAR(100);"))
        conn.execute(text("ALTER TABLE feedback ADD PRIMARY KEY (feedback_id);"))
        conn.execute(text("ALTER TABLE feedback ADD CONSTRAINT fk_feedback_orders FOREIGN KEY (order_id) REFERENCES orders(order_id);"))
        conn.execute(text("ALTER TABLE feedback ADD CONSTRAINT fk_feedback_customers FOREIGN KEY (customer_id) REFERENCES customers(customer_id);"))
        conn.execute(text("ALTER TABLE feedback ADD CONSTRAINT fk_feedback_outlets FOREIGN KEY (outlet_id) REFERENCES outlets(outlet_id);"))
        
        conn.execute(text("SET FOREIGN_KEY_CHECKS=1"))
        
    print("RDS Upload & Constraints Complete ✅")



# ============================================================================
# VS Code to S3 Bucket 
# ============================================================================

def upload_to_s3(tables: dict):
    print("\n--- UPLOADING CLEAN DATA TO S3 ---")
    
    s3 = boto3.client('s3', region_name=AWS_REGION)
    PROCESSED_BUCKET = 'ra2-processed-data'
    
    for table_name, df in tables.items():
        print(f"Uploading {table_name} to S3...")
        
        csv_buffer = StringIO()
        df.to_csv(csv_buffer, index=False)
        
        s3.put_object(
            Bucket = PROCESSED_BUCKET,
            Key    = f'{table_name}.csv',
            Body   = csv_buffer.getvalue()
        )
        
        print(f"{table_name} uploaded ✅ | rows : {len(df)}")
    
    print("\nAll tables uploaded to S3 successfully ✅")
    print("S3 Upload & Constraints Complete ✅")


# =============================================================================
# 5. MAIN EXECUTION
# =============================================================================

def main():
    tables = execute_phase_one()
    tables = process_phase_two(tables)
    tables = process_phase_three(tables)
    tables = process_phase_four(tables)
    load_to_rds(tables)
    upload_to_s3(tables)
    print("\n" + "=" * 80)
    print("PIPELINE COMPLETE ✅ ALL DATA IS CLEAN & LIVE IN AWS")
    print("=" * 80)

if __name__ == "__main__":
    main()
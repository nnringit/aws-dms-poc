-- =============================================================================
-- Sample E-Commerce Database Schema and Data
-- This script creates tables and populates them with sample data
-- =============================================================================

-- Drop existing tables if they exist (in correct order due to foreign keys)
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS inventory CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

-- =============================================================================
-- Table: categories
-- =============================================================================
CREATE TABLE categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- Table: customers
-- =============================================================================
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(50),
    postal_code VARCHAR(20),
    country VARCHAR(50) DEFAULT 'USA',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index on email for faster lookups
CREATE INDEX idx_customers_email ON customers(email);

-- =============================================================================
-- Table: products
-- =============================================================================
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    category_id INTEGER REFERENCES categories(category_id),
    product_name VARCHAR(255) NOT NULL,
    description TEXT,
    sku VARCHAR(50) UNIQUE NOT NULL,
    price DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
    cost DECIMAL(10, 2) CHECK (cost >= 0),
    weight DECIMAL(8, 2),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_sku ON products(sku);

-- =============================================================================
-- Table: inventory
-- =============================================================================
CREATE TABLE inventory (
    inventory_id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(product_id) UNIQUE,
    quantity_on_hand INTEGER NOT NULL DEFAULT 0 CHECK (quantity_on_hand >= 0),
    quantity_reserved INTEGER NOT NULL DEFAULT 0 CHECK (quantity_reserved >= 0),
    reorder_point INTEGER DEFAULT 10,
    reorder_quantity INTEGER DEFAULT 50,
    warehouse_location VARCHAR(50),
    last_restocked_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- Table: orders
-- =============================================================================
CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id),
    order_number VARCHAR(50) UNIQUE NOT NULL,
    order_status VARCHAR(20) NOT NULL DEFAULT 'pending' 
        CHECK (order_status IN ('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled')),
    subtotal DECIMAL(12, 2) NOT NULL DEFAULT 0,
    tax_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
    shipping_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
    total_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
    shipping_address_line1 VARCHAR(255),
    shipping_address_line2 VARCHAR(255),
    shipping_city VARCHAR(100),
    shipping_state VARCHAR(50),
    shipping_postal_code VARCHAR(20),
    shipping_country VARCHAR(50) DEFAULT 'USA',
    notes TEXT,
    ordered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    shipped_at TIMESTAMP,
    delivered_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_status ON orders(order_status);
CREATE INDEX idx_orders_number ON orders(order_number);
CREATE INDEX idx_orders_date ON orders(ordered_at);

-- =============================================================================
-- Table: order_items
-- =============================================================================
CREATE TABLE order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES products(product_id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10, 2) NOT NULL,
    discount_percent DECIMAL(5, 2) DEFAULT 0,
    line_total DECIMAL(12, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id);

-- =============================================================================
-- Insert Sample Data: Categories
-- =============================================================================
INSERT INTO categories (category_name, description) VALUES
('Electronics', 'Electronic devices and accessories'),
('Clothing', 'Apparel and fashion items'),
('Books', 'Books, magazines, and publications'),
('Home & Garden', 'Home improvement and garden supplies'),
('Sports & Outdoors', 'Sporting goods and outdoor equipment'),
('Toys & Games', 'Toys, games, and entertainment'),
('Health & Beauty', 'Health, beauty, and personal care products'),
('Automotive', 'Car parts and accessories'),
('Food & Beverages', 'Food items and drinks'),
('Office Supplies', 'Office and school supplies');

-- =============================================================================
-- Insert Sample Data: Customers (50 customers)
-- =============================================================================
INSERT INTO customers (email, first_name, last_name, phone, address_line1, city, state, postal_code, country) VALUES
('john.smith@email.com', 'John', 'Smith', '555-0101', '123 Main St', 'New York', 'NY', '10001', 'USA'),
('jane.doe@email.com', 'Jane', 'Doe', '555-0102', '456 Oak Ave', 'Los Angeles', 'CA', '90001', 'USA'),
('bob.johnson@email.com', 'Bob', 'Johnson', '555-0103', '789 Pine Rd', 'Chicago', 'IL', '60601', 'USA'),
('alice.williams@email.com', 'Alice', 'Williams', '555-0104', '321 Elm St', 'Houston', 'TX', '77001', 'USA'),
('charlie.brown@email.com', 'Charlie', 'Brown', '555-0105', '654 Maple Dr', 'Phoenix', 'AZ', '85001', 'USA'),
('diana.davis@email.com', 'Diana', 'Davis', '555-0106', '987 Cedar Ln', 'Philadelphia', 'PA', '19101', 'USA'),
('edward.miller@email.com', 'Edward', 'Miller', '555-0107', '147 Birch Way', 'San Antonio', 'TX', '78201', 'USA'),
('fiona.wilson@email.com', 'Fiona', 'Wilson', '555-0108', '258 Spruce Ct', 'San Diego', 'CA', '92101', 'USA'),
('george.moore@email.com', 'George', 'Moore', '555-0109', '369 Walnut Pl', 'Dallas', 'TX', '75201', 'USA'),
('helen.taylor@email.com', 'Helen', 'Taylor', '555-0110', '741 Ash Blvd', 'San Jose', 'CA', '95101', 'USA'),
('ivan.anderson@email.com', 'Ivan', 'Anderson', '555-0111', '852 Poplar St', 'Austin', 'TX', '78701', 'USA'),
('julia.thomas@email.com', 'Julia', 'Thomas', '555-0112', '963 Willow Ave', 'Jacksonville', 'FL', '32099', 'USA'),
('kevin.jackson@email.com', 'Kevin', 'Jackson', '555-0113', '159 Cherry Rd', 'Fort Worth', 'TX', '76101', 'USA'),
('laura.white@email.com', 'Laura', 'White', '555-0114', '267 Peach Dr', 'Columbus', 'OH', '43085', 'USA'),
('michael.harris@email.com', 'Michael', 'Harris', '555-0115', '378 Apple Ln', 'Charlotte', 'NC', '28201', 'USA'),
('nancy.martin@email.com', 'Nancy', 'Martin', '555-0116', '489 Orange Way', 'Seattle', 'WA', '98101', 'USA'),
('oscar.garcia@email.com', 'Oscar', 'Garcia', '555-0117', '591 Grape Ct', 'Denver', 'CO', '80201', 'USA'),
('patricia.martinez@email.com', 'Patricia', 'Martinez', '555-0118', '682 Lemon Pl', 'Washington', 'DC', '20001', 'USA'),
('quinn.robinson@email.com', 'Quinn', 'Robinson', '555-0119', '793 Lime Blvd', 'Boston', 'MA', '02101', 'USA'),
('rachel.clark@email.com', 'Rachel', 'Clark', '555-0120', '814 Mango St', 'El Paso', 'TX', '79901', 'USA'),
('samuel.rodriguez@email.com', 'Samuel', 'Rodriguez', '555-0121', '925 Kiwi Ave', 'Nashville', 'TN', '37201', 'USA'),
('tina.lewis@email.com', 'Tina', 'Lewis', '555-0122', '136 Banana Rd', 'Detroit', 'MI', '48201', 'USA'),
('ulysses.lee@email.com', 'Ulysses', 'Lee', '555-0123', '247 Coconut Dr', 'Oklahoma City', 'OK', '73101', 'USA'),
('victoria.walker@email.com', 'Victoria', 'Walker', '555-0124', '358 Pineapple Ln', 'Portland', 'OR', '97201', 'USA'),
('william.hall@email.com', 'William', 'Hall', '555-0125', '469 Strawberry Way', 'Las Vegas', 'NV', '89101', 'USA'),
('xena.allen@email.com', 'Xena', 'Allen', '555-0126', '571 Blueberry Ct', 'Memphis', 'TN', '38101', 'USA'),
('yusuf.young@email.com', 'Yusuf', 'Young', '555-0127', '682 Raspberry Pl', 'Louisville', 'KY', '40201', 'USA'),
('zoe.king@email.com', 'Zoe', 'King', '555-0128', '793 Blackberry Blvd', 'Baltimore', 'MD', '21201', 'USA'),
('adam.wright@email.com', 'Adam', 'Wright', '555-0129', '814 Cranberry St', 'Milwaukee', 'WI', '53201', 'USA'),
('bella.lopez@email.com', 'Bella', 'Lopez', '555-0130', '925 Watermelon Ave', 'Albuquerque', 'NM', '87101', 'USA'),
('carl.hill@email.com', 'Carl', 'Hill', '555-0131', '136 Cantaloupe Rd', 'Tucson', 'AZ', '85701', 'USA'),
('donna.scott@email.com', 'Donna', 'Scott', '555-0132', '247 Honeydew Dr', 'Fresno', 'CA', '93650', 'USA'),
('eric.green@email.com', 'Eric', 'Green', '555-0133', '358 Papaya Ln', 'Sacramento', 'CA', '94203', 'USA'),
('faith.adams@email.com', 'Faith', 'Adams', '555-0134', '469 Guava Way', 'Long Beach', 'CA', '90801', 'USA'),
('gary.baker@email.com', 'Gary', 'Baker', '555-0135', '571 Fig Ct', 'Kansas City', 'MO', '64101', 'USA'),
('hope.gonzalez@email.com', 'Hope', 'Gonzalez', '555-0136', '682 Date Pl', 'Mesa', 'AZ', '85201', 'USA'),
('ian.nelson@email.com', 'Ian', 'Nelson', '555-0137', '793 Plum Blvd', 'Virginia Beach', 'VA', '23450', 'USA'),
('jenny.carter@email.com', 'Jenny', 'Carter', '555-0138', '814 Apricot St', 'Atlanta', 'GA', '30301', 'USA'),
('kyle.mitchell@email.com', 'Kyle', 'Mitchell', '555-0139', '925 Nectarine Ave', 'Colorado Springs', 'CO', '80901', 'USA'),
('lisa.perez@email.com', 'Lisa', 'Perez', '555-0140', '136 Tangerine Rd', 'Omaha', 'NE', '68101', 'USA'),
('mark.roberts@email.com', 'Mark', 'Roberts', '555-0141', '247 Grapefruit Dr', 'Raleigh', 'NC', '27601', 'USA'),
('nina.turner@email.com', 'Nina', 'Turner', '555-0142', '358 Pomelo Ln', 'Miami', 'FL', '33101', 'USA'),
('oliver.phillips@email.com', 'Oliver', 'Phillips', '555-0143', '469 Kumquat Way', 'Oakland', 'CA', '94601', 'USA'),
('penny.campbell@email.com', 'Penny', 'Campbell', '555-0144', '571 Persimmon Ct', 'Minneapolis', 'MN', '55401', 'USA'),
('quentin.parker@email.com', 'Quentin', 'Parker', '555-0145', '682 Lychee Pl', 'Tulsa', 'OK', '74101', 'USA'),
('rose.evans@email.com', 'Rose', 'Evans', '555-0146', '793 Dragonfruit Blvd', 'Cleveland', 'OH', '44101', 'USA'),
('steve.edwards@email.com', 'Steve', 'Edwards', '555-0147', '814 Starfruit St', 'Wichita', 'KS', '67201', 'USA'),
('tracy.collins@email.com', 'Tracy', 'Collins', '555-0148', '925 Passion Ave', 'Arlington', 'TX', '76001', 'USA'),
('uma.stewart@email.com', 'Uma', 'Stewart', '555-0149', '136 Jackfruit Rd', 'New Orleans', 'LA', '70112', 'USA'),
('victor.sanchez@email.com', 'Victor', 'Sanchez', '555-0150', '247 Durian Dr', 'Bakersfield', 'CA', '93301', 'USA');

-- =============================================================================
-- Insert Sample Data: Products (100 products)
-- =============================================================================
INSERT INTO products (category_id, product_name, description, sku, price, cost, weight, is_active) VALUES
-- Electronics (10 products)
(1, 'Wireless Bluetooth Headphones', 'Premium noise-cancelling wireless headphones', 'ELEC-001', 149.99, 75.00, 0.35, true),
(1, 'Smart Watch Pro', 'Advanced fitness tracking smartwatch', 'ELEC-002', 299.99, 150.00, 0.15, true),
(1, 'Portable Power Bank 20000mAh', 'High-capacity portable charger', 'ELEC-003', 49.99, 25.00, 0.45, true),
(1, 'USB-C Hub 7-in-1', 'Multi-port USB-C adapter', 'ELEC-004', 59.99, 30.00, 0.12, true),
(1, 'Wireless Charging Pad', 'Fast wireless charger for smartphones', 'ELEC-005', 29.99, 15.00, 0.18, true),
(1, 'Bluetooth Speaker', 'Portable waterproof speaker', 'ELEC-006', 79.99, 40.00, 0.55, true),
(1, 'Tablet Stand Adjustable', 'Aluminum tablet and phone stand', 'ELEC-007', 34.99, 17.50, 0.65, true),
(1, 'Wireless Mouse', 'Ergonomic wireless mouse', 'ELEC-008', 24.99, 12.50, 0.10, true),
(1, 'Mechanical Keyboard', 'RGB mechanical gaming keyboard', 'ELEC-009', 89.99, 45.00, 1.20, true),
(1, 'Webcam HD 1080p', 'High-definition webcam with microphone', 'ELEC-010', 69.99, 35.00, 0.22, true),

-- Clothing (10 products)
(2, 'Cotton T-Shirt Classic', 'Premium cotton crew neck t-shirt', 'CLTH-001', 24.99, 8.00, 0.20, true),
(2, 'Denim Jeans Slim Fit', 'Classic slim fit denim jeans', 'CLTH-002', 59.99, 25.00, 0.75, true),
(2, 'Hoodie Pullover', 'Comfortable cotton blend hoodie', 'CLTH-003', 44.99, 18.00, 0.60, true),
(2, 'Running Shorts', 'Breathable athletic shorts', 'CLTH-004', 29.99, 12.00, 0.15, true),
(2, 'Winter Jacket', 'Insulated winter jacket', 'CLTH-005', 129.99, 55.00, 1.50, true),
(2, 'Dress Shirt Oxford', 'Classic oxford button-down shirt', 'CLTH-006', 49.99, 20.00, 0.30, true),
(2, 'Wool Sweater', 'Merino wool crew neck sweater', 'CLTH-007', 79.99, 35.00, 0.45, true),
(2, 'Cargo Pants', 'Multi-pocket cargo pants', 'CLTH-008', 54.99, 22.00, 0.65, true),
(2, 'Baseball Cap', 'Adjustable cotton baseball cap', 'CLTH-009', 19.99, 6.00, 0.10, true),
(2, 'Athletic Socks 6-Pack', 'Moisture-wicking athletic socks', 'CLTH-010', 14.99, 5.00, 0.25, true),

-- Books (10 products)
(3, 'The Art of Programming', 'Complete guide to software development', 'BOOK-001', 49.99, 15.00, 1.20, true),
(3, 'Mystery at Midnight', 'Bestselling mystery novel', 'BOOK-002', 14.99, 4.00, 0.35, true),
(3, 'Cookbook: World Cuisines', 'International recipes collection', 'BOOK-003', 34.99, 12.00, 1.50, true),
(3, 'Science for Everyone', 'Popular science explained', 'BOOK-004', 24.99, 8.00, 0.55, true),
(3, 'History of Innovation', 'Technology through the ages', 'BOOK-005', 29.99, 10.00, 0.75, true),
(3, 'Self-Help Success Guide', 'Personal development strategies', 'BOOK-006', 19.99, 6.00, 0.40, true),
(3, 'Fantasy Epic Vol 1', 'Epic fantasy adventure series', 'BOOK-007', 16.99, 5.00, 0.50, true),
(3, 'Business Strategy', 'Modern business management', 'BOOK-008', 39.99, 14.00, 0.65, true),
(3, 'Travel Photography Guide', 'Tips for travel photographers', 'BOOK-009', 44.99, 16.00, 1.00, true),
(3, 'Children Story Collection', 'Classic bedtime stories', 'BOOK-010', 12.99, 4.00, 0.45, true),

-- Home & Garden (10 products)
(4, 'LED Desk Lamp', 'Adjustable LED desk lamp', 'HOME-001', 39.99, 18.00, 1.10, true),
(4, 'Throw Blanket Fleece', 'Soft fleece throw blanket', 'HOME-002', 29.99, 12.00, 0.80, true),
(4, 'Ceramic Plant Pot Set', 'Set of 3 decorative plant pots', 'HOME-003', 34.99, 14.00, 2.50, true),
(4, 'Kitchen Knife Set', 'Professional 5-piece knife set', 'HOME-004', 89.99, 40.00, 1.80, true),
(4, 'Wall Clock Modern', 'Contemporary wall clock', 'HOME-005', 44.99, 18.00, 0.95, true),
(4, 'Garden Tool Set', '5-piece gardening tool set', 'HOME-006', 49.99, 22.00, 2.20, true),
(4, 'Scented Candle Set', 'Set of 4 aromatherapy candles', 'HOME-007', 24.99, 10.00, 1.40, true),
(4, 'Picture Frame Set', 'Set of 5 matching frames', 'HOME-008', 39.99, 16.00, 1.60, true),
(4, 'Storage Basket Woven', 'Decorative woven storage basket', 'HOME-009', 27.99, 11.00, 0.70, true),
(4, 'Welcome Door Mat', 'Durable outdoor door mat', 'HOME-010', 22.99, 9.00, 1.50, true),

-- Sports & Outdoors (10 products)
(5, 'Yoga Mat Premium', 'Non-slip exercise yoga mat', 'SPRT-001', 34.99, 14.00, 1.20, true),
(5, 'Dumbbell Set 20lb', 'Adjustable dumbbell set', 'SPRT-002', 79.99, 35.00, 9.50, true),
(5, 'Running Shoes', 'Lightweight running shoes', 'SPRT-003', 89.99, 40.00, 0.75, true),
(5, 'Camping Tent 4-Person', 'Waterproof camping tent', 'SPRT-004', 149.99, 65.00, 4.50, true),
(5, 'Hiking Backpack 40L', 'Large capacity hiking backpack', 'SPRT-005', 69.99, 30.00, 1.30, true),
(5, 'Resistance Bands Set', 'Set of 5 resistance bands', 'SPRT-006', 19.99, 8.00, 0.35, true),
(5, 'Water Bottle Insulated', 'Stainless steel water bottle', 'SPRT-007', 24.99, 10.00, 0.45, true),
(5, 'Bicycle Helmet', 'Safety certified bike helmet', 'SPRT-008', 54.99, 24.00, 0.55, true),
(5, 'Tennis Racket Pro', 'Professional tennis racket', 'SPRT-009', 129.99, 55.00, 0.32, true),
(5, 'Sleeping Bag', 'All-season sleeping bag', 'SPRT-010', 59.99, 26.00, 2.00, true),

-- Toys & Games (10 products)
(6, 'Building Blocks Set 500pc', 'Creative building blocks', 'TOYS-001', 39.99, 16.00, 1.80, true),
(6, 'Board Game Strategy', 'Classic strategy board game', 'TOYS-002', 34.99, 14.00, 1.20, true),
(6, 'Remote Control Car', 'High-speed RC car', 'TOYS-003', 49.99, 22.00, 0.85, true),
(6, 'Puzzle 1000 Pieces', 'Scenic landscape puzzle', 'TOYS-004', 19.99, 8.00, 0.60, true),
(6, 'Action Figure Set', 'Collectible action figures', 'TOYS-005', 29.99, 12.00, 0.40, true),
(6, 'Card Game Classic', 'Family card game set', 'TOYS-006', 14.99, 5.00, 0.25, true),
(6, 'Plush Teddy Bear', 'Soft plush teddy bear', 'TOYS-007', 24.99, 10.00, 0.35, true),
(6, 'Science Kit Kids', 'Educational science experiments', 'TOYS-008', 44.99, 18.00, 1.50, true),
(6, 'Drone Mini', 'Beginner-friendly mini drone', 'TOYS-009', 69.99, 30.00, 0.28, true),
(6, 'Art Supplies Set', 'Complete art set for kids', 'TOYS-010', 34.99, 14.00, 1.10, true),

-- Health & Beauty (10 products)
(7, 'Vitamin C Serum', 'Anti-aging vitamin C serum', 'HLTH-001', 29.99, 12.00, 0.10, true),
(7, 'Electric Toothbrush', 'Sonic electric toothbrush', 'HLTH-002', 49.99, 22.00, 0.25, true),
(7, 'Hair Dryer Professional', 'Salon-quality hair dryer', 'HLTH-003', 79.99, 35.00, 0.85, true),
(7, 'Moisturizer SPF 30', 'Daily moisturizer with sunscreen', 'HLTH-004', 24.99, 10.00, 0.15, true),
(7, 'Massage Gun', 'Percussion massage device', 'HLTH-005', 129.99, 55.00, 1.20, true),
(7, 'Essential Oils Set', 'Aromatherapy essential oils', 'HLTH-006', 34.99, 14.00, 0.35, true),
(7, 'Makeup Brush Set', 'Professional makeup brushes', 'HLTH-007', 39.99, 16.00, 0.30, true),
(7, 'Nail Care Kit', 'Complete nail care set', 'HLTH-008', 19.99, 8.00, 0.20, true),
(7, 'Fitness Tracker Band', 'Activity and sleep tracker', 'HLTH-009', 59.99, 26.00, 0.05, true),
(7, 'Shampoo Organic', 'Natural organic shampoo', 'HLTH-010', 14.99, 5.00, 0.45, true),

-- Automotive (10 products)
(8, 'Car Phone Mount', 'Universal car phone holder', 'AUTO-001', 19.99, 8.00, 0.18, true),
(8, 'Dash Cam HD', '1080p dashboard camera', 'AUTO-002', 69.99, 30.00, 0.25, true),
(8, 'Car Vacuum Cleaner', 'Portable car vacuum', 'AUTO-003', 39.99, 17.00, 0.85, true),
(8, 'Tire Pressure Gauge', 'Digital tire pressure gauge', 'AUTO-004', 14.99, 6.00, 0.12, true),
(8, 'Car Air Freshener Set', 'Vent clip air fresheners', 'AUTO-005', 9.99, 3.00, 0.08, true),
(8, 'Jump Starter Portable', 'Emergency car jump starter', 'AUTO-006', 89.99, 40.00, 1.50, true),
(8, 'Seat Cushion Memory Foam', 'Ergonomic car seat cushion', 'AUTO-007', 34.99, 14.00, 0.65, true),
(8, 'Car Wash Kit', 'Complete car cleaning kit', 'AUTO-008', 29.99, 12.00, 2.00, true),
(8, 'Steering Wheel Cover', 'Leather steering wheel cover', 'AUTO-009', 24.99, 10.00, 0.30, true),
(8, 'Trunk Organizer', 'Collapsible trunk organizer', 'AUTO-010', 27.99, 11.00, 1.20, true),

-- Food & Beverages (10 products)
(9, 'Organic Coffee Beans', 'Premium arabica coffee beans', 'FOOD-001', 18.99, 7.00, 0.50, true),
(9, 'Green Tea Collection', 'Assorted green tea bags', 'FOOD-002', 12.99, 4.00, 0.25, true),
(9, 'Dark Chocolate Bar Set', 'Gourmet dark chocolate bars', 'FOOD-003', 24.99, 10.00, 0.35, true),
(9, 'Olive Oil Extra Virgin', 'Premium Italian olive oil', 'FOOD-004', 19.99, 8.00, 0.75, true),
(9, 'Mixed Nuts Premium', 'Roasted mixed nuts', 'FOOD-005', 14.99, 6.00, 0.45, true),
(9, 'Honey Raw Organic', 'Pure organic raw honey', 'FOOD-006', 16.99, 7.00, 0.55, true),
(9, 'Protein Bars Box', 'High-protein snack bars', 'FOOD-007', 29.99, 12.00, 0.60, true),
(9, 'Maple Syrup Pure', 'Grade A maple syrup', 'FOOD-008', 22.99, 9.00, 0.65, true),
(9, 'Dried Fruit Mix', 'Assorted dried fruits', 'FOOD-009', 11.99, 4.00, 0.40, true),
(9, 'Gourmet Pasta Set', 'Italian pasta variety pack', 'FOOD-010', 17.99, 7.00, 1.00, true),

-- Office Supplies (10 products)
(10, 'Notebook Leather Bound', 'Premium leather journal', 'OFFC-001', 24.99, 10.00, 0.35, true),
(10, 'Pen Set Executive', 'Luxury pen set', 'OFFC-002', 39.99, 16.00, 0.15, true),
(10, 'Desk Organizer', 'Multi-compartment desk organizer', 'OFFC-003', 29.99, 12.00, 0.85, true),
(10, 'Sticky Notes Mega Pack', 'Assorted sticky notes', 'OFFC-004', 12.99, 4.00, 0.30, true),
(10, 'File Folders 50-Pack', 'Letter size file folders', 'OFFC-005', 19.99, 8.00, 0.95, true),
(10, 'Stapler Heavy Duty', 'Commercial stapler', 'OFFC-006', 22.99, 9.00, 0.55, true),
(10, 'Calculator Scientific', 'Advanced scientific calculator', 'OFFC-007', 34.99, 14.00, 0.18, true),
(10, 'Whiteboard 24x36', 'Magnetic dry erase board', 'OFFC-008', 49.99, 20.00, 3.50, true),
(10, 'Highlighter Set 12pk', 'Assorted highlighter colors', 'OFFC-009', 9.99, 3.00, 0.20, true),
(10, 'Paper Shredder', 'Cross-cut paper shredder', 'OFFC-010', 79.99, 35.00, 5.50, true);

-- =============================================================================
-- Insert Sample Data: Inventory (for all products)
-- =============================================================================
INSERT INTO inventory (product_id, quantity_on_hand, quantity_reserved, reorder_point, reorder_quantity, warehouse_location, last_restocked_at)
SELECT 
    product_id,
    FLOOR(RANDOM() * 200 + 50)::INTEGER,  -- Random quantity 50-250
    FLOOR(RANDOM() * 10)::INTEGER,         -- Random reserved 0-10
    10,
    50,
    'WH-' || LPAD((FLOOR(RANDOM() * 5 + 1)::INTEGER)::TEXT, 2, '0') || '-' || 
    CHR(65 + FLOOR(RANDOM() * 26)::INTEGER) || 
    LPAD((FLOOR(RANDOM() * 100 + 1)::INTEGER)::TEXT, 3, '0'),
    NOW() - (FLOOR(RANDOM() * 30)::INTEGER || ' days')::INTERVAL
FROM products;

-- =============================================================================
-- Insert Sample Data: Orders (200 orders)
-- =============================================================================
DO $$
DECLARE
    i INTEGER;
    v_customer_id INTEGER;
    v_order_id INTEGER;
    v_order_date TIMESTAMP;
    v_subtotal DECIMAL(12,2);
    v_tax DECIMAL(10,2);
    v_shipping DECIMAL(10,2);
    v_status TEXT;
    v_statuses TEXT[] := ARRAY['pending', 'confirmed', 'processing', 'shipped', 'delivered'];
BEGIN
    FOR i IN 1..200 LOOP
        -- Random customer
        v_customer_id := FLOOR(RANDOM() * 50 + 1)::INTEGER;
        
        -- Random order date within last 90 days
        v_order_date := NOW() - (FLOOR(RANDOM() * 90)::INTEGER || ' days')::INTERVAL;
        
        -- Random status
        v_status := v_statuses[FLOOR(RANDOM() * 5 + 1)::INTEGER];
        
        -- Insert order
        INSERT INTO orders (
            customer_id, 
            order_number, 
            order_status, 
            ordered_at,
            shipping_address_line1,
            shipping_city,
            shipping_state,
            shipping_postal_code,
            shipping_country
        )
        SELECT 
            v_customer_id,
            'ORD-' || TO_CHAR(v_order_date, 'YYYYMMDD') || '-' || LPAD(i::TEXT, 5, '0'),
            v_status,
            v_order_date,
            c.address_line1,
            c.city,
            c.state,
            c.postal_code,
            c.country
        FROM customers c
        WHERE c.customer_id = v_customer_id
        RETURNING order_id INTO v_order_id;
        
        -- Add 1-5 random items to each order
        INSERT INTO order_items (order_id, product_id, quantity, unit_price, discount_percent, line_total)
        SELECT 
            v_order_id,
            p.product_id,
            FLOOR(RANDOM() * 3 + 1)::INTEGER,
            p.price,
            CASE WHEN RANDOM() < 0.2 THEN FLOOR(RANDOM() * 15 + 5)::INTEGER ELSE 0 END,
            p.price * FLOOR(RANDOM() * 3 + 1)::INTEGER * 
                (1 - CASE WHEN RANDOM() < 0.2 THEN FLOOR(RANDOM() * 15 + 5)::INTEGER ELSE 0 END / 100.0)
        FROM products p
        WHERE p.product_id IN (
            SELECT product_id 
            FROM products 
            ORDER BY RANDOM() 
            LIMIT FLOOR(RANDOM() * 4 + 1)::INTEGER
        );
        
        -- Update order totals
        SELECT COALESCE(SUM(line_total), 0) INTO v_subtotal
        FROM order_items WHERE order_id = v_order_id;
        
        v_tax := v_subtotal * 0.08;  -- 8% tax
        v_shipping := CASE 
            WHEN v_subtotal >= 100 THEN 0 
            ELSE 9.99 
        END;
        
        UPDATE orders 
        SET subtotal = v_subtotal,
            tax_amount = v_tax,
            shipping_amount = v_shipping,
            total_amount = v_subtotal + v_tax + v_shipping,
            shipped_at = CASE 
                WHEN v_status IN ('shipped', 'delivered') THEN v_order_date + '2 days'::INTERVAL 
                ELSE NULL 
            END,
            delivered_at = CASE 
                WHEN v_status = 'delivered' THEN v_order_date + '5 days'::INTERVAL 
                ELSE NULL 
            END
        WHERE order_id = v_order_id;
    END LOOP;
END $$;

-- =============================================================================
-- Create Views for Reporting
-- =============================================================================

-- View: Order Summary
CREATE OR REPLACE VIEW v_order_summary AS
SELECT 
    o.order_id,
    o.order_number,
    o.order_status,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.email AS customer_email,
    COUNT(oi.order_item_id) AS item_count,
    o.subtotal,
    o.tax_amount,
    o.shipping_amount,
    o.total_amount,
    o.ordered_at
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id, o.order_number, o.order_status, c.first_name, c.last_name, 
         c.email, o.subtotal, o.tax_amount, o.shipping_amount, o.total_amount, o.ordered_at;

-- View: Product Inventory Status
CREATE OR REPLACE VIEW v_product_inventory AS
SELECT 
    p.product_id,
    p.product_name,
    p.sku,
    cat.category_name,
    p.price,
    i.quantity_on_hand,
    i.quantity_reserved,
    (i.quantity_on_hand - i.quantity_reserved) AS available_quantity,
    i.reorder_point,
    CASE 
        WHEN (i.quantity_on_hand - i.quantity_reserved) <= i.reorder_point THEN 'LOW STOCK'
        WHEN (i.quantity_on_hand - i.quantity_reserved) <= 0 THEN 'OUT OF STOCK'
        ELSE 'IN STOCK'
    END AS stock_status,
    i.warehouse_location
FROM products p
JOIN categories cat ON p.category_id = cat.category_id
LEFT JOIN inventory i ON p.product_id = i.product_id
WHERE p.is_active = true;

-- View: Sales by Category
CREATE OR REPLACE VIEW v_sales_by_category AS
SELECT 
    cat.category_name,
    COUNT(DISTINCT o.order_id) AS order_count,
    SUM(oi.quantity) AS units_sold,
    SUM(oi.line_total) AS total_sales
FROM categories cat
JOIN products p ON cat.category_id = p.category_id
JOIN order_items oi ON p.product_id = oi.product_id
JOIN orders o ON oi.order_id = o.order_id
GROUP BY cat.category_id, cat.category_name
ORDER BY total_sales DESC;

-- =============================================================================
-- Create Functions for Business Logic
-- =============================================================================

-- Function: Calculate order total
CREATE OR REPLACE FUNCTION calculate_order_total(p_order_id INTEGER)
RETURNS DECIMAL(12,2) AS $$
DECLARE
    v_total DECIMAL(12,2);
BEGIN
    SELECT COALESCE(SUM(line_total), 0)
    INTO v_total
    FROM order_items
    WHERE order_id = p_order_id;
    
    RETURN v_total;
END;
$$ LANGUAGE plpgsql;

-- Function: Get customer order count
CREATE OR REPLACE FUNCTION get_customer_order_count(p_customer_id INTEGER)
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM orders
    WHERE customer_id = p_customer_id;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Summary Statistics
-- =============================================================================
DO $$
DECLARE
    v_categories INTEGER;
    v_customers INTEGER;
    v_products INTEGER;
    v_orders INTEGER;
    v_order_items INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_categories FROM categories;
    SELECT COUNT(*) INTO v_customers FROM customers;
    SELECT COUNT(*) INTO v_products FROM products;
    SELECT COUNT(*) INTO v_orders FROM orders;
    SELECT COUNT(*) INTO v_order_items FROM order_items;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Sample Data Loaded Successfully!';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Categories: %', v_categories;
    RAISE NOTICE 'Customers: %', v_customers;
    RAISE NOTICE 'Products: %', v_products;
    RAISE NOTICE 'Orders: %', v_orders;
    RAISE NOTICE 'Order Items: %', v_order_items;
    RAISE NOTICE '========================================';
END $$;

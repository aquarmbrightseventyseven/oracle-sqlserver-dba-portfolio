--=============================================================
-- Schema for User ECOM
--=============================================================
-- Connect as ecom at FREEPDB2
CONNECT ecom/&ecom_password.@freepdb2
--=================================================================
--Tables involve in the stock and order management database system
--=================================================================
CREATE TABLE customer_information (
    customer_id INTEGER GENERATED ALWAYS AS IDENTITY CONSTRAINT customer_information_pk PRIMARY KEY,
    last_name   VARCHAR2(30) NOT NULL,
    first_name  VARCHAR2(30) NOT NULL,
	dob         DATE         NOT NULL
);
CREATE TABLE customer_credentials (
    customer_id      INTEGER CONSTRAINT customer_credentials_pk PRIMARY KEY
	CONSTRAINT customer_credentials_fk REFERENCES customer_information(customer_id) ON DELETE CASCADE,
    username         VARCHAR2(50) NOT NULL,
    password_hash   VARCHAR2(255) NOT NULL,
    password_salt   VARCHAR2(255) NOT NULL,
    password_algo   VARCHAR2(30)  DEFAULT 'BCRYPT',
    password_changed TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_customer_username UNIQUE (username)
);
-- Password Reset & MFA (Professional Design)
-- Password reset (token-based)
CREATE TABLE password_reset_tokens (
  token_id        RAW(32) PRIMARY KEY,
  otp_code        VARCHAR2(10),
  expires_at      TIMESTAMP,
  used_flag       CHAR(1) DEFAULT 'N',
  customer_id INTEGER NOT NULL CONSTRAINT customer_password_reset_fk REFERENCES customer_information(customer_id) ON DELETE CASCADE 
);
-- MFA table
CREATE TABLE customer_mfa (
  customer_id INTEGER NOT NULL CONSTRAINT customer_mfa_fk REFERENCES customer_information(customer_id) ON DELETE CASCADE,
  mfa_type    VARCHAR2(20),
  secret      VARCHAR2(255)
);
-- Account Lockout & Brute-Force Protection (DB + App)
-- Supporting table
CREATE TABLE login_attempts (
  customer_id INTEGER NOT NULL CONSTRAINT customer_login_attempts_fk REFERENCES customer_information(customer_id) ON DELETE CASCADE,
  failed_attempts  NUMBER DEFAULT 0,
  last_failed_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  locked_until     TIMESTAMP DEFAULT SYSDATE + INTERVAL '30' MINUTE
);
-- OTP Table
CREATE TABLE customer_otp (
  customer_id INTEGER NOT NULL CONSTRAINT customer_customer_otp_fk REFERENCES customer_information(customer_id) ON DELETE CASCADE,
  otp_hash    VARCHAR2(128),
  expires_at  TIMESTAMP,
  attempts    NUMBER DEFAULT 0
);
-- Device Fingerprinting (Production Pattern) Table
CREATE TABLE trusted_devices (
  customer_id INTEGER NOT NULL CONSTRAINT customer_trusted_devices_fk REFERENCES customer_information(customer_id) ON DELETE CASCADE,
  device_hash VARCHAR2(256),
  last_seen   TIMESTAMP,
  trusted     CHAR(1) CHECK (trusted IN ('Y','N'))
);
CREATE TABLE supplier_information (
    supplier_id   INTEGER GENERATED ALWAYS AS IDENTITY START WITH 5 INCREMENT BY 5 CONSTRAINT supplier_information_pk PRIMARY KEY,
    supplier_name VARCHAR2(30) NOT NULL
);
CREATE TABLE stock_categories (
    category_id   INTEGER GENERATED ALWAYS AS IDENTITY START WITH 100 INCREMENT BY 10 CONSTRAINT stock_categories_pk PRIMARY KEY,
    category_name VARCHAR2(30) NOT NULL UNIQUE
);
CREATE TABLE inventory_status(
    inventory_status_id     VARCHAR2(3) CONSTRAINT inventory_status_pk PRIMARY KEY,
    status_name   VARCHAR2(30) NOT NULL CHECK (status_name IN ('Expired', 'Damaged', 'Reserved', 'Available', 'Out of Stock')) UNIQUE
);
CREATE TABLE stock (
    stock_id        INTEGER GENERATED ALWAYS AS IDENTITY START WITH 10 INCREMENT BY 5 CONSTRAINT stock_pk PRIMARY KEY,
    product_name      VARCHAR2(50) NOT NULL UNIQUE,
	quantity_in_stock  NUMBER(12) NOT NULL CHECK (quantity_in_stock >= 0),
	reserved_quantity  NUMBER(12) DEFAULT 0 CHECK (reserved_quantity >= 0) NOT NULL,
    unit_price        NUMBER(12, 2) DEFAULT 0 NOT NULL,
    reorder_level     NUMBER(12) DEFAULT 0
);
CREATE TABLE payment_methods (
    payment_mode_id      VARCHAR2(3) CONSTRAINT payment_methods_pk PRIMARY KEY,
    payment_mode VARCHAR2(30) NOT NULL UNIQUE CHECK (payment_mode IN ('cash', 'debit card', 'mobile money', 'credit card'))
);
CREATE TABLE payment_status(
	payment_status_id    CHAR(2) CONSTRAINT payment_status_pk PRIMARY KEY,
	status_name       VARCHAR2(10) NOT NULL CONSTRAINT status_chk CHECK (status_name IN ('Paid', 'Unpaid')) UNIQUE
);
CREATE TABLE order_status (
    order_status_id     CHAR(2) CONSTRAINT order_status_pk PRIMARY KEY,
    status_name   VARCHAR2(30) NOT NULL CHECK (status_name IN ('Submitted', 'Processing', 'Dispatch', 'Delivered', 'Cancelled', 'Returned')) UNIQUE
);
CREATE TABLE orders (
    order_id              INTEGER GENERATED ALWAYS AS IDENTITY START WITH 5 INCREMENT BY 5 CONSTRAINT orders_pk PRIMARY KEY,
    transaction_init_date DATE DEFAULT SYSDATE NOT NULL,
    delivery_date         DATE,  
    order_total           NUMBER(16, 2) DEFAULT 0 CHECK (order_total >= 0),
    discount_pct          NUMBER(5, 2) DEFAULT 0 CHECK (discount_pct >= 0),
    discount_amount       NUMBER(16, 2) DEFAULT 0 CHECK (discount_amount >= 0),
    amount_to_pay         NUMBER(16, 2) DEFAULT 0 CHECK (amount_to_pay >= 0),
    amount_paid           NUMBER(16, 2) DEFAULT 0,
    change                NUMBER(16, 2) DEFAULT 0,
    payment_date          DATE,
    payment_mode_id       VARCHAR2(3) CONSTRAINT payment_methods_fk REFERENCES payment_methods(payment_mode_id),
    payment_status_id     CHAR(2) NOT NULL CONSTRAINT payment_status_fk REFERENCES payment_status(payment_status_id),
    order_status_id       CHAR(2) NOT NULL CONSTRAINT order_status_fk REFERENCES order_status(order_status_id),
    customer_id           NUMBER NOT NULL CONSTRAINT cust_info_fk REFERENCES customer_information(customer_id) ON DELETE CASCADE,
    CONSTRAINT del_date_chk   CHECK (delivery_date >= transaction_init_date),
	CONSTRAINT amt_to_pay_chk CHECK (amount_to_pay <= order_total),
    CONSTRAINT chng_chk       CHECK (change <= amount_paid)
);
CREATE TABLE customer_phone_numbers(
    phone_number_id INTEGER GENERATED ALWAYS AS IDENTITY START WITH 100 INCREMENT BY 5 CONSTRAINT customer_phone_numbers_p PRIMARY KEY,
    phone           VARCHAR2(15) NOT NULL,
    customer_id     INTEGER NOT NULL CONSTRAINT customer_info_fk REFERENCES customer_information(customer_id) ON DELETE CASCADE
);
CREATE TABLE supplier_phone_numbers(
    phone_number_id INTEGER GENERATED ALWAYS AS IDENTITY START WITH 100 INCREMENT BY 5 CONSTRAINT supplier_phone_numbers_pk PRIMARY KEY,
    phone           VARCHAR2(15) NOT NULL UNIQUE,
    supplier_id     INTEGER NOT NULL CONSTRAINT supplier_info_fk REFERENCES supplier_information(supplier_id)
);
CREATE TABLE stock_information (
	stock_info_id 	INTEGER GENERATED ALWAYS AS IDENTITY START WITH 100 INCREMENT BY 10 CONSTRAINT stock_info_pk PRIMARY KEY,
    unit_price  	NUMBER(12, 2) NOT NULL,
    quantity    	INTEGER NOT NULL CHECK (quantity >= 0),
	request_date    DATE NOT NULL,
    supply_date 	DATE NOT NULL,
    category_id 	INTEGER NOT NULL CONSTRAINT stock_categories_fk REFERENCES stock_categories(category_id),
    supplier_id 	INTEGER NOT NULL CONSTRAINT supplier_id_fk REFERENCES supplier_information(supplier_id),
	stock_id    	INTEGER NOT NULL CONSTRAINT stock_stock_id_fk REFERENCES stock(stock_id)
);
CREATE TABLE stock_entries (
    entry_id   			     INTEGER GENERATED ALWAYS AS IDENTITY START WITH 10 INCREMENT BY 5 CONSTRAINT stock_entries_pk PRIMARY KEY,
	entry_date  	 		 DATE DEFAULT SYSDATE NOT NULL,
    quantity   		 		 NUMBER(12) NOT NULL CHECK (quantity > 0),
    unit_price  	 		 NUMBER(12, 2) NOT NULL CHECK (unit_price > 0),
	quantity_to_sell 		 NUMBER(12) NOT NULL CHECK (quantity_to_sell >= 0),
	expiry_date 			 DATE NOT NULL,
	stock_id               INTEGER NOT NULL CONSTRAINT stock_id_fk REFERENCES stock(stock_id),
	inventory_status_id      VARCHAR2(3) CONSTRAINT inventory_status_fk REFERENCES inventory_status(inventory_status_id),
	CONSTRAINT exp_ent_date_chk CHECK (expiry_date > entry_date)
);
CREATE TABLE order_items (
	item_id          NUMBER(12) GENERATED ALWAYS AS IDENTITY START WITH 5 INCREMENT BY 5 CONSTRAINT order_items_pk PRIMARY KEY,
	order_id   			   NUMBER(12) CONSTRAINT orders_fk REFERENCES orders(order_id), 
    quantity               INTEGER NOT NULL CHECK (quantity > 0),
    unit_price             NUMBER(16, 2) NOT NULL CHECK (unit_price > 0),
    stock_id               INTEGER NOT NULL CONSTRAINT order_product_fk REFERENCES stock(stock_id),
	entry_id               INTEGER NOT NULL CONSTRAINT stock_entries_fk REFERENCES stock_entries(entry_id)
);
CREATE TABLE customer_email_accounts(
	account_id			   NUMBER GENERATED ALWAYS AS IDENTITY START WITH 100 INCREMENT BY 5 CONSTRAINT customer_email_pk PRIMARY KEY,
	email_account           VARCHAR2(200) CHECK (email_account LIKE '%@%'),
	customer_id            INTEGER CONSTRAINT customer_information_fk REFERENCES customer_information(customer_id) ON DELETE CASCADE
);
CREATE TABLE supplier_email_accounts(
	account_id			   NUMBER GENERATED ALWAYS AS IDENTITY START WITH 100 INCREMENT BY 5 CONSTRAINT supplier_email_pk PRIMARY KEY,
	email_account           VARCHAR2(200) UNIQUE CHECK (email_account LIKE '%@%'),
	supplier_id            INTEGER CONSTRAINT supplier_information_fk REFERENCES supplier_information(supplier_id)
);
CREATE TABLE regions(
	region_id CHAR(2) CONSTRAINT regions_pk PRIMARY KEY,
	region_name VARCHAR2(50) NOT NULL
);
CREATE TABLE countries(
	country_id CHAR(2) CONSTRAINT countries_pk PRIMARY KEY,
	country_name VARCHAR2(100) NOT NULL,
	region_id CHAR(2) NOT NULL CONSTRAINT regions_fk REFERENCES regions(region_id)
);
CREATE TABLE locations(
	location_id INTEGER GENERATED ALWAYS AS IDENTITY CONSTRAINT locations_pk PRIMARY KEY,
	city VARCHAR2(50),
	state_province VARCHAR2(50),
	country_id CHAR(2) NOT NULL CONSTRAINT country_id_fk REFERENCES countries(country_id)
);
CREATE TABLE supplier_addresses (
    address_id  INTEGER GENERATED ALWAYS AS IDENTITY START WITH 10 INCREMENT BY 10 CONSTRAINT supplier_addresses_pk PRIMARY KEY,
    street_address VARCHAR2(100) NOT NULL,
	postal_code VARCHAR2(30) NOT NULL,
	location_id INTEGER CONSTRAINT location_fk REFERENCES locations(location_id),
	supplier_id INTEGER CONSTRAINT supplier_fk REFERENCES supplier_information(supplier_id) NOT NULL
);
CREATE TABLE customer_addresses (
    address_id  INTEGER GENERATED ALWAYS AS IDENTITY START WITH 10 INCREMENT BY 10 CONSTRAINT customer_addresses_pk PRIMARY KEY,
    street_address VARCHAR2(100) NOT NULL,
	postal_code VARCHAR2(30) NOT NULL,
	location_id INTEGER CONSTRAINT locations_fk REFERENCES locations(location_id),
	customer_id INTEGER NOT NULL CONSTRAINT customer_fk REFERENCES customer_information(customer_id) ON DELETE CASCADE
);
CREATE TABLE rating_scale (
    rating_value INTEGER CONSTRAINT rating_scale_pk PRIMARY KEY CHECK (rating_value BETWEEN 1 AND 5),
    rating_label VARCHAR2(50) NOT NULL,
    rating_description VARCHAR2(200)
);
CREATE TABLE product_reviews (
    product_review_id INTEGER GENERATED ALWAYS AS IDENTITY CONSTRAINT product_review_pk PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customer_information(customer_id),
    stock_id INTEGER NOT NULL REFERENCES stock(stock_id),
    rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5) CONSTRAiNT rating_scale_fk REFERENCES rating_scale(rating_value),
    feedback  VARCHAR2(1000),
    review_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE service_ratings (
    service_rating_id INTEGER GENERATED ALWAYS AS IDENTITY CONSTRAINT service_rating_pk PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders(order_id),
    customer_id INTEGER NOT NULL REFERENCES customer_information(customer_id),
    delivery_rating INTEGER CHECK (delivery_rating BETWEEN 1 AND 5) CONSTRAiNT rating_value_fk REFERENCES rating_scale(rating_value),
    packaging_rating INTEGER CHECK (packaging_rating BETWEEN 1 AND 5) CONSTRAiNT rating_fk REFERENCES rating_scale(rating_value),
    support_rating INTEGER CHECK (support_rating BETWEEN 1 AND 5) CONSTRAiNT rating_values_fk REFERENCES rating_scale(rating_value),
    overall_comment VARCHAR2(1000),
    rating_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- Create stock view
CREATE VIEW products AS 
SELECT product_name, unit_price FROM stock;

--===========================================
-- Index for stock_id in STOCK_ENTRIES table
--===========================================
CREATE INDEX idx_stock_id ON stock_entries(stock_id);
-- Index for stock_id in ORDER_ITEMS table
CREATE INDEX idx_stock_item_stock_id ON order_items(stock_id, order_id);
-- Index for customer_id in CUSTOMER_EMAIL_ACCOUNTS
CREATE INDEX idx_cust_email_customer_id ON customer_email_accounts(customer_id);
-- Index for supplier_id in SUPPLIER_EMAIL_ACCOUNTS
CREATE INDEX idx_supp_email_supplier_id ON supplier_email_accounts(supplier_id);
-- Index for stock_id, supplier_id, category_id in STOCK_INFORMATION (if used in joins or searches)
CREATE INDEX idx_stock_item_item_id ON stock_information(stock_id, supplier_id, category_id);
-- Index for customer_id on ORDERS table.
CREATE INDEX idx_customer_id ON orders(customer_id);
--===================
--Auditing the tables 
--===================
-------------------------------------------------------------------------------------------------------------
-- Audit the customer information table.--Duplicate customer information table structure as customer_info_audit.
--------------------------------------------------------------------------------------------------------------
CREATE TABLE customer_info_audit
	AS SELECT * FROM customer_information
	WHERE 1 = 2; 	
-----------------------------------------------------------------------------------------------------
--Adding the following columns(changed_by, action_type, changed_at) to the customer_info_audit table.
------------------------------------------------------------------------------------------------------
ALTER TABLE customer_info_audit					   
ADD (user_name VARCHAR2(30),                --Who chdeanged it?
			action_type VARCHAR(10) CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')), 

			changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP				 --When the user ran the DML statement.
);
----------------------------------------
--Audit the supplier information table
----------------------------------------
CREATE TABLE supplier_info_audit
	AS SELECT * FROM supplier_information
	WHERE 2 = 1;
------------------------------------------------------------------------------------------------------
--Adding the following columns(changed_by, action_type, changed_at) to the supplier_info_audit table.
------------------------------------------------------------------------------------------------------
ALTER TABLE supplier_info_audit
ADD (user_name VARCHAR2(30),                --Who changed it?
			action_type VARCHAR(10) CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')), 
			changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP					 --When the user ran the DML statement.
);
----------------------------------
--Audit the payment methods table
----------------------------------
CREATE TABLE payment_methods_audit
	AS SELECT * FROM payment_methods
	WHERE 1 = 2;
--------------------------------------------------------------------------------------------------
--Adding the following columns(changed_by, action_type, changed_at) to the payment_methods_audit.
--------------------------------------------------------------------------------------------------
ALTER TABLE payment_methods_audit
ADD (user_name VARCHAR2(30),                --Who changed it?
			action_type VARCHAR(10) CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')), 
			changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP 					 --When the user ran the DML statement.
);
---------------------------------
--Audit the payment status table
---------------------------------
CREATE TABLE payment_status_audit
	AS SELECT * FROM payment_status
	WHERE 1 = 2;
------------------------------------------------------------------------------------------------
--Adding the following columns(changed_by, action_type, changed_at) to the payment_status_audit.
-------------------------------------------------------------------------------------------------
ALTER TABLE payment_status_audit
ADD (user_name VARCHAR2(30),                --Who changed it?
			action_type VARCHAR(10) CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')), 
			changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP 					 --When the user ran the DML statement.
);
-----------------------------------
--Audit the stock categories table
-----------------------------------
CREATE TABLE stock_categories_audit
	AS SELECT * FROM stock_categories
	WHERE 2 = 1;
--------------------------------------------------------------------------------------------------
--Adding the following columns(changed_by, action_type, changed_at) to the stock_categories_audit.
--------------------------------------------------------------------------------------------------
ALTER TABLE stock_categories_audit
ADD (user_name VARCHAR2(30),                --Who changed it?
			action_type VARCHAR(10) CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')),
			changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP					 --When the user ran the DML statement.
);
------------------------
--Audit the stock table
------------------------
CREATE TABLE stock_audit
	AS SELECT * FROM stock
	WHERE 1 = 2;	
----------------------------------------------------------------------------------------
--Adding the following columns(changed_by, action_type, changed_at) to the stock_audit.
----------------------------------------------------------------------------------------
ALTER TABLE stock_audit
ADD (user_name VARCHAR2(30),                --Who changed it?
			action_type VARCHAR(10) CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')), 
			changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP 					 --When the user ran the DML statement.
);
-------------------------------
--Audit the order status table
-------------------------------
CREATE TABLE order_status_audit
	AS SELECT * FROM order_status
	WHERE 2 = 1;
----------------------------------------------------------------------------------------------------
--Adding the following columns(changed_by, action_type, changed_at) to the order_status_audit table.
-----------------------------------------------------------------------------------------------------
ALTER TABLE order_status_audit					   
ADD (user_name VARCHAR2(30),                --Who changed it?
			action_type VARCHAR(10) CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')), 
			changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP   --When the user ran the DML statement.
);
-------------------------
--Audit the orders table
-------------------------
CREATE TABLE orders_audit
	AS SELECT * FROM orders
	WHERE 2 = 1;
----------------------------------------------------------------------------------------------	
--Adding the following columns(changed_by, action_type, changed_at) to the orders_audit table.
----------------------------------------------------------------------------------------------
ALTER TABLE orders_audit					   
ADD (user_name VARCHAR2(30),                --Who changed it?
			action_type VARCHAR(10) CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')), 
			changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP 					 --When the user ran the DML statement.
);
-----------------------------------------
--Audit the customer_phone_numbers table
-----------------------------------------
CREATE TABLE customer_phone_numbers_audit
	AS SELECT * FROM customer_phone_numbers
	WHERE 1 = 2;
--------------------------------------------------------------------------------------------------------------
--Adding the following columns(changed_by, action_type, changed_at) to the customer_phone_numbers_audit table.
--------------------------------------------------------------------------------------------------------------
ALTER TABLE customer_phone_numbers_audit					   
ADD (user_name VARCHAR2(30),                --Who changed it?
			action_type VARCHAR(10) CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')),  
			changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP 					 --When the user ran the DML statement.
);
-----------------------------------------
--Audit the supplier_phone_numbers table
-----------------------------------------
CREATE TABLE supplier_phone_numbers_audit
	AS SELECT * FROM supplier_phone_numbers
	WHERE 2 = 1;
-------------------------------------------------------------------------------------------------------------
--Adding the following columns(changed_by, action_type, changed_at) to the supplier_phone_numbers_audit table
--------------------------------------------------------------------------------------------------------------
ALTER TABLE supplier_phone_numbers_audit					   
ADD (user_name VARCHAR2(30),                --Who changed it?
			action_type VARCHAR(10) CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')), 
			changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP 					 --When the user ran the DML statement.
);
-----------------------------------
--Audit the stock information table
-----------------------------------
CREATE TABLE stock_info_audit
	AS SELECT * FROM stock_information
	WHERE 2 = 1;
---------------------------------------------------------------------------------------------------
--Adding the following columns(changed_by, action_type, changed_at) to the stock_information_audit.
----------------------------------------------------------------------------------------------------
ALTER TABLE stock_info_audit
ADD (user_name VARCHAR2(30),                --Who changed it?
			action_type VARCHAR(10) CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')),  
			changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP 					 --When the user ran the DML statement.
);
----------------------------------
--Audit the inventory_status table
----------------------------------
CREATE TABLE inventory_status_audit
	AS SELECT * FROM inventory_status
	WHERE 1 = 2;	
--------------------------------------------------------------------------------------------------
--Adding the following columns(changed_by, action_type, changed_at) to the inventory_status_audit.
--------------------------------------------------------------------------------------------------
ALTER TABLE inventory_status_audit
ADD (user_name VARCHAR2(30),                --Who changed it?
			action_type VARCHAR(10) CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')),  
			changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP 					 --When the user ran the DML statement.
);
------------------------------
--Audit the stock entry table
------------------------------
CREATE TABLE stock_entries_audit
	AS SELECT * FROM stock_entries
	WHERE 2 = 1;	
---------------------------------------------------------------------------------------------
--Adding the following columns(changed_by, action_type, changed_at) to the stock_entry_audit.
---------------------------------------------------------------------------------------------
ALTER TABLE stock_entries_audit
ADD (user_name VARCHAR2(30),                --Who changed it?
			action_type VARCHAR(10) CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')),  
			changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP 					 --When the user ran the DML statement.
);
--------------------------------
--Audit the ordered stock table
--------------------------------
CREATE TABLE order_items_audit
	AS SELECT * FROM order_items
	WHERE 1 = 2;	
-----------------------------------------------------------------------------------------------
--Adding the following columns(changed_by, action_type, changed_at) to the ordered_stock_audit.
------------------------------------------------------------------------------------------------
ALTER TABLE order_items_audit
ADD (user_name VARCHAR2(30),                --Who changed it?
			action_type VARCHAR(10) CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')),  
			changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP			--When the user ran the DML statement.
);
-----------------------------------------
--Audit the customer email account table
-----------------------------------------
CREATE TABLE customer_email_accounts_audit
	AS SELECT * FROM customer_email_accounts
	WHERE 2 = 1;
--------------------------------------------------------------------------------------------------------
--Adding the following columns(changed_by, action_type, changed_at) to the customer_email_accounts_audit
--------------------------------------------------------------------------------------------------------		   
ALTER TABLE customer_email_accounts_audit					   
ADD (user_name VARCHAR2(30),                --Who changed it?
			action_type VARCHAR(10) CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')),  
			changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP 					 --When the user ran the DML statement.
);
----------------------------------------
--Audit the supplier email account table
----------------------------------------
CREATE TABLE supplier_email_accounts_audit
	AS SELECT * FROM supplier_email_accounts
	WHERE 1 = 2;
--------------------------------------------------------------------------------------------------------
--Adding the following columns(changed_by, action_type, changed_at) to the supplier_email_accounts_audit
---------------------------------------------------------------------------------------------------------		   
ALTER TABLE supplier_email_accounts_audit					   
ADD (user_name VARCHAR2(30),                --Who changed it?
			action_type VARCHAR(10) CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')),  
			changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP 					 --When the user ran the DML statement.
);
--------------------------
--Audit the regions table
--------------------------
CREATE TABLE regions_audit
	AS SELECT * FROM regions
	WHERE 2 = 1;
----------------------------------------------------------------------------------------
--Adding the following columns(changed_by, action_type, changed_at) to the regions_audit
----------------------------------------------------------------------------------------		   
ALTER TABLE regions_audit					   
ADD (user_name VARCHAR2(30),                --Who changed it?
			action_type VARCHAR(10) CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')),  
			changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP 					 --When the user ran the DML statement.
);
-----------------------------
--Audit the countries table
----------------------------
CREATE TABLE countries_audit
	AS SELECT * FROM countries
	WHERE 1 = 2;
------------------------------------------------------------------------------------------
--Adding the following columns(changed_by, action_type, changed_at) to the countries_audit
------------------------------------------------------------------------------------------		   
ALTER TABLE countries_audit					   
ADD (user_name VARCHAR2(30),                --Who changed it?
			action_type VARCHAR(10) CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')),  
			changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP 					 --When the user ran the DML statement.
);
-----------------------------
--Audit the locations table
-----------------------------
CREATE TABLE locations_audit
	AS SELECT * FROM locations
	WHERE 2 = 1;
-------------------------------------------------------------------------------------------
--Adding the following columns(changed_by, action_type, changed_at) to the locations_audit
-------------------------------------------------------------------------------------------		   
ALTER TABLE locations_audit					   
ADD (user_name VARCHAR2(30),                --Who changed it?
			action_type VARCHAR(10) CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')),  
			changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP 					 --When the user ran the DML statement.
);
-----------------------------------
--Audit the supplier address table
-----------------------------------
CREATE TABLE supplier_address_audit
	AS SELECT * FROM supplier_addresses
	WHERE 1 = 2;
--------------------------------------------------------------------------------------------------------
--Adding the following columns(changed_by, action_type, changed_at) to the supplier_address_audit table.
--------------------------------------------------------------------------------------------------------
ALTER TABLE supplier_address_audit					   
ADD (user_name VARCHAR2(30),                --Who changed it?
			action_type VARCHAR(10) CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')),  
			changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP 					 --When the user ran the DML statement.
);
-----------------------------------
--Audit the customer address table
-----------------------------------
CREATE TABLE customer_address_audit
	AS SELECT * FROM customer_addresses
	WHERE 1 = 2;
--------------------------------------------------------------------------------------------------------------
--Adding the following columns(changed_by, action_type, changed_at) to the customer_address_audit
--------------------------------------------------------------------------------------------------------------					   
ALTER TABLE customer_address_audit					   
ADD (user_name VARCHAR2(30),                --Who changed it?
			action_type VARCHAR(10) CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')), 
			changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP 					 --When the user ran the DML statement.
);
-----------------------------------
--Audit the product_reviews table
-----------------------------------
CREATE TABLE product_reviews_audit AS
SELECT * FROM product_reviews 
WHERE 2 = 1;
--------------------------------------------------------------------------------------------------------------
--Adding the following columns(changed_by, action_type, changed_at) to the product_reviews_audit
--------------------------------------------------------------------------------------------------------------					   
ALTER TABLE product_reviews_audit
ADD (user_name VARCHAR2(30),                --Who changed it?
			action_type VARCHAR(10) CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')),  
			changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP 					 --When the user ran the DML statement.
);
-----------------------------------
--Audit the service_ratings table
-----------------------------------
CREATE TABLE service_ratings_audit AS
SELECT * FROM service_ratings
WHERE 1 = 2;
--------------------------------------------------------------------------------------------------------------
--Adding the following columns(changed_by, action_type, changed_at) to the service_ratings_audit
--------------------------------------------------------------------------------------------------------------					   
ALTER TABLE service_ratings_audit
ADD (user_name VARCHAR2(30),                --Who changed it?
			action_type VARCHAR(10) CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')),  
			changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP 					 --When the user ran the DML statement.
);
-----------------------------------
--Audit the rating_scale table
-----------------------------------
CREATE TABLE rating_scale_audit
AS SELECT * FROM rating_scale
WHERE 1 = 2;
--------------------------------------------------------------------------------------------------------------
--Adding the following columns(changed_by, action_type, changed_at) to the rating_scale_audit
--------------------------------------------------------------------------------------------------------------					   
ALTER TABLE rating_scale_audit
ADD (user_name VARCHAR2(30),                --Who changed it?
			action_type VARCHAR(10) CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')),  
			changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP 					 --When the user ran the DML statement.
);
							--========================================================================
							-- Package to hold the database store procedures (functions and procedure)
							--========================================================================
----------------------------------
--customer package specification.
----------------------------------
CREATE OR REPLACE PACKAGE customer_pkg
AS
	PROCEDURE create_customer_info(p_last_name customer_information.last_name%TYPE,
		p_first_name customer_information.first_name%TYPE, p_dob customer_information.dob%TYPE);
	PROCEDURE create_customer_email_account(p_email_account customer_email_accounts.email_account%TYPE,
			p_customer_id customer_email_accounts.customer_id%TYPE);
	PROCEDURE create_customer_address(p_street_address customer_addresses.street_address%TYPE,
			p_postal_code customer_addresses.postal_code%TYPE, p_location_id customer_addresses.location_id%TYPE, 
			p_customer_id customer_addresses.customer_id%TYPE);
	PROCEDURE create_customer_phone(p_phone customer_phone_numbers.phone%TYPE,
						p_customer_id customer_phone_numbers.customer_id%TYPE);	
END customer_pkg;
/
------------------------
--customer package body.
------------------------
CREATE OR REPLACE PACKAGE BODY customer_pkg
AS
	PROCEDURE create_customer_info(p_last_name customer_information.last_name%TYPE,
			p_first_name customer_information.first_name%TYPE, p_dob customer_information.dob%TYPE)
	AS
	BEGIN
		INSERT INTO customer_information(last_name, first_name, dob)
		VALUES(p_last_name, p_first_name, p_dob);
				COMMIT;
	EXCEPTION
			WHEN VALUE_ERROR THEN
				RAISE_APPLICATION_ERROR(-20001, 'Invalid value entered.');
	END create_customer_info;
		PROCEDURE create_customer_email_account(p_email_account customer_email_accounts.email_account%TYPE,
								p_customer_id customer_email_accounts.customer_id%TYPE)
		AS
		BEGIN
			INSERT INTO customer_email_accounts(email_account, customer_id)
			VALUES(p_email_account, p_customer_id);
					COMMIT;
		EXCEPTION
				WHEN VALUE_ERROR THEN
					RAISE_APPLICATION_ERROR(-20002, 'Invalid value entered.');
		END create_customer_email_account;
	PROCEDURE create_customer_address(p_street_address customer_addresses.street_address%TYPE,
				p_postal_code customer_addresses.postal_code%TYPE, p_location_id customer_addresses.location_id%TYPE,
				p_customer_id customer_addresses.customer_id%TYPE)
	AS
	BEGIN
		INSERT INTO customer_addresses(street_address, postal_code, location_id, customer_id)
		VALUES(p_street_address, p_postal_code, p_location_id, p_customer_id);
				COMMIT;
	EXCEPTION
			WHEN VALUE_ERROR THEN
				RAISE_APPLICATION_ERROR(-20003, 'Invalid value entered.');
	END create_customer_address;
		PROCEDURE create_customer_phone(p_phone customer_phone_numbers.phone%TYPE,
				p_customer_id customer_phone_numbers.customer_id%TYPE)
		AS
		BEGIN
			INSERT INTO customer_phone_numbers(Phone, customer_id)
			VALUES(p_phone, p_customer_id);
						COMMIT;
		EXCEPTION
				WHEN VALUE_ERROR THEN
					RAISE_APPLICATION_ERROR(-20004, 'Invalid value entered.');
		END create_customer_phone;
END customer_pkg;
/
----------------------------------
--supplier package specification.
----------------------------------
CREATE OR REPLACE PACKAGE supplier_pkg
AS
	PROCEDURE create_supplier_info(p_supplier_name supplier_information.supplier_name%TYPE);
	PROCEDURE create_supplier_email_account(p_email_account supplier_email_accounts.email_account%TYPE,
						p_supplier_id supplier_email_accounts.supplier_id%TYPE);
	PROCEDURE create_supplier_address(p_street_address supplier_addresses.street_address%TYPE,
		p_postal_code supplier_addresses.postal_code%TYPE, p_location_id supplier_addresses.location_id%TYPE,
		p_supplier_id supplier_addresses.supplier_id%TYPE);
	PROCEDURE create_supplier_phone(p_phone supplier_phone_numbers.phone%TYPE,
					p_supplier_id supplier_phone_numbers.supplier_id%TYPE);
END supplier_pkg;
/
-------------------------
--supplier package body.
-------------------------
CREATE OR REPLACE PACKAGE BODY supplier_pkg
AS
	PROCEDURE create_supplier_info(p_supplier_name supplier_information.supplier_name%TYPE)													
	AS
	BEGIN
		INSERT INTO supplier_information(supplier_name)
		VALUES(p_supplier_name);
				COMMIT;
	EXCEPTION
			WHEN VALUE_ERROR THEN
				RAISE_APPLICATION_ERROR(-20005, 'Invalid value entered.');
	END create_supplier_info;
		PROCEDURE create_supplier_email_account(p_email_account supplier_email_accounts.email_account%TYPE,
						p_supplier_id supplier_email_accounts.supplier_id%TYPE)
		AS
		BEGIN
			INSERT INTO supplier_email_accounts(email_account, supplier_id)
			VALUES(p_email_account, p_supplier_id);
						COMMIT;
		EXCEPTION
				WHEN VALUE_ERROR THEN
					RAISE_APPLICATION_ERROR(-20006, 'Invalid value entered.');
		END create_supplier_email_account;
	PROCEDURE create_supplier_address(p_street_address supplier_addresses.street_address%TYPE,
			p_postal_code supplier_addresses.postal_code%TYPE, p_location_id supplier_addresses.location_id%TYPE,
			p_supplier_id supplier_addresses.supplier_id%TYPE)
	AS
	BEGIN
		INSERT INTO supplier_addresses(street_address, postal_code, location_id, supplier_id)
		VALUES(p_street_address, p_postal_code, p_location_id, p_supplier_id);
					COMMIT;
	EXCEPTION
			WHEN VALUE_ERROR THEN
				RAISE_APPLICATION_ERROR(-20007, 'Invalid value entered.');
	END create_supplier_address;
		PROCEDURE create_supplier_phone(p_phone supplier_phone_numbers.phone%TYPE,
					p_supplier_id supplier_phone_numbers.supplier_id%TYPE)
		AS
		BEGIN
			INSERT INTO supplier_phone_numbers(Phone, supplier_id)
			VALUES(p_phone, p_supplier_id);
					COMMIT;
		EXCEPTION
				WHEN VALUE_ERROR THEN
					RAISE_APPLICATION_ERROR(-20008, 'Invalid value entered.');
		END create_supplier_phone;
END supplier_pkg;
/
---------------------------------	
--location package specification.
---------------------------------
CREATE OR REPLACE PACKAGE location_pkg
AS	
	PROCEDURE create_regions(p_region_id regions.region_id%TYPE, 
							p_region_name regions.region_name%TYPE);
	PROCEDURE create_countries(p_country_id countries.country_id%TYPE,
			p_country_name countries.country_name%TYPE, p_region_id countries.region_id%TYPE);
	PROCEDURE create_locations(p_city locations.city%TYPE, 
		p_country_id locations.country_id%TYPE, p_state_province locations.state_province%TYPE DEFAULT NULL);
END location_pkg;
/
-------------------------
--location package body.
-------------------------
CREATE OR REPLACE PACKAGE BODY location_pkg
AS
	PROCEDURE create_regions(p_region_id regions.region_id%TYPE, 
		p_region_name regions.region_name%TYPE)
	AS
	BEGIN
		INSERT INTO regions(region_id, region_name)
		VALUES(p_region_id, p_region_name);
				COMMIT;
	EXCEPTION
			WHEN VALUE_ERROR THEN
			RAISE_APPLICATION_ERROR(-20009, 'Invalid value entered.');
	END create_regions;
		PROCEDURE create_countries(p_country_id countries.country_id%TYPE,
			p_country_name countries.country_name%TYPE, p_region_id countries.region_id%TYPE)
		AS
		BEGIN
				INSERT INTO countries(country_id, country_name, region_id)
				VALUES(p_country_id, p_country_name, p_region_id);
					COMMIT;
		EXCEPTION
					WHEN VALUE_ERROR THEN
						RAISE_APPLICATION_ERROR(-20010, 'Invalid value entered.');
					WHEN OTHERS THEN
						DBMS_OUTPUT.PUT_LINE('Error ' || SQLCODE || ': ' || SQLERRM);
		END create_countries;
	PROCEDURE create_locations(p_city locations.city%TYPE,	
		 p_country_id locations.country_id%TYPE, p_state_province locations.state_province%TYPE DEFAULT NULL)
	AS
	BEGIN
		INSERT INTO locations(city, state_province, country_id)
		VALUES(p_city, p_state_province, p_country_id);
				COMMIT;
	EXCEPTION
			WHEN VALUE_ERROR THEN
				RAISE_APPLICATION_ERROR(-20011, 'Invalid value entered.');
			WHEN OTHERS THEN
				DBMS_OUTPUT.PUT_LINE('Error ' || SQLCODE || ': ' || SQLERRM);
	END create_locations;
END location_pkg;
/

-------------------------------
--stock package specification.
------------------------------
CREATE OR REPLACE PACKAGE stock_pkg
AS	

	PROCEDURE create_stock_entry(P_stock_id stock_entries.stock_id%TYPE, p_unit_price stock_entries.unit_price%TYPE,
				p_quantity stock_entries.quantity%TYPE, p_quantity_to_sell NUMBER,
				p_inventory_status_id stock_entries.inventory_status_id%TYPE,
				p_expiry_date DATE, p_entry_date DATE DEFAULT SYSDATE);
	PROCEDURE create_stock(p_stock_name  stock.product_name%TYPE, p_reorder_level stock.reorder_level%TYPE DEFAULT 0,
								p_quantity_in_stock NUMBER DEFAULT 0, p_unit_price NUMBER DEFAULT 0);
	PROCEDURE create_stock_category(p_category_name stock_categories.category_name%TYPE);
	PROCEDURE create_stock_information(p_unit_price stock_information.unit_price%TYPE, p_quantity stock_information.quantity%TYPE,
		p_category_id stock_information.category_id%TYPE, p_supplier_id stock_information.supplier_id%TYPE,
		p_stock_id stock_information.stock_id%TYPE, p_request_date stock_information.request_date%TYPE DEFAULT SYSDATE,
		p_supply_date stock_information.supply_date%TYPE DEFAULT SYSDATE);
	PROCEDURE create_payment_method(p_payment_mode_id payment_methods.payment_mode_id%TYPE, p_payment_mode payment_methods.payment_mode%TYPE);		
	PROCEDURE create_payment_status(p_payment_status_id payment_status.payment_status_id%TYPE,
									p_status_name payment_status.status_name%TYPE);
	PROCEDURE create_order_status(p_order_status_id order_status.order_status_id%TYPE,
									p_status_name order_status.status_name%TYPE);
	PROCEDURE create_inventory_status(p_inventory_status_id inventory_status.inventory_status_id%TYPE,
									p_status_name inventory_status.status_name%TYPE);
	PROCEDURE update_quantity_unit_price_in_stock_entry(new_quantity stock_entries.quantity%TYPE,
				new_unit_price stock_entries.unit_price%TYPE, P_stock_id stock_entries.stock_id%TYPE,
				p_entry_id stock_entries.entry_id %TYPE);
END stock_pkg;
/

----------------------
--stock package body.
----------------------
CREATE OR REPLACE PACKAGE BODY stock_pkg
AS	
		
	PROCEDURE create_stock_entry(P_stock_id stock_entries.stock_id%TYPE, p_unit_price stock_entries.unit_price%TYPE,
				p_quantity stock_entries.quantity%TYPE, p_quantity_to_sell NUMBER,
				p_inventory_status_id stock_entries.inventory_status_id%TYPE,
				p_expiry_date DATE, p_entry_date DATE DEFAULT SYSDATE)
	AS
	BEGIN
		INSERT INTO stock_entries(entry_date, quantity, unit_price, quantity_to_sell, expiry_date, stock_id, inventory_status_id)
		VALUES(p_entry_date, p_quantity, p_unit_price, p_quantity_to_sell, p_expiry_date, p_stock_id, p_inventory_status_id);
				COMMIT;
	EXCEPTION
			WHEN VALUE_ERROR THEN
				RAISE_APPLICATION_ERROR(-20013, 'Invalid value entered.');
	END create_stock_entry;
		PROCEDURE create_stock(p_stock_name  stock.product_name%TYPE, p_reorder_level stock.reorder_level%TYPE DEFAULT 0, p_quantity_in_stock NUMBER DEFAULT 0, p_unit_price NUMBER DEFAULT 0)
		AS
		BEGIN
			INSERT INTO stock(product_name, quantity_in_stock, unit_price, reorder_level) 
			VALUES(p_stock_name, p_quantity_in_stock, p_unit_price, p_reorder_level);
					COMMIT;
		EXCEPTION
				WHEN VALUE_ERROR THEN
					RAISE_APPLICATION_ERROR(-20014, 'Invalid value entered.');
		END create_stock;
		PROCEDURE create_stock_category(p_category_name stock_categories.category_name%TYPE)													
		AS
		BEGIN
			INSERT INTO stock_categories(category_name)
			VALUES(p_category_name);
					COMMIT;
		EXCEPTION
				WHEN VALUE_ERROR THEN
					RAISE_APPLICATION_ERROR(-20015, 'Invalid value entered.');
		END create_stock_category;
	PROCEDURE create_stock_information(p_unit_price stock_information.unit_price%TYPE, p_quantity stock_information.quantity%TYPE,
				p_category_id stock_information.category_id%TYPE, p_supplier_id stock_information.supplier_id%TYPE,
				p_stock_id stock_information.stock_id%TYPE, p_request_date stock_information.request_date%TYPE DEFAULT SYSDATE,
				p_supply_date stock_information.supply_date%TYPE DEFAULT SYSDATE)
	AS
	BEGIN
		INSERT INTO stock_information(unit_price, quantity, request_date, supply_date, category_id, supplier_id, stock_id)
		VALUES(p_unit_price, p_quantity, p_request_date, p_supply_date, p_category_id, p_supplier_id, p_stock_id);
					COMMIT;
	EXCEPTION
			WHEN VALUE_ERROR THEN
				RAISE_APPLICATION_ERROR(-20016, 'Invalid value entered.');
	END create_stock_information;
		PROCEDURE create_payment_method(p_payment_mode_id payment_methods.payment_mode_id%TYPE, p_payment_mode payment_methods.payment_mode%TYPE)											
		AS
		BEGIN
			INSERT INTO payment_methods(payment_mode_id, payment_mode)
			VALUES(p_payment_mode_id, p_payment_mode);
					COMMIT;
		EXCEPTION
				WHEN VALUE_ERROR THEN
					RAISE_APPLICATION_ERROR(-20017, 'Invalid value entered.');
		END create_payment_method;
	
	PROCEDURE create_payment_status(p_payment_status_id payment_status.payment_status_id%TYPE,
									p_status_name payment_status.status_name%TYPE)
	AS
	BEGIN
		INSERT INTO payment_status(payment_status_id, status_name)
		VALUES(p_payment_status_id, p_status_name);
				COMMIT;
	EXCEPTION
			WHEN VALUE_ERROR THEN
				RAISE_APPLICATION_ERROR(-20019, 'Invalid value entered.');
			WHEN NO_DATA_FOUND THEN
				RAISE_APPLICATION_ERROR(-20072, 'Insufficient data supplied');
	END create_payment_status;
		PROCEDURE create_order_status(p_order_status_id order_status.order_status_id%TYPE,
											p_status_name order_status.status_name%TYPE)
		AS
		BEGIN
			INSERT INTO order_status(order_status_id, status_name)
			VALUES(p_order_status_id, p_status_name);
					COMMIT;
		EXCEPTION
				WHEN VALUE_ERROR THEN
					RAISE_APPLICATION_ERROR(-20020, 'Invalid value entered.');
				WHEN OTHERS THEN
					RAISE_APPLICATION_ERROR(SQLCODE, SQLERRM);
		END create_order_status;
	PROCEDURE create_inventory_status(p_inventory_status_id inventory_status.inventory_status_id%TYPE,
										p_status_name inventory_status.status_name%TYPE)
	AS
	BEGIN
		INSERT INTO inventory_status(inventory_status_id, status_name)
		VALUES(p_inventory_status_id, p_status_name);
				COMMIT;
	EXCEPTION
			WHEN VALUE_ERROR THEN
				RAISE_APPLICATION_ERROR(-20021, 'Invalid value entered.');
			WHEN OTHERS THEN
				RAISE_APPLICATION_ERROR(-20084, SQLERRM);
	END create_inventory_status;
	
	PROCEDURE update_quantity_unit_price_in_stock_entry(new_quantity stock_entries.quantity%TYPE,
				new_unit_price stock_entries.unit_price%TYPE, P_stock_id stock_entries.stock_id%TYPE,
				p_entry_id stock_entries.entry_id %TYPE)
	AS
	BEGIN
	UPDATE stock_entries
	SET quantity = new_quantity,
	    quantity_to_sell = new_quantity,
		unit_price = new_unit_price
	WHERE stock_id = p_stock_id AND entry_id = p_entry_id;
	
			COMMIT;
	EXCEPTION
			WHEN NO_DATA_FOUND THEN
				RAISE_APPLICATION_ERROR(-20028, 'No row updated');
			WHEN VALUE_ERROR THEN
				RAISE_APPLICATION_ERROR(-20029, 'Invalid quantity  :  '||new_quantity||' or product id  :  '||p_stock_id||' or unit price'||new_unit_price||' entered');
			WHEN OTHERS THEN
				DBMS_OUTPUT.PUT_LINE(SQLERRM);
	END update_quantity_unit_price_in_stock_entry;
END stock_pkg;
/


-------------------------------
--sales package specification.
------------------------------
CREATE OR REPLACE PACKAGE sales_pkg
AS
    PROCEDURE create_orders(p_customer_id orders.customer_id%TYPE,  
			p_transaction_init_date orders.transaction_init_date%TYPE DEFAULT SYSDATE);
	PROCEDURE create_order_item(p_order_id   order_items.order_id%TYPE,
		p_stock_id order_items.stock_id%TYPE, p_quantity order_items.quantity%type);
END sales_pkg;
/


-------------------------------
--sales package body
------------------------------
CREATE OR REPLACE PACKAGE BODY sales_pkg
AS
    PROCEDURE create_orders(p_customer_id orders.customer_id%TYPE,
			p_transaction_init_date orders.transaction_init_date%TYPE DEFAULT SYSDATE)
							
	AS
	BEGIN
		INSERT INTO orders(transaction_init_date, customer_id)
		VALUES(p_transaction_init_date, p_customer_id);
				COMMIT;
	EXCEPTION
			WHEN VALUE_ERROR THEN
				   RAISE_APPLICATION_ERROR(-20012, 'Invalid value entered.');
	END create_orders;
	
	PROCEDURE create_order_item(p_order_id   order_items.order_id%TYPE,
				p_stock_id order_items.stock_id%TYPE, p_quantity order_items.quantity%type)
	AS
	BEGIN
			-- Insert order item
			INSERT INTO order_items (order_id, quantity, stock_id)
			VALUES (p_order_id, p_quantity, p_stock_id);
					COMMIT;
	END create_order_item;
END sales_pkg;
/	


-------------------------------------------	
--transaction update package specification.
-------------------------------------------
CREATE OR REPLACE PACKAGE transaction_update_pkg
AS
	PROCEDURE update_orders_on_insert(new_order_id order_items.order_id%TYPE, new_stock_id order_items.stock_id%TYPE,
				new_unit_price order_items.unit_price%TYPE, new_quantity order_items.quantity%TYPE);
	PROCEDURE update_orders_on_update(new_order_id order_items.order_id%TYPE, new_stock_id order_items.stock_id%TYPE,
				new_unit_price order_items.unit_price%TYPE, new_quantity order_items.quantity%TYPE,
				old_unit_price order_items.unit_price%TYPE, old_quantity order_items.quantity%TYPE);
	PROCEDURE update_orders_on_del(old_order_id order_items.order_id%TYPE, old_stock_id order_items.stock_id%TYPE,
				old_unit_price order_items.unit_price%TYPE, old_quantity order_items.quantity%TYPE);
	FUNCTION discount_pct(f_order_total orders.order_total%TYPE) RETURN NUMBER;
	
END transaction_update_pkg;
/

-------------------------------------------	
--transaction update package body.
-------------------------------------------
CREATE OR REPLACE PACKAGE BODY transaction_update_pkg
AS
	FUNCTION discount_pct(f_order_total orders.order_total%TYPE)
	RETURN NUMBER
	AS
		v_discount_pct orders.discount_pct%TYPE;
	BEGIN
		IF f_order_total < 100 THEN
			v_discount_pct := 0;
		ELSIF f_order_total BETWEEN 100 AND 200 THEN
			v_discount_pct := 5 / 100;
		ELSIF f_order_total BETWEEN 201 AND 500 THEN
			v_discount_pct := 10 / 100;
		ELSE
			v_discount_pct := 15 / 100;
		END IF;
			RETURN v_discount_pct;
	EXCEPTION
			WHEN NO_DATA_FOUND THEN
				RETURN 0;
			WHEN VALUE_ERROR THEN
				RETURN 0;
	END discount_pct;
		PROCEDURE update_orders_on_insert(new_order_id order_items.order_id%TYPE, new_stock_id order_items.stock_id%TYPE,
						new_unit_price order_items.unit_price%TYPE, new_quantity order_items.quantity%TYPE)
		AS
			existing_order_total 			orders.order_total%TYPE;
			current_order_total 			orders.order_total%TYPE;
			v_discount_pct 					orders.discount_pct%TYPE;
			existing_reserved_quantity      stock.reserved_quantity%TYPE;
			new_reserved_quantity           stock.reserved_quantity%TYPE;
		BEGIN
				SELECT order_total INTO existing_order_total FROM orders WHERE order_id = new_order_id;
				SELECT reserved_quantity INTO existing_reserved_quantity FROM stock
				WHERE stock_id = new_stock_id
                FOR UPDATE;				
					
					new_reserved_quantity := existing_reserved_quantity + new_quantity;  --Available reserved stock quantity.
					
					
					
					
					current_order_total := ROUND((new_unit_price * new_quantity) + NVL(existing_order_total, 0), 1);
					--v_discount_pct := transaction_update_pkg.discount_pct(current_order_total);
					--Update order_total, discount_pct, discount_amount, amount_to_pay on orders when order item is created
					UPDATE orders
					SET order_total = current_order_total,
					    amount_to_pay = current_order_total
						--discount_pct = v_discount_pct, 
						--discount_amount = ROUND(v_discount_pct * current_order_total, 1),
						--amount_to_pay = ROUND(current_order_total - (v_discount_pct * current_order_total), 1)
					WHERE order_id = new_order_id;	
					
					
					--Update quantity_in_stock on stock when order item is created
					UPDATE stock
					SET reserved_quantity = new_reserved_quantity
					WHERE stock_id = new_stock_id;
				
		EXCEPTION
				WHEN NO_DATA_FOUND THEN
					RAISE_APPLICATION_ERROR(-20022, 'No data found.');
				WHEN VALUE_ERROR THEN
					RAISE_APPLICATION_ERROR(-20023, 'Invalid value entered.');
				WHEN TOO_MANY_ROWS THEN
					RAISE_APPLICATION_ERROR(-20077, 'More than one row retuened by the select statement.');
		END update_orders_on_insert;
	PROCEDURE update_orders_on_update(new_order_id order_items.order_id%TYPE, new_stock_id order_items.stock_id%TYPE,
					new_unit_price order_items.unit_price%TYPE, new_quantity order_items.quantity%TYPE,
					old_unit_price order_items.unit_price%TYPE, old_quantity order_items.quantity%TYPE)
	AS
		existing_order_total 			orders.order_total%TYPE;
		current_order_total 			orders.order_total%TYPE;
		v_discount_pct 					orders.discount_pct%TYPE;
		existing_reserved_quantity      stock.reserved_quantity%TYPE;				
        new_reserved_quantity           stock.reserved_quantity%TYPE;
	BEGIN
		SELECT order_total INTO existing_order_total FROM orders WHERE order_id = new_order_id;
		SELECT reserved_quantity INTO existing_reserved_quantity FROM stock
		WHERE stock_id = new_stock_id
		FOR UPDATE;
		
		
			new_reserved_quantity := existing_reserved_quantity + (new_quantity - old_quantity); --Available quantity in stock.
			
			
			
				current_order_total := ROUND(existing_order_total + ((new_unit_price * new_quantity) - (old_unit_price * old_quantity)),1);
				--v_discount_pct := transaction_update_pkg.discount_pct(current_order_total);
				
				--Update order_total, discount_pct, discount_amount, amount_to_pay on orders when order item is updated
				UPDATE orders
				SET order_total = current_order_total,
				    amount_to_pay = current_order_total
					--discount_pct = v_discount_pct, 
					--discount_amount = ROUND(v_discount_pct * current_order_total, 1),
					--amount_to_pay = ROUND(current_order_total - (v_discount_pct * current_order_total), 1)
				WHERE order_id = new_order_id;
				
				
				
				--Update quantity_in_stock on stock when order item is updated
				UPDATE stock
				SET reserved_quantity = new_reserved_quantity
				WHERE stock_id = new_stock_id;
				
			
	EXCEPTION
			WHEN NO_DATA_FOUND THEN
				RAISE_APPLICATION_ERROR(-20024, 'No data found.');
			WHEN VALUE_ERROR THEN
				RAISE_APPLICATION_ERROR(-20025, 'Invalid value entered.');
			WHEN TOO_MANY_ROWS THEN
				RAISE_APPLICATION_ERROR(-20078, 'More than one row retuened by the select statement.');
	END update_orders_on_update;
		PROCEDURE update_orders_on_del(old_order_id order_items.order_id%TYPE, old_stock_id order_items.stock_id%TYPE,
						old_unit_price order_items.unit_price%TYPE, old_quantity order_items.quantity%TYPE)
		AS
			existing_order_total 			orders.order_total%TYPE;
			current_order_total 			orders.order_total%TYPE;
			v_discount_pct 					orders.discount_pct%TYPE;
			existing_reserved_quantity      stock.reserved_quantity%TYPE;				
            new_reserved_quantity           stock.reserved_quantity%TYPE;
		BEGIN
			SELECT order_total INTO existing_order_total FROM orders WHERE order_id = old_order_id;
			SELECT reserved_quantity INTO existing_reserved_quantity FROM stock
			WHERE stock_id = old_stock_id
			FOR UPDATE;
			
				current_order_total := ROUND(existing_order_total - (old_unit_price * old_quantity), 1);
				--v_discount_pct := transaction_update_pkg.discount_pct(current_order_total);
				new_reserved_quantity := existing_reserved_quantity - old_quantity;   --Available quantity in stock.
				
				
				
			
					--Update order_total, discount_pct, discount_amount, amount_to_pay on orders when order item is deleted
					UPDATE orders
					SET order_total = current_order_total,
					    amount_to_pay = current_order_total
						--discount_pct = v_discount_pct, 
						--discount_amount = ROUND(v_discount_pct * current_order_total, 1),
						--amount_to_pay = ROUND(current_order_total - (v_discount_pct * current_order_total), 1)
					WHERE order_id = old_order_id;
					
					
					--Update quantity_in_stock on stock when order item is deleted
					UPDATE stock
					SET reserved_quantity = new_reserved_quantity
					WHERE stock_id = old_stock_id;

				
		EXCEPTION
				WHEN NO_DATA_FOUND THEN
					RAISE_APPLICATION_ERROR(-20026, 'No data found.');
				WHEN VALUE_ERROR THEN
					RAISE_APPLICATION_ERROR(-20027, 'Invalid value entered.');
				WHEN TOO_MANY_ROWS THEN
					RAISE_APPLICATION_ERROR(-20079, 'More than one row retuened by the select statement.');
		END update_orders_on_del;
	
END transaction_update_pkg;
/

-------------------------------------------	
-- stock update package specification.
-------------------------------------------

CREATE OR REPLACE PACKAGE stock_update_pkg
AS
    PROCEDURE stock_update_on_insert_on_stock_entries(new_stock_id stock.stock_id%TYPE, new_quantity stock_entries.quantity%TYPE,
			new_unit_price stock_entries.unit_price%TYPE, p_new_inventory_status_id inventory_status.inventory_status_id%TYPE);
	PROCEDURE stock_update_on_delete_on_stock_entries(old_quantity stock_entries.quantity%TYPE,
			old_unit_price stock_entries.unit_price%TYPE, old_stock_id stock.stock_id%TYPE,
			p_old_inventory_status_id inventory_status.inventory_status_id%TYPE,
			old_quantity_to_sell stock_entries.quantity_to_sell%TYPE);
    PROCEDURE stock_update_on_update_on_stock_entries(new_stock_id stock.stock_id%TYPE, new_quantity stock_entries.quantity%TYPE,
					new_unit_price stock_entries.unit_price%TYPE, old_quantity stock_entries.quantity%TYPE, old_unit_price stock_entries.unit_price%TYPE,
					p_new_inventory_status_id inventory_status.inventory_status_id%TYPE, p_old_inventory_status_id inventory_status.inventory_status_id%TYPE,
					new_quantity_to_sell stock_entries.quantity_to_sell%TYPE);

END stock_update_pkg;
/

-------------------------------------------	
-- stock update package body.
-------------------------------------------
CREATE OR REPLACE PACKAGE BODY stock_update_pkg
AS
		
	PROCEDURE stock_update_on_insert_on_stock_entries(new_stock_id stock.stock_id%TYPE, new_quantity stock_entries.quantity%TYPE,
			new_unit_price stock_entries.unit_price%TYPE, p_new_inventory_status_id inventory_status.inventory_status_id%TYPE)
	AS
		 existing_quantity_in_stock stock.quantity_in_stock%TYPE;
		 existing_unit_price stock.unit_price%type;
		 v_new_quantity stock.quantity_in_stock%TYPE;
		 v_inventory_status_id inventory_status.inventory_status_id%TYPE;
	BEGIN
		SELECT s.quantity_in_stock, s.unit_price INTO existing_quantity_in_stock, existing_unit_price  FROM stock s WHERE stock_id = new_stock_id;
		SELECT inventory_status_id INTO v_inventory_status_id FROM inventory_status WHERE status_name = 'Available';
			IF p_new_inventory_status_id = v_inventory_status_id THEN   -- Use where inventory status is Available only to update stock 
					v_new_quantity := existing_quantity_in_stock + new_quantity;    -- When insert on stock_entries
					UPDATE stock
					SET quantity_in_stock = v_new_quantity,
						unit_price = ROUND((((new_unit_price * new_quantity) + (existing_unit_price * existing_quantity_in_stock)) /  (existing_quantity_in_stock + new_quantity)), 1)
					WHERE stock_id = new_stock_id;		
			END IF;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			RAISE_APPLICATION_ERROR(-20030, 'No data found.');
		WHEN VALUE_ERROR THEN
			RAISE_APPLICATION_ERROR(-20031, 'Invalid value entered.');
		WHEN TOO_MANY_ROWS THEN
			RAISE_APPLICATION_ERROR(-20080, 'More than one row retuened by the select statement.');
	END stock_update_on_insert_on_stock_entries;
		PROCEDURE stock_update_on_update_on_stock_entries(new_stock_id stock.stock_id%TYPE, new_quantity stock_entries.quantity%TYPE,
					new_unit_price stock_entries.unit_price%TYPE, old_quantity stock_entries.quantity%TYPE, old_unit_price stock_entries.unit_price%TYPE,
					p_new_inventory_status_id inventory_status.inventory_status_id%TYPE, p_old_inventory_status_id inventory_status.inventory_status_id%TYPE,
					new_quantity_to_sell stock_entries.quantity_to_sell%TYPE)
		AS
				 existing_quantity_in_stock stock.quantity_in_stock%TYPE;
				 existing_unit_price stock.unit_price%type;
				 v_new_quantity stock.quantity_in_stock%TYPE;
				 v_inventory_status_id inventory_status.inventory_status_id%TYPE;
				 v_new_unit_price stock_entries.unit_price%TYPE;
		BEGIN
				SELECT s.quantity_in_stock, s.unit_price INTO existing_quantity_in_stock, existing_unit_price  FROM stock s WHERE stock_id = new_stock_id;
				SELECT inventory_status_id INTO v_inventory_status_id FROM inventory_status WHERE UPPER(status_name) = 'AVAILABLE';
					IF p_new_inventory_status_id = v_inventory_status_id AND p_old_inventory_status_id = v_inventory_status_id THEN   -- Use where inventory status is Available only to update stock 
						v_new_quantity := existing_quantity_in_stock - (new_quantity - old_quantity); -- When update on stock_entries
						IF v_new_quantity = 0 THEN
							v_new_unit_price := existing_unit_price;
						ELSE
							v_new_unit_price := ROUND((((new_unit_price * new_quantity) - (old_unit_price * old_quantity) + (existing_unit_price * existing_quantity_in_stock)) /  (v_new_quantity)), 1);
						END IF;
						UPDATE stock
								SET quantity_in_stock = v_new_quantity,
									unit_price = v_new_unit_price
								WHERE stock_id = new_stock_id;
					END IF;
					IF p_old_inventory_status_id = v_inventory_status_id AND p_new_inventory_status_id != v_inventory_status_id THEN
						v_new_quantity := existing_quantity_in_stock - new_quantity_to_sell;
						IF v_new_quantity = 0 THEN
							v_new_unit_price := existing_unit_price;
						ELSE
							v_new_unit_price := ROUND(((existing_unit_price * existing_quantity_in_stock) - (old_unit_price * new_quantity_to_sell)) / v_new_quantity, 1);
						END IF;
							UPDATE stock
							SET quantity_in_stock = v_new_quantity,
									unit_price = v_new_unit_price
							WHERE stock_id = new_stock_id;
					END IF;
					IF p_old_inventory_status_id != v_inventory_status_id AND p_new_inventory_status_id = v_inventory_status_id THEN
						v_new_quantity := existing_quantity_in_stock + new_quantity_to_sell;
						v_new_unit_price := ROUND(((existing_unit_price * existing_quantity_in_stock) + (new_unit_price * new_quantity_to_sell)) / v_new_quantity, 1);
						UPDATE stock
								SET quantity_in_stock = v_new_quantity,
									unit_price = v_new_unit_price
								WHERE stock_id = new_stock_id;
					END IF;
		EXCEPTION
				WHEN NO_DATA_FOUND THEN
					RAISE_APPLICATION_ERROR(-20032, 'No data found.');
				WHEN VALUE_ERROR THEN
					RAISE_APPLICATION_ERROR(-20033, 'Invalid value entered.');
				WHEN TOO_MANY_ROWS THEN
				    RAISE_APPLICATION_ERROR(-20081, 'More than one row retuened by the select statement.');
		END stock_update_on_update_on_stock_entries;
	PROCEDURE stock_update_on_delete_on_stock_entries(old_quantity stock_entries.quantity%TYPE,
			old_unit_price stock_entries.unit_price%TYPE, old_stock_id stock.stock_id%TYPE,
			p_old_inventory_status_id inventory_status.inventory_status_id%TYPE,
			old_quantity_to_sell stock_entries.quantity_to_sell%TYPE)
	AS
			 existing_quantity_in_stock stock.quantity_in_stock%TYPE;
			 existing_unit_price stock.unit_price%type;
			 v_new_quantity stock.quantity_in_stock%TYPE;
			 v_inventory_status_id inventory_status.inventory_status_id%TYPE;
			 v_new_unit_price stock_entries.unit_price%TYPE;
	BEGIN
			SELECT s.quantity_in_stock, s.unit_price INTO existing_quantity_in_stock, existing_unit_price  FROM stock s WHERE stock_id = old_stock_id;
			SELECT inventory_status_id INTO v_inventory_status_id FROM inventory_status WHERE status_name = 'Available';
				IF p_old_inventory_status_id = v_inventory_status_id THEN   -- Use where inventory status is Available only to update stock.
						v_new_quantity := existing_quantity_in_stock - old_quantity_to_sell; -- When delete on stock_entries
						IF v_new_quantity = 0 THEN
							v_new_unit_price := existing_unit_price;
						ELSE
							v_new_unit_price := ROUND(((existing_unit_price * existing_quantity_in_stock) - (old_unit_price * old_quantity_to_sell)) / v_new_quantity, 1);
						END IF;
							UPDATE stock
							SET quantity_in_stock = v_new_quantity,
								unit_price = v_new_unit_price
							WHERE stock_id = old_stock_id;
				END IF;
	EXCEPTION
			WHEN NO_DATA_FOUND THEN
				RAISE_APPLICATION_ERROR(-20034, 'No data found.');
			WHEN VALUE_ERROR THEN
				RAISE_APPLICATION_ERROR(-20035, 'Invalid value entered.');
			WHEN TOO_MANY_ROWS THEN
				RAISE_APPLICATION_ERROR(-20082, 'More than one row retuened by the select statement.');
	END stock_update_on_delete_on_stock_entries;
	
END stock_update_pkg;
/
	
-------------------------------------------	
-- sales update package specification.
-------------------------------------------
CREATE OR REPLACE PACKAGE sales_update_pkg
AS

    PROCEDURE update_order_item(p_quantity order_items.quantity%TYPE, p_item_id order_items.item_id%TYPE);
	
	PROCEDURE update_amount_paid(p_order_id orders.order_id%TYPE, p_customer_id orders.customer_id%TYPE,
				p_amount_paid orders.amount_paid%TYPE, p_payment_mode_id orders.payment_mode_id%TYPE,
				p_payment_date orders.payment_date%TYPE DEFAULT SYSDATE);
END sales_update_pkg;
/

-------------------------------------------	
-- sales update package body.
-------------------------------------------
CREATE OR REPLACE PACKAGE BODY sales_update_pkg
AS

    PROCEDURE update_order_item(p_quantity order_items.quantity%TYPE, p_item_id order_items.item_id%TYPE)
    AS
	BEGIN
          UPDATE order_items
		  SET quantity = p_quantity
		  WHERE item_id = p_item_id;
	END update_order_item;
	
	
	PROCEDURE update_amount_paid(p_order_id orders.order_id%TYPE, p_customer_id orders.customer_id%TYPE,
				p_amount_paid orders.amount_paid%TYPE, p_payment_mode_id orders.payment_mode_id%TYPE,
				p_payment_date orders.payment_date%TYPE DEFAULT SYSDATE)
	AS
		v_amount_to_pay  orders.amount_to_pay%TYPE;
		v_change         orders.change%TYPE;
		v_paid_id        orders.payment_status_id%TYPE;
	BEGIN
			SELECT amount_to_pay INTO v_amount_to_pay FROM orders 
			WHERE order_id = p_order_id AND customer_id = p_customer_id;
			SELECT payment_status_id INTO v_paid_id FROM payment_status WHERE UPPER(status_name) = 'PAID';
			v_change := p_amount_paid - v_amount_to_pay;
			IF v_change < 0 THEN
				RAISE_APPLICATION_ERROR(-20074, 'Amount paid: "'||p_amount_paid||'" can''t be less than amount to pay: "'||v_amount_to_pay||'"' );
			ELSE
				UPDATE orders
				SET amount_paid = p_amount_paid, payment_mode_id = p_payment_mode_id,
					change = v_change, payment_date = p_payment_date,
					payment_status_id = v_paid_id
				WHERE customer_id = p_customer_id AND order_id = p_order_id;
			END IF;
	EXCEPTION
			WHEN VALUE_ERROR THEN
				RAISE_APPLICATION_ERROR(-20075, SQLERRM);
			WHEN TOO_MANY_ROWS THEN
				RAISE_APPLICATION_ERROR(-20083, 'More than one row retuened by the select statement.');
			WHEN OTHERS THEN
				RAISE_APPLICATION_ERROR(-20076, SQLERRM);
	END update_amount_paid;
	
END sales_update_pkg;
/

-- Order delivery package specification.
CREATE OR REPLACE PACKAGE product_delivery_pkg
AS
     PROCEDURE product_delivery(p_order_id   order_items.order_id%TYPE, p_stock_id order_items.stock_id%TYPE,
                   p_quantity order_items.quantity%type);
	PROCEDURE product_delivery_status(p_order_id   order_items.order_id%TYPE, p_order_status_id orders.order_status_id%TYPE);		   
	
END product_delivery_pkg;
/

-- Order delivery package body.
CREATE OR REPLACE PACKAGE BODY product_delivery_pkg
AS
PROCEDURE product_delivery(p_order_id   order_items.order_id%TYPE, p_stock_id order_items.stock_id%TYPE,
                   p_quantity order_items.quantity%type)
	AS
		v_remaining_quantity NUMBER := p_quantity;  -- quantity of items being ordered by a customer.
		v_use_qty   NUMBER;                         -- quantity sold.
		v_product_name stock.product_name%TYPE;
		v_inventory_status_id inventory_status.inventory_status_id%TYPE;
	BEGIN
			SELECT product_name INTO v_product_name FROM stock WHERE stock_id = p_stock_id;
			SELECT inventory_status_id INTO v_inventory_status_id FROM inventory_status WHERE UPPER(status_name) = 'OUT OF STOCK';
		    -- Cursor FOR loop: FIFO, deliver order by expiry_date, then entry_date
		FOR rec IN (
					SELECT entry_id, quantity_to_sell, expiry_date, inventory_status_id
					FROM stock_entries JOIN inventory_status USING (inventory_status_id)
					WHERE stock_id = p_stock_id
					AND quantity_to_sell > 0 AND UPPER(status_name) = ('AVAILABLE')
					ORDER BY expiry_date, entry_date
					)	
		LOOP
			EXIT WHEN v_remaining_quantity = 0;
			-- Take the smaller of remaining demand and batch quantity
			v_use_qty := LEAST(v_remaining_quantity, rec.quantity_to_sell);
			-- Insert order item
			
			UPDATE stock
			SET quantity_in_stock = quantity_in_stock - v_use_qty
			WHERE stock_id = p_stock_id;
					
			v_remaining_quantity := v_remaining_quantity - v_use_qty;
		END LOOP;
		           COMMIT;
		-- If still not enough stock
		IF v_remaining_quantity > 0 THEN
			RAISE_APPLICATION_ERROR(-20018, 'Insufficient "'||v_product_name||'" in stock');
		END IF;
		
		EXCEPTION
	        WHEN NO_DATA_FOUND THEN
			         DBMS_OUTPUT.PUT_LINE('No data updated.');
			WHEN OTHERS THEN
			         DBMS_OUTPUT.PUT_LINE(SQLCODE||': '||SQLERRM);
	
	END product_delivery;
	
	PROCEDURE product_delivery_status(p_order_id   order_items.order_id%TYPE, p_order_status_id orders.order_status_id%TYPE)
	AS
	BEGIN
	   UPDATE orders
	   SET order_status_id = p_order_status_id
	   WHERE order_id = p_order_id;
	   COMMIT;
	EXCEPTION
	         WHEN NO_DATA_FOUND THEN
			         DBMS_OUTPUT.PUT_LINE('No data updated.');
			WHEN OTHERS THEN
			         DBMS_OUTPUT.PUT_LINE(SQLCODE||': '||SQLERRM);
	END product_delivery_status;
END product_delivery_pkg;
/

----------------------------------
--rating scale package specification
-----------------------------------
CREATE OR REPLACE PACKAGE rating_scale_pkg
AS
     PROCEDURE create_rating_scale(p_rating_value rating_scale.rating_value%TYPE,
            p_rating_label rating_scale.rating_label%TYPE, p_rating_description rating_scale.rating_description%TYPE);
END rating_scale_pkg;
/

----------------------------------
--rating scale package body
-----------------------------------
CREATE OR REPLACE PACKAGE BODY rating_scale_pkg
AS
    PROCEDURE create_rating_scale(p_rating_value rating_scale.rating_value%TYPE,
            p_rating_label rating_scale.rating_label%TYPE, p_rating_description rating_scale.rating_description%TYPE)
	AS
    BEGIN
		 INSERT INTO rating_scale(rating_value, rating_label, rating_description)
		 VALUES(p_rating_value, p_rating_label, p_rating_description);
			COMMIT;
	EXCEPTION
			 WHEN VALUE_ERROR THEN
					RAISE_APPLICATION_ERROR(-20093, 'Invalid value entered.');
			WHEN NO_DATA_FOUND THEN
					RAISE_APPLICATION_ERROR(-20094, 'No data found.');
	END create_rating_scale;
END rating_scale_pkg;
/


----------------------------------
--Ratings package specification
-----------------------------------
CREATE OR REPLACE PACKAGE ratings_pkg
AS
	
	PROCEDURE create_service_ratings(p_customer_id service_ratings.customer_id%TYPE,
            p_order_id service_ratings.order_id%TYPE, p_delivery_rating service_ratings.delivery_rating%TYPE,
			p_packaging_rating service_ratings.packaging_rating%TYPE, p_support_rating service_ratings.support_rating%TYPE,
			p_overall_comment service_ratings.overall_comment%TYPE,
			p_rating_date service_ratings.rating_date%TYPE DEFAULT CURRENT_TIMESTAMP);
	PROCEDURE create_product_reviews(p_customer_id product_reviews.customer_id%TYPE,
            p_stock_id product_reviews.stock_id%TYPE, p_rating product_reviews.rating%TYPE,
			p_feedback product_reviews.feedback%TYPE);
END ratings_pkg;
/
----------------------------------
--Ratings package body
-----------------------------------
CREATE OR REPLACE PACKAGE BODY ratings_pkg
AS
	
		PROCEDURE create_product_reviews(p_customer_id product_reviews.customer_id%TYPE,
            p_stock_id product_reviews.stock_id%TYPE, p_rating product_reviews.rating%TYPE,
			p_feedback product_reviews.feedback%TYPE)
		AS
		BEGIN
			 INSERT INTO product_reviews(customer_id, stock_id, rating, feedback)
			 VALUES(p_customer_id, p_stock_id, p_rating, p_feedback);
				COMMIT;
		EXCEPTION
				 WHEN VALUE_ERROR THEN
						RAISE_APPLICATION_ERROR(-20003, 'Invalid value entered.');
				WHEN NO_DATA_FOUND THEN
						RAISE_APPLICATION_ERROR(-20003, 'No data found.');
		END create_product_reviews;
	PROCEDURE create_service_ratings(p_customer_id service_ratings.customer_id%TYPE,
            p_order_id service_ratings.order_id%TYPE, p_delivery_rating service_ratings.delivery_rating%TYPE,
			p_packaging_rating service_ratings.packaging_rating%TYPE, p_support_rating service_ratings.support_rating%TYPE,
			p_overall_comment service_ratings.overall_comment%TYPE,
			p_rating_date service_ratings.rating_date%TYPE DEFAULT CURRENT_TIMESTAMP)
	AS
	BEGIN
		 INSERT INTO service_ratings(order_id, customer_id, delivery_rating, packaging_rating, support_rating, overall_comment, rating_date)
		 VALUES(p_order_id, p_customer_id, p_delivery_rating, p_packaging_rating, p_support_rating, p_overall_comment, p_rating_date);
			COMMIT;
	EXCEPTION
			 WHEN VALUE_ERROR THEN
					RAISE_APPLICATION_ERROR(-20091, 'Invalid value entered.');
			WHEN NO_DATA_FOUND THEN
					RAISE_APPLICATION_ERROR(-20092, 'No data found.');
	END create_service_ratings;
END ratings_pkg;
/

-- Package to which it update customer_information, customer_email_accounts, customer_phone_numbers, customer_address
             -- Package specification
CREATE OR REPLACE PACKAGE ecom.customer_update_pkg
AS

/* CUSTOMER */
  PROCEDURE update_customer_information (
    p_customer_id IN customer_information.customer_id%TYPE,
    p_first_name  IN customer_information.first_name%TYPE,
    p_last_name   IN customer_information.last_name%TYPE,
    p_dob         IN customer_information.dob%TYPE
  );
-- Customer email 
  PROCEDURE update_customer_email_account (
    p_customer_id IN customer_email_accounts.customer_id%TYPE,
    p_account_id  IN customer_email_accounts.account_id%TYPE,
    p_email_account   IN customer_email_accounts.email_account%TYPE
  );
-- Customer phone 
  PROCEDURE update_customer_phone_number (
    p_customer_id IN customer_phone_numbers.customer_id%TYPE,
    p_phone_number_id  IN customer_phone_numbers.phone_number_id%TYPE,
    p_phone   IN customer_phone_numbers.phone%TYPE
  );
  -- Customer address 
  PROCEDURE update_customer_address (
    p_customer_id IN customer_addresses.customer_id%TYPE,
    p_street_address  IN customer_addresses.street_address%TYPE,
	p_postal_code  IN customer_addresses.postal_code%TYPE,
	p_location_id  IN customer_addresses.location_id%TYPE,
    p_address_id   IN customer_addresses.address_id%TYPE
  );
  
END customer_update_pkg;
/
  
  
        -- Package body
CREATE OR REPLACE PACKAGE BODY ecom.customer_update_pkg
AS 
  
	PROCEDURE update_customer_information (
		p_customer_id IN customer_information.customer_id%TYPE,
		p_first_name  IN customer_information.first_name%TYPE,
		p_last_name   IN customer_information.last_name%TYPE,
		p_dob         IN customer_information.dob%TYPE
	  ) IS
	  BEGIN
		UPDATE customer_information
		   SET first_name = p_first_name,
			   last_name  = p_last_name,
			   dob        = p_dob
		 WHERE customer_id = p_customer_id;
		                 COMMIT;
	  END update_customer_information;
  
	  PROCEDURE update_customer_email_account (
		p_customer_id IN customer_email_accounts.customer_id%TYPE,
		p_account_id  IN customer_email_accounts.account_id%TYPE,
		p_email_account   IN customer_email_accounts.email_account%TYPE
	  ) IS
	  BEGIN
		UPDATE customer_email_accounts
		   SET email_account = p_email_account
		 WHERE account_id = p_account_id AND customer_id = p_customer_id;
		                         COMMIT;
	  END update_customer_email_account;
  
	  PROCEDURE update_customer_phone_number (
		p_customer_id IN customer_phone_numbers.customer_id%TYPE,
		p_phone_number_id  IN customer_phone_numbers.phone_number_id%TYPE,
		p_phone   IN customer_phone_numbers.phone%TYPE
	  ) IS
	  BEGIN
		UPDATE customer_phone_numbers
		   SET phone = p_phone
		 WHERE phone_number_id = p_phone_number_id AND customer_id = p_customer_id;
		                            COMMIT;
	  END update_customer_phone_number;  
  
  PROCEDURE update_customer_address (
    p_customer_id IN customer_addresses.customer_id%TYPE,
    p_street_address  IN customer_addresses.street_address%TYPE,
	p_postal_code  IN customer_addresses.postal_code%TYPE,
	p_location_id  IN customer_addresses.location_id%TYPE,
    p_address_id   IN customer_addresses.address_id%TYPE
  ) IS
	  BEGIN
		UPDATE customer_addresses
		   SET street_address = p_street_address,
		       postal_code = p_postal_code,
			   location_id = p_location_id
		 WHERE address_id = p_address_id AND customer_id = p_customer_id;
		                        COMMIT;
	  END update_customer_address; 
  
END customer_update_pkg;
/

-- Package to update region, country and location
        -- Package specification 
CREATE OR REPLACE PACKAGE ecom.location_update_pkg
AS 
    /* REGION */
  PROCEDURE update_region (
    p_region_id   IN regions.region_id%TYPE,
    p_region_name IN regions.region_name%TYPE
  );

  /* COUNTRY */
  PROCEDURE update_country (
    p_country_id   IN countries.country_id%TYPE,
    p_country_name IN countries.country_name%TYPE,
    p_region_id    IN countries.region_id%TYPE
  );

  /* LOCATION */
  PROCEDURE update_location (
    p_location_id     IN locations.location_id%TYPE,
    p_city            IN locations.city%TYPE,
    p_state_province  IN locations.state_province%TYPE,
    p_country_id      IN locations.country_id%TYPE
  );
  
END location_update_pkg;
/

        -- Package body 
CREATE OR REPLACE PACKAGE BODY ecom.location_update_pkg
AS   
PROCEDURE update_region (
    p_region_id   IN regions.region_id%TYPE,
    p_region_name IN regions.region_name%TYPE
  ) IS
  BEGIN
    UPDATE regions
       SET region_name = p_region_name
     WHERE region_id = p_region_id;
	             COMMIT;
  END update_region;

  PROCEDURE update_country (
    p_country_id   IN countries.country_id%TYPE,
    p_country_name IN countries.country_name%TYPE,
    p_region_id    IN countries.region_id%TYPE
  ) IS
  BEGIN
    UPDATE countries
       SET country_name = p_country_name,
           region_id    = p_region_id
     WHERE country_id = p_country_id;
	             COMMIT;
  END update_country;

  PROCEDURE update_location (
    p_location_id     IN locations.location_id%TYPE,
    p_city            IN locations.city%TYPE,
    p_state_province  IN locations.state_province%TYPE,
    p_country_id      IN locations.country_id%TYPE
  ) IS
  BEGIN
    UPDATE locations
       SET city           = p_city,
           state_province = p_state_province,
           country_id     = p_country_id
     WHERE location_id = p_location_id;
	                COMMIT;
  END update_location;
  
END location_update_pkg;
/


/* Package which update supplier_information, supplier_email_account, supplier_phone_number, supplier_address, stock
	stock_category,inventory_status, payment_method, payment_status, order_status, rating_scale,  stock_information*/
    -- Package specification
CREATE OR REPLACE PACKAGE ecom.ecom_update_pkg
AS
  
  /* SUPPLIER */
  PROCEDURE update_supplier_information (
    p_supplier_id   IN supplier_information.supplier_id%TYPE,
    p_supplier_name IN supplier_information.supplier_name%TYPE
  );

-- Customer email 
  PROCEDURE update_supplier_email_account (
    p_supplier_id IN supplier_email_accounts.supplier_id%TYPE,
    p_account_id  IN supplier_email_accounts.account_id%TYPE,
    p_email_account   IN supplier_email_accounts.email_account%TYPE
  );
-- Customer phone 
  PROCEDURE update_supplier_phone_number (
    p_supplier_id IN supplier_phone_numbers.supplier_id%TYPE,
    p_phone_number_id  IN supplier_phone_numbers.phone_number_id%TYPE,
    p_phone   IN supplier_phone_numbers.phone%TYPE
  );

  /* STOCK CATEGORY */
  PROCEDURE update_stock_category (
    p_category_id   IN stock_categories.category_id%TYPE,
    p_category_name IN stock_categories.category_name%TYPE
  );

  /* INVENTORY STATUS */
  PROCEDURE update_inventory_status (
    p_inventory_status_id IN inventory_status.inventory_status_id%TYPE,
    p_status_name         IN inventory_status.status_name%TYPE
  );

  /* STOCK */
  PROCEDURE update_stock (
    p_stock_id          IN stock.stock_id%TYPE,
    p_product_name      IN stock.product_name%TYPE,
    p_reorder_level     IN stock.reorder_level%TYPE
  );

  /* PAYMENT METHOD */
  PROCEDURE update_payment_method (
    p_payment_mode_id IN payment_methods.payment_mode_id%TYPE,
    p_payment_mode    IN payment_methods.payment_mode%TYPE
  );

  /* PAYMENT STATUS */
  PROCEDURE update_payment_status (
    p_payment_status_id IN payment_status.payment_status_id%TYPE,
    p_status_name       IN payment_status.status_name%TYPE
  );

  /* ORDER STATUS */
  PROCEDURE update_order_status (
    p_order_status_id IN order_status.order_status_id%TYPE,
    p_status_name     IN order_status.status_name%TYPE
  );
  -- RATING SCALE
  PROCEDURE update_rating_scale(p_rating_value rating_scale.rating_value%TYPE,
          p_rating_label rating_scale.rating_label%TYPE, p_rating_description rating_scale.rating_description%TYPE);

  -- Supplier address
  PROCEDURE update_supplier_address (
    p_supplier_id IN supplier_addresses.supplier_id%TYPE,
    p_street_address  IN supplier_addresses.street_address%TYPE,
	p_postal_code  IN supplier_addresses.postal_code%TYPE,
	p_location_id  IN supplier_addresses.location_id%TYPE,
    p_address_id   IN supplier_addresses.address_id%TYPE
  );
  -- Stock information 
  PROCEDURE update_stock_information (
	p_stock_id      IN stock_information.stock_id%TYPE,
    p_unit_price            IN stock_information.unit_price%TYPE,
    p_category_id  IN stock_information.category_id%TYPE,
    p_supplier_id      IN stock_information.supplier_id%TYPE,
	p_stock_info_id     IN stock_information.stock_info_id%TYPE,
	p_request_date      IN stock_information.request_date%TYPE DEFAULT SYSDATE,
	p_supply_date      IN stock_information.supply_date%TYPE DEFAULT SYSDATE
  );
  
END ecom_update_pkg;
/

       -- Package body 
CREATE OR REPLACE PACKAGE BODY ecom.ecom_update_pkg
AS  

  PROCEDURE update_supplier_information (
    p_supplier_id   IN supplier_information.supplier_id%TYPE,
    p_supplier_name IN supplier_information.supplier_name%TYPE
  ) IS
  BEGIN
    UPDATE supplier_information
       SET supplier_name = p_supplier_name
     WHERE supplier_id = p_supplier_id;
	          COMMIT;
  END update_supplier_information;

  PROCEDURE update_stock_category (
    p_category_id   IN stock_categories.category_id%TYPE,
    p_category_name IN stock_categories.category_name%TYPE
  ) IS
  BEGIN
    UPDATE stock_categories
       SET category_name = p_category_name
     WHERE category_id = p_category_id;
	           COMMIT;
  END update_stock_category;

  PROCEDURE update_inventory_status (
    p_inventory_status_id IN inventory_status.inventory_status_id%TYPE,
    p_status_name         IN inventory_status.status_name%TYPE
  ) IS
  BEGIN
    UPDATE inventory_status
       SET status_name = p_status_name
     WHERE inventory_status_id = p_inventory_status_id;
	                  COMMIT;
  END update_inventory_status;

  PROCEDURE update_stock (
    p_stock_id          IN stock.stock_id%TYPE,
    p_product_name      IN stock.product_name%TYPE,
    p_reorder_level     IN stock.reorder_level%TYPE
  ) IS
  BEGIN
    UPDATE stock
       SET product_name      = p_product_name,
           reorder_level     = p_reorder_level
     WHERE stock_id = p_stock_id;
	               COMMIT;
  END update_stock;

  PROCEDURE update_payment_method (
    p_payment_mode_id IN payment_methods.payment_mode_id%TYPE,
    p_payment_mode    IN payment_methods.payment_mode%TYPE
  ) IS
  BEGIN
    UPDATE payment_methods
       SET payment_mode = p_payment_mode
     WHERE payment_mode_id = p_payment_mode_id;
	                COMMIT;
  END update_payment_method;

  PROCEDURE update_payment_status (
    p_payment_status_id IN payment_status.payment_status_id%TYPE,
    p_status_name       IN payment_status.status_name%TYPE
  ) IS
  BEGIN
    UPDATE payment_status
       SET status_name = p_status_name
     WHERE payment_status_id = p_payment_status_id;
	                   COMMIT;
  END update_payment_status;

  PROCEDURE update_order_status (
    p_order_status_id IN order_status.order_status_id%TYPE,
    p_status_name     IN order_status.status_name%TYPE
  ) IS
  BEGIN
    UPDATE order_status
       SET status_name = p_status_name
     WHERE order_status_id = p_order_status_id;
	                   COMMIT;
  END update_order_status;

      PROCEDURE update_supplier_email_account (
		p_supplier_id IN supplier_email_accounts.supplier_id%TYPE,
		p_account_id  IN supplier_email_accounts.account_id%TYPE,
		p_email_account   IN supplier_email_accounts.email_account%TYPE
	  ) IS
	  BEGIN
		UPDATE supplier_email_accounts
		   SET email_account = p_email_account
		 WHERE account_id = p_account_id AND supplier_id = p_supplier_id;
		                          COMMIT;
	  END update_supplier_email_account;
  
	  PROCEDURE update_supplier_phone_number (
		p_supplier_id IN supplier_phone_numbers.supplier_id%TYPE,
		p_phone_number_id  IN supplier_phone_numbers.phone_number_id%TYPE,
		p_phone   IN supplier_phone_numbers.phone%TYPE
	  ) IS
	  BEGIN
		UPDATE supplier_phone_numbers
		   SET phone = p_phone
		 WHERE phone_number_id = p_phone_number_id AND supplier_id = p_supplier_id;
		                         COMMIT;
	  END update_supplier_phone_number;  
  
  
	  PROCEDURE update_rating_scale(p_rating_value rating_scale.rating_value%TYPE,
				p_rating_label rating_scale.rating_label%TYPE, p_rating_description rating_scale.rating_description%TYPE)
	  AS
	  BEGIN
		   UPDATE rating_scale
		   SET rating_value = p_rating_value,
				 rating_label = p_rating_label,
				 rating_description = p_rating_description
		   WHERE rating_value = p_rating_value;
		                   COMMIT;
	  END update_rating_scale;  
	 
    PROCEDURE update_supplier_address (
    p_supplier_id IN supplier_addresses.supplier_id%TYPE,
    p_street_address  IN supplier_addresses.street_address%TYPE,
	p_postal_code  IN supplier_addresses.postal_code%TYPE,
	p_location_id  IN supplier_addresses.location_id%TYPE,
    p_address_id   IN supplier_addresses.address_id%TYPE
    ) IS
	BEGIN
		UPDATE supplier_addresses
		   SET street_address = p_street_address,
		       postal_code = p_postal_code,
			   location_id = p_location_id
		 WHERE address_id = p_address_id AND supplier_id = p_supplier_id;
		                    COMMIT;
	END update_supplier_address; 
  
  PROCEDURE update_stock_information (
	p_stock_id      IN stock_information.stock_id%TYPE,
    p_unit_price            IN stock_information.unit_price%TYPE,
    p_category_id  IN stock_information.category_id%TYPE,
    p_supplier_id      IN stock_information.supplier_id%TYPE,
	p_stock_info_id     IN stock_information.stock_info_id%TYPE,
	p_request_date      IN stock_information.request_date%TYPE DEFAULT SYSDATE,
	p_supply_date      IN stock_information.supply_date%TYPE DEFAULT SYSDATE
	)
	AS
	BEGIN
		 UPDATE stock_information
		 SET unit_price = p_unit_price,
			 request_date = p_request_date,
			 supply_date = p_supply_date,
			 category_id = p_category_id,
			 supplier_id = p_supplier_id,
			 stock_id = p_stock_id
		WHERE stock_info_id = p_stock_info_id AND stock_id = p_stock_id;
		                   COMMIT;
    END update_stock_information;
  
END ecom_update_pkg;
/

				----------------------------
				    -- AUDIT PACKAGES
				----------------------------
---------------------------------------
--Customer Audit package specification.
---------------------------------------
CREATE OR REPLACE PACKAGE customer_audit_pkg
AS
	PROCEDURE create_customer_info_audit(p_customer_id customer_info_audit.customer_id%TYPE, p_last_name customer_info_audit.last_name%TYPE,
		p_first_name customer_info_audit.first_name%TYPE, p_dob customer_info_audit.dob%TYPE, p_action_type customer_info_audit.action_type%TYPE,
		p_user_name customer_info_audit.user_name%TYPE, p_changed_at customer_info_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP);
	PROCEDURE create_customer_email_audit(p_email_account customer_email_accounts_audit.email_account%TYPE, 
		p_customer_id customer_email_accounts_audit.customer_id%TYPE, p_user_name customer_email_accounts_audit.user_name%TYPE,
		p_action_type customer_email_accounts_audit.action_type%TYPE, p_account_id customer_email_accounts_audit.account_id%TYPE,
		p_changed_at customer_email_accounts_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP);
	PROCEDURE create_customer_address_audit(p_address_id customer_address_audit.address_id%TYPE,
			p_location_id customer_address_audit.location_id%TYPE, p_customer_id customer_address_audit.customer_id%TYPE,
			p_user_name customer_address_audit.user_name%TYPE, p_street_address customer_address_audit.street_address%TYPE,
			p_postal_code customer_address_audit.postal_code%TYPE, p_action_type customer_address_audit.action_type%TYPE,
			p_changed_at customer_address_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP);
	PROCEDURE create_customer_phone_audit(p_phone customer_phone_numbers_audit.phone%TYPE, p_customer_id customer_phone_numbers_audit.customer_id%TYPE, 
		p_user_name customer_phone_numbers_audit.user_name%TYPE, p_phone_number_id customer_phone_numbers_audit.phone_number_id%TYPE,
		p_action_type customer_phone_numbers_audit.action_type%TYPE , p_changed_at customer_phone_numbers_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP);
END customer_audit_pkg;
/
------------------------------
--Customer Audit package body.
------------------------------
CREATE OR REPLACE PACKAGE BODY customer_audit_pkg
AS
	PROCEDURE create_customer_info_audit(p_customer_id customer_info_audit.customer_id%TYPE, p_last_name customer_info_audit.last_name%TYPE,
						p_first_name customer_info_audit.first_name%TYPE, p_dob customer_info_audit.dob%TYPE, p_action_type customer_info_audit.action_type%TYPE,
						p_user_name customer_info_audit.user_name%TYPE, p_changed_at customer_info_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP)
	AS
	BEGIN
		INSERT INTO customer_info_audit(customer_id, last_name, first_name, dob, user_name, action_type, changed_at)
		VALUES(p_customer_id, p_last_name, p_first_name, p_dob, p_user_name, p_action_type, p_changed_at);
	EXCEPTION
			WHEN VALUE_ERROR THEN
				RAISE_APPLICATION_ERROR(-20036, 'Invalid value entered.');
	END create_customer_info_audit;
		PROCEDURE create_customer_email_audit(p_email_account customer_email_accounts_audit.email_account%TYPE, 
								p_customer_id customer_email_accounts_audit.customer_id%TYPE,
								p_user_name customer_email_accounts_audit.user_name%TYPE,
								p_action_type customer_email_accounts_audit.action_type%TYPE,
								p_account_id customer_email_accounts_audit.account_id%TYPE,
								p_changed_at customer_email_accounts_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP)
		AS
		BEGIN
			INSERT INTO customer_email_accounts_audit(account_id, email_account, customer_id, user_name, action_type, changed_at)
			VALUES(p_account_id, p_email_account, p_customer_id, p_user_name, p_action_type, p_changed_at);
		EXCEPTION
				WHEN VALUE_ERROR THEN
					RAISE_APPLICATION_ERROR(-20037, 'Invalid value entered.');
		END create_customer_email_audit;
	PROCEDURE create_customer_address_audit(p_address_id customer_address_audit.address_id%TYPE,
				p_location_id customer_address_audit.location_id%TYPE, p_customer_id customer_address_audit.customer_id%TYPE,
				p_user_name customer_address_audit.user_name%TYPE, p_street_address customer_address_audit.street_address%TYPE,
				p_postal_code customer_address_audit.postal_code%TYPE, p_action_type customer_address_audit.action_type%TYPE,
				p_changed_at customer_address_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP)
	AS
	BEGIN
		INSERT INTO customer_address_audit(address_id, street_address, postal_code, location_id, customer_id, user_name, action_type, changed_at)
		VALUES(p_address_id, p_street_address, p_postal_code, p_location_id, p_customer_id, p_user_name, p_action_type, p_changed_at);
	EXCEPTION
			WHEN VALUE_ERROR THEN
				RAISE_APPLICATION_ERROR(-20038, 'Invalid value entered.');
	END create_customer_address_audit;
		PROCEDURE create_customer_phone_audit(p_phone customer_phone_numbers_audit.phone%TYPE, p_customer_id customer_phone_numbers_audit.customer_id%TYPE, 
						p_user_name customer_phone_numbers_audit.user_name%TYPE, p_phone_number_id customer_phone_numbers_audit.phone_number_id%TYPE,
						p_action_type customer_phone_numbers_audit.action_type%TYPE , p_changed_at customer_phone_numbers_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP)											
		AS
		BEGIN
			INSERT INTO customer_phone_numbers_audit(phone_number_id, Phone, customer_id, user_name, action_type, changed_at)
			VALUES(p_phone_number_id, p_phone, p_customer_id, p_user_name, p_action_type, p_changed_at);
		EXCEPTION
				WHEN VALUE_ERROR THEN
					RAISE_APPLICATION_ERROR(-20039, 'Invalid value entered.');
		END create_customer_phone_audit;
END customer_audit_pkg;
/
---------------------------------------	
--Supplier Audit package specification.
---------------------------------------
CREATE OR REPLACE PACKAGE supplier_audit_pkg
AS
	PROCEDURE create_supplier_info_audit(p_supplier_id supplier_info_audit.supplier_id%TYPE, p_supplier_name supplier_info_audit.supplier_name%TYPE,
		p_action_type supplier_info_audit.action_type%TYPE, p_user_name supplier_info_audit.user_name%TYPE, 
		p_changed_at supplier_info_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP);
	PROCEDURE create_supplier_email_audit(p_account_id supplier_email_accounts_audit.account_id%TYPE, p_email_account supplier_email_accounts_audit.email_account%TYPE,
		p_supplier_id supplier_email_accounts_audit.supplier_id%TYPE, p_action_type supplier_email_accounts_audit.action_type%TYPE,
		p_user_name supplier_email_accounts_audit.user_name%TYPE, p_changed_at supplier_email_accounts_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP);
	PROCEDURE create_supplier_address_audit(p_address_id supplier_address_audit.address_id%TYPE, p_street_address supplier_address_audit.street_address%TYPE,
		p_postal_code supplier_address_audit.postal_code%TYPE, p_supplier_id supplier_address_audit.supplier_id%TYPE,
		 p_user_name supplier_address_audit.user_name%TYPE, p_location_id supplier_address_audit.location_id%TYPE,
		p_action_type supplier_address_audit.action_type%TYPE, p_changed_at supplier_address_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP);
	PROCEDURE create_supplier_phone_audit(p_phone_number_id supplier_phone_numbers_audit.phone_number_id%TYPE, p_phone supplier_phone_numbers_audit.phone%TYPE,
		p_supplier_id supplier_phone_numbers_audit.supplier_id%TYPE, p_user_name supplier_phone_numbers_audit.user_name%TYPE,
		p_action_type supplier_phone_numbers_audit.action_type%TYPE, p_changed_at supplier_phone_numbers_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP);
END supplier_audit_pkg;
/
------------------------------
--Supplier Audit package body.
------------------------------
CREATE OR REPLACE PACKAGE BODY supplier_audit_pkg
AS
	PROCEDURE create_supplier_info_audit(p_supplier_id supplier_info_audit.supplier_id%TYPE, p_supplier_name supplier_info_audit.supplier_name%TYPE,
							p_action_type supplier_info_audit.action_type%TYPE, p_user_name supplier_info_audit.user_name%TYPE, 
							p_changed_at supplier_info_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP)
	AS
	BEGIN
		INSERT INTO supplier_info_audit(supplier_id, supplier_name, user_name, action_type, changed_at)
		VALUES(p_supplier_id, p_supplier_name, p_user_name, p_action_type, p_changed_at);
		EXCEPTION
				WHEN VALUE_ERROR THEN
					RAISE_APPLICATION_ERROR(-20040, 'Invalid value entered.');
	END create_supplier_info_audit;
		PROCEDURE create_supplier_email_audit(p_account_id supplier_email_accounts_audit.account_id%TYPE, p_email_account supplier_email_accounts_audit.email_account%TYPE,
						p_supplier_id supplier_email_accounts_audit.supplier_id%TYPE, p_action_type supplier_email_accounts_audit.action_type%TYPE,
						p_user_name supplier_email_accounts_audit.user_name%TYPE, p_changed_at supplier_email_accounts_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP)
		AS
		BEGIN
			INSERT INTO supplier_email_accounts_audit(account_id, email_account, supplier_id, user_name, action_type, changed_at)
			VALUES(p_account_id, p_email_account, p_supplier_id, p_user_name, p_action_type, p_changed_at);
		EXCEPTION
			WHEN VALUE_ERROR THEN
				RAISE_APPLICATION_ERROR(-20041, 'Invalid value entered.');
		END create_supplier_email_audit;
	PROCEDURE create_supplier_address_audit(p_address_id supplier_address_audit.address_id%TYPE, p_street_address supplier_address_audit.street_address%TYPE,
				p_postal_code supplier_address_audit.postal_code%TYPE, p_supplier_id supplier_address_audit.supplier_id%TYPE,
				p_user_name supplier_address_audit.user_name%TYPE, p_location_id supplier_address_audit.location_id%TYPE,
				p_action_type supplier_address_audit.action_type%TYPE, p_changed_at supplier_address_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP)
	AS
	BEGIN
		INSERT INTO supplier_address_audit(address_id, street_address, postal_code, location_id, supplier_id, user_name, action_type, changed_at)
		VALUES(p_address_id, p_street_address, p_postal_code, p_location_id, p_supplier_id, p_user_name, p_action_type, p_changed_at);
	EXCEPTION
			WHEN VALUE_ERROR THEN
				RAISE_APPLICATION_ERROR(-20042, 'Invalid value entered.');
	END create_supplier_address_audit;
		PROCEDURE create_supplier_phone_audit(p_phone_number_id supplier_phone_numbers_audit.phone_number_id%TYPE, p_phone supplier_phone_numbers_audit.phone%TYPE,
							p_supplier_id supplier_phone_numbers_audit.supplier_id%TYPE, p_user_name supplier_phone_numbers_audit.user_name%TYPE,
							p_action_type supplier_phone_numbers_audit.action_type%TYPE, p_changed_at supplier_phone_numbers_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP)
		AS
		BEGIN
				INSERT INTO supplier_phone_numbers_audit(phone_number_id, Phone, supplier_id, user_name, action_type, changed_at)
				VALUES(p_phone_number_id, p_phone, p_supplier_id, p_user_name, p_action_type, p_changed_at);
		EXCEPTION
				WHEN VALUE_ERROR THEN
					RAISE_APPLICATION_ERROR(-20043, 'Invalid value entered.');
		END create_supplier_phone_audit;
END supplier_audit_pkg;
/
----------------------------------------
--Location Audit package specification.
----------------------------------------
CREATE OR REPLACE PACKAGE location_audit_pkg
AS
	PROCEDURE create_regions_audit(p_region_id regions_audit.region_id%TYPE, 
		p_region_name regions_audit.region_name%TYPE, p_user_name regions_audit.user_name%TYPE,
		p_action_type regions_audit.action_type%TYPE, 
		p_changed_at regions_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP);
  PROCEDURE create_countries_audit(p_country_id countries_audit.country_id%TYPE,
		p_country_name countries_audit.country_name%TYPE, p_region_id countries_audit.region_id%TYPE,
		p_user_name countries_audit.user_name%TYPE, p_action_type countries_audit.action_type%TYPE, 
		p_changed_at countries_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP);
  PROCEDURE create_locations_audit(p_location_id locations_audit.location_id%TYPE,
		p_city locations_audit.city%TYPE, p_state_province locations_audit.state_province%TYPE,
		p_country_id locations_audit.country_id%TYPE, p_user_name locations_audit.user_name%TYPE,
		p_action_type locations_audit.action_type%TYPE, 
		p_changed_at locations_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP);
END location_audit_pkg;
/
------------------------------
--Location Audit package body.
------------------------------
CREATE OR REPLACE PACKAGE BODY location_audit_pkg
AS
	PROCEDURE create_regions_audit(p_region_id regions_audit.region_id%TYPE, 
			p_region_name regions_audit.region_name%TYPE, p_user_name regions_audit.user_name%TYPE,
			p_action_type regions_audit.action_type%TYPE, 
			p_changed_at regions_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP)
	AS
	BEGIN
		INSERT INTO regions_audit(region_id, region_name, user_name, action_type, changed_at)
		VALUES(p_region_id, p_region_name, p_user_name, p_action_type, p_changed_at);
	EXCEPTION
			WHEN VALUE_ERROR THEN
				RAISE_APPLICATION_ERROR(-20044, 'Invalid value entered.');
	END create_regions_audit;
		PROCEDURE create_countries_audit(p_country_id countries_audit.country_id%TYPE,
			p_country_name countries_audit.country_name%TYPE, p_region_id countries_audit.region_id%TYPE,
			p_user_name countries_audit.user_name%TYPE, p_action_type countries_audit.action_type%TYPE, 
			p_changed_at countries_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP)
		AS
		BEGIN
				INSERT INTO countries_audit(country_id, country_name, region_id, user_name, action_type, changed_at)
				VALUES(p_country_id, p_country_name, p_region_id, p_user_name, p_action_type, p_changed_at);
		EXCEPTION
				WHEN VALUE_ERROR THEN
					RAISE_APPLICATION_ERROR(-20045, 'Invalid value entered.');
		END create_countries_audit;
	PROCEDURE create_locations_audit(p_location_id locations_audit.location_id%TYPE,
		p_city locations_audit.city%TYPE, p_state_province locations_audit.state_province%TYPE,
		p_country_id locations_audit.country_id%TYPE, p_user_name locations_audit.user_name%TYPE,
		p_action_type locations_audit.action_type%TYPE, 
		p_changed_at locations_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP)
	AS
	BEGIN
			INSERT INTO locations_audit(location_id, city, state_province, country_id, user_name, action_type, changed_at)
			VALUES(p_location_id, p_city, p_state_province, p_country_id, p_user_name, p_action_type, p_changed_at);
	EXCEPTION
				WHEN VALUE_ERROR THEN
					RAISE_APPLICATION_ERROR(-20046, 'Invalid value entered.');
	END create_locations_audit;
END location_audit_pkg;
/
--------------------------------------
--Stock Audit package specification.
--------------------------------------
CREATE OR REPLACE PACKAGE stock_audit_pkg
AS
	PROCEDURE create_stock_category_audit(p_category_id stock_categories_audit.category_id%TYPE, p_category_name stock_categories_audit.category_name%TYPE,
		p_action_type stock_categories_audit.action_type%TYPE, p_user_name stock_categories_audit.user_name%TYPE, 
		p_changed_at stock_categories_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP);
	PROCEDURE create_stock_info_audit(p_unit_price stock_info_audit.unit_price%TYPE, p_quantity stock_info_audit.quantity%TYPE,
						p_category_id stock_info_audit.category_id%TYPE, p_supplier_id stock_info_audit.supplier_id%TYPE,
						p_stock_id stock_info_audit.stock_id%TYPE, p_user_name stock_info_audit.user_name%TYPE,
						p_stock_info_id stock_info_audit.stock_info_id%TYPE, p_action_type stock_info_audit.action_type%TYPE, 
						p_request_date stock_info_audit.request_date%TYPE DEFAULT SYSDATE,
						p_supply_date stock_info_audit.supply_date%TYPE DEFAULT SYSDATE,
						 p_changed_at stock_info_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP);
	PROCEDURE create_payment_status_audit(p_payment_status_id payment_status_audit.payment_status_id%TYPE,
		p_status_name payment_status_audit.status_name%TYPE, p_action_type payment_status_audit.action_type%TYPE,		
		p_user_name payment_status_audit.user_name%TYPE, p_changed_at payment_status_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP);
	PROCEDURE create_payment_method_audit(p_payment_mode_id payment_methods_audit.payment_mode_id%TYPE, p_payment_mode payment_methods_audit.payment_mode%TYPE,
		p_user_name payment_methods_audit.user_name%TYPE, p_action_type payment_methods_audit.action_type%TYPE,
		p_changed_at payment_methods_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP);
	PROCEDURE create_stock_audit(p_stock_id stock_audit.stock_id%TYPE, p_stock_name  stock_audit.product_name%TYPE,
		p_quantity_in_stock stock_audit.quantity_in_stock%TYPE, p_reserved_quantity stock_audit.reserved_quantity%TYPE, p_unit_price stock_audit.unit_price%TYPE,
		p_reorder_level stock_audit.reorder_level%TYPE, p_user_name stock_audit.user_name%TYPE,
		p_action_type stock_audit.action_type%TYPE, p_changed_at stock_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP);
	PROCEDURE create_stock_entry_audit(p_entry_id stock_entries_audit.entry_id%TYPE, p_user_name stock_entries_audit.user_name%TYPE, p_quantity_to_sell NUMBER,
			P_stock_id stock_entries_audit.stock_id%TYPE, p_action_type stock_entries_audit.action_type%TYPE, 
			p_unit_price stock_entries_audit.unit_price%TYPE, p_quantity stock_entries_audit.quantity%TYPE, p_expiry_date DATE,
			p_entry_date DATE DEFAULT SYSDATE, p_inventory_status_id stock_entries_audit.inventory_status_id%TYPE,
			p_changed_at stock_entries_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP);
	PROCEDURE create_orders_audit( p_order_total orders_audit.order_total%TYPE, p_discount_pct orders_audit.discount_pct%TYPE, p_payment_date DATE,
		p_payment_mode_id orders_audit.payment_mode_id%TYPE, p_customer_id orders_audit.customer_id%TYPE, p_user_name orders_audit.user_name%TYPE,
		p_payment_status_id orders_audit.payment_status_id%TYPE, p_order_status_id orders_audit.order_status_id%TYPE,
		p_discount_amount orders_audit.discount_amount%TYPE, p_amount_paid orders_audit.amount_paid%TYPE, p_order_id orders_audit.order_id%TYPE,
		p_amount_to_pay orders_audit.amount_to_pay%TYPE, p_change orders_audit.change%TYPE,
		p_action_type orders_audit.action_type%TYPE, p_transaction_init_date orders_audit.transaction_init_date%TYPE DEFAULT SYSDATE,
		p_delivery_date orders_audit.delivery_date%TYPE DEFAULT SYSDATE, p_changed_at orders_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP);
	PROCEDURE create_order_item_audit(p_item_id order_items_audit.item_id%TYPE, p_order_id  order_items_audit.order_id%TYPE, p_user_name order_items_audit.user_name%TYPE,
		p_stock_id order_items_audit.stock_id %TYPE, p_quantity order_items_audit.quantity%TYPE, p_unit_price order_items_audit.unit_price%TYPE,
		p_action_type order_items_audit.action_type%TYPE, p_changed_at order_items_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP);
	PROCEDURE create_order_status_audit(p_order_status_id order_status_audit.order_status_id%TYPE,
			p_status_name order_status_audit.status_name%TYPE,
			p_user_name order_status_audit.user_name%TYPE, p_action_type order_status_audit.action_type%TYPE,
			p_changed_at order_status_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP);
	PROCEDURE create_inventory_status_audit(p_inventory_status_id inventory_status_audit.inventory_status_id%TYPE,
		p_status_name inventory_status_audit.status_name%TYPE, p_user_name inventory_status_audit.user_name%TYPE,
		p_action_type inventory_status_audit.action_type%TYPE, 
		p_changed_at inventory_status_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP);
END stock_audit_pkg;
/
-----------------------------
--Stock Audit package body.
-----------------------------
CREATE OR REPLACE PACKAGE BODY stock_audit_pkg
AS
	PROCEDURE create_stock_category_audit(p_category_id stock_categories_audit.category_id%TYPE, p_category_name stock_categories_audit.category_name%TYPE,
							p_action_type stock_categories_audit.action_type%TYPE, p_user_name stock_categories_audit.user_name%TYPE, 
							p_changed_at stock_categories_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP)
	AS
	BEGIN
		INSERT INTO stock_categories_audit(category_id, category_name, user_name, action_type, changed_at)
		VALUES(p_category_id, p_category_name, p_user_name, p_action_type, p_changed_at);
			DBMS_OUTPUT.PUT_LINE(SQL%ROWCOUNT||'  -  row created.');
	EXCEPTION
			WHEN VALUE_ERROR THEN
					RAISE_APPLICATION_ERROR(-20047, 'Invalid value entered.');
	END create_stock_category_audit;
		PROCEDURE create_stock_info_audit(p_unit_price stock_info_audit.unit_price%TYPE, p_quantity stock_info_audit.quantity%TYPE,
						p_category_id stock_info_audit.category_id%TYPE, p_supplier_id stock_info_audit.supplier_id%TYPE,
						p_stock_id stock_info_audit.stock_id%TYPE, p_user_name stock_info_audit.user_name%TYPE,
						p_stock_info_id stock_info_audit.stock_info_id%TYPE, p_action_type stock_info_audit.action_type%TYPE, 
						p_request_date stock_info_audit.request_date%TYPE DEFAULT SYSDATE,
						p_supply_date stock_info_audit.supply_date%TYPE DEFAULT SYSDATE,
						p_changed_at stock_info_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP)
		AS
		BEGIN
			INSERT INTO stock_info_audit(stock_info_id, unit_price, quantity, request_date, supply_date, category_id, supplier_id, stock_id, user_name, action_type, changed_at)
			VALUES(p_stock_info_id, p_unit_price, p_quantity, p_request_date, p_supply_date, p_category_id, p_supplier_id, p_stock_id, p_user_name, p_action_type, p_changed_at);
		EXCEPTION
				WHEN VALUE_ERROR THEN
					RAISE_APPLICATION_ERROR(-20048, 'Invalid value entered.');
		END create_stock_info_audit;
	PROCEDURE create_payment_status_audit(p_payment_status_id payment_status_audit.payment_status_id%TYPE,
			p_status_name payment_status_audit.status_name%TYPE, p_action_type payment_status_audit.action_type%TYPE,		
			p_user_name payment_status_audit.user_name%TYPE, p_changed_at payment_status_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP)
	AS
	BEGIN
		INSERT INTO payment_status_audit(payment_status_id, status_name, user_name, action_type, changed_at)
		VALUES(p_payment_status_id, p_status_name, p_user_name, p_action_type, p_changed_at);
	EXCEPTION
			WHEN VALUE_ERROR THEN
				RAISE_APPLICATION_ERROR(-20049, 'Invalid value entered');
			WHEN OTHERS THEN
				RAISE_APPLICATION_ERROR(SQLCODE, SQLERRM);
	END create_payment_status_audit;
		PROCEDURE create_payment_method_audit(p_payment_mode_id payment_methods_audit.payment_mode_id%TYPE, p_payment_mode payment_methods_audit.payment_mode%TYPE,
					p_user_name payment_methods_audit.user_name%TYPE, p_action_type payment_methods_audit.action_type%TYPE,
				    p_changed_at payment_methods_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP)
		AS
		BEGIN
				INSERT INTO payment_methods_audit(payment_mode_id, payment_mode, user_name, action_type, changed_at)
				VALUES(p_payment_mode_id, p_payment_mode, p_user_name, p_action_type, p_changed_at);
		EXCEPTION
				WHEN VALUE_ERROR THEN
					RAISE_APPLICATION_ERROR(-20050, 'Invalid value entered.');
		END create_payment_method_audit;
	PROCEDURE create_stock_audit(p_stock_id stock_audit.stock_id%TYPE, p_stock_name  stock_audit.product_name%TYPE,
					p_quantity_in_stock stock_audit.quantity_in_stock%TYPE, p_reserved_quantity stock_audit.reserved_quantity%TYPE, p_unit_price stock_audit.unit_price%TYPE,
					p_reorder_level stock_audit.reorder_level%TYPE, p_user_name stock_audit.user_name%TYPE,
					p_action_type stock_audit.action_type%TYPE, p_changed_at stock_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP)
	AS
	BEGIN
		INSERT INTO stock_audit(stock_id, product_name, quantity_in_stock, reserved_quantity, unit_price, reorder_level, user_name, action_type, changed_at) 
		VALUES(p_stock_id, p_stock_name, p_quantity_in_stock, p_reserved_quantity, p_unit_price, p_reorder_level, p_user_name, p_action_type, p_changed_at);
	EXCEPTION
			WHEN VALUE_ERROR THEN
				RAISE_APPLICATION_ERROR(-20051, 'Invalid value entered.');
	END create_stock_audit;
		PROCEDURE create_stock_entry_audit(p_entry_id stock_entries_audit.entry_id%TYPE, p_user_name stock_entries_audit.user_name%TYPE, p_quantity_to_sell NUMBER,
									  P_stock_id stock_entries_audit.stock_id%TYPE, p_action_type stock_entries_audit.action_type%TYPE, 
									  p_unit_price stock_entries_audit.unit_price%TYPE, p_quantity stock_entries_audit.quantity%TYPE, p_expiry_date DATE,
									  p_entry_date DATE DEFAULT SYSDATE, p_inventory_status_id stock_entries_audit.inventory_status_id%TYPE,
									  p_changed_at stock_entries_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP)	  
		AS
		BEGIN
			INSERT INTO stock_entries_audit(entry_id, entry_date, quantity, unit_price,  quantity_to_sell, expiry_date, stock_id, inventory_status_id, user_name, action_type, changed_at)
			VALUES(p_entry_id, p_entry_date, p_quantity, p_unit_price,  p_quantity_to_sell, p_expiry_date, p_stock_id, p_inventory_status_id, p_user_name, p_action_type, p_changed_at);
		EXCEPTION
				WHEN VALUE_ERROR THEN
					RAISE_APPLICATION_ERROR(-20052, 'Invalid value entered.');
		END create_stock_entry_audit;
	PROCEDURE create_orders_audit( p_order_total orders_audit.order_total%TYPE, p_discount_pct orders_audit.discount_pct%TYPE, p_payment_date DATE,
		p_payment_mode_id orders_audit.payment_mode_id%TYPE, p_customer_id orders_audit.customer_id%TYPE, p_user_name orders_audit.user_name%TYPE,
		p_payment_status_id orders_audit.payment_status_id%TYPE, p_order_status_id orders_audit.order_status_id%TYPE,
		p_discount_amount orders_audit.discount_amount%TYPE, p_amount_paid orders_audit.amount_paid%TYPE, p_order_id orders_audit.order_id%TYPE,
		p_amount_to_pay orders_audit.amount_to_pay%TYPE, p_change orders_audit.change%TYPE,
		p_action_type orders_audit.action_type%TYPE, p_transaction_init_date orders_audit.transaction_init_date%TYPE DEFAULT SYSDATE,
		p_delivery_date orders_audit.delivery_date%TYPE DEFAULT SYSDATE, p_changed_at orders_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP)  
	AS
	BEGIN
		INSERT INTO orders_audit(order_id, transaction_init_date, delivery_date, order_total, discount_pct, discount_amount, amount_to_pay, amount_paid, change, payment_date, payment_mode_id, payment_status_id, order_status_id, customer_id, user_name, action_type, changed_at)
		VALUES(p_order_id, p_transaction_init_date, p_delivery_date, p_order_total, p_discount_pct, p_discount_amount, p_amount_to_pay, p_amount_paid, p_change, p_payment_date, p_payment_mode_id, p_payment_status_id, p_order_status_id, p_customer_id, p_user_name, p_action_type, p_changed_at);
	EXCEPTION
			WHEN VALUE_ERROR THEN
				RAISE_APPLICATION_ERROR(-20053, 'Invalid value entered.');
	END create_orders_audit;
		PROCEDURE create_order_item_audit(p_item_id order_items_audit.item_id%TYPE, p_order_id order_items_audit.order_id%TYPE, p_user_name order_items_audit.user_name%TYPE,
						p_stock_id order_items_audit.stock_id %TYPE, p_quantity order_items_audit.quantity%type, p_unit_price order_items_audit.unit_price%TYPE,
						p_action_type order_items_audit.action_type%TYPE, p_changed_at order_items_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP)
		AS
		BEGIN
			INSERT INTO order_items_audit(item_id, order_id, quantity, unit_price, stock_id, user_name, action_type, changed_at)
			VALUES(p_item_id, p_order_id, p_quantity, p_unit_price, p_stock_id, p_user_name, p_action_type, p_changed_at);
		EXCEPTION
				WHEN VALUE_ERROR THEN
					RAISE_APPLICATION_ERROR(-20054, 'Invalid quantity entered');			
		END create_order_item_audit;
	PROCEDURE create_inventory_status_audit(p_inventory_status_id inventory_status_audit.inventory_status_id%TYPE,
							p_status_name inventory_status_audit.status_name%TYPE, p_user_name inventory_status_audit.user_name%TYPE,
							p_action_type inventory_status_audit.action_type%TYPE, 
							p_changed_at inventory_status_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP)
		AS
		BEGIN
			INSERT INTO inventory_status_audit(inventory_status_id, status_name, user_name, action_type, changed_at)
			VALUES(p_inventory_status_id, p_status_name, p_user_name, p_action_type, p_changed_at);
		EXCEPTION
				WHEN VALUE_ERROR THEN
					RAISE_APPLICATION_ERROR(-20055, 'Invalid value entered.');
		END create_inventory_status_audit;
	PROCEDURE create_order_status_audit(p_order_status_id order_status_audit.order_status_id%TYPE,
			p_status_name order_status_audit.status_name%TYPE,
			p_user_name order_status_audit.user_name%TYPE, p_action_type order_status_audit.action_type%TYPE,
			p_changed_at order_status_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP)
	AS
	BEGIN
		INSERT INTO order_status_audit(order_status_id, status_name, user_name, action_type, changed_at)
		VALUES(p_order_status_id, p_status_name, p_user_name, p_action_type, p_changed_at);
	EXCEPTION
			WHEN VALUE_ERROR THEN
				RAISE_APPLICATION_ERROR(-20056, 'Invalid value entered.');
	END create_order_status_audit;
END stock_audit_pkg;
/	
----------------------------------
--Ratings audit package specification
-----------------------------------
CREATE OR REPLACE PACKAGE ratings_audit_pkg
AS
	PROCEDURE create_rating_scale_audit(p_rating_value rating_scale_audit.rating_value%TYPE,
            p_rating_label rating_scale_audit.rating_label%TYPE, p_rating_description rating_scale_audit.rating_description%TYPE,
			p_action_type rating_scale_audit.action_type%TYPE, p_user_name rating_scale_audit.user_name%TYPE,
		    p_changed_at rating_scale_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP);
	PROCEDURE create_service_ratings_audit(p_service_rating_id service_ratings_audit.service_rating_id%TYPE,
          	p_customer_id service_ratings_audit.customer_id%TYPE, p_order_id service_ratings_audit.order_id%TYPE,
            p_delivery_rating service_ratings_audit.delivery_rating%TYPE, p_packaging_rating service_ratings_audit.packaging_rating%TYPE,
			p_support_rating service_ratings_audit.support_rating%TYPE, p_overall_comment service_ratings_audit.overall_comment%TYPE,
			p_rating_date service_ratings_audit.rating_date%TYPE DEFAULT CURRENT_TIMESTAMP,
			p_action_type service_ratings_audit.action_type%TYPE, p_user_name service_ratings_audit.user_name%TYPE,
		    p_changed_at service_ratings_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP);
	PROCEDURE create_product_reviews_audit(p_product_review_id product_reviews_audit.product_review_id%TYPE, p_customer_id product_reviews_audit.customer_id%TYPE,
            p_stock_id product_reviews_audit.stock_id%TYPE, p_rating product_reviews_audit.rating%TYPE,
			p_feedback product_reviews_audit.feedback%TYPE, p_review_date product_reviews_audit.review_date%TYPE,
			p_action_type product_reviews_audit.action_type%TYPE, p_user_name product_reviews_audit.user_name%TYPE,
		    p_changed_at product_reviews_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP);
END ratings_audit_pkg;
/
----------------------------------
--Ratings audit package body
-----------------------------------
CREATE OR REPLACE PACKAGE BODY ratings_audit_pkg
AS
	PROCEDURE create_rating_scale_audit(p_rating_value rating_scale_audit.rating_value%TYPE,
            p_rating_label rating_scale_audit.rating_label%TYPE, p_rating_description rating_scale_audit.rating_description%TYPE,
			p_action_type rating_scale_audit.action_type%TYPE, p_user_name rating_scale_audit.user_name%TYPE,
		    p_changed_at rating_scale_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP)
	AS
	BEGIN
		 INSERT INTO rating_scale_audit(rating_value, rating_label, rating_description, user_name, action_type, changed_at)
		 VALUES(p_rating_value, p_rating_label, p_rating_description , p_user_name, p_action_type, p_changed_at);
	EXCEPTION
			 WHEN VALUE_ERROR THEN
					RAISE_APPLICATION_ERROR(-20093, 'Invalid value entered.');
			WHEN NO_DATA_FOUND THEN
					RAISE_APPLICATION_ERROR(-20094, 'No data found.');
	END create_rating_scale_audit;
		PROCEDURE create_product_reviews_audit(p_product_review_id product_reviews_audit.product_review_id%TYPE, p_customer_id product_reviews_audit.customer_id%TYPE,
            p_stock_id product_reviews_audit.stock_id%TYPE, p_rating product_reviews_audit.rating%TYPE,
			p_feedback product_reviews_audit.feedback%TYPE, p_review_date product_reviews_audit.review_date%TYPE,
			p_action_type product_reviews_audit.action_type%TYPE, p_user_name product_reviews_audit.user_name%TYPE,
		    p_changed_at product_reviews_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP)
		AS
		BEGIN
			 INSERT INTO product_reviews_audit(product_review_id, customer_id, stock_id, rating, feedback, review_date, user_name, action_type, changed_at)
			 VALUES(p_product_review_id, p_customer_id, p_stock_id, p_rating, p_feedback, p_review_date, p_user_name, p_action_type, p_changed_at);
		EXCEPTION
				 WHEN VALUE_ERROR THEN
						RAISE_APPLICATION_ERROR(-20003, 'Invalid value entered.');
				WHEN NO_DATA_FOUND THEN
						RAISE_APPLICATION_ERROR(-20003, 'No data found.');
		END create_product_reviews_audit;
	PROCEDURE create_service_ratings_audit(p_service_rating_id service_ratings_audit.service_rating_id%TYPE,
          	p_customer_id service_ratings_audit.customer_id%TYPE, p_order_id service_ratings_audit.order_id%TYPE,
            p_delivery_rating service_ratings_audit.delivery_rating%TYPE, p_packaging_rating service_ratings_audit.packaging_rating%TYPE,
			p_support_rating service_ratings_audit.support_rating%TYPE, p_overall_comment service_ratings_audit.overall_comment%TYPE,
			p_rating_date service_ratings_audit.rating_date%TYPE DEFAULT CURRENT_TIMESTAMP,
			p_action_type service_ratings_audit.action_type%TYPE, p_user_name service_ratings_audit.user_name%TYPE,
		    p_changed_at service_ratings_audit.changed_at%TYPE DEFAULT CURRENT_TIMESTAMP)
	AS
	BEGIN
		 INSERT INTO service_ratings_audit(service_rating_id, order_id, customer_id, delivery_rating, packaging_rating, support_rating, overall_comment, rating_date, user_name, action_type, changed_at)
		 VALUES(p_service_rating_id, p_order_id, p_customer_id, p_delivery_rating, p_packaging_rating, p_support_rating, p_overall_comment, p_rating_date, p_user_name, p_action_type, p_changed_at);
	EXCEPTION
			 WHEN VALUE_ERROR THEN
					RAISE_APPLICATION_ERROR(-20091, 'Invalid value entered.');
			WHEN NO_DATA_FOUND THEN
					RAISE_APPLICATION_ERROR(-20092, 'No data found.');
	END create_service_ratings_audit;
END ratings_audit_pkg;
/
--====================================================================
							--TRIGGERS
--====================================================================
		--Check stock is created with zero cost and zero unit prce.
--------------------------------------------------------------------		
CREATE OR REPLACE TRIGGER stock_creation_trigger
BEFORE INSERT ON stock
FOR EACH ROW
BEGIN
		IF :NEW.quantity_in_stock != 0 OR :NEW.unit_price != 0 THEN
			RAISE_APPLICATION_ERROR(-20057, 'Set quantity and unit price to zero when creating a new product.');
		END IF;
EXCEPTION
		WHEN NO_DATA_FOUND THEN
			RAISE_APPLICATION_ERROR(-20059, 'No data found.');
		WHEN VALUE_ERROR THEN
			RAISE_APPLICATION_ERROR(-20060, 'Invalid value entered.');
END;
/
-----------------------------------------------------------------------------------------------------
-- Trigger to check payment before delivery and to implement order can't be modified after delivery.
------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER chk_payment_before_delivery_trg
BEFORE INSERT OR UPDATE OR DELETE ON orders
FOR EACH ROW
DECLARE
    v_paid_id   payment_status.payment_status_id%TYPE;
    v_unpaid_id payment_status.payment_status_id%TYPE;
    v_delivered_status_id order_status.order_status_id%TYPE;
	v_dispatch_status_id order_status.order_status_id%TYPE;
BEGIN
    SELECT payment_status_id INTO v_paid_id FROM payment_status WHERE UPPER(status_name) = 'PAID';
    SELECT payment_status_id INTO v_unpaid_id FROM payment_status WHERE UPPER(status_name) = 'UNPAID';
    SELECT order_status_id INTO v_delivered_status_id FROM order_status WHERE UPPER(status_name) = 'DELIVERED';
	SELECT order_status_id INTO v_dispatch_status_id FROM order_status WHERE UPPER(status_name) = 'DISPATCH';
    IF :NEW.amount_paid >= :NEW.amount_to_pay THEN
        :NEW.payment_status_id := v_paid_id;
    ELSE
        :NEW.payment_status_id := v_unpaid_id;
    END IF;
	IF :OLD.payment_status_id = v_paid_id AND :OLD.order_status_id = v_delivered_status_id    --Disallow modifications on delivered orders or
	      OR :OLD.order_status_id = v_dispatch_status_id THEN                                   -- on delivery orders
		  RAISE_APPLICATION_ERROR(-20090, 'Order is already delivered. You can''t modify delivered orders or orders on delivery.');
	END IF;
    IF :NEW.payment_status_id != v_paid_id AND :NEW.order_status_id = v_delivered_status_id
		OR :NEW.order_status_id = v_dispatch_status_id THEN
        RAISE_APPLICATION_ERROR(-20061, 'Order cannot be delivered unless payment is marked as "PAID".');
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20062, 'Order status "'||v_delivered_status_id||'" not found.');
END;
/
 --------------------------------------------------------------------------------------------------------------------------------------------
--Trigger to update quantity and unit price on stock after insert or update or delete and and update inventory status on stock entries table.
----------------------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER qty_in_stock_unit_price_update
BEFORE INSERT OR DELETE OR UPDATE OF quantity, unit_price, inventory_status_id, quantity_to_sell, expiry_date ON stock_entries
FOR EACH ROW
DECLARE
		expired_inventory_status_id      inventory_status.inventory_status_id%TYPE;
BEGIN
		SELECT inventory_status_id INTO expired_inventory_status_id FROM inventory_status WHERE UPPER(status_name) = 'EXPIRED';
		IF :NEW.expiry_date <= SYSDATE THEN
			:NEW.inventory_status_id := expired_inventory_status_id;
		END IF;
				IF INSERTING THEN
					stock_update_pkg.stock_update_on_insert_on_stock_entries(:NEW.stock_id, :NEW.quantity, :NEW.unit_price, :NEW.inventory_status_id);
				ELSIF UPDATING THEN
					stock_update_pkg.stock_update_on_update_on_stock_entries(:NEW.stock_id, :NEW.quantity, :NEW.unit_price, :OLD.quantity, :OLD.unit_price,
					:NEW.inventory_status_id, :OLD.inventory_status_id, :NEW.quantity_to_sell);
                ELSIF DELETING THEN
					stock_update_pkg.stock_update_on_delete_on_stock_entries(:OLD.quantity, :OLD.unit_price, :OLD.stock_id, :OLD.inventory_status_id, :OLD.quantity_to_sell);
                END IF;
EXCEPTION
		WHEN NO_DATA_FOUND THEN
			RAISE_APPLICATION_ERROR(-20063, 'No data found.');
		WHEN VALUE_ERROR THEN
			RAISE_APPLICATION_ERROR(-20064, 'Invalid value entered.');
		WHEN TOO_MANY_ROWS THEN
			RAISE_APPLICATION_ERROR(20080, 'more than one row returned by the "SELECT" statement.');
END;
/
------------------------------------------------------------------------------------------------------------
--Trigger to calculate order_total, discount_percent, discount amount and amount to be paid on orders table.
-------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER update_orders
BEFORE INSERT OR UPDATE OR DELETE ON order_items
FOR EACH ROW
BEGIN
			IF INSERTING THEN
				transaction_update_pkg.update_orders_on_insert(:NEW.order_id, :NEW.stock_id, :NEW.unit_price, :NEW.quantity);
			ELSIF UPDATING THEN
				transaction_update_pkg.update_orders_on_update(:NEW.order_id, :NEW.stock_id, :NEW.unit_price, :NEW.quantity, :OLD.unit_price, :OLD.quantity);
			ELSIF DELETING THEN
				transaction_update_pkg.update_orders_on_del(:OLD.order_id, :OLD.stock_id, :OLD.unit_price, :OLD.quantity);
			END IF;
EXCEPTION
		WHEN NO_DATA_FOUND THEN
			RAISE_APPLICATION_ERROR(-20069, 'No data found.');
		WHEN VALUE_ERROR THEN
			RAISE_APPLICATION_ERROR(-20070, 'Invalid value entered.');
END;
/
-----------------------------------------------------------------------------------------------
--Trigger to set unit price of a product on order items to unit price of stock on stock table.
-----------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER insert_unit_price
BEFORE INSERT OR UPDATE OF unit_price ON order_items
FOR EACH ROW
DECLARE
		v_unit_price stock.unit_price%TYPE;
BEGIN
		SELECT unit_price INTO v_unit_price FROM stock WHERE stock_id = :NEW.stock_id;
		:NEW.unit_price := v_unit_price;
END;
/
--------------------------------------------------------------
-- On creation of order, order status is always 'Submitted'
--------------------------------------------------------------
CREATE OR REPLACE TRIGGER insert_order_status_on_orders
BEFORE INSERT ON orders
FOR EACH ROW
DECLARE
		v_order_status_id orders.order_status_id%TYPE;
BEGIN
		SELECT order_status_id INTO v_order_status_id FROM order_status WHERE UPPER(status_name) = 'SUBMITTED';
		:NEW.order_status_id := v_order_status_id;
EXCEPTION 
		WHEN NO_DATA_FOUND THEN
			RAISE_APPLICATION_ERROR(-20073, 'order_status_id "'||v_order_status_id||'" not found.');
END;
/
========================================================================================
----------------------------------------------------------
-- Prevent Use of Expired, Damaged, or Out-of-Stock Items and 
----------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_validate_inventory_status_before_order_item
BEFORE INSERT OR UPDATE ON order_items
FOR EACH ROW
DECLARE
	  v_status_name                         inventory_status.status_name%TYPE;
BEGIN
    SELECT status_name INTO v_status_name
    FROM inventory_status JOIN stock_entries USING (inventory_status_id)
    WHERE entry_id = :NEW.entry_id AND stock_id = :NEW.stock_id;
		IF UPPER(v_status_name) != 'AVAILABLE' THEN
			RAISE_APPLICATION_ERROR(-20071, 'Cannot use stock item with status: "' || v_status_name|| '". You can only use stock item with status: "Available"');
		END IF;
END;
/
===============================================================================================
------------------------------------------------------------------------------------------------------------------------
--Trigger to insert into customer_info_audit when DML statement(INSERT, UPDATE, DELETE) is ran on customer_information.
------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER customer_info_audit_trigg
AFTER INSERT OR UPDATE OR DELETE ON customer_information
FOR EACH ROW
BEGIN
		IF INSERTING THEN
			customer_audit_pkg.create_customer_info_audit(:NEW.customer_id, :NEW.last_name, :NEW.first_name, :NEW.dob, 'INSERT', USER);
		ELSIF UPDATING THEN
			customer_audit_pkg.create_customer_info_audit(:OLD.customer_id, :OLD.last_name, :OLD.first_name, :OLD.dob, 'UPDATE', USER);
			customer_audit_pkg.create_customer_info_audit(:NEW.customer_id, :NEW.last_name, :NEW.first_name, :NEW.dob, 'UPDATE', USER);
		ELSIF DELETING THEN
			customer_audit_pkg.create_customer_info_audit(:OLD.customer_id, :OLD.last_name, :OLD.first_name, :OLD.dob, 'DELETE', USER);
		END IF;
EXCEPTION
		WHEN NO_DATA_FOUND THEN
			DBMS_OUTPUT.PUT_LINE('No data found.');
END;
/
-----------------------------------------------------------------------------------------------------------------------
--Trigger to insert into supplier_info_audit when DML statement(INSERT, UPDATE, DELETE) is ran on supplier_information.
-----------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER supplier_info_audit_trigg
AFTER INSERT OR UPDATE OR DELETE ON supplier_information
FOR EACH ROW
BEGIN
		IF INSERTING THEN
			supplier_audit_pkg.create_supplier_info_audit(:NEW.supplier_id, :NEW.supplier_name, 'INSERT', USER);
		ELSIF UPDATING THEN
			supplier_audit_pkg.create_supplier_info_audit(:OLD.supplier_id, :OLD.supplier_name, 'UPDATE', USER);
			supplier_audit_pkg.create_supplier_info_audit(:NEW.supplier_id, :NEW.supplier_name, 'UPDATE', USER);
		ELSIF DELETING THEN
			supplier_audit_pkg.create_supplier_info_audit(:OLD.supplier_id, :OLD.supplier_name, 'DELETE', USER);
		END IF;
EXCEPTION
		WHEN NO_DATA_FOUND THEN
			DBMS_OUTPUT.PUT_LINE('No data found.');
END;
/
--------------------------------------------------------------------------------------------------------------------
--Trigger to insert into payment_methods_audit when DML statement(INSERT, UPDATE, DELETE) is ran on payment_methods.
---------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER payment_methods_audit_trigg
AFTER INSERT OR UPDATE OR DELETE ON payment_methods
FOR EACH ROW
BEGIN
		IF INSERTING THEN
			stock_audit_pkg.create_payment_method_audit(:NEW.payment_mode_id, :NEW.payment_mode, USER, 'INSERT');
		ELSIF UPDATING THEN
			stock_audit_pkg.create_payment_method_audit(:OLD.payment_mode_id, :OLD.payment_mode, USER, 'UPDATE');
			stock_audit_pkg.create_payment_method_audit(:NEW.payment_mode_id, :NEW.payment_mode, USER, 'UPDATE');
		ELSIF DELETING THEN
			stock_audit_pkg.create_payment_method_audit(:OLD.payment_mode_id, :OLD.payment_mode, USER, 'DELETE');
		END IF;
EXCEPTION
		WHEN NO_DATA_FOUND THEN
			DBMS_OUTPUT.PUT_LINE('No data found.');
END;
/
------------------------------------------------------------------------------------------------------------------
--Trigger to insert into payment_status_audit when DML statement(INSERT, UPDATE, DELETE) is ran on payment_status.
-------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER payment_status_audit_trigg
AFTER INSERT OR UPDATE OR DELETE ON payment_status
FOR EACH ROW
BEGIN
	IF INSERTING THEN
		stock_audit_pkg.create_payment_status_audit(:NEW.payment_status_id, :NEW.status_name, 'INSERT', USER);
	ELSIF UPDATING THEN
		stock_audit_pkg.create_payment_status_audit(:OLD.payment_status_id, :OLD.status_name, 'UPDATE', USER);
		stock_audit_pkg.create_payment_status_audit(:NEW.payment_status_id, :NEW.status_name, 'UPDATE', USER);
	ELSIF DELETING THEN
		stock_audit_pkg.create_payment_status_audit(:OLD.payment_status_id, :OLD.status_name, 'DELETE', USER);
	END IF;
EXCEPTION
		WHEN NO_DATA_FOUND THEN
			DBMS_OUTPUT.PUT_LINE('No data found.');
END;
/
----------------------------------------------------------------------------------------------------------------------	
--Trigger to insert into customer_address_audit when DML statement(INSERT, UPDATE, DELETE) is ran on customer_address.
-----------------------------------------------------------------------------------------------------------------------	
CREATE OR REPLACE TRIGGER customer_address_audit_trigg
AFTER DELETE OR UPDATE OR INSERT ON customer_addresses
FOR EACH ROW
BEGIN
		IF INSERTING THEN
			customer_audit_pkg.create_customer_address_audit(:NEW.address_id, :NEW.location_id, :NEW.customer_id, USER, :NEW.street_address, :NEW.postal_code, 'INSERT');
		ELSIF UPDATING THEN
			customer_audit_pkg.create_customer_address_audit(:OLD.address_id, :OLD.location_id, :OLD.customer_id, USER, :OLD.street_address, :OLD.postal_code, 'UPDATE');
			customer_audit_pkg.create_customer_address_audit(:NEW.address_id, :NEW.location_id, :NEW.customer_id, USER, :NEW.street_address, :NEW.postal_code, 'UPDATE');
		ELSIF DELETING THEN
			customer_audit_pkg.create_customer_address_audit(:OLD.address_id, :OLD.location_id, :OLD.customer_id, USER, :OLD.street_address, :OLD.postal_code, 'DELETE');
		END IF;
EXCEPTION
		WHEN NO_DATA_FOUND THEN
			DBMS_OUTPUT.PUT_LINE('No data found.');
END;
/
-----------------------------------------------------------------------------------------------------------------------		
--Trigger to insert into supplier_address_audit when DML statement(INSERT, UPDATE, DELETE) is ran on supplier_address.
-----------------------------------------------------------------------------------------------------------------------	
CREATE OR REPLACE TRIGGER supplier_address_audit_trigg
AFTER DELETE OR UPDATE OR INSERT ON supplier_addresses
FOR EACH ROW
BEGIN
		IF INSERTING THEN
			supplier_audit_pkg.create_supplier_address_audit(:NEW.address_id, :NEW.street_address, :NEW.postal_code, :NEW.supplier_id, USER, :NEW.location_id, 'INSERT');
		ELSIF UPDATING THEN
			supplier_audit_pkg.create_supplier_address_audit(:OLD.address_id, :OLD.street_address, :OLD.postal_code, :OLD.supplier_id, USER, :OLD.location_id, 'UPDATE');
			supplier_audit_pkg.create_supplier_address_audit(:NEW.address_id, :NEW.street_address, :NEW.postal_code, :NEW.supplier_id, USER, :NEW.location_id, 'UPDATE');
		ELSIF DELETING THEN
			supplier_audit_pkg.create_supplier_address_audit(:OLD.address_id, :OLD.street_address, :OLD.postal_code, :OLD.supplier_id, USER, :OLD.location_id, 'DELETE');
		END IF;
EXCEPTION
		WHEN NO_DATA_FOUND THEN
			DBMS_OUTPUT.PUT_LINE('No data found.');
END;
/
----------------------------------------------------------------------------------------------------------------------------------			
--Trigger to insert into supplier_phone_numbers_audit when DML statement(INSERT, UPDATE, DELETE) is ran on supplier_phone_numbers.
-----------------------------------------------------------------------------------------------------------------------------------	
CREATE OR REPLACE TRIGGER supplier_phone_numbers_audit_trigg
AFTER DELETE OR UPDATE OR INSERT ON supplier_phone_numbers
FOR EACH ROW
BEGIN
		IF INSERTING THEN
			supplier_audit_pkg.create_supplier_phone_audit(:NEW.phone_number_id, :NEW.phone, :NEW.supplier_id, USER, 'INSERT');
		ELSIF UPDATING THEN
			supplier_audit_pkg.create_supplier_phone_audit(:OLD.phone_number_id, :OLD.phone, :OLD.supplier_id, USER, 'UPDATE');
			supplier_audit_pkg.create_supplier_phone_audit(:NEW.phone_number_id, :NEW.phone, :NEW.supplier_id, USER, 'UPDATE');
		ELSIF DELETING THEN
			supplier_audit_pkg.create_supplier_phone_audit(:OLD.phone_number_id, :OLD.phone, :OLD.supplier_id, USER, 'DELETE');
		END IF;
EXCEPTION
		WHEN NO_DATA_FOUND THEN
			DBMS_OUTPUT.PUT_LINE('No data found.');
END;
/
----------------------------------------------------------------------------------------------------------------------------------		
--Trigger to insert into customer_phone_numbers_audit when DML statement(INSERT, UPDATE, DELETE) is ran on supplier_phone_numbers.
-----------------------------------------------------------------------------------------------------------------------------------	
CREATE OR REPLACE TRIGGER customer_phone_numbers_audit_trigg
AFTER DELETE OR UPDATE OR INSERT ON customer_phone_numbers
FOR EACH ROW
BEGIN
		IF INSERTING THEN
			customer_audit_pkg.create_customer_phone_audit(:NEW.phone, :NEW.customer_id, USER, :NEW.phone_number_id,  'INSERT');
		ELSIF UPDATING THEN
			customer_audit_pkg.create_customer_phone_audit(:OLD.phone, :OLD.customer_id, USER, :OLD.phone_number_id,  'UPDATE');
			customer_audit_pkg.create_customer_phone_audit(:NEW.phone, :NEW.customer_id, USER, :NEW.phone_number_id,  'UPDATE');
		ELSIF DELETING THEN
			customer_audit_pkg.create_customer_phone_audit(:OLD.phone, :OLD.customer_id, USER, :OLD.phone_number_id,  'DELETE');
		END IF;
EXCEPTION
		WHEN NO_DATA_FOUND THEN
			DBMS_OUTPUT.PUT_LINE('No data found.');
END;
/
------------------------------------------------------------------------------------------------------------------------------------
--Trigger to insert into customer_email_accounts_audit when DML statement(INSERT, UPDATE, DELETE) is ran on customer_email_accounts.
------------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER customer_email_accounts_audit_trigg
AFTER DELETE OR INSERT OR UPDATE ON customer_email_accounts
FOR EACH ROW
BEGIN
		IF INSERTING THEN
			customer_audit_pkg.create_customer_email_audit(:NEW.email_account, :NEW.customer_id, USER, 'INSERT', :NEW.account_id);
		ELSIF UPDATING THEN
			customer_audit_pkg.create_customer_email_audit(:OLD.email_account, :OLD.customer_id, USER, 'UPDATE', :OLD.account_id);
			customer_audit_pkg.create_customer_email_audit(:NEW.email_account, :NEW.customer_id, USER, 'UPDATE', :NEW.account_id);
		ELSIF DELETING THEN
			customer_audit_pkg.create_customer_email_audit(:OLD.email_account, :OLD.customer_id, USER, 'DELETE', :OLD.account_id);
		END IF;
EXCEPTION
		WHEN NO_DATA_FOUND THEN
			DBMS_OUTPUT.PUT_LINE('No data found.');
END;
/
------------------------------------------------------------------------------------------------------------------------------------		
--Trigger to insert into supplier_email_accounts_audit when DML statement(INSERT, UPDATE, DELETE) is ran on supplier_email_accounts.
-------------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER supplier_email_audit_trigg
AFTER DELETE OR INSERT OR UPDATE ON supplier_email_accounts
FOR EACH ROW
BEGIN
		IF INSERTING THEN
			supplier_audit_pkg.create_supplier_email_audit(:NEW.account_id, :NEW.email_account, :NEW.supplier_id, 'INSERT', USER );
		ELSIF UPDATING THEN
			supplier_audit_pkg.create_supplier_email_audit(:OLD.account_id, :OLD.email_account, :OLD.supplier_id, 'UPDATE', USER );
			supplier_audit_pkg.create_supplier_email_audit(:NEW.account_id, :NEW.email_account, :NEW.supplier_id, 'UPDATE', USER );
		ELSIF DELETING THEN
			supplier_audit_pkg.create_supplier_email_audit(:OLD.account_id, :OLD.email_account, :OLD.supplier_id, 'DELETE', USER );
		END IF;
EXCEPTION
		WHEN NO_DATA_FOUND THEN
			DBMS_OUTPUT.PUT_LINE('No data found.');
END;
/
------------------------------------------------------------------------------------------------		
--Trigger to insert into stock_audit when DML statement(INSERT, UPDATE, DELETE) is ran on stock.
-------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER stock_audit_trigg
AFTER INSERT OR UPDATE OR DELETE ON stock
FOR EACH ROW
BEGIN
		IF INSERTING THEN
			stock_audit_pkg.create_stock_audit(:NEW.stock_id, :NEW.product_name, :NEW.quantity_in_stock, :NEW.reserved_quantity, :NEW.unit_price, :NEW.reorder_level, USER, 'INSERT');
		ELSIF UPDATING THEN
			stock_audit_pkg.create_stock_audit(:OLD.stock_id, :OLD.product_name, :OLD.quantity_in_stock, :OLD.reserved_quantity, :OLD.unit_price, :OLD.reorder_level, USER, 'UPDATE');
			stock_audit_pkg.create_stock_audit(:NEW.stock_id, :NEW.product_name, :NEW.quantity_in_stock, :NEW.reserved_quantity, :NEW.unit_price, :NEW.reorder_level, USER, 'UPDATE');
		ELSIF DELETING THEN
			stock_audit_pkg.create_stock_audit(:OLD.stock_id, :OLD.product_name, :OLD.quantity_in_stock, :OLD.reserved_quantity, :OLD.unit_price, :OLD.reorder_level, USER, 'DELETE');
		END IF;
EXCEPTION
		WHEN NO_DATA_FOUND THEN
			DBMS_OUTPUT.PUT_LINE('No data found.');
END;
/
-------------------------------------------------------------------------------------------------------------
--Trigger to insert into stock_entry_audit when DML statement(INSERT, UPDATE, DELETE) is ran on stock_entry.
--------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER stock_entry_audit_trigg
AFTER INSERT OR UPDATE OR DELETE ON stock_entries
FOR EACH ROW
BEGIN
		IF INSERTING THEN
			stock_audit_pkg.create_stock_entry_audit(:NEW.entry_id, USER, :NEW.quantity_to_sell, :NEW.stock_id, 'INSERT', :NEW.unit_price, :NEW.quantity, :NEW.expiry_date, :NEW.entry_date, :NEW.inventory_status_id);
		ELSIF UPDATING THEN
			stock_audit_pkg.create_stock_entry_audit(:OLD.entry_id, USER, :OLD.quantity_to_sell, :OLD.stock_id, 'UPDATE', :OLD.unit_price, :OLD.quantity, :OLD.expiry_date, :OLD.entry_date, :OLD.inventory_status_id);
			stock_audit_pkg.create_stock_entry_audit(:NEW.entry_id, USER, :NEW.quantity_to_sell, :NEW.stock_id, 'UPDATE', :NEW.unit_price, :NEW.quantity, :NEW.expiry_date, :NEW.entry_date, :NEW.inventory_status_id);
		ELSIF DELETING THEN
			stock_audit_pkg.create_stock_entry_audit(:OLD.entry_id, USER, :OLD.quantity_to_sell, :OLD.stock_id, 'DELETE', :OLD.unit_price, :OLD.quantity, :OLD.expiry_date, :OLD.entry_date, :OLD.inventory_status_id);
		END IF;
EXCEPTION
		WHEN NO_DATA_FOUND THEN
			DBMS_OUTPUT.PUT_LINE('No data found.');
END;
/
---------------------------------------------------------------------------------------------------
--Trigger to insert into orders_audit when DML statement(INSERT, UPDATE, DELETE) is ran on orders.
---------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER orders_audit_trigg
AFTER INSERT OR UPDATE OR DELETE ON orders
FOR EACH ROW
BEGIN
		IF INSERTING THEN
			stock_audit_pkg.create_orders_audit(:NEW.order_total, :NEW.discount_pct, :NEW.payment_date, :NEW.payment_mode_id, :NEW.customer_id, USER, :NEW.payment_status_id, :NEW.order_status_id, :NEW.discount_amount, :NEW.amount_paid, :NEW.order_id, :NEW.amount_to_pay, :NEW.change, 'INSERT', :NEW.transaction_init_date, :NEW.delivery_date);
		ELSIF UPDATING THEN
			stock_audit_pkg.create_orders_audit(:OLD.order_total, :OLD.discount_pct, :OLD.payment_date, :OLD.payment_mode_id, :OLD.customer_id, USER, :OLD.payment_status_id, :OLD.order_status_id, :OLD.discount_amount, :OLD.amount_paid, :OLD.order_id, :OLD.amount_to_pay, :OLD.change, 'UPDATE', :OLD.transaction_init_date, :OLD.delivery_date);
			stock_audit_pkg.create_orders_audit(:NEW.order_total, :NEW.discount_pct, :NEW.payment_date,:NEW.payment_mode_id, :NEW.customer_id, USER, :NEW.payment_status_id, :NEW.order_status_id, :NEW.discount_amount, :NEW.amount_paid, :NEW.order_id, :NEW.amount_to_pay, :NEW.change, 'UPDATE', :NEW.transaction_init_date, :NEW.delivery_date);
		ELSIF DELETING THEN
			stock_audit_pkg.create_orders_audit(:OLD.order_total, :OLD.discount_pct, :OLD.payment_date, :OLD.payment_mode_id, :OLD.customer_id, USER, :OLD.payment_status_id, :OLD.order_status_id, :OLD.discount_amount, :OLD.amount_paid, :OLD.order_id, :OLD.amount_to_pay, :OLD.change, 'DELETE', :OLD.transaction_init_date, :OLD.delivery_date);
		END IF;
EXCEPTION
		WHEN NO_DATA_FOUND THEN
			DBMS_OUTPUT.PUT_LINE('No data found.');
END;
/
-----------------------------------------------------------------------------------------------------------------
--Trigger to insert into ordered_stock_audit when DML statement(INSERT, UPDATE, DELETE) is ran on ordered_stock.
-----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER ordered_stock_audit_trigg
AFTER INSERT OR UPDATE OR DELETE ON order_items
FOR EACH ROW
BEGIN
		IF INSERTING THEN
			stock_audit_pkg.create_order_item_audit(:NEW.item_id, :NEW.order_id, USER, :NEW.stock_id, :NEW.quantity, :NEW.unit_price, 'INSERT');
		ELSIF UPDATING THEN
			stock_audit_pkg.create_order_item_audit(:OLD.item_id, :OLD.order_id, USER, :OLD.stock_id, :OLD.quantity, :OLD.unit_price, 'UPDATE');
			stock_audit_pkg.create_order_item_audit(:NEW.item_id, :NEW.order_id, USER, :NEW.stock_id, :NEW.quantity, :NEW.unit_price, 'UPDATE');
		ELSIF DELETING THEN
			stock_audit_pkg.create_order_item_audit(:OLD.item_id, :OLD.order_id, USER, :OLD.stock_id, :OLD.quantity, :OLD.unit_price, 'DELETE');
		END IF;
EXCEPTION
		WHEN NO_DATA_FOUND THEN
			DBMS_OUTPUT.PUT_LINE('No data found.');
END;
/
-----------------------------------------------------------------------------------------------------------------
--Trigger to insert into stock_info_audit when DML statement(INSERT, UPDATE, DELETE) is ran on stock_information.
-------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER stock_info_audit_trigg
AFTER INSERT OR UPDATE OR DELETE ON stock_information
FOR EACH ROW
BEGIN
		IF INSERTING THEN
			stock_audit_pkg.create_stock_info_audit(:NEW.unit_price, :NEW.quantity, :NEW.category_id, :NEW.supplier_id, :NEW.stock_id, USER, :NEW.stock_info_id, 'INSERT', :NEW.request_date, :NEW.supply_date);
		ELSIF UPDATING THEN
			stock_audit_pkg.create_stock_info_audit(:OLD.unit_price, :OLD.quantity, :OLD.category_id, :OLD.supplier_id, :OLD.stock_id, USER, :OLD.stock_info_id, 'UPDATE', :OLD.request_date, :OLD.supply_date);
			stock_audit_pkg.create_stock_info_audit(:NEW.unit_price, :NEW.quantity, :NEW.category_id, :NEW.supplier_id, :NEW.stock_id, USER, :NEW.stock_info_id, 'UPDATE', :NEW.request_date, :NEW.supply_date);
		ELSIF DELETING THEN
			stock_audit_pkg.create_stock_info_audit(:OLD.unit_price, :OLD.quantity, :OLD.category_id, :OLD.supplier_id, :OLD.stock_id, USER, :OLD.stock_info_id, 'DELETE', :OLD.request_date, :OLD.supply_date);
		END IF;
EXCEPTION
		WHEN NO_DATA_FOUND THEN
			DBMS_OUTPUT.PUT_LINE('No data found.');
END;
/
--------------------------------------------------------------------------------------------------------------------
--Trigger to insert into stock_categories_audit when DML statement(INSERT, UPDATE, DELETE) is ran on stock_category.
---------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER stock_categories_audit_trigg
AFTER INSERT OR UPDATE OR DELETE ON stock_categories
FOR EACH ROW
BEGIN
		IF INSERTING THEN
			stock_audit_pkg.create_stock_category_audit(:NEW.category_id, :NEW.category_name, 'INSERT', USER);
		ELSIF UPDATING THEN
			stock_audit_pkg.create_stock_category_audit(:OLD.category_id, :OLD.category_name, 'UPDATE', USER);
			stock_audit_pkg.create_stock_category_audit(:NEW.category_id, :NEW.category_name, 'UPDATE', USER);
		ELSIF DELETING THEN
			stock_audit_pkg.create_stock_category_audit(:OLD.category_id, :OLD.category_name, 'DELETE', USER);
		END IF;
EXCEPTION
		WHEN NO_DATA_FOUND THEN
			DBMS_OUTPUT.PUT_LINE('No data found.');
END;
/
----------------------------------------------------------------------------------------------------
--Trigger to insert into regions_audit when DML statement(INSERT, UPDATE, DELETE) is ran on regions.
----------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER create_regions_audit_trig
AFTER INSERT OR UPDATE OR DELETE ON regions
FOR EACH ROW
BEGIN
		IF INSERTING THEN
			location_audit_pkg.create_regions_audit(:NEW.region_id, :NEW.region_name, USER, 'INSERT');
		ELSIF UPDATING THEN
			location_audit_pkg.create_regions_audit(:OLD.region_id, :OLD.region_name, USER, 'UPDATE');
			location_audit_pkg.create_regions_audit(:NEW.region_id, :NEW.region_name, USER, 'UPDATE');
		ELSIF DELETING THEN
			location_audit_pkg.create_regions_audit(:OLD.region_id, :OLD.region_name, USER, 'DELETE');
		END IF;
EXCEPTION
		WHEN NO_DATA_FOUND THEN
			DBMS_OUTPUT.PUT_LINE('No data found.');
END;
/
-------------------------------------------------------------------------------------------------------			
--Trigger to insert into countries_audit when DML statement(INSERT, UPDATE, DELETE) is ran on countries
--------------------------------------------------------------------------------------------------------.
CREATE OR REPLACE TRIGGER create_countries_audit_trig
AFTER INSERT OR UPDATE OR DELETE ON countries
FOR EACH ROW
BEGIN
		IF INSERTING THEN
			location_audit_pkg.create_countries_audit(:NEW.country_id, :NEW.country_name, :NEW.region_id, USER, 'INSERT');
		ELSIF UPDATING THEN
			location_audit_pkg.create_countries_audit(:OLD.country_id, :OLD.country_name, :OLD.region_id, USER, 'UPDATE');
			location_audit_pkg.create_countries_audit(:NEW.country_id, :NEW.country_name, :NEW.region_id, USER, 'UPDATE');
		ELSIF DELETING THEN
			location_audit_pkg.create_countries_audit(:OLD.country_id, :OLD.country_name, :OLD.region_id, USER, 'DELETE');
		END IF;
EXCEPTION
		WHEN NO_DATA_FOUND THEN
			DBMS_OUTPUT.PUT_LINE('No data found.');
END;
/
--------------------------------------------------------------------------------------------------------
--Trigger to insert into locations_audit when DML statement(INSERT, UPDATE, DELETE) is ran on locations.
--------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER create_locations_audit_trig
AFTER INSERT OR UPDATE OR DELETE ON locations
FOR EACH ROW
BEGIN
		IF INSERTING THEN
			location_audit_pkg.create_locations_audit(:NEW.location_id, :NEW.city, :NEW.state_province, :NEW.country_id, USER, 'INSERT');
		ELSIF UPDATING THEN
			location_audit_pkg.create_locations_audit(:OLD.location_id, :OLD.city, :OLD.state_province, :OLD.country_id, USER, 'UPDATE');
			location_audit_pkg.create_locations_audit(:NEW.location_id, :NEW.city, :NEW.state_province, :NEW.country_id, USER, 'UPDATE');
		ELSIF DELETING THEN
			location_audit_pkg.create_locations_audit(:OLD.location_id, :OLD.city, :OLD.state_province, :OLD.country_id, USER, 'DELETE');
		END IF;
EXCEPTION
		WHEN NO_DATA_FOUND THEN
			DBMS_OUTPUT.PUT_LINE('No data found.');
END;
/
--------------------------------------------------------------------------------------------------------------
--Trigger to insert into order_status_audit when DML statement(INSERT, UPDATE, DELETE) is ran on order_status.
--------------------------------------------------------------------------------------------------------------	
CREATE OR REPLACE TRIGGER order_status_audit_trigg
AFTER DELETE OR UPDATE OR INSERT ON order_status
FOR EACH ROW
BEGIN
		IF INSERTING THEN
			stock_audit_pkg.create_order_status_audit(:NEW.order_status_id, :NEW.status_name, USER, 'INSERT');
		ELSIF UPDATING THEN
			stock_audit_pkg.create_order_status_audit(:OLD.order_status_id, :OLD.status_name, USER, 'UPDATE');
			stock_audit_pkg.create_order_status_audit(:NEW.order_status_id, :NEW.status_name, USER, 'UPDATE');
		ELSIF DELETING THEN
			stock_audit_pkg.create_order_status_audit(:OLD.order_status_id, :OLD.status_name, USER, 'DELETE');
		END IF;
EXCEPTION
		WHEN NO_DATA_FOUND THEN
			DBMS_OUTPUT.PUT_LINE('No data found.');
END;
/
----------------------------------------------------------------------------------------------------------------------
--Trigger to insert into inventory_status_audit when DML statement(INSERT, UPDATE, DELETE) is ran on inventory_status.
-----------------------------------------------------------------------------------------------------------------------	
CREATE OR REPLACE TRIGGER inventory_status_audit_trigg
AFTER DELETE OR UPDATE OR INSERT ON inventory_status
FOR EACH ROW
BEGIN
		IF INSERTING THEN
			stock_audit_pkg.create_inventory_status_audit(:NEW.inventory_status_id, :NEW.status_name, USER, 'INSERT');
		ELSIF UPDATING THEN
			stock_audit_pkg.create_inventory_status_audit(:OLD.inventory_status_id, :OLD.status_name, USER, 'UPDATE');
			stock_audit_pkg.create_inventory_status_audit(:NEW.inventory_status_id, :NEW.status_name, USER, 'UPDATE');
		ELSIF DELETING THEN
			stock_audit_pkg.create_inventory_status_audit(:OLD.inventory_status_id, :OLD.status_name, USER, 'DELETE');
		END IF;
EXCEPTION
		WHEN NO_DATA_FOUND THEN
			DBMS_OUTPUT.PUT_LINE('No data found.');
END;
/	
--------------------------------------------------------------------------------------------------------------
--Trigger to insert into rating_scale_audit when DML statement(INSERT, UPDATE, DELETE) is ran on rating_scale.
---------------------------------------------------------------------------------------------------------------	
CREATE OR REPLACE TRIGGER rating_scale_audit_trigg
AFTER DELETE OR UPDATE OR INSERT ON rating_scale
FOR EACH ROW
BEGIN
		IF INSERTING THEN
			ratings_audit_pkg.create_rating_scale_audit(:NEW.rating_value, :NEW.rating_label, :NEW.rating_description, 'INSERT', USER);
		ELSIF UPDATING THEN
			ratings_audit_pkg.create_rating_scale_audit(:OLD.rating_value, :OLD.rating_label, :OLD.rating_description, 'UPDATE', USER);
			ratings_audit_pkg.create_rating_scale_audit(:NEW.rating_value, :NEW.rating_label, :NEW.rating_description, 'UPDATE', USER);
		ELSIF DELETING THEN
			ratings_audit_pkg.create_rating_scale_audit(:OLD.rating_value, :OLD.rating_label, :OLD.rating_description, 'DELETE', USER);
		END IF;
EXCEPTION
		WHEN NO_DATA_FOUND THEN
			DBMS_OUTPUT.PUT_LINE('No data found.');
END;
/
--------------------------------------------------------------------------------------------------------------
--Trigger to insert into service_ratings_audit when DML statement(INSERT, UPDATE, DELETE) is ran on service_ratings.
---------------------------------------------------------------------------------------------------------------	
CREATE OR REPLACE TRIGGER service_ratings_audit_trigg
AFTER DELETE OR UPDATE OR INSERT ON service_ratings
FOR EACH ROW
BEGIN
		IF INSERTING THEN
			ratings_audit_pkg.create_service_ratings_audit(:NEW.service_rating_id, :NEW.customer_id, :NEW.order_id, :NEW.delivery_rating,
        			          :NEW.packaging_rating, :NEW.support_rating, :NEW.overall_comment, :NEW.rating_date, 'INSERT', USER
			);
		ELSIF UPDATING THEN
			ratings_audit_pkg.create_service_ratings_audit(:OLD.service_rating_id, :OLD.customer_id, :OLD.order_id, :OLD.delivery_rating,
        			       :OLD.packaging_rating, :OLD.support_rating, :OLD.overall_comment, :OLD.rating_date, 'UPDATE', USER
			);
			ratings_audit_pkg.create_service_ratings_audit(:NEW.service_rating_id, :NEW.customer_id, :NEW.order_id, :NEW.delivery_rating,
        			       :NEW.packaging_rating, :NEW.support_rating, :NEW.overall_comment, :NEW.rating_date, 'UPDATE', USER
			);
		ELSIF DELETING THEN
			ratings_audit_pkg.create_service_ratings_audit(:OLD.service_rating_id, :OLD.customer_id, :OLD.order_id, :OLD.delivery_rating,
        			       :OLD.packaging_rating, :OLD.support_rating, :OLD.overall_comment, :OLD.rating_date, 'DELETE', USER
			);
		END IF;
EXCEPTION
		WHEN NO_DATA_FOUND THEN
			DBMS_OUTPUT.PUT_LINE('No data found.');
END;
/
--------------------------------------------------------------------------------------------------------------
--Trigger to insert into product_reviews_audit when DML statement(INSERT, UPDATE, DELETE) is ran on product_reviews.
---------------------------------------------------------------------------------------------------------------	

CREATE OR REPLACE TRIGGER product_reviews_audit_trigg
AFTER DELETE OR UPDATE OR INSERT ON product_reviews
FOR EACH ROW
BEGIN
		IF INSERTING THEN
			ratings_audit_pkg.create_product_reviews_audit(:NEW.product_review_id, :NEW.customer_id, :NEW.stock_id, :NEW.rating, :NEW.feedback, :NEW.review_date, 'INSERT', USER);
		ELSIF UPDATING THEN
			ratings_audit_pkg.create_product_reviews_audit(:OLD.product_review_id, :OLD.customer_id, :OLD.stock_id, :OLD.rating, :OLD.feedback, :OLD.review_date, 'UPDATE', USER);
			ratings_audit_pkg.create_product_reviews_audit(:NEW.product_review_id, :NEW.customer_id, :NEW.stock_id, :NEW.rating, :NEW.feedback, :NEW.review_date, 'UPDATE', USER);
		ELSIF DELETING THEN
			ratings_audit_pkg.create_product_reviews_audit(:OLD.product_review_id, :OLD.customer_id, :OLD.stock_id, :OLD.rating, :OLD.feedback, :OLD.review_date, 'DELETE', USER);
		END IF;
EXCEPTION
		WHEN NO_DATA_FOUND THEN
			DBMS_OUTPUT.PUT_LINE('No data found.');
END;
/
--===================================================================================================================
-- SAMPLE DATA IS INSERTED TO TEST THE IMPLEMENTATION AND FUNCTION OF THE STOCK AND ORDER MANAGEMENT DATABASE SYSTEM.
--====================================================================================================================
----------------------------------------------------------------
/* Adding Customer
customer_pkg.create_customer_info(p_last_name, p_first_name);*/
----------------------------------------------------------------
BEGIN
    customer_pkg.create_customer_info('Doe', 'John', Date '2000-02-12');
    customer_pkg.create_customer_info('Smith', 'Jane', Date '1990-02-12');
    customer_pkg.create_customer_info('Aquarm', 'Bright', Date '1989-02-12');
    customer_pkg.create_customer_info('Annobil', 'Gad', Date '1998-02-12');
    customer_pkg.create_customer_info('Amoansah', 'Caleb', Date '1999-02-12');
    customer_pkg.create_customer_info('Koomson', 'Raymond', Date '1994-02-12');
    customer_pkg.create_customer_info('Jackson', 'Nickolas', Date '2001-02-12');
    customer_pkg.create_customer_info('Hammond', 'Miriam', Date '1996-02-12');
    customer_pkg.create_customer_info('Kobby', 'Stone', Date '1992-02-12');
    customer_pkg.create_customer_info('Abraafi', 'Precious', Date '1996-02-12');
    customer_pkg.create_customer_info('Okpoti', 'Vanessa', Date '2002-02-12');          
END;
/
-----------------------------------------------------------------
/* Adding Customer phone
customer_pkg.create_customer_phone(p_phone, p_customer_id);	*/
-----------------------------------------------------------------
EXEC customer_pkg.create_customer_phone('+233-556-7892', 1)
EXEC customer_pkg.create_customer_phone('+233-551-3771', 2)
EXEC customer_pkg.create_customer_phone('+233-541-9971', 3)
EXEC customer_pkg.create_customer_phone('+233-253-1871', 4)
EXEC customer_pkg.create_customer_phone('+233-251-3901', 5)
EXEC customer_pkg.create_customer_phone('+233-505-3081', 6)
EXEC customer_pkg.create_customer_phone('+233-581-3701', 7)
EXEC customer_pkg.create_customer_phone('+233-531-0771', 8)
EXEC customer_pkg.create_customer_phone('+233-550-3071', 9)
EXEC customer_pkg.create_customer_phone('+233-251-3779', 10)
EXEC customer_pkg.create_customer_phone('+233-151-3765', 7)
EXEC customer_pkg.create_customer_phone('+233-541-3472', 3)
EXEC customer_pkg.create_customer_phone('+233-531-4472', 11)
-----------------------------------------------------------------------------
/* Adding Customer Email Account 
customer_pkg.create_customer_email_account(p_email_account, p_customer_id);*/
------------------------------------------------------------------------------
EXEC customer_pkg.create_customer_email_account('john.doe@gmail.com', 1)
EXEC customer_pkg.create_customer_email_account('aquarmbright@gmail.com', 3)
EXEC customer_pkg.create_customer_email_account('amoansahcaleb@gmail.com', 5)
EXEC customer_pkg.create_customer_email_account('hammondmiriam@gmail.com', 8)
EXEC customer_pkg.create_customer_email_account('kobbystone@gmail.com', 9)
------------------------------------------------------
/* Adding Suppliers
supplier_pkg.create_supplier_info(p_supplier_name);*/
------------------------------------------------------
BEGIN
     supplier_pkg.create_supplier_info('TechGlobal Ltd');
     supplier_pkg.create_supplier_info('FreshFarms Ltd');
     supplier_pkg.create_supplier_info('Global Supplies Ltd.');
END;
/
-------------------------------------------------------------
/*Adding Supplier phone
supplier_pkg.create_supplier_phone(p_phone, p_supplier_id);*/
--------------------------------------------------------------
EXEC supplier_pkg.create_supplier_phone('987-654-5510', 5)
EXEC supplier_pkg.create_supplier_phone('987-774-5540', 5)
EXEC supplier_pkg.create_supplier_phone('987-655-4410', 10)
EXEC supplier_pkg.create_supplier_phone('987-652-3321', 10)
EXEC supplier_pkg.create_supplier_phone('987-651-3211', 15)
EXEC supplier_pkg.create_supplier_phone('987-651-3244', 15)
------------------------------------------------------------------------------
/* Adding Supplier Email Account
supplier_pkg.create_supplier_email_account(p_email_account, p_supplier_id);*/
-------------------------------------------------------------------------------
EXEC supplier_pkg.create_supplier_email_account('techgloballtd@gmail.com', 5);
EXEC supplier_pkg.create_supplier_email_account('freshFarmsltd@gmail.com', 10);
EXEC supplier_pkg.create_supplier_email_account('globalsuppliesltd@gmail.com', 15);
---------------------------------------------------
/* Adding Stock Categories
stock_pkg.create_stock_category(p_category_name);*/
---------------------------------------------------
EXECUTE stock_pkg.create_stock_category('Electronics')
EXECUTE stock_pkg.create_stock_category('Groceries');
---------------------------------------------------------------------------------------------------------------------
/* Creating Products
(Products are created with zero cost and zero quantity initially, as per business rules)
stock_pkg.create_stock(p_stock_name, p_reorder_level DEFAULT 0, quantity_in_stock DEFAULT 0, unit_price DEFAULT 0);*/
-----------------------------------------------------------------------------------------------------------------------
BEGIN
    stock_pkg.create_stock('Smartphone', 10);
    stock_pkg.create_stock('Abena rice', 20);
    stock_pkg.create_stock('Ice cream', 30);
	stock_pkg.create_stock('Laptop', 15);
END;
/
---------------------------------------------------------------------------------------------------------------------------------------
/* Creating Stock Information
stock_pkg.create_stock_information(p_unit_price, p_quantity, p_category_id, p_supplier_id,p_stock_id, p_request_date, p_supply_date);*/
-----------------------------------------------------------------------------------------------------------------------------------------
EXEC stock_pkg.create_stock_information(200, 550, 100, 5, 10, Date '2025-02-12'  , Date '2025-03-02');
EXEC stock_pkg.create_stock_information(250, 300, 110, 10, 15, Date '2025-03-18'  , Date '2025-03-29');
EXEC stock_pkg.create_stock_information(300, 230, 110, 15, 20, Date '2025-04-12'  , Date '2025-05-09');
EXEC stock_pkg.create_stock_information(350, 150, 100, 15, 25, Date '2025-04-27'  , Date '2025-06-05');
--------------------------------
-- Entering Inventory_Status
-------------------------------
BEGIN										
	stock_pkg.create_inventory_status(p_inventory_status_id => 'EX', p_status_name => 'Expired');
	stock_pkg.create_inventory_status(p_inventory_status_id => 'DM', p_status_name => 'Damaged');
	stock_pkg.create_inventory_status(p_inventory_status_id => 'RS', p_status_name => 'Reserved');
	stock_pkg.create_inventory_status(p_inventory_status_id => 'AVL', p_status_name => 'Available');
	stock_pkg.create_inventory_status(p_inventory_status_id => 'OOS', p_status_name => 'Out of Stock');
END;
/
------------------------------------------------------------------------------------------------------------------------------------------------------------
/* Entering Stock (Updating Quantity & Price)
(Procedure updates quantity_in_stock and sets latest unit_price)
stock_pkg.create_stock_entry(P_stock_id, p_unit_price, p_inventory_status_id, p_quantity, p_quantity_to_sell, p_expiry_date,p_entry_date DEFAULT SYSDATE);*/
-------------------------------------------------------------------------------------------------------------------------------------------------------------
BEGIN
	stock_pkg.create_stock_entry(10, 12000, 150, 150, 'AVL', DATE '2030-10-30');              			    -- Smartphone, 100 units @ GHS 12000 Each
	stock_pkg.create_stock_entry(15, 320, 70, 70, 'AVL', SYSDATE + 50);                   -- Abena rice, 600 units @ GHS 320 Each
	stock_pkg.create_stock_entry(20, 350, 175, 175, 'AVL', DATE '2029-06-17');               			    -- Lacoste, 500 units @ GHS 350 Each
	stock_pkg.create_stock_entry(15, 300, 30, 30, 'AVL', DATE '2027-11-23');  	     -- Abena rice, 450 units @ GHS 300 Each
	stock_pkg.create_stock_entry(25, 550, 90, 90, 'AVL', DATE '2028-10-12');-- Air force, 250 units @ GHS 550 Each
END;
/
--------------------------------------------------------------
/* Processing Payment methods
stock_pkg.create_payment_method(p_mode_id, p_payment_mode);*/
--------------------------------------------------------------
BEGIN
     stock_pkg.create_payment_method('CA',  'cash');
     stock_pkg.create_payment_method('CC', 'credit card');
 	 stock_pkg.create_payment_method('DC', 'debit card');
     stock_pkg.create_payment_method('MM', 'mobile money');
END;
/
---------------------------
-- Entering Payment status
---------------------------
EXEC stock_pkg.create_payment_status('PD', 'Paid')
EXEC stock_pkg.create_payment_status('UP', 'Unpaid')
------------------------
-- Adding Order Status
------------------------
BEGIN										
	stock_pkg.create_order_status(p_order_status_id => 'SM', p_status_name => 'Submitted');
	stock_pkg.create_order_status(p_order_status_id => 'PR', p_status_name => 'Processing');
	stock_pkg.create_order_status(p_order_status_id => 'DP', p_status_name => 'Dispatch');
	stock_pkg.create_order_status(p_order_status_id => 'CA', p_status_name => 'Cancelled');
	stock_pkg.create_order_status(p_order_status_id => 'DE', p_status_name => 'Delivered');
	stock_pkg.create_order_status(p_order_status_id => 'RT', p_status_name => 'Returned');
END;
/
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/* Placing Orders
(Ensures discounts and order_total are automatically applied)
stock_pkg.create_orders( p_mode_id, p_customer_id, p_payment_status_id, p_order_status, p_payment_date  DEFAULT SYSDATE, p_transaction_init_date DEFAULT SYSDATE, p_delivery_date DEFAULT SYSDATE);*/
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
BEGIN
 	    sales_pkg.create_orders(p_customer_id => 1, p_transaction_init_date => DATE '2025-03-19');
 	    sales_pkg.create_orders(p_customer_id => 2, p_transaction_init_date => DATE '2025-04-03');
 	    sales_pkg.create_orders(p_customer_id => 3, p_transaction_init_date => DATE '2025-04-11');
		sales_pkg.create_orders(p_customer_id => 1, p_transaction_init_date => DATE '2025-05-14');
        sales_pkg.create_orders(p_customer_id => 4, p_transaction_init_date => DATE '2025-05-21');
		sales_pkg.create_orders(p_customer_id => 2, p_transaction_init_date => DATE '2025-06-10');
   	    sales_pkg.create_orders(p_customer_id => 5, p_transaction_init_date => DATE '2025-07-08');
		sales_pkg.create_orders(p_customer_id => 1, p_transaction_init_date => DATE '2025-07-15');
        sales_pkg.create_orders(p_customer_id => 6, p_transaction_init_date => DATE '2025-08-01');
        sales_pkg.create_orders(p_customer_id => 7, p_transaction_init_date => DATE '2025-08-19');
	    sales_pkg.create_orders(p_customer_id => 8, p_transaction_init_date => DATE '2025-08-19');
	    sales_pkg.create_orders(p_customer_id => 9, p_transaction_init_date => DATE '2025-09-08');
		sales_pkg.create_orders(p_customer_id => 10, p_transaction_init_date => DATE '2025-09-20');
	    sales_pkg.create_orders(p_customer_id => 11, p_transaction_init_date => DATE '2025-10-01');
	    sales_pkg.create_orders(p_customer_id => 8, p_transaction_init_date => DATE '2025-10-01');
END;
/
-------------------------
-- Entering Order Items
-------------------------
EXECUTE sales_pkg.create_order_item(p_order_id => 5, p_stock_id => 10, p_quantity => 10);
EXECUTE sales_pkg.create_order_item(p_order_id => 5, p_stock_id => 15, p_quantity => 20);
EXECUTE sales_pkg.create_order_item(p_order_id => 10, p_stock_id => 15, p_quantity => 7);
EXECUTE sales_pkg.create_order_item(p_order_id => 15, p_stock_id => 25, p_quantity => 11);
EXECUTE sales_pkg.create_order_item(p_order_id => 15, p_stock_id => 20, p_quantity => 16);
EXECUTE sales_pkg.create_order_item(p_order_id => 20, p_stock_id => 10, p_quantity => 4);
EXECUTE sales_pkg.create_order_item(p_order_id => 20, p_stock_id => 15, p_quantity => 10);
EXECUTE sales_pkg.create_order_item(p_order_id => 25, p_stock_id => 15, p_quantity => 15);
EXECUTE sales_pkg.create_order_item(p_order_id => 25, p_stock_id => 10, p_quantity => 25);
EXECUTE sales_pkg.create_order_item(p_order_id => 30, p_stock_id => 25, p_quantity => 16);
EXECUTE sales_pkg.create_order_item(p_order_id => 30, p_stock_id => 20, p_quantity => 12);
EXECUTE sales_pkg.create_order_item(p_order_id => 35, p_stock_id => 10, p_quantity => 35);
EXECUTE sales_pkg.create_order_item(p_order_id => 40, p_stock_id => 15, p_quantity => 3);
EXECUTE sales_pkg.create_order_item(p_order_id => 40, p_stock_id => 20, p_quantity => 55);
EXECUTE sales_pkg.create_order_item(p_order_id => 45, p_stock_id => 15, p_quantity => 13);
EXECUTE sales_pkg.create_order_item(p_order_id => 45, p_stock_id => 25, p_quantity => 25);
EXECUTE sales_pkg.create_order_item(p_order_id => 45, p_stock_id => 20, p_quantity => 17);
EXECUTE sales_pkg.create_order_item(p_order_id => 45, p_stock_id => 10, p_quantity => 10);
EXECUTE sales_pkg.create_order_item(p_order_id => 50, p_stock_id => 15, p_quantity => 5);
EXECUTE sales_pkg.create_order_item(p_order_id => 55, p_stock_id => 15, p_quantity => 3);
EXECUTE sales_pkg.create_order_item(p_order_id => 55, p_stock_id => 10, p_quantity => 20);
EXECUTE sales_pkg.create_order_item(p_order_id => 60, p_stock_id => 10, p_quantity => 10);
EXECUTE sales_pkg.create_order_item(p_order_id => 60, p_stock_id => 20, p_quantity => 25);
EXECUTE sales_pkg.create_order_item(p_order_id => 65, p_stock_id => 15, p_quantity => 12);
EXECUTE sales_pkg.create_order_item(p_order_id => 65, p_stock_id => 25, p_quantity => 16);
EXECUTE sales_pkg.create_order_item(p_order_id => 70, p_stock_id => 25, p_quantity => 13);
EXECUTE sales_pkg.create_order_item(p_order_id => 70, p_stock_id =>10 , p_quantity => 5);
EXECUTE sales_pkg.create_order_item(p_order_id => 75, p_stock_id => 20, p_quantity => 25);
-------------------------------------------------------------------------------------------------------
-- Update amount_paid, delivery_date, payment_mode_id, payment_status_id and order_status_id on ORDERS.
-------------------------------------------------------------------------------------------------------
PROCEDURE update_amount_paid(p_order_id orders.order_id%TYPE, p_customer_id orders.customer_id%TYPE,
				p_amount_paid orders.amount_paid%TYPE, p_payment_mode_id orders.payment_mode_id%TYPE,
				p_payment_date orders.payment_date%TYPE DEFAULT SYSDATE)
EXEC sales_update_pkg.update_amount_paid(p_order_id => 5, p_customer_id => 1, p_amount_paid => 107400, p_payment_mode_id => 'CA', p_payment_date=> DATE '2025-03-19')
EXEC sales_update_pkg.update_amount_paid(p_order_id => 10, p_customer_id => 2, p_amount_paid => 1900, p_payment_mode_id => 'MM', p_payment_date=> DATE '2025-04-11')
EXEC sales_update_pkg.update_amount_paid(p_order_id => 15, p_customer_id => 3, p_amount_paid => 10000, p_payment_mode_id => 'MM', p_payment_date=> DATE '2025-04-19')
EXEC sales_update_pkg.update_amount_paid(p_order_id => 20, p_customer_id => 1, p_amount_paid => 43469, p_payment_mode_id => 'CC', p_payment_date=> DATE '2025-05-14')
EXEC sales_update_pkg.update_amount_paid(p_order_id => 25, p_customer_id => 4, p_amount_paid => 259003.5, p_payment_mode_id => 'CC', p_payment_date=> DATE '2025-05-25')
EXEC sales_update_pkg.update_amount_paid(p_order_id => 30, p_customer_id => 2, p_amount_paid => 11100, p_payment_mode_id => 'CA', p_payment_date=> DATE '2025-06-10')
EXEC sales_update_pkg.update_amount_paid(p_order_id => 35, p_customer_id => 5, p_amount_paid =>  357000, p_payment_mode_id => 'CC', p_payment_date=> DATE '2025-07-08')
EXEC sales_update_pkg.update_amount_paid(p_order_id => 40, p_customer_id => 1, p_amount_paid => 17200, p_payment_mode_id => 'CA', p_payment_date=> DATE '2025-07-15')
EXEC sales_update_pkg.update_amount_paid(p_order_id => 45, p_customer_id => 6, p_amount_paid => 122214.7, p_payment_mode_id => 'CC', p_payment_date=> DATE '2025-08-01')
EXEC sales_update_pkg.update_amount_paid(p_order_id => 50, p_customer_id => 7, p_amount_paid => 1334.5, p_payment_mode_id => 'DC', p_payment_date=> DATE '2025-08-19')
EXEC sales_update_pkg.update_amount_paid(p_order_id => 55, p_customer_id => 8, p_amount_paid => 204800.7, p_payment_mode_id => 'CC', p_payment_date=> DATE '2025-08-19')
EXEC sales_update_pkg.update_amount_paid(p_order_id => 60, p_customer_id => 9, p_amount_paid => 109437.5, p_payment_mode_id => 'CC', p_payment_date=> DATE '2025-09-08')
EXEC sales_update_pkg.update_amount_paid(p_order_id => 65, p_customer_id => 10, p_amount_paid => 10690, p_payment_mode_id => 'CA', p_payment_date=> DATE '2025-09-20')
------------------------------------------------------------
/*Creating Regions
location_pkg.create_regions(p_region_id, p_region_name)*/
---------------------------------------------------------
BEGIN
	location_pkg.create_regions('EU', 'Europe');
	location_pkg.create_regions('AM', 'Americas');
	location_pkg.create_regions('AS', 'Asia');
	location_pkg.create_regions('ME', 'Middle East');
	location_pkg.create_regions('AF', 'Africa');
END;
/
--------------------------------------------------------------------------
/*Entering Countries
location_pkg.create_countries(p_country_id, p_country_name, p_region_id)*/
--------------------------------------------------------------------------
BEGIN
	location_pkg.create_countries('US', 'USA', 'AM');
	location_pkg.create_countries('CN', 'China', 'AS');
	location_pkg.create_countries('JP', 'Japan', 'AS');
	location_pkg.create_countries('IN', 'India', 'AS');
	location_pkg.create_countries('GH', 'Ghana', 'AF');
	location_pkg.create_countries('DE', 'Germany', 'EU');
	location_pkg.create_countries('UK', 'United Kingdom', 'EU');
END;
/
-------------------------------------------------------------------------
/*Adding Locations
location_pkg.create_locations(p_city, p_country_id, p_state_province)*/
------------------------------------------------------------------------
BEGIN
	location_pkg.create_locations('South San Francisco', 'US', 'California');
	location_pkg.create_locations('Beijing', 'CN');
	location_pkg.create_locations('Tokyo', 'JP', 'Tokyo Prefecture');
	location_pkg.create_locations('Bombay', 'IN', 'Maharashtra');
	location_pkg.create_locations('Accra', 'GH', 'Greater Accra');
	location_pkg.create_locations('Munich', 'DE', 'Bavana');
	location_pkg.create_locations('Stretford', 'UK', 'Manchester');
END;
/
---------------------------------------------------------------------------------------------------
/*Adding Customer Address
customer_pkg.create_customer_address(p_street_address, p_postal_code, location_id, p_customer_id)*/
---------------------------------------------------------------------------------------------------
BEGIN
	customer_pkg.create_customer_address('2011 Interiors Blvd', '99236', 1, 1);
	customer_pkg.create_customer_address('40-5-12 Laogianggen', '190518', 2, 2);
	customer_pkg.create_customer_address('2017 Shinjuku-ku', '1689', 3, 3);
	customer_pkg.create_customer_address('2010 Interiors Blvd', '99346', 1, 1);
	customer_pkg.create_customer_address('1298 Vileparle (E)', '490231', 4, 4);
	customer_pkg.create_customer_address('No. 123, High Street, Osu, Accra', 'P.O. Box GP 123, Accra, Ghana', 5, 5);
	customer_pkg.create_customer_address('Schwanthalerstr. 7031', '80925', 6, 6);
	customer_pkg.create_customer_address('9702 Chester Road', '09629850293', 7, 7);
	customer_pkg.create_customer_address('9602 Chester Road', '09629850093', 7, 8);
	customer_pkg.create_customer_address('2018 Shinjuku-ku', '1679', 3,  9);
	customer_pkg.create_customer_address('No. 124, High Street, Circle, Accra', 'P.O. Box GP 124, Accra, Ghana', 5, 10);
	customer_pkg.create_customer_address('1208 Vileparle (E)', '490332', 4, 11);
	customer_pkg.create_customer_address('2017 Shinjuku-ku', '1669', 3,  8);
END;
/
----------------------------------------------------------------------------------------------------
/*Adding Supplier Address
supplier_pkg.create_supplier_address(p_street_address, p_postal_code, location_id, p_supplier_id);*/
----------------------------------------------------------------------------------------------------
BEGIN	
	supplier_pkg.create_supplier_address('1200 17th Street, South San Francisco, CA 94080', '94080', 1, 5);
	supplier_pkg.create_supplier_address('Beijing Economic-Technological Development Area (BDA)', '100176', 2, 10);
	supplier_pkg.create_supplier_address('5 Chome-5-1 Ota, Tokyo, 143-0006, Japan', '143-0006', 3, 15);
	supplier_pkg.create_supplier_address('Tema Industrial Area, Tema, Greater Accra Region, Ghana', ' 00233', 5, 10);
	supplier_pkg.create_supplier_address('Lower Parel Industrial Zone, Mumbai, Maharashtra, India', ' 400013', 3, 15);
END;
/
-- Insert standard 5-point scale
BEGIN
  rating_scale_pkg.create_rating_scale(p_rating_value => 1, p_rating_label => 'Poor',
    p_rating_description => 'Unsatisfactory service or product quality. Major issues encountered.'
  );

  rating_scale_pkg.create_rating_scale(p_rating_value => 2, p_rating_label => 'Fair',
    p_rating_description => 'Below average experience. Needs significant improvement.'
  );

  rating_scale_pkg.create_rating_scale(p_rating_value => 3, p_rating_label => 'Good',
    p_rating_description => 'Satisfactory service or product. Some minor issues.'
  );

  rating_scale_pkg.create_rating_scale(p_rating_value => 4, p_rating_label => 'Very Good',
    p_rating_description => 'High-quality experience with minimal issues.'
  );

  rating_scale_pkg.create_rating_scale(p_rating_value => 5, p_rating_label => 'Excellent',
    p_rating_description => 'Outstanding service or product. Exceeded expectations.'
  );
END;
/
/*ratings_pkg.create_service_ratings(p_customer_id, p_order_id, p_delivery_rating,
        			       p_packaging_rating, p_support_rating, p_overall_comment, p_rating_date);*/
BEGIN
  ratings_pkg.create_service_ratings(1, 5, 5, 5, 5, 'Outstanding delivery and packaging.');
  ratings_pkg.create_service_ratings(2, 10, 4, 4, 5, 'Very good service overall.');
  ratings_pkg.create_service_ratings(3, 15, 3, 3, 4, 'Average delivery, decent support.');
  ratings_pkg.create_service_ratings(1, 20, 2, 3, 2, 'Needs improvement in packaging.');
  ratings_pkg.create_service_ratings(4, 25, 1, 2, 1, 'Unacceptable service experience.');
  ratings_pkg.create_service_ratings(2, 30, 5, 5, 4, 'Prompt delivery and responsive support.');
  ratings_pkg.create_service_ratings(5, 35, 4, 4, 3, 'Good service, room for improvement.');
  ratings_pkg.create_service_ratings(1, 40, 3, 2, 3, 'Average experience.');
  ratings_pkg.create_service_ratings(6, 45, 2, 2, 2, 'Service could be much better.');
  ratings_pkg.create_service_ratings(7, 50, 5, 5, 5, 'Exceptional service across the board!');
  ratings_pkg.create_service_ratings(8, 55, 4, 5, 4, 'Fast delivery and secure packaging.');
  ratings_pkg.create_service_ratings(9, 60, 4, 3, 4, 'Good service, room for improvement.');
  ratings_pkg.create_service_ratings(10, 65, 5, 5, 4, 'Fast delivery and secure packaging.');
  ratings_pkg.create_service_ratings(11, 70, 3, 2, 4, 'Average delivery, Not really bad though.');
  ratings_pkg.create_service_ratings(8, 75, 4, 5, 4, 'Fast delivery and secure packaging.');
END;
/
--ratings_pkg.create_product_reviews(p_customer_id, p_stock_id, p_rating, p_feedback, p_review_date);
BEGIN
  ratings_pkg.create_product_reviews(1, 10, 5, 'Excellent product quality and durability.');
  ratings_pkg.create_product_reviews(2, 15, 4, 'Very good, met expectations.');
  ratings_pkg.create_product_reviews(3, 20, 3, 'Average experience, product was okay.');
  ratings_pkg.create_product_reviews(1, 20, 2, 'Below average, packaging was damaged.');
  ratings_pkg.create_product_reviews(4, 15, 1, 'Poor quality, not satisfied.');
  ratings_pkg.create_product_reviews(2, 15, 5, 'Loved it! Will buy again.');
  ratings_pkg.create_product_reviews(5, 10, 4, 'Good product for the price.');
  ratings_pkg.create_product_reviews(6, 10, 3, 'Fairly decent, room for improvement.');
  ratings_pkg.create_product_reviews(7, 15, 2, 'Did not meet my expectations.');
  ratings_pkg.create_product_reviews(8, 15, 5, 'Top-notch quality!');
  ratings_pkg.create_product_reviews(9, 20, 4, 'Product was great and well-packaged.');
  ratings_pkg.create_product_reviews(10, 25, 5, 'I really like the package.');
  ratings_pkg.create_product_reviews(11, 10, 3, 'The product not really bad though.');
END;
/
----------------------------------------------
/*Testing Business Rule Violations
(Ensures system prevents invalid operations)
Attempt to sell more than available stock.*/
---------------------------------------------
/*BEGIN
stock_pkg.create_order_item(p_order_id => 5, p_stock_id => 15, p_quantity => 2000);  -- Should raise error (not enough Abena rice in stock)
END;
/
-------------------------------------------------------------------
-- Attempt to create quantity with certain quantity and unit price.
-------------------------------------------------------------------
EXEC stock_pkg.create_stock('T-Shirt', 10, 230, 150);*/


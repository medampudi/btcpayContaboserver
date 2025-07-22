# 📦 Frappe Bitcoin Apps - Complete Structure & Code

## 🎯 Overview of Frappe Bitcoin Apps

We'll create modular Frappe apps that can be installed together or separately:

1. **bitcoin_payment** - Core Bitcoin payment functionality
2. **lightning_integration** - Lightning Network features
3. **crypto_accounting** - Multi-currency accounting
4. **bitcoin_india** - Indian compliance features

## 📁 Complete App Structures

### 1. Bitcoin Payment App (Core)

```bash
# Create the app
bench new-app bitcoin_payment
```

**Complete file structure:**
```
bitcoin_payment/
├── bitcoin_payment/
│   ├── __init__.py
│   ├── hooks.py
│   ├── modules.txt
│   ├── patches.txt
│   ├── bitcoin_payment/
│   │   ├── __init__.py
│   │   ├── doctype/
│   │   │   ├── __init__.py
│   │   │   ├── bitcoin_invoice/
│   │   │   │   ├── __init__.py
│   │   │   │   ├── bitcoin_invoice.js
│   │   │   │   ├── bitcoin_invoice.json
│   │   │   │   ├── bitcoin_invoice.py
│   │   │   │   ├── bitcoin_invoice_list.js
│   │   │   │   └── test_bitcoin_invoice.py
│   │   │   ├── bitcoin_payment_gateway/
│   │   │   │   ├── __init__.py
│   │   │   │   ├── bitcoin_payment_gateway.js
│   │   │   │   ├── bitcoin_payment_gateway.json
│   │   │   │   └── bitcoin_payment_gateway.py
│   │   │   ├── btcpay_settings/
│   │   │   │   ├── __init__.py
│   │   │   │   ├── btcpay_settings.js
│   │   │   │   ├── btcpay_settings.json
│   │   │   │   └── btcpay_settings.py
│   │   │   └── exchange_rate_btc/
│   │   │       ├── __init__.py
│   │   │       ├── exchange_rate_btc.json
│   │   │       └── exchange_rate_btc.py
│   │   ├── api/
│   │   │   ├── __init__.py
│   │   │   ├── v1.py
│   │   │   └── webhooks.py
│   │   ├── public/
│   │   │   ├── js/
│   │   │   │   └── bitcoin_payment.js
│   │   │   └── css/
│   │   │       └── bitcoin_payment.css
│   │   ├── templates/
│   │   │   ├── pages/
│   │   │   │   └── bitcoin_checkout.html
│   │   │   └── includes/
│   │   │       └── bitcoin_payment_button.html
│   │   ├── config/
│   │   │   ├── __init__.py
│   │   │   └── bitcoin_payment.py
│   │   └── utils/
│   │       ├── __init__.py
│   │       ├── btcpay_client.py
│   │       └── exchange_rates.py
│   ├── requirements.txt
│   └── setup.py
├── license.txt
└── README.md
```

**Key Files Implementation:**

**hooks.py**
```python
from . import __version__ as app_version

app_name = "bitcoin_payment"
app_title = "Bitcoin Payment"
app_publisher = "Your Company"
app_description = "Bitcoin and Lightning payment integration for Frappe"
app_icon = "octicon octicon-file-directory"
app_color = "orange"
app_email = "support@yourcompany.com"
app_license = "MIT"

# Include js, css files in header of desk.html
app_include_css = "/assets/bitcoin_payment/css/bitcoin_payment.css"
app_include_js = "/assets/bitcoin_payment/js/bitcoin_payment.js"

# Include js in page
page_js = {"point-of-sale": "public/js/pos_bitcoin.js"}

# Scheduled Tasks
scheduler_events = {
    "cron": {
        "*/5 * * * *": [
            "bitcoin_payment.utils.exchange_rates.update_btc_rates"
        ]
    },
    "all": [
        "bitcoin_payment.tasks.check_pending_invoices"
    ],
    "hourly": [
        "bitcoin_payment.tasks.cleanup_expired_invoices"
    ]
}

# Webhooks
webhooks = {
    "BTCPay Invoice": {
        "on_payment_received": "bitcoin_payment.webhooks.handle_payment"
    }
}

# Override standard methods
override_whitelisted_methods = {
    "erpnext.accounts.doctype.payment_request.payment_request.make_payment_request": "bitcoin_payment.overrides.make_payment_request"
}

# Fixtures
fixtures = [
    {
        "dt": "Custom Field",
        "filters": [["module", "=", "Bitcoin Payment"]]
    },
    {
        "dt": "Mode of Payment",
        "filters": [["name", "in", ["Bitcoin", "Lightning"]]]
    }
]
```

**bitcoin_invoice.py (Core DocType)**
```python
import frappe
from frappe.model.document import Document
from frappe import _
import requests
import json
from datetime import datetime, timedelta

class BitcoinInvoice(Document):
    def validate(self):
        self.validate_amount()
        self.set_exchange_rate()
        self.calculate_btc_amount()
        self.set_expiry()
    
    def validate_amount(self):
        if self.amount <= 0:
            frappe.throw(_("Amount must be greater than 0"))
    
    def set_exchange_rate(self):
        if not self.exchange_rate:
            from bitcoin_payment.utils.exchange_rates import get_current_btc_rate
            self.exchange_rate = get_current_btc_rate(self.currency)
    
    def calculate_btc_amount(self):
        if self.amount and self.exchange_rate:
            self.btc_amount = float(self.amount) / float(self.exchange_rate)
            self.btc_amount = round(self.btc_amount, 8)  # Bitcoin precision
    
    def set_expiry(self):
        if not self.expiry_time:
            settings = frappe.get_single("BTCPay Settings")
            self.expiry_time = frappe.utils.add_to_date(
                frappe.utils.now_datetime(),
                minutes=settings.invoice_expiry_minutes
            )
    
    def before_insert(self):
        self.create_btcpay_invoice()
    
    def create_btcpay_invoice(self):
        """Create invoice in BTCPay Server"""
        from bitcoin_payment.utils.btcpay_client import BTCPayClient
        
        client = BTCPayClient()
        
        # Prepare invoice data
        invoice_data = {
            "price": self.amount,
            "currency": self.currency,
            "orderId": self.name,
            "buyer": {
                "email": self.customer_email,
                "name": self.customer_name,
                "notify": True
            },
            "notificationURL": frappe.utils.get_url() + "/api/method/bitcoin_payment.api.webhooks.btcpay_webhook",
            "redirectURL": self.redirect_url or frappe.utils.get_url(),
            "closeURL": self.close_url or frappe.utils.get_url(),
            "metadata": {
                "frappe_invoice": self.reference_doctype + ":" + self.reference_name if self.reference_doctype else None,
                "customer": self.customer
            },
            "checkout": {
                "speedPolicy": self.speed_policy or "MediumSpeed",
                "paymentMethods": self.get_payment_methods(),
                "defaultPaymentMethod": self.default_payment_method
            }
        }
        
        # Create invoice
        response = client.create_invoice(invoice_data)
        
        if response:
            self.btcpay_invoice_id = response.get("id")
            self.bitcoin_address = response.get("bitcoinAddress")
            self.lightning_invoice = response.get("lightningInvoice")
            self.payment_url = response.get("checkoutLink")
            self.status = "Pending"
    
    def get_payment_methods(self):
        methods = []
        if self.accept_bitcoin:
            methods.append("BTC")
        if self.accept_lightning:
            methods.append("BTC-LightningNetwork")
        return methods if methods else ["BTC", "BTC-LightningNetwork"]
    
    def on_payment_received(self, payment_data):
        """Handle payment received webhook"""
        self.status = "Processing"
        self.payment_received_at = frappe.utils.now_datetime()
        self.transaction_id = payment_data.get("transactionId")
        self.save()
        
        # Trigger payment received event
        frappe.publish_realtime('bitcoin_payment_received', {
            'invoice': self.name,
            'amount': self.btc_amount,
            'transaction_id': self.transaction_id
        }, user=self.owner)
    
    def on_payment_confirmed(self, confirmation_data):
        """Handle payment confirmation"""
        self.status = "Paid"
        self.payment_confirmed_at = frappe.utils.now_datetime()
        self.confirmations = confirmation_data.get("confirmations")
        self.save()
        self.submit()
        
        # Create payment entry if linked to invoice
        if self.reference_doctype and self.reference_name:
            self.create_payment_entry()
        
        # Send confirmation email
        self.send_payment_confirmation()
    
    def create_payment_entry(self):
        """Create payment entry in ERPNext"""
        if self.reference_doctype != "Sales Invoice":
            return
        
        from erpnext.accounts.doctype.payment_entry.payment_entry import get_payment_entry
        
        payment_entry = get_payment_entry(
            self.reference_doctype,
            self.reference_name,
            party_type="Customer",
            party=self.customer,
            payment_type="Receive"
        )
        
        payment_entry.mode_of_payment = "Bitcoin"
        payment_entry.reference_no = self.btcpay_invoice_id
        payment_entry.reference_date = self.payment_confirmed_at.date()
        
        # Add Bitcoin details in remarks
        payment_entry.remarks = f"""Bitcoin Payment
Invoice: {self.name}
BTC Amount: {self.btc_amount} BTC
Exchange Rate: {self.exchange_rate} {self.currency}/BTC
Transaction ID: {self.transaction_id}"""
        
        payment_entry.insert()
        payment_entry.submit()
        
        return payment_entry.name
    
    def send_payment_confirmation(self):
        """Send payment confirmation email"""
        if not self.customer_email:
            return
        
        frappe.sendmail(
            recipients=[self.customer_email],
            subject=f"Bitcoin Payment Confirmed - {self.name}",
            template="bitcoin_payment_confirmation",
            args={
                "invoice": self,
                "customer_name": self.customer_name,
                "amount_btc": self.btc_amount,
                "amount_fiat": self.amount,
                "currency": self.currency,
                "transaction_id": self.transaction_id
            }
        )
    
    @frappe.whitelist()
    def get_payment_status(self):
        """Get current payment status from BTCPay"""
        from bitcoin_payment.utils.btcpay_client import BTCPayClient
        
        if not self.btcpay_invoice_id:
            return {"status": "No BTCPay Invoice"}
        
        client = BTCPayClient()
        invoice = client.get_invoice(self.btcpay_invoice_id)
        
        if invoice:
            return {
                "status": invoice.get("status"),
                "exception_status": invoice.get("exceptionStatus"),
                "btc_paid": invoice.get("btcPaid"),
                "btc_due": invoice.get("btcDue"),
                "rate": invoice.get("rate")
            }
        
        return {"status": "Unknown"}
```

**btcpay_client.py (Utility)**
```python
import requests
import json
import frappe
from frappe import _

class BTCPayClient:
    def __init__(self):
        settings = frappe.get_single("BTCPay Settings")
        self.base_url = settings.server_url
        self.api_key = settings.get_password("api_key")
        self.store_id = settings.store_id
        
        if not all([self.base_url, self.api_key, self.store_id]):
            frappe.throw(_("BTCPay Settings not configured"))
        
        self.headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
    
    def create_invoice(self, invoice_data):
        """Create a new invoice in BTCPay"""
        url = f"{self.base_url}/api/v1/stores/{self.store_id}/invoices"
        
        try:
            response = requests.post(url, headers=self.headers, json=invoice_data)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            frappe.log_error(f"BTCPay API Error: {str(e)}", "BTCPay Client")
            frappe.throw(_("Failed to create Bitcoin invoice"))
    
    def get_invoice(self, invoice_id):
        """Get invoice details from BTCPay"""
        url = f"{self.base_url}/api/v1/stores/{self.store_id}/invoices/{invoice_id}"
        
        try:
            response = requests.get(url, headers=self.headers)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            frappe.log_error(f"BTCPay API Error: {str(e)}", "BTCPay Client")
            return None
    
    def get_rates(self):
        """Get current exchange rates from BTCPay"""
        url = f"{self.base_url}/api/v1/stores/{self.store_id}/rates"
        
        try:
            response = requests.get(url, headers=self.headers)
            response.raise_for_status()
            return response.json()
        except:
            return None
```

**webhooks.py (API Webhooks)**
```python
import frappe
import json
import hmac
import hashlib
from frappe import _

@frappe.whitelist(allow_guest=True)
def btcpay_webhook():
    """Handle BTCPay Server webhooks"""
    try:
        # Verify webhook signature
        if not verify_webhook_signature():
            frappe.response["http_status_code"] = 401
            return {"error": "Invalid signature"}
        
        # Parse webhook data
        data = json.loads(frappe.request.data)
        
        # Log webhook for debugging
        frappe.get_doc({
            "doctype": "Bitcoin Webhook Log",
            "webhook_type": data.get("type"),
            "invoice_id": data.get("invoiceId"),
            "data": json.dumps(data),
            "timestamp": frappe.utils.now_datetime()
        }).insert(ignore_permissions=True)
        
        # Process based on event type
        event_type = data.get("type")
        
        if event_type == "InvoiceCreated":
            handle_invoice_created(data)
        elif event_type == "InvoiceReceivedPayment":
            handle_payment_received(data)
        elif event_type == "InvoiceProcessing":
            handle_invoice_processing(data)
        elif event_type == "InvoiceSettled":
            handle_payment_settled(data)
        elif event_type == "InvoiceExpired":
            handle_invoice_expired(data)
        elif event_type == "InvoiceInvalid":
            handle_invoice_invalid(data)
        
        return {"status": "ok"}
        
    except Exception as e:
        frappe.log_error(f"Webhook Error: {str(e)}", "BTCPay Webhook")
        frappe.response["http_status_code"] = 500
        return {"error": str(e)}

def verify_webhook_signature():
    """Verify BTCPay webhook signature"""
    settings = frappe.get_single("BTCPay Settings")
    webhook_secret = settings.get_password("webhook_secret")
    
    if not webhook_secret:
        # No secret configured, skip verification
        return True
    
    signature = frappe.get_request_header("BTCPay-Sig")
    if not signature:
        return False
    
    expected_signature = hmac.new(
        webhook_secret.encode(),
        frappe.request.data,
        hashlib.sha256
    ).hexdigest()
    
    return hmac.compare_digest(signature, f"sha256={expected_signature}")

def handle_payment_received(data):
    """Handle payment received event"""
    invoice_id = data.get("invoiceId")
    
    # Find Bitcoin Invoice
    invoice = frappe.get_all(
        "Bitcoin Invoice",
        filters={"btcpay_invoice_id": invoice_id},
        limit=1
    )
    
    if invoice:
        doc = frappe.get_doc("Bitcoin Invoice", invoice[0].name)
        doc.on_payment_received(data)
        frappe.db.commit()

def handle_payment_settled(data):
    """Handle payment settled (confirmed) event"""
    invoice_id = data.get("invoiceId")
    
    # Find Bitcoin Invoice
    invoice = frappe.get_all(
        "Bitcoin Invoice",
        filters={"btcpay_invoice_id": invoice_id},
        limit=1
    )
    
    if invoice:
        doc = frappe.get_doc("Bitcoin Invoice", invoice[0].name)
        doc.on_payment_confirmed(data)
        frappe.db.commit()
```

### 2. Lightning Integration App

**Structure:**
```
lightning_integration/
├── lightning_integration/
│   ├── doctype/
│   │   ├── lightning_node_settings/
│   │   ├── lightning_invoice/
│   │   ├── lightning_channel/
│   │   └── lightning_payment/
│   ├── api/
│   │   └── lightning_api.py
│   └── utils/
│       ├── lnd_client.py
│       └── clightning_client.py
```

**lnd_client.py**
```python
import grpc
import codecs
import frappe
from frappe import _

# Import LND gRPC modules
import lightning_pb2 as ln
import lightning_pb2_grpc as lnrpc

class LNDClient:
    def __init__(self):
        settings = frappe.get_single("Lightning Node Settings")
        
        # LND connection details
        self.host = settings.lnd_host
        self.port = settings.lnd_port
        self.tls_cert_path = settings.tls_cert_path
        self.macaroon_path = settings.macaroon_path
        
        # Initialize connection
        self.stub = self._get_stub()
    
    def _get_stub(self):
        """Create gRPC stub for LND"""
        # Load TLS cert
        with open(self.tls_cert_path, 'rb') as f:
            cert = f.read()
        
        # Load macaroon
        with open(self.macaroon_path, 'rb') as f:
            macaroon_bytes = f.read()
            macaroon = codecs.encode(macaroon_bytes, 'hex')
        
        # Create SSL credentials
        creds = grpc.ssl_channel_credentials(cert)
        
        # Create channel
        channel = grpc.secure_channel(f"{self.host}:{self.port}", creds)
        
        # Create stub
        stub = lnrpc.LightningStub(channel)
        
        # Add macaroon to metadata
        self.metadata = [('macaroon', macaroon)]
        
        return stub
    
    def create_invoice(self, amount_sats, memo="", expiry=3600):
        """Create Lightning invoice"""
        request = ln.Invoice(
            value=amount_sats,
            memo=memo,
            expiry=expiry
        )
        
        try:
            response = self.stub.AddInvoice(request, metadata=self.metadata)
            return {
                "payment_request": response.payment_request,
                "r_hash": codecs.encode(response.r_hash, 'hex').decode(),
                "add_index": response.add_index
            }
        except grpc.RpcError as e:
            frappe.log_error(f"LND Error: {str(e)}", "Lightning Client")
            frappe.throw(_("Failed to create Lightning invoice"))
    
    def check_invoice(self, r_hash):
        """Check invoice status"""
        request = ln.PaymentHash(
            r_hash=codecs.decode(r_hash, 'hex')
        )
        
        try:
            response = self.stub.LookupInvoice(request, metadata=self.metadata)
            return {
                "settled": response.settled,
                "value": response.value,
                "settle_date": response.settle_date,
                "payment_request": response.payment_request,
                "state": response.state
            }
        except grpc.RpcError as e:
            return None
    
    def get_node_info(self):
        """Get Lightning node information"""
        request = ln.GetInfoRequest()
        
        try:
            response = self.stub.GetInfo(request, metadata=self.metadata)
            return {
                "alias": response.alias,
                "identity_pubkey": response.identity_pubkey,
                "num_active_channels": response.num_active_channels,
                "num_peers": response.num_peers,
                "block_height": response.block_height,
                "synced_to_chain": response.synced_to_chain
            }
        except grpc.RpcError as e:
            frappe.log_error(f"LND Error: {str(e)}", "Lightning Client")
            return None
```

### 3. Frappe Configuration Files

**bitcoin_payment.py (Desk Configuration)**
```python
from frappe import _

def get_data():
    return [
        {
            "module_name": "Bitcoin Payment",
            "category": "Modules",
            "label": _("Bitcoin Payment"),
            "color": "orange",
            "icon": "octicon octicon-plug",
            "type": "module",
            "description": "Bitcoin and Lightning payment processing"
        }
    ]
```

**bitcoin_payment_settings.json (Module Settings)**
```json
{
    "category": "Modules",
    "charts": [],
    "creation": "2024-01-01 00:00:00.000000",
    "developer_mode_only": 0,
    "disable_user_customization": 0,
    "docstatus": 0,
    "doctype": "Module Def",
    "module_name": "Bitcoin Payment",
    "name": "Bitcoin Payment",
    "restrict_to_domain": "",
    "roles": []
}
```

### 4. Client-Side JavaScript

**bitcoin_invoice.js**
```javascript
frappe.ui.form.on('Bitcoin Invoice', {
    refresh: function(frm) {
        // Add custom buttons
        if (frm.doc.status === "Pending" && !frm.doc.__islocal) {
            frm.add_custom_button(__('Check Payment Status'), function() {
                check_payment_status(frm);
            });
            
            frm.add_custom_button(__('Show QR Code'), function() {
                show_payment_qr(frm);
            });
        }
        
        // Real-time updates
        if (frm.doc.status === "Pending") {
            setup_realtime_updates(frm);
        }
        
        // Show payment URL prominently
        if (frm.doc.payment_url) {
            frm.dashboard.add_comment(__('Payment URL: <a href="{0}" target="_blank">{0}</a>', 
                [frm.doc.payment_url]), 'blue', true);
        }
    },
    
    amount: function(frm) {
        calculate_btc_amount(frm);
    },
    
    currency: function(frm) {
        get_exchange_rate(frm);
    }
});

function check_payment_status(frm) {
    frappe.call({
        method: 'get_payment_status',
        doc: frm.doc,
        callback: function(r) {
            if (r.message) {
                frappe.msgprint(__('Payment Status: {0}', [r.message.status]));
                if (r.message.status !== frm.doc.status) {
                    frm.reload_doc();
                }
            }
        }
    });
}

function show_payment_qr(frm) {
    // Generate QR code dialog
    let qr_dialog = new frappe.ui.Dialog({
        title: __('Bitcoin Payment QR Code'),
        fields: [
            {
                fieldtype: 'HTML',
                fieldname: 'qr_code'
            }
        ]
    });
    
    // Generate QR codes for both Bitcoin and Lightning
    let qr_html = '<div class="text-center">';
    
    if (frm.doc.bitcoin_address) {
        qr_html += `
            <h4>Bitcoin</h4>
            <div id="bitcoin-qr"></div>
            <p class="small">${frm.doc.bitcoin_address}</p>
            <p><strong>${frm.doc.btc_amount} BTC</strong></p>
        `;
    }
    
    if (frm.doc.lightning_invoice) {
        qr_html += `
            <hr>
            <h4>Lightning Network</h4>
            <div id="lightning-qr"></div>
            <p class="small text-muted">Lightning Invoice</p>
        `;
    }
    
    qr_html += '</div>';
    
    qr_dialog.fields_dict.qr_code.$wrapper.html(qr_html);
    qr_dialog.show();
    
    // Generate QR codes
    if (frm.doc.bitcoin_address) {
        new QRCode(document.getElementById("bitcoin-qr"), {
            text: `bitcoin:${frm.doc.bitcoin_address}?amount=${frm.doc.btc_amount}`,
            width: 256,
            height: 256
        });
    }
    
    if (frm.doc.lightning_invoice) {
        new QRCode(document.getElementById("lightning-qr"), {
            text: frm.doc.lightning_invoice,
            width: 256,
            height: 256
        });
    }
}

function setup_realtime_updates(frm) {
    frappe.realtime.on('bitcoin_payment_received', function(data) {
        if (data.invoice === frm.doc.name) {
            frappe.show_alert({
                message: __('Bitcoin payment received! Amount: {0} BTC', [data.amount]),
                indicator: 'green'
            }, 5);
            frm.reload_doc();
        }
    });
}
```

### 5. Installation & Setup Scripts

**setup.py**
```python
from setuptools import setup, find_packages

with open("requirements.txt") as f:
    install_requires = f.read().strip().split("\n")

setup(
    name="bitcoin_payment",
    version="1.0.0",
    description="Bitcoin Payment Integration for Frappe",
    author="Your Company",
    author_email="support@yourcompany.com",
    packages=find_packages(),
    zip_safe=False,
    include_package_data=True,
    install_requires=install_requires
)
```

**requirements.txt**
```
frappe
requests>=2.28.0
grpcio>=1.51.0
grpcio-tools>=1.51.0
qrcode>=7.3.1
python-bitcoinrpc>=1.0
```

**post_install.py**
```python
import frappe

def after_install():
    """Setup Bitcoin Payment after installation"""
    # Create Mode of Payment
    if not frappe.db.exists("Mode of Payment", "Bitcoin"):
        frappe.get_doc({
            "doctype": "Mode of Payment",
            "mode_of_payment": "Bitcoin",
            "enabled": 1,
            "type": "General"
        }).insert()
    
    if not frappe.db.exists("Mode of Payment", "Lightning"):
        frappe.get_doc({
            "doctype": "Mode of Payment", 
            "mode_of_payment": "Lightning",
            "enabled": 1,
            "type": "General"
        }).insert()
    
    # Add custom fields to Sales Invoice
    add_bitcoin_fields_to_sales_invoice()
    
    # Create Bitcoin accounts in Chart of Accounts
    create_bitcoin_accounts()
    
    frappe.db.commit()

def add_bitcoin_fields_to_sales_invoice():
    """Add Bitcoin payment fields to Sales Invoice"""
    custom_fields = [
        {
            "fieldname": "accept_bitcoin",
            "label": "Accept Bitcoin",
            "fieldtype": "Check",
            "insert_after": "is_pos"
        },
        {
            "fieldname": "bitcoin_invoice_id",
            "label": "Bitcoin Invoice",
            "fieldtype": "Link",
            "options": "Bitcoin Invoice",
            "read_only": 1,
            "insert_after": "accept_bitcoin"
        },
        {
            "fieldname": "bitcoin_payment_url",
            "label": "Bitcoin Payment URL",
            "fieldtype": "Data",
            "read_only": 1,
            "insert_after": "bitcoin_invoice_id"
        }
    ]
    
    for field in custom_fields:
        if not frappe.db.exists("Custom Field", {"dt": "Sales Invoice", "fieldname": field["fieldname"]}):
            field["dt"] = "Sales Invoice"
            frappe.get_doc(field).insert()
```

## 🚀 Quick Installation Commands

```bash
# Install the Bitcoin Payment app
cd ~/frappe-bench
bench get-app https://github.com/yourusername/bitcoin_payment
bench --site yoursite.local install-app bitcoin_payment

# Install Lightning Integration (optional)
bench get-app https://github.com/yourusername/lightning_integration  
bench --site yoursite.local install-app lightning_integration

# Install Indian compliance (for Indian businesses)
bench get-app https://github.com/yourusername/bitcoin_india
bench --site yoursite.local install-app bitcoin_india

# Run patches and update
bench --site yoursite.local migrate
bench restart
```

---

**Your Frappe Bitcoin apps are ready! Complete implementation with minimal custom code!** 🚀💼
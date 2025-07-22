# 🔌 Business Services Integration Guide
## Complete Integration Stack for Bitcoin Business Infrastructure

### 📊 ERP & Accounting Integrations

## 1. SAP Integration

```yaml
# docker-compose-sap.yml
  sap-bitcoin-connector:
    build: ./sap-connector
    container_name: sap-bitcoin
    restart: unless-stopped
    networks:
      business:
        ipv4_address: 172.30.0.120
    environment:
      - SAP_HOST=${SAP_HOST}
      - SAP_CLIENT=${SAP_CLIENT}
      - SAP_USER=${SAP_USER}
      - SAP_PASSWORD=${SAP_PASSWORD}
      - BTCPAY_API=${BTCPAY_API_KEY}
    volumes:
      - sap_data:/app/data
```

**SAP ABAP Function Module**
```abap
FUNCTION Z_BITCOIN_PAYMENT_PROCESS.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(I_INVOICE_ID) TYPE VBELN
*"     VALUE(I_AMOUNT) TYPE WRBTR
*"     VALUE(I_CURRENCY) TYPE WAERS
*"  EXPORTING
*"     VALUE(E_BITCOIN_ADDRESS) TYPE STRING
*"     VALUE(E_AMOUNT_BTC) TYPE P DECIMALS 8
*"     VALUE(E_PAYMENT_URL) TYPE STRING
*"     VALUE(E_SUCCESS) TYPE BOOLEAN
*"----------------------------------------------------------------------

  DATA: lo_http_client TYPE REF TO if_http_client,
        lv_json_string TYPE string,
        lv_response    TYPE string.

  " Create HTTP client for BTCPay Server
  cl_http_client=>create_by_url(
    EXPORTING
      url = 'https://btcpay.company.com/api/v1/invoices'
    IMPORTING
      client = lo_http_client ).

  " Set request method and headers
  lo_http_client->request->set_method( 'POST' ).
  lo_http_client->request->set_header_field(
    name  = 'Authorization'
    value = |Bearer { sy-sysid }| ).

  " Prepare invoice data
  lv_json_string = |{ "price": { lv_amount }, "currency": "{ lv_currency }" }|.
  lo_http_client->request->set_cdata( lv_json_string ).

  " Send request
  lo_http_client->send( ).
  lo_http_client->receive( ).

  " Process response
  lv_response = lo_http_client->response->get_cdata( ).
  
  " Parse Bitcoin payment details
  e_bitcoin_address = extract_json_value( lv_response, 'bitcoinAddress' ).
  e_amount_btc = extract_json_value( lv_response, 'btcAmount' ).
  e_payment_url = extract_json_value( lv_response, 'checkoutLink' ).
  e_success = abap_true.

ENDFUNCTION.
```

## 2. Oracle NetSuite Integration

```javascript
// netsuite-bitcoin-integration.js
define(['N/https', 'N/record', 'N/search'], 
function(https, record, search) {
    
    function createBitcoinInvoice(context) {
        var invoice = context.newRecord;
        var customerId = invoice.getValue('entity');
        var amount = invoice.getValue('total');
        
        // Call BTCPay Server API
        var response = https.post({
            url: 'https://btcpay.company.com/api/v1/invoices',
            headers: {
                'Authorization': 'Bearer ' + CONFIG.BTCPAY_API_KEY,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                price: amount,
                currency: 'USD',
                orderId: invoice.getValue('tranid'),
                buyer: {
                    email: getCustomerEmail(customerId)
                },
                redirectURL: 'https://erp.company.com/invoice-paid',
                notificationURL: 'https://erp.company.com/webhooks/btcpay'
            })
        });
        
        var btcInvoice = JSON.parse(response.body);
        
        // Update NetSuite invoice with Bitcoin details
        invoice.setValue('custbody_btc_address', btcInvoice.bitcoinAddress);
        invoice.setValue('custbody_btc_amount', btcInvoice.btcAmount);
        invoice.setValue('custbody_btc_invoice_url', btcInvoice.url);
        
        return true;
    }
    
    return {
        beforeSubmit: createBitcoinInvoice
    };
});
```

## 3. Microsoft Dynamics 365 Integration

```csharp
// Dynamics365BitcoinPlugin.cs
using Microsoft.Xrm.Sdk;
using System;
using System.Net.Http;
using Newtonsoft.Json;

namespace BitcoinIntegration
{
    public class BitcoinInvoicePlugin : IPlugin
    {
        public void Execute(IServiceProvider serviceProvider)
        {
            var context = (IPluginExecutionContext)serviceProvider
                .GetService(typeof(IPluginExecutionContext));
            
            if (context.MessageName != "Create" || 
                context.PrimaryEntityName != "invoice")
                return;
            
            var invoice = (Entity)context.InputParameters["Target"];
            var amount = invoice.GetAttributeValue<Money>("totalamount");
            
            // Create Bitcoin invoice
            var btcInvoice = CreateBTCPayInvoice(amount.Value);
            
            // Update invoice with Bitcoin payment option
            invoice["btc_address"] = btcInvoice.BitcoinAddress;
            invoice["btc_amount"] = btcInvoice.BtcAmount;
            invoice["btc_payment_url"] = btcInvoice.CheckoutLink;
            invoice["btc_qr_code"] = GenerateQRCode(btcInvoice.BitcoinAddress);
        }
        
        private BTCPayInvoice CreateBTCPayInvoice(decimal amount)
        {
            using (var client = new HttpClient())
            {
                client.DefaultRequestHeaders.Add("Authorization", 
                    $"Bearer {ConfigurationManager.AppSettings["BTCPayApiKey"]}");
                
                var content = new StringContent(JsonConvert.SerializeObject(new
                {
                    price = amount,
                    currency = "USD",
                    speedPolicy = "MediumSpeed"
                }));
                
                var response = client.PostAsync(
                    "https://btcpay.company.com/api/v1/invoices", 
                    content).Result;
                    
                return JsonConvert.DeserializeObject<BTCPayInvoice>(
                    response.Content.ReadAsStringAsync().Result);
            }
        }
    }
}
```

## 4. QuickBooks Integration

```python
# quickbooks_bitcoin_sync.py
from quickbooks import QuickBooks
from btcpay import BTCPayClient
import schedule
import time

class QuickBooksBitcoinSync:
    def __init__(self):
        self.qb = QuickBooks(
            client_id=os.environ['QB_CLIENT_ID'],
            client_secret=os.environ['QB_CLIENT_SECRET'],
            refresh_token=os.environ['QB_REFRESH_TOKEN'],
            company_id=os.environ['QB_COMPANY_ID']
        )
        
        self.btcpay = BTCPayClient(
            host=os.environ['BTCPAY_HOST'],
            api_key=os.environ['BTCPAY_API_KEY']
        )
        
    def sync_bitcoin_payments(self):
        """Sync Bitcoin payments from BTCPay to QuickBooks"""
        # Get new Bitcoin payments
        btc_payments = self.btcpay.get_invoices(status='complete')
        
        for payment in btc_payments:
            # Check if already synced
            if self.payment_exists_in_qb(payment['id']):
                continue
                
            # Create payment in QuickBooks
            qb_payment = {
                'TotalAmt': payment['price'],
                'CustomerRef': {'value': self.get_qb_customer_id(payment)},
                'DepositToAccountRef': {'value': '1'},  # Bitcoin wallet account
                'PaymentMethodRef': {'value': '99'},  # Bitcoin payment method
                'PrivateNote': f"Bitcoin payment - {payment['btcPaid']} BTC",
                'PaymentRefNum': payment['id']
            }
            
            self.qb.create_payment(qb_payment)
            
            # Create journal entry for Bitcoin conversion
            if payment['rate']:
                self.create_conversion_entry(payment)
    
    def create_conversion_entry(self, payment):
        """Create journal entry for BTC to USD conversion"""
        journal_entry = {
            'DocNumber': f"BTC-{payment['id']}",
            'TxnDate': payment['paidDate'],
            'PrivateNote': f"Bitcoin rate: ${payment['rate']}",
            'Line': [
                {
                    'Description': 'Bitcoin received',
                    'Amount': payment['price'],
                    'DetailType': 'JournalEntryLineDetail',
                    'JournalEntryLineDetail': {
                        'PostingType': 'Debit',
                        'AccountRef': {'value': '101'}  # Bitcoin Asset
                    }
                },
                {
                    'Description': 'Revenue from Bitcoin sale',
                    'Amount': payment['price'],
                    'DetailType': 'JournalEntryLineDetail',
                    'JournalEntryLineDetail': {
                        'PostingType': 'Credit',
                        'AccountRef': {'value': '400'}  # Sales Revenue
                    }
                }
            ]
        }
        
        self.qb.create_journal_entry(journal_entry)
```

## 5. Xero Integration

```javascript
// xero-bitcoin-integration.js
const XeroClient = require('xero-node').XeroClient;
const BTCPayClient = require('btcpay-node');

class XeroBitcoinIntegration {
    constructor() {
        this.xero = new XeroClient({
            clientId: process.env.XERO_CLIENT_ID,
            clientSecret: process.env.XERO_CLIENT_SECRET,
            redirectUris: [process.env.XERO_REDIRECT_URI],
            scopes: ['accounting.transactions', 'accounting.contacts']
        });
        
        this.btcpay = new BTCPayClient({
            host: process.env.BTCPAY_HOST,
            apiKey: process.env.BTCPAY_API_KEY
        });
    }
    
    async createBitcoinInvoice(xeroInvoice) {
        // Create corresponding BTCPay invoice
        const btcInvoice = await this.btcpay.createInvoice({
            price: xeroInvoice.total,
            currency: xeroInvoice.currencyCode,
            orderId: xeroInvoice.invoiceNumber,
            buyer: {
                email: xeroInvoice.contact.email,
                name: xeroInvoice.contact.name
            },
            metadata: {
                xeroInvoiceId: xeroInvoice.invoiceID,
                xeroContactId: xeroInvoice.contact.contactID
            }
        });
        
        // Add Bitcoin payment details to Xero invoice
        await this.xero.accountingApi.updateInvoice(
            xeroInvoice.invoiceID,
            {
                invoiceNumber: xeroInvoice.invoiceNumber,
                reference: `Bitcoin: ${btcInvoice.bitcoinAddress}`,
                url: btcInvoice.checkoutLink
            }
        );
        
        return btcInvoice;
    }
    
    async reconcileBitcoinPayment(btcPayment) {
        // Create bank transaction in Xero
        const bankTransaction = {
            type: 'RECEIVE',
            contact: { contactID: btcPayment.metadata.xeroContactId },
            lineItems: [{
                description: 'Bitcoin payment received',
                unitAmount: btcPayment.price,
                accountCode: '200' // Sales account
            }],
            bankAccount: { accountID: process.env.XERO_BTC_ACCOUNT_ID },
            date: new Date(btcPayment.paidDate),
            reference: btcPayment.id
        };
        
        const transaction = await this.xero.accountingApi.createBankTransaction(
            bankTransaction
        );
        
        // Reconcile with invoice
        await this.xero.accountingApi.createPayment({
            invoice: { invoiceID: btcPayment.metadata.xeroInvoiceId },
            account: { accountID: process.env.XERO_BTC_ACCOUNT_ID },
            amount: btcPayment.price,
            date: new Date(btcPayment.paidDate)
        });
    }
}
```

## 📦 E-commerce Platform Integrations

### 1. WooCommerce Advanced Integration

```php
// woocommerce-bitcoin-advanced.php
class WC_Bitcoin_Advanced_Gateway extends WC_Payment_Gateway {
    
    public function __construct() {
        $this->id = 'bitcoin_advanced';
        $this->icon = plugins_url('bitcoin-icon.png', __FILE__);
        $this->has_fields = true;
        $this->method_title = 'Bitcoin (Advanced)';
        
        $this->init_form_fields();
        $this->init_settings();
        
        // Lightning Network priority
        $this->lightning_preferred = $this->get_option('lightning_preferred') === 'yes';
        $this->auto_convert_fiat = $this->get_option('auto_convert') === 'yes';
        $this->offer_discount = $this->get_option('bitcoin_discount');
    }
    
    public function process_payment($order_id) {
        $order = wc_get_order($order_id);
        $amount = $order->get_total();
        
        // Apply Bitcoin discount if configured
        if ($this->offer_discount > 0) {
            $discount = $amount * ($this->offer_discount / 100);
            $amount = $amount - $discount;
            $order->add_order_note(
                sprintf('Bitcoin discount applied: %s%%', $this->offer_discount)
            );
        }
        
        // Create BTCPay invoice with advanced options
        $invoice = $this->create_btcpay_invoice([
            'price' => $amount,
            'currency' => get_woocommerce_currency(),
            'orderId' => $order->get_order_number(),
            'speedPolicy' => $this->get_option('confirmation_speed'),
            'paymentMethods' => $this->get_payment_methods(),
            'notificationURL' => $this->get_webhook_url(),
            'redirectURL' => $this->get_return_url($order),
            'closeURL' => $order->get_cancel_order_url(),
            'metadata' => [
                'orderId' => $order_id,
                'customerEmail' => $order->get_billing_email(),
                'source' => 'woocommerce',
                'discount_applied' => $this->offer_discount
            ]
        ]);
        
        // Save invoice details
        $order->update_meta_data('_btcpay_invoice_id', $invoice['id']);
        $order->update_meta_data('_btc_address', $invoice['bitcoinAddress']);
        $order->update_meta_data('_btc_amount', $invoice['btcAmount']);
        $order->save();
        
        // Auto-convert to fiat if enabled
        if ($this->auto_convert_fiat) {
            $this->schedule_auto_conversion($invoice['id'], $amount);
        }
        
        return [
            'result' => 'success',
            'redirect' => $invoice['checkoutLink']
        ];
    }
    
    private function get_payment_methods() {
        $methods = [];
        
        if ($this->get_option('accept_onchain') === 'yes') {
            $methods[] = 'BTC';
        }
        
        if ($this->get_option('accept_lightning') === 'yes') {
            $methods[] = 'BTC-LightningNetwork';
            
            if ($this->lightning_preferred) {
                array_reverse($methods); // Lightning first
            }
        }
        
        return $methods;
    }
}
```

### 2. Shopify Advanced App

```javascript
// shopify-bitcoin-advanced-app.js
const { Shopify } = require('@shopify/shopify-api');
const BTCPayServer = require('btcpay');

class ShopifyBitcoinAdvanced {
    constructor() {
        this.btcpay = new BTCPayServer({
            url: process.env.BTCPAY_URL,
            apiKey: process.env.BTCPAY_API_KEY,
            storeId: process.env.BTCPAY_STORE_ID
        });
        
        this.features = {
            multiCurrency: true,
            subscriptions: true,
            bulkOrders: true,
            customCheckout: true,
            analytics: true
        };
    }
    
    async handleCheckout(session) {
        const shop = session.shop;
        const checkoutId = session.params.checkout_id;
        
        // Get checkout details
        const checkout = await this.getCheckout(shop, checkoutId);
        
        // Handle subscription products
        if (this.hasSubscriptionProducts(checkout)) {
            return this.createSubscriptionInvoice(checkout);
        }
        
        // Handle bulk/wholesale orders
        if (checkout.totalPrice > 1000) {
            return this.createWholesaleInvoice(checkout);
        }
        
        // Standard invoice with advanced features
        const invoice = await this.btcpay.createInvoice({
            price: checkout.totalPrice,
            currency: checkout.currency,
            orderId: checkout.id,
            speedPolicy: this.getSpeedPolicy(checkout),
            paymentMethods: this.getPaymentMethods(checkout),
            buyer: {
                email: checkout.email,
                name: checkout.shippingAddress?.name,
                address1: checkout.shippingAddress?.address1,
                locality: checkout.shippingAddress?.city,
                region: checkout.shippingAddress?.province,
                postalCode: checkout.shippingAddress?.zip,
                country: checkout.shippingAddress?.countryCode
            },
            metadata: {
                shopifyCheckoutId: checkout.id,
                shopifyOrderId: checkout.order?.id,
                customerTags: checkout.customer?.tags,
                isWholesale: checkout.totalPrice > 1000,
                hasSubscription: this.hasSubscriptionProducts(checkout)
            }
        });
        
        // Track analytics
        await this.trackConversion(checkout, invoice);
        
        return invoice;
    }
    
    async createSubscriptionInvoice(checkout) {
        // Create recurring payment setup
        const subscription = await this.btcpay.createPullPayment({
            name: `Subscription for ${checkout.email}`,
            amount: checkout.totalPrice,
            currency: checkout.currency,
            period: this.getSubscriptionPeriod(checkout),
            metadata: {
                shopifyCustomerId: checkout.customer.id,
                products: checkout.lineItems.map(item => item.title)
            }
        });
        
        return subscription;
    }
    
    getSpeedPolicy(checkout) {
        // High-value orders require more confirmations
        if (checkout.totalPrice > 5000) {
            return 'LowSpeed'; // 6 confirmations
        } else if (checkout.totalPrice > 1000) {
            return 'MediumSpeed'; // 1 confirmation
        } else {
            return 'HighSpeed'; // 0 confirmations
        }
    }
}
```

## 🏭 Industry-Specific Solutions

### 1. Manufacturing ERP Integration

```python
# manufacturing_erp_bitcoin.py
class ManufacturingBitcoinERP:
    def __init__(self):
        self.modules = {
            'procurement': ProcurementBitcoin(),
            'sales': SalesBitcoin(),
            'inventory': InventoryBitcoin(),
            'finance': FinanceBitcoin()
        }
        
    def handle_supplier_payment(self, purchase_order):
        """Pay suppliers with Bitcoin for better rates"""
        supplier = self.get_supplier(purchase_order.supplier_id)
        
        if supplier.accepts_bitcoin:
            # Create payment with discount
            payment = {
                'amount': purchase_order.total * 0.97,  # 3% discount
                'currency': purchase_order.currency,
                'recipient': supplier.bitcoin_address,
                'reference': purchase_order.number,
                'payment_terms': supplier.payment_terms
            }
            
            # Multi-sig approval for large payments
            if payment['amount'] > 10000:
                payment['approval_required'] = True
                payment['approvers'] = ['cfo', 'purchase_manager']
            
            return self.process_b2b_bitcoin_payment(payment)
```

### 2. Retail Chain POS System

```javascript
// retail-chain-pos-bitcoin.js
class RetailChainBitcoinPOS {
    constructor() {
        this.stores = {};
        this.centralProcessor = new CentralPaymentProcessor();
    }
    
    async initializeStore(storeId, config) {
        this.stores[storeId] = {
            terminals: {},
            dailyLimit: config.dailyLimit || 10000,
            acceptedMethods: config.acceptedMethods || ['lightning'],
            localNode: config.runLocalNode || false
        };
        
        if (this.stores[storeId].localNode) {
            // Each store runs its own Lightning node
            await this.setupStoreNode(storeId);
        }
    }
    
    async processPayment(storeId, terminalId, amount) {
        const store = this.stores[storeId];
        
        // Check daily limits
        if (await this.checkDailyLimit(storeId, amount)) {
            throw new Error('Daily Bitcoin limit exceeded');
        }
        
        // Route to appropriate processor
        if (amount < 100 && store.acceptedMethods.includes('lightning')) {
            return this.processLightningPayment(storeId, terminalId, amount);
        } else {
            return this.processOnChainPayment(storeId, terminalId, amount);
        }
    }
}
```

## 🔧 Advanced Configuration

### Multi-Store Setup Script
```bash
#!/bin/bash
# setup-multi-store-business.sh

echo "🏪 Setting up Multi-Store Bitcoin Infrastructure"

# Configuration
STORES=("main-store" "online-store" "wholesale" "international")
CURRENCIES=("USD" "EUR" "GBP" "JPY")

# Create stores in BTCPay
for store in "${STORES[@]}"; do
    echo "Creating store: $store"
    
    # Create store via API
    STORE_ID=$(curl -s -X POST \
        -H "Authorization: Bearer $BTCPAY_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"$store\", \"defaultCurrency\": \"USD\"}" \
        $BTCPAY_URL/api/v1/stores | jq -r '.id')
    
    # Configure store settings
    curl -X PUT \
        -H "Authorization: Bearer $BTCPAY_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "speedPolicy": "MediumSpeed",
            "networkFeeMode": "Always",
            "invoiceExpiration": 900,
            "displayExpirationTimer": 300,
            "monitoringExpiration": 86400,
            "paymentTolerance": 0,
            "anyoneCanCreateInvoice": false,
            "requiresRefundEmail": true
        }' \
        $BTCPAY_URL/api/v1/stores/$STORE_ID/settings
    
    # Add payment methods
    for currency in "${CURRENCIES[@]}"; do
        curl -X POST \
            -H "Authorization: Bearer $BTCPAY_API_KEY" \
            -H "Content-Type: application/json" \
            -d "{\"currency\": \"$currency\", \"enabled\": true}" \
            $BTCPAY_URL/api/v1/stores/$STORE_ID/rates
    done
    
    echo "✅ Store $store created with ID: $STORE_ID"
done

echo "🎉 Multi-store setup complete!"
```

---

**Your business Bitcoin infrastructure is enterprise-ready! Complete integration with all major business systems!** 💼🚀
# Uellow Vendor

Native mobile companion to the `uellow_multivendor` portal for the Uellow marketplace. Vendors run their entire store from the phone — orders, products, inventory, payouts, reviews, chat with customers.

## Inside

| Path | What |
| --- | --- |
| `lib/` | Flutter app — 13 screens, bilingual EN+AR with full RTL, Kuwait flag for Arabic. |
| `lib/api/api.dart` | Single-file API client + null-safe models. Talks to `/api/vendor/v1/*`. |
| `lib/screens/` | Tabs: Dashboard / Orders / Products / Finance / Me. Extras: order detail, product detail+edit, chat with customer, wallet, payouts, commissions, reviews+reply, analytics with charts, profile, settings. |
| `odoo_backend/` | Companion Odoo 18 module `uellow_vendor_api`. Drop into addons + `-i uellow_vendor_api`. |
| `assets/` | Uellow logo + Tajawal font for Arabic. |

## Building

```bash
flutter pub get
flutter build apk --release
```

## Hardened from day one

Same defensive patterns we learned in the customer + driver apps:

- `flutter_localizations` + 3 delegates → no AR Material crash (the v2.0.17 bug).
- `is Map`-then-cast in every model → no `'String' is not a subtype of Map` crash (v1.0.1 driver bug).
- `_check_credentials` with credential dict for Odoo 18 auth.
- Vendor sessions live in their own `vendor.session` table — isolated from `mobile.session` (customer) and `driver.session` (driver) so a bug in one cannot break the others.

## Backend endpoints

All under `/api/vendor/v1/*`:

```
auth/login | auth/logout | me | me/push-token
dashboard
orders?state=&search= | orders/<id> | orders/<id>/{confirm,cancel,ship}
products?state=&search= | products/<id> | products/create | products/<id>/{update,stock,delete}
chat/<order_id> | chat/<order_id>/send
reviews | reviews/<id>/reply
wallet
payouts | payouts/<id> | payouts/request
commissions?state=
analytics/{sales,top-products,top-customers}
settings/profile
app/languages
```

Connected to: `uellow.vendor`, `uellow.vendor.wallet`, `uellow.vendor.commission`, `uellow.vendor.payout`, `uellow.commission.plan`, `uellow.wallet.transaction`, `product.template.vendor_id`, `sale.order.vendor_id`, `delivery_carrier_portal` (orders flow through the same trip lines as the driver app).

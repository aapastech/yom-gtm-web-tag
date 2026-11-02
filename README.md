# YOM Analytics: Google Tag Manager web tag

A tag template for [YOM (Your Own Metrics)](https://yom.aapastech.com/), first-party analytics that stays cookieless until a visitor consents. It loads the YOM script, sends your GA4 ecommerce and lead events to YOM, and follows the visitor's choices in your consent banner.

## What it does

- Loads the YOM SDK from `https://yom.aapastech.com/app/cdn/sdk/latest/yom.min.js`. That is the only script it may inject.
- Sends these GA4 dataLayer events to YOM: `view_item`, `add_to_cart`, `begin_checkout`, `purchase`, `refund` and `generate_lead`.
- Uses `transaction_id` as the purchase's event id. If your server also sends the order (for example with the YOM Analytics Server tag), YOM counts it once.
- Reads Google Consent Mode v2. `analytics_storage` sets YOM analytics consent. `ad_storage` together with `ad_user_data` sets marketing consent. Changes made in your banner apply straight away.
- Sends only an allow-list of commerce fields, so `user_data`, emails and other personal fields in the dataLayer are ignored. Page URLs leave the browser as paths, without query strings or fragments.

## Set up

1. In YOM, open **Settings → API keys** and copy your **publishable key** (`yom_pk_…`).
2. In GTM, go to **Templates → Tag templates → Search Gallery**, find **YOM Analytics** and add it.
3. Create a tag with the template, paste the publishable key and pick your consent source.
4. Add two triggers: **All Pages**, and a Custom Event trigger matching `view_item|add_to_cart|begin_checkout|purchase|refund|generate_lead` (tick "Use regex matching").
5. Preview, check the events in YOM's realtime report, then publish.

### Consent

| Setting                                                        | What happens                                                                                                                                                                              |
| -------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Consent source: Google Consent Mode v2, default box ticked     | YOM reads the Consent Mode state when the tag first fires and follows every change after that. Tick the box only if your banner sets a default on the **Consent Initialization** trigger. |
| Consent source: Google Consent Mode v2, default box not ticked | GTM reports consent that was never set as granted, so YOM ignores the state at start-up and stays cookieless until your banner changes it.                                                |
| Consent source: YOM                                            | The tag leaves consent to YOM's own banner or to `YOM.setConsent()` on the page.                                                                                                          |

Global Privacy Control is detected by the YOM script itself. With GPC on, YOM never forwards data to ad platforms.

## Data sent

Purchases and refunds send `transaction_id`, `value`, `currency`, `tax`, `shipping`, `coupon`, `discount`, `affiliation`, `payment_type`, `shipping_tier` and items. Items carry `item_id`, `item_name`, `item_variant`, `item_brand`, categories, list id and name, `coupon`, `discount`, `index`, `price` and `quantity`. Leads send the form id, `value`, `currency` and `lead_source`. Any text value containing `@` is dropped.

## Support

[yom.aapastech.com/contact](https://yom.aapastech.com/contact) · [Privacy](https://yom.aapastech.com/privacy) · [Terms](https://yom.aapastech.com/terms). Issues on this repository are welcome.

Licensed under Apache 2.0. This repository contains the tag template only.

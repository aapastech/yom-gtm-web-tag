___TERMS_OF_SERVICE___

By creating or modifying this file you agree to Google Tag Manager's Community
Template Gallery Developer Terms of Service available at
https://developers.google.com/tag-manager/gallery-tos (or such other URL as
Google may provide), as modified from time to time.


___INFO___

{
  "type": "TAG",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "YOM Analytics",
  "categories": [
    "ANALYTICS",
    "CONVERSIONS"
  ],
  "brand": {
    "id": "github.com_aapastech",
    "displayName": "YOM (Your Own Metrics)"
  },
  "description": "Loads YOM, privacy-first first-party analytics, and sends GA4 ecommerce events (view_item, add_to_cart, begin_checkout, purchase, refund) and generate_lead to it. Reads Google Consent Mode v2 and keeps YOM cookieless until analytics consent is granted. Docs: https://github.com/aapastech/yom-gtm-web-tag",
  "containerContexts": [
    "WEB"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "TEXT",
    "name": "publishableKey",
    "displayName": "Publishable key",
    "simpleValueType": true,
    "alwaysInSummary": true,
    "help": "Your YOM publishable key, for example <strong>yom_pk_live_…</strong>. Find it in YOM under Settings → API keys. Never paste a secret key (yom_sk_…) here: this tag runs in the browser.",
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      },
      {
        "type": "REGEX",
        "args": [
          "^(yom_pk_\\S+|\\{\\{[^}]+\\}\\})$"
        ],
        "errorMessage": "Enter a publishable key that starts with yom_pk_."
      }
    ]
  },
  {
    "type": "SELECT",
    "name": "consentSource",
    "displayName": "Consent source",
    "macrosInSelect": false,
    "selectItems": [
      {
        "value": "gcm",
        "displayValue": "Google Consent Mode v2 (your consent banner)"
      },
      {
        "value": "yom",
        "displayValue": "YOM (YOM banner or YOM.setConsent on the page)"
      }
    ],
    "simpleValueType": true,
    "defaultValue": "gcm",
    "help": "With Consent Mode, <em>analytics_storage</em> sets YOM analytics consent and <em>ad_storage</em> plus <em>ad_user_data</em> set marketing consent. Changes made in your banner apply straight away. Until consent is known, YOM runs cookieless."
  },
  {
    "type": "CHECKBOX",
    "name": "gcmDefaultSet",
    "checkboxText": "My consent banner sets a Consent Mode default before this tag fires",
    "simpleValueType": true,
    "defaultValue": false,
    "enablingConditions": [
      {
        "paramName": "consentSource",
        "paramValue": "gcm",
        "type": "EQUALS"
      }
    ],
    "help": "Tick this only if your banner sets a Consent Mode default on the Consent Initialization trigger. GTM reports consent that was never set as granted, so without a default YOM ignores the start-up state and waits for your banner's next change."
  },
  {
    "type": "TEXT",
    "name": "leadFormId",
    "displayName": "Lead form id",
    "simpleValueType": true,
    "defaultValue": "gtm",
    "help": "Form id sent with <em>generate_lead</em> when the dataLayer push has no <em>form_id</em>, for example <strong>contact</strong>. Never put contact details in the dataLayer for this event."
  },
  {
    "type": "GROUP",
    "name": "collection",
    "displayName": "Automatic collection",
    "groupStyle": "ZIPPY_CLOSED",
    "subParams": [
      {
        "type": "CHECKBOX",
        "name": "autoPageviews",
        "checkboxText": "Page views",
        "simpleValueType": true,
        "defaultValue": true
      },
      {
        "type": "CHECKBOX",
        "name": "autoEngagement",
        "checkboxText": "Engaged time",
        "simpleValueType": true,
        "defaultValue": true
      },
      {
        "type": "CHECKBOX",
        "name": "autoErrors",
        "checkboxText": "JavaScript errors",
        "simpleValueType": true,
        "defaultValue": true
      },
      {
        "type": "CHECKBOX",
        "name": "autoPerformance",
        "checkboxText": "Web vitals",
        "simpleValueType": true,
        "defaultValue": true
      }
    ]
  },
  {
    "type": "GROUP",
    "name": "advanced",
    "displayName": "Advanced",
    "groupStyle": "ZIPPY_CLOSED",
    "subParams": [
      {
        "type": "TEXT",
        "name": "endpoint",
        "displayName": "Collection endpoint",
        "simpleValueType": true,
        "help": "Leave empty to send to YOM directly. Set your own collection domain, for example <strong>https://t.example.com</strong>, or a same-origin proxy path such as <strong>/yom</strong>."
      },
      {
        "type": "TEXT",
        "name": "subTenant",
        "displayName": "Sub-tenant",
        "simpleValueType": true,
        "help": "For agencies and platforms that split one YOM project per client site, for example <strong>client-42</strong>. Leave empty otherwise."
      },
      {
        "type": "CHECKBOX",
        "name": "debug",
        "checkboxText": "Log to the console in preview mode",
        "simpleValueType": true,
        "defaultValue": false
      }
    ]
  }
]


___SANDBOXED_JS_FOR_WEB_TEMPLATE___

// YOM Analytics (web) — loads the YOM SDK and maps GA4 dataLayer events and Consent Mode v2.
// Docs: https://github.com/aapastech/yom-gtm-web-tag
const addConsentListener = require('addConsentListener');
const copyFromDataLayer = require('copyFromDataLayer');
const createQueue = require('createQueue');
const getType = require('getType');
const injectScript = require('injectScript');
const isConsentGranted = require('isConsentGranted');
const logToConsole = require('logToConsole');
const makeNumber = require('makeNumber');
const makeString = require('makeString');
const templateStorage = require('templateStorage');

const SDK_URL = 'https://yom.aapastech.com/app/cdn/sdk/latest/yom.min.js';
const CONSENT_TYPES = ['analytics_storage', 'ad_storage', 'ad_user_data'];
const MAPPED_EVENTS = {
  view_item: true,
  add_to_cart: true,
  begin_checkout: true,
  purchase: true,
  refund: true,
  generate_lead: true
};
// Only these fields leave the page. Anything else in the dataLayer (user_data, emails, ...) is ignored.
const ORDER_FIELDS = ['transaction_id', 'value', 'currency', 'tax', 'shipping', 'coupon', 'discount',
  'affiliation', 'payment_type', 'shipping_tier'];
const ITEM_FIELDS = ['item_id', 'item_name', 'item_variant', 'item_brand', 'item_category',
  'item_category2', 'item_category3', 'item_category4', 'item_category5', 'item_list_id',
  'item_list_name', 'coupon', 'discount', 'index', 'price', 'quantity'];
const LEAD_FIELDS = ['value', 'currency', 'lead_source'];
const NUMERIC = { value: true, tax: true, shipping: true, discount: true, price: true, quantity: true, index: true };
const MAX_ITEMS = 50;

const yomq = createQueue('yomq');

const log = (msg) => {
  if (data.debug) {
    logToConsole('[YOM GTM] ' + msg);
  }
};

// A value from the allow-list, or undefined. Strings that look like an email are dropped.
const cleanValue = (field, v) => {
  if (v === undefined || v === null || v === '') {
    return undefined;
  }
  if (NUMERIC[field]) {
    const n = makeNumber(v);
    return n === n ? n : undefined;
  }
  const t = getType(v);
  if (t !== 'string' && t !== 'number' && t !== 'boolean') {
    return undefined;
  }
  const s = makeString(v);
  return s.indexOf('@') >= 0 ? undefined : s.substring(0, 200);
};

const pick = (src, fields) => {
  const out = {};
  if (getType(src) !== 'object') {
    return out;
  }
  fields.forEach((f) => {
    const v = cleanValue(f, src[f]);
    if (v !== undefined) {
      out[f] = v;
    }
  });
  return out;
};

const pickItems = (items) => {
  if (getType(items) !== 'array') {
    return undefined;
  }
  return items
    .map((it) => pick(it, ITEM_FIELDS))
    .filter((it) => it.item_id !== undefined)
    .slice(0, MAX_ITEMS);
};

// --- Consent Mode v2 → YOM consent. Never turns "not set" into "granted". ---
const consentState = {};
const applyConsent = (live) => {
  const analytics = consentState.analytics_storage;
  if (!analytics) {
    return;
  }
  const marketing = consentState.ad_storage === 'granted' && consentState.ad_user_data === 'granted';
  yomq(['setConsent', { analytics: analytics, marketing: marketing }, { source: 'gcm', receipt: live }]);
  log('consent analytics=' + analytics + ' marketing=' + marketing);
};

const wireConsentMode = () => {
  // GTM reports a consent type that was never set as granted, so the start-up state is read only
  // when the site confirms its CMP sets a Consent Mode default before this tag fires.
  if (data.gcmDefaultSet) {
    CONSENT_TYPES.forEach((type) => {
      consentState[type] = isConsentGranted(type) ? 'granted' : 'denied';
    });
    applyConsent(false);
  }
  CONSENT_TYPES.forEach((type) => {
    addConsentListener(type, (changed, granted) => {
      consentState[changed] = granted ? 'granted' : 'denied';
      applyConsent(true);
    });
  });
};

// --- Initialise once per page ---
const initialise = () => {
  const config = {
    apiKey: data.publishableKey,
    consent: { default: 'unknown' },
    autoCapture: {
      pageviews: data.autoPageviews !== false,
      engagement: data.autoEngagement !== false,
      errors: data.autoErrors !== false,
      performance: data.autoPerformance !== false
    }
  };
  if (data.endpoint) {
    config.endpoint = data.endpoint;
  }
  if (data.subTenant) {
    config.subTenant = data.subTenant;
  }
  yomq(['init', config]);
  if (data.consentSource !== 'yom') {
    wireConsentMode();
  }
};

// --- dataLayer event → SDK call ---
const trackEvent = (name) => {
  if (name === 'generate_lead') {
    const formId = cleanValue('form_id', copyFromDataLayer('form_id')) || data.leadFormId || 'gtm';
    const lead = {};
    LEAD_FIELDS.forEach((f) => {
      const v = cleanValue(f, copyFromDataLayer(f));
      if (v !== undefined) {
        lead[f] = v;
      }
    });
    yomq(['lead', formId, lead]);
    return true;
  }
  const ecommerce = copyFromDataLayer('ecommerce');
  const params = pick(ecommerce, ORDER_FIELDS);
  const items = pickItems(getType(ecommerce) === 'object' ? ecommerce.items : undefined);
  if (items) {
    params.items = items;
  }
  if (name === 'purchase' || name === 'refund') {
    if (!params.transaction_id) {
      log(name + ' without ecommerce.transaction_id was not sent');
      return false;
    }
    if (name === 'purchase') {
      // Same id as the server-side purchase for this order, so YOM counts it once.
      yomq(['track', 'purchase', params, { id: params.transaction_id }]);
      return true;
    }
    const refundId = cleanValue('refund_id', ecommerce.refund_id);
    yomq(refundId
      ? ['track', 'refund', params, { id: params.transaction_id + ':refund:' + refundId }]
      : ['track', 'refund', params]);
    return true;
  }
  yomq(['track', name, params]);
  return true;
};

if (!data.publishableKey || makeString(data.publishableKey).indexOf('yom_pk_') !== 0) {
  log('a publishable key (yom_pk_...) is required');
  data.gtmOnFailure();
} else {
  if (!templateStorage.getItem('initialised')) {
    templateStorage.setItem('initialised', true);
    initialise();
  }
  const eventName = makeString(copyFromDataLayer('event'));
  const ok = MAPPED_EVENTS[eventName] === true ? trackEvent(eventName) : true;
  injectScript(SDK_URL, ok ? data.gtmOnSuccess : data.gtmOnFailure, data.gtmOnFailure, 'yom-sdk');
}


___WEB_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "inject_script",
        "versionId": "1"
      },
      "param": [
        {
          "key": "urls",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 1,
                "string": "https://yom.aapastech.com/app/cdn/sdk/*"
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "access_globals",
        "versionId": "1"
      },
      "param": [
        {
          "key": "keys",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "yomq"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": false
                  }
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "read_data_layer",
        "versionId": "1"
      },
      "param": [
        {
          "key": "allowedKeys",
          "value": {
            "type": 1,
            "string": "specific"
          }
        },
        {
          "key": "keyPatterns",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 1,
                "string": "event"
              },
              {
                "type": 1,
                "string": "ecommerce"
              },
              {
                "type": 1,
                "string": "form_id"
              },
              {
                "type": 1,
                "string": "value"
              },
              {
                "type": 1,
                "string": "currency"
              },
              {
                "type": 1,
                "string": "lead_source"
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "access_consent",
        "versionId": "1"
      },
      "param": [
        {
          "key": "consentTypes",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "consentType"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "ad_storage"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": false
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "consentType"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "ad_user_data"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": false
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "consentType"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "analytics_storage"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": false
                  }
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "access_template_storage",
        "versionId": "1"
      },
      "param": []
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "logging",
        "versionId": "1"
      },
      "param": [
        {
          "key": "environments",
          "value": {
            "type": 1,
            "string": "debug"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  }
]


___TESTS___

scenarios:
- name: Initialises the SDK once and loads it from the YOM CDN
  code: |-
    runCode(mockData);
    runCode(mockData);
    const inits = queued.filter((c) => c[0] === 'init');
    assertThat(inits.length).isEqualTo(1);
    assertThat(inits[0][1].apiKey).isEqualTo('yom_pk_test_123');
    assertThat(inits[0][1].consent.default).isEqualTo('unknown');
    assertThat(injected[0]).isEqualTo('https://yom.aapastech.com/app/cdn/sdk/latest/yom.min.js');
    assertApi('gtmOnSuccess').wasCalled();
    assertApi('gtmOnFailure').wasNotCalled();
- name: Purchase uses transaction_id as the event id and drops PII
  code: |-
    dataLayer = {
      event: 'purchase',
      ecommerce: {
        transaction_id: 'T-1001',
        value: 59.9,
        currency: 'USD',
        tax: 4.9,
        shipping: 5,
        customer_email: 'jane.doe@example.com',
        items: [{ item_id: 'SKU-1', item_name: 'jane.doe@example.com', price: 49.9, quantity: 1 }]
      },
      user_data: { email: 'jane.doe@example.com' }
    };
    runCode(mockData);
    const tracks = queued.filter((c) => c[0] === 'track');
    assertThat(tracks.length).isEqualTo(1);
    assertThat(tracks[0][1]).isEqualTo('purchase');
    assertThat(tracks[0][3]).isEqualTo({ id: 'T-1001' });
    assertThat(tracks[0][2]).isEqualTo({
      transaction_id: 'T-1001',
      value: 59.9,
      currency: 'USD',
      tax: 4.9,
      shipping: 5,
      items: [{ item_id: 'SKU-1', price: 49.9, quantity: 1 }]
    });
    assertApi('gtmOnSuccess').wasCalled();
- name: Purchase without transaction_id is not sent
  code: |-
    dataLayer = { event: 'purchase', ecommerce: { value: 10, currency: 'USD' } };
    runCode(mockData);
    assertThat(queued.filter((c) => c[0] === 'track').length).isEqualTo(0);
    assertApi('gtmOnFailure').wasCalled();
- name: Refund with a refund id is keyed to the order
  code: |-
    dataLayer = { event: 'refund', ecommerce: { transaction_id: 'T-1001', refund_id: 'R-7', value: 20, currency: 'USD' } };
    runCode(mockData);
    const tracks = queued.filter((c) => c[0] === 'track');
    assertThat(tracks[0][1]).isEqualTo('refund');
    assertThat(tracks[0][3]).isEqualTo({ id: 'T-1001:refund:R-7' });
- name: generate_lead sends the form id and no contact details
  code: |-
    dataLayer = { event: 'generate_lead', form_id: 'contact', value: 25, currency: 'USD', lead_source: 'footer', email: 'jane.doe@example.com' };
    runCode(mockData);
    const leads = queued.filter((c) => c[0] === 'lead');
    assertThat(leads.length).isEqualTo(1);
    assertThat(leads[0][1]).isEqualTo('contact');
    assertThat(leads[0][2]).isEqualTo({ value: 25, currency: 'USD', lead_source: 'footer' });
- name: Consent Mode that may be unset never becomes granted
  code: |-
    mock('isConsentGranted', () => true);
    runCode(mockData);
    assertThat(queued.filter((c) => c[0] === 'setConsent').length).isEqualTo(0);
    assertApi('isConsentGranted').wasNotCalled();
    assertApi('addConsentListener').wasCalled();
- name: A confirmed Consent Mode default is mirrored and live updates apply
  code: |-
    mockData.gcmDefaultSet = true;
    const state = { analytics_storage: true, ad_storage: false, ad_user_data: false };
    mock('isConsentGranted', (type) => state[type]);
    const listeners = {};
    mock('addConsentListener', (type, fn) => { listeners[type] = fn; });
    runCode(mockData);
    const consent = () => queued.filter((c) => c[0] === 'setConsent');
    assertThat(consent()[0][1]).isEqualTo({ analytics: 'granted', marketing: false });
    assertThat(consent()[0][2]).isEqualTo({ source: 'gcm', receipt: false });
    listeners.ad_storage('ad_storage', true);
    assertThat(consent()[consent().length - 1][1]).isEqualTo({ analytics: 'granted', marketing: false });
    listeners.ad_user_data('ad_user_data', true);
    assertThat(consent()[consent().length - 1][1]).isEqualTo({ analytics: 'granted', marketing: true });
    assertThat(consent()[consent().length - 1][2]).isEqualTo({ source: 'gcm', receipt: true });
    listeners.analytics_storage('analytics_storage', false);
    assertThat(consent()[consent().length - 1][1]).isEqualTo({ analytics: 'denied', marketing: true });
- name: YOM consent source leaves consent to the SDK
  code: |-
    mockData.consentSource = 'yom';
    runCode(mockData);
    assertApi('addConsentListener').wasNotCalled();
    assertApi('isConsentGranted').wasNotCalled();
- name: A missing or secret key is rejected
  code: |-
    mockData.publishableKey = 'yom_sk_should_never_be_in_a_page';
    runCode(mockData);
    assertApi('gtmOnFailure').wasCalled();
    assertThat(injected.length).isEqualTo(0);
    assertThat(queued.length).isEqualTo(0);
setup: |-
  const mockData = {
    publishableKey: 'yom_pk_test_123',
    consentSource: 'gcm',
    gcmDefaultSet: false,
    autoPageviews: true,
    autoEngagement: true,
    autoErrors: true,
    autoPerformance: true,
    debug: false
  };
  let queued = [];
  mock('createQueue', () => (cmd) => { queued.push(cmd); });
  const injected = [];
  mock('injectScript', (url, onSuccess) => {
    injected.push(url);
    onSuccess();
  });
  let dataLayer = { event: 'gtm.js' };
  mock('copyFromDataLayer', (key) => dataLayer[key]);
  mock('addConsentListener', () => {});


___NOTES___

YOM Analytics web tag template, version 1.0.0.
Source of truth: integrations/gtm in the YOM repository; published copies are synced from there.



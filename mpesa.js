const express = require('express');
const axios   = require('axios');
const { createClient } = require('@supabase/supabase-js');

const router = express.Router();

// Supabase admin client (uses service role key — keep this secret!)
const db = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

// ── Safaricom base URL — change to production when ready ──
const SAFARICOM_BASE = process.env.MPESA_ENV === 'production'
  ? 'https://api.safaricom.co.ke'
  : 'https://sandbox.safaricom.co.ke';

// ══════════════════════════════════════════════
// HELPER: Get Safaricom access token
// ══════════════════════════════════════════════
async function getToken() {
  const key    = process.env.MPESA_CONSUMER_KEY;
  const secret = process.env.MPESA_CONSUMER_SECRET;
  const credentials = Buffer.from(`${key}:${secret}`).toString('base64');

  const res = await axios.get(
    `${SAFARICOM_BASE}/oauth/v1/generate?grant_type=client_credentials`,
    { headers: { Authorization: `Basic ${credentials}` } }
  );
  return res.data.access_token;
}

// ══════════════════════════════════════════════
// HELPER: Build timestamp + password
// ══════════════════════════════════════════════
function getTimestampAndPassword() {
  const timestamp = new Date()
    .toISOString()
    .replace(/[-T:.Z]/g, '')
    .slice(0, 14);

  const password = Buffer.from(
    process.env.MPESA_SHORTCODE + process.env.MPESA_PASSKEY + timestamp
  ).toString('base64');

  return { timestamp, password };
}

// ══════════════════════════════════════════════
// POST /api/mpesa/stk-push
// Triggers the M-Pesa payment prompt on user's phone
// ══════════════════════════════════════════════
router.post('/stk-push', async (req, res) => {
  const { phone, amount, accountReference, description } = req.body;

  if (!phone || !amount || !accountReference) {
    return res.status(400).json({ success: false, error: 'Missing required fields.' });
  }

  try {
    const token = await getToken();
    const { timestamp, password } = getTimestampAndPassword();

    const response = await axios.post(
      `${SAFARICOM_BASE}/mpesa/stkpush/v1/processrequest`,
      {
        BusinessShortCode: process.env.MPESA_SHORTCODE,
        Password:          password,
        Timestamp:         timestamp,
        TransactionType:   'CustomerPayBillOnline',
        Amount:            Math.ceil(amount), // M-Pesa only accepts integers
        PartyA:            phone,
        PartyB:            process.env.MPESA_SHORTCODE,
        PhoneNumber:       phone,
        CallBackURL:       process.env.MPESA_CALLBACK_URL,
        AccountReference:  accountReference,
        TransactionDesc:   description || 'Host Me Ke Payment',
      },
      { headers: { Authorization: `Bearer ${token}` } }
    );

    res.json({ success: true, data: response.data });

  } catch (err) {
    console.error('STK Push error:', err.response?.data || err.message);
    res.status(500).json({
      success: false,
      error: err.response?.data || { errorMessage: err.message }
    });
  }
});

// ══════════════════════════════════════════════
// POST /api/mpesa/stk-query
// Checks whether a payment was completed
// ══════════════════════════════════════════════
router.post('/stk-query', async (req, res) => {
  const { checkoutRequestID } = req.body;

  if (!checkoutRequestID) {
    return res.status(400).json({ success: false, error: 'Missing checkoutRequestID.' });
  }

  try {
    const token = await getToken();
    const { timestamp, password } = getTimestampAndPassword();

    const response = await axios.post(
      `${SAFARICOM_BASE}/mpesa/stkpushquery/v1/query`,
      {
        BusinessShortCode: process.env.MPESA_SHORTCODE,
        Password:          password,
        Timestamp:         timestamp,
        CheckoutRequestID: checkoutRequestID,
      },
      { headers: { Authorization: `Bearer ${token}` } }
    );

    res.json({ success: true, data: response.data });

  } catch (err) {
    console.error('STK Query error:', err.response?.data || err.message);
    res.status(500).json({
      success: false,
      error: err.response?.data || { errorMessage: err.message }
    });
  }
});

// ══════════════════════════════════════════════
// POST /api/mpesa/callback
// Safaricom calls THIS endpoint after payment
// Update the booking record in Supabase
// ══════════════════════════════════════════════
router.post('/callback', async (req, res) => {
  // Always respond 200 to Safaricom immediately
  res.json({ ResultCode: 0, ResultDesc: 'Accepted' });

  try {
    const body     = req.body?.Body?.stkCallback;
    const resultCode = body?.ResultCode;
    const checkoutRequestID = body?.CheckoutRequestID;

    if (!checkoutRequestID) return;

    if (resultCode === 0) {
      // ✅ Payment successful
      const items = body?.CallbackMetadata?.Item || [];
      const get   = name => items.find(i => i.Name === name)?.Value;

      const mpesaReceipt = get('MpesaReceiptNumber');
      const amount       = get('Amount');
      const phone        = get('PhoneNumber');

      await db
        .from('bookings')
        .update({
          status:        'confirmed',
          mpesa_receipt: mpesaReceipt || null,
          amount:        amount || undefined,
        })
        .eq('checkout_request_id', checkoutRequestID);

      console.log(`✅ Payment confirmed: ${mpesaReceipt} for ${checkoutRequestID}`);

    } else {
      // ❌ Payment failed or cancelled
      await db
        .from('bookings')
        .update({ status: 'failed' })
        .eq('checkout_request_id', checkoutRequestID);

      console.log(`❌ Payment failed (code ${resultCode}) for ${checkoutRequestID}`);
    }

  } catch (err) {
    console.error('Callback processing error:', err.message);
  }
});

module.exports = router;

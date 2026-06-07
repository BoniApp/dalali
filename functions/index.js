/**
 * ═══════════════════════════════════════════════════════════════
 * DALALI WALLET & PAYMENT BACKEND
 * Firebase Functions v2 (Cloud Functions for Firebase)
 * ═══════════════════════════════════════════════════════════════
 *
 * Deploy with:
 *   cd functions && npm install && firebase deploy --only functions
 *
 * Required secrets (set via Google Cloud Secret Manager):
 *   SELCOM_API_KEY, SELCOM_API_SECRET, SELCOM_VENDOR_ID, SELCOM_WEBHOOK_SECRET
 */

const {onRequest, onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/https");
const {onDocumentCreated: onDocCreatedV2} = require("firebase-functions/v2/firestore");
const {getFirestore, FieldValue, Timestamp} = require("firebase-admin/firestore");
const {initializeApp} = require("firebase-admin/app");
const crypto = require("crypto");

initializeApp();
const db = getFirestore();

// ═══════════════════════════════════════════════════════════════
//  CONFIGURATION
// ═══════════════════════════════════════════════════════════════

const CONFIG = {
  AGENCY_FEE: 20000,
  AGENT_SHARE: 0.60,
  PLATFORM_SHARE: 0.40,
  SETTLEMENT_DELAY_HOURS: 48,
  MIN_WITHDRAWAL: 5000,
};

// ═══════════════════════════════════════════════════════════════
//  HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════

function hmacSign(payload, secret) {
  return crypto.createHmac("sha256", secret).update(payload).digest("base64");
}

function verifyWebhookSignature(payload, signature, secret) {
  const computed = hmacSign(payload, secret);
  try {
    return crypto.timingSafeEqual(Buffer.from(computed), Buffer.from(signature));
  } catch {
    return false;
  }
}

async function getSystemSettings() {
  const doc = await db.collection("systemSettings").doc("default").get();
  if (!doc.exists) return CONFIG;
  const data = doc.data();
  return {
    AGENCY_FEE: data.agencyFee ?? CONFIG.AGENCY_FEE,
    AGENT_SHARE: data.agentShare ?? CONFIG.AGENT_SHARE,
    PLATFORM_SHARE: data.platformShare ?? CONFIG.PLATFORM_SHARE,
    SETTLEMENT_DELAY_HOURS: data.settlementDelayHours ?? CONFIG.SETTLEMENT_DELAY_HOURS,
    MIN_WITHDRAWAL: data.minWithdrawal ?? CONFIG.MIN_WITHDRAWAL,
  };
}

async function getOrCreateWallet(userId) {
  const ref = db.collection("wallets").doc(userId);
  const doc = await ref.get();
  if (doc.exists) return doc.data();

  const wallet = {
    userId,
    availableBalance: 0,
    pendingBalance: 0,
    lockedBalance: 0,
    totalEarned: 0,
    totalWithdrawn: 0,
    updatedAt: Timestamp.now(),
  };
  await ref.set(wallet);
  return wallet;
}

// Atomic wallet update using a transaction
async function updateWalletBalance(userId, updateFn) {
  const ref = db.collection("wallets").doc(userId);
  return db.runTransaction(async (t) => {
    const doc = await t.get(ref);
    const wallet = doc.exists ? doc.data() : {
      userId,
      availableBalance: 0,
      pendingBalance: 0,
      lockedBalance: 0,
      totalEarned: 0,
      totalWithdrawn: 0,
      updatedAt: Timestamp.now(),
    };
    const updated = updateFn(wallet);
    updated.updatedAt = Timestamp.now();
    t.set(ref, updated);
    return updated;
  });
}

// Idempotency check
async function isIdempotent(idempotencyKey) {
  if (!idempotencyKey) return false;
  const snap = await db.collection("transactions")
    .where("idempotencyKey", "==", idempotencyKey)
    .limit(1)
    .get();
  return snap.empty;
}

// ═══════════════════════════════════════════════════════════════
//  1. SELCOM WEBHOOK HANDLER
// ═══════════════════════════════════════════════════════════════

exports.selcomWebhook = onRequest(
  {cors: ["https://*.selcommobile.com", "https://*.selcom.net"]},
  async (req, res) => {
    try {
      // Validate webhook signature
      const signature = req.headers["x-selcom-signature"] || req.headers["x-webhook-signature"];
      const webhookSecret = process.env.SELCOM_WEBHOOK_SECRET || "";
      const payload = JSON.stringify(req.body);

      if (!signature || !verifyWebhookSignature(payload, signature, webhookSecret)) {
        console.error("Invalid webhook signature");
        res.status(401).send("Unauthorized");
        return;
      }

      const event = req.body;
      const eventType = event.event_type || event.event || "";
      const orderId = event.order_id || event.payout_id || "";
      const status = event.status || "";

      console.log(`Webhook received: ${eventType} for ${orderId}`);

      // Idempotency check
      const processedRef = db.collection("_webhook_processed").doc(orderId + "_" + status);
      const processedDoc = await processedRef.get();
      if (processedDoc.exists) {
        console.log(`Duplicate webhook ignored: ${orderId}`);
        res.status(200).send("Already processed");
        return;
      }
      await processedRef.set({processedAt: Timestamp.now(), eventType, status});

      // Handle payment completion
      if (eventType === "order.payment_success" || status === "completed") {
        await _handlePaymentSuccess(event);
      }

      // Handle payout completion
      if (eventType === "payout.completed" || eventType === "payout.success") {
        await _handlePayoutSuccess(event);
      }

      // Handle failures
      if (status === "failed" || status === "cancelled") {
        await _handlePaymentFailure(event);
      }

      res.status(200).send("OK");
    } catch (err) {
      console.error("Webhook error:", err);
      res.status(500).send("Internal error");
    }
  }
);

async function _handlePaymentSuccess(event) {
  const orderId = event.order_id;
  const selcomTxId = event.transaction_id || event.id;

  // Find the pending transaction
  const txSnap = await db.collection("transactions")
    .where("idempotencyKey", "==", orderId)
    .where("status", "==", "pending")
    .limit(1)
    .get();

  if (txSnap.empty) {
    console.warn(`No pending transaction found for order ${orderId}`);
    return;
  }

  const txDoc = txSnap.docs[0];
  const tx = txDoc.data();

  const settings = await getSystemSettings();
  const agentShare = tx.amount * settings.AGENT_SHARE;
  const platformShare = tx.amount * settings.PLATFORM_SHARE;

  // Update transaction to processing
  await txDoc.ref.update({
    status: "processing",
    selcomTransactionId: selcomTxId,
    processedAt: Timestamp.now(),
    split: {
      agentId: agentShare,
      platform: platformShare,
    },
  });

  // Credit agent's pending balance
  if (tx.payeeId) {
    await updateWalletBalance(tx.payeeId, (w) => ({
      ...w,
      pendingBalance: (w.pendingBalance || 0) + agentShare,
      totalEarned: (w.totalEarned || 0) + agentShare,
    }));
  }

  // Credit platform's pending balance (optional tracking)
  await updateWalletBalance("_platform", (w) => ({
    ...w,
    pendingBalance: (w.pendingBalance || 0) + platformShare,
    totalEarned: (w.totalEarned || 0) + platformShare,
  }));

  // Schedule settlement after delay
  const delayMs = settings.SETTLEMENT_DELAY_HOURS * 60 * 60 * 1000;
  setTimeout(async () => {
    await _settleTransaction(txDoc.ref.id, tx.payeeId, agentShare, platformShare);
  }, delayMs);

  console.log(`Payment processed: ${orderId}, agent=${agentShare}, platform=${platformShare}`);
}

async function _settleTransaction(txId, agentId, agentAmount, platformAmount) {
  try {
    const txRef = db.collection("transactions").doc(txId);
    const txDoc = await txRef.get();
    if (!txDoc.exists) return;

    const tx = txDoc.data();
    if (tx.status !== "processing" && tx.status !== "locked") return;

    // Move from pending to available for agent
    if (agentId) {
      await updateWalletBalance(agentId, (w) => ({
        ...w,
        pendingBalance: Math.max(0, (w.pendingBalance || 0) - agentAmount),
        availableBalance: (w.availableBalance || 0) + agentAmount,
      }));
    }

    // Move platform share
    await updateWalletBalance("_platform", (w) => ({
      ...w,
      pendingBalance: Math.max(0, (w.pendingBalance || 0) - platformAmount),
      availableBalance: (w.availableBalance || 0) + platformAmount,
    }));

    // Update transaction status
    await txRef.update({
      status: "available",
      settledAt: Timestamp.now(),
    });

    console.log(`Transaction settled: ${txId}`);
  } catch (err) {
    console.error(`Settlement failed for ${txId}:`, err);
  }
}

async function _handlePayoutSuccess(event) {
  const payoutId = event.payout_id;

  const withdrawalSnap = await db.collection("withdrawals")
    .where("selcomPayoutId", "==", payoutId)
    .limit(1)
    .get();

  if (withdrawalSnap.empty) return;

  const wdDoc = withdrawalSnap.docs[0];
  const wd = wdDoc.data();

  // Update withdrawal status
  await wdDoc.ref.update({
    status: "completed",
    processedAt: Timestamp.now(),
  });

  // Debit wallet
  await updateWalletBalance(wd.userId, (w) => ({
    ...w,
    availableBalance: Math.max(0, (w.availableBalance || 0) - wd.amount),
    totalWithdrawn: (w.totalWithdrawn || 0) + wd.amount,
  }));

  console.log(`Payout completed: ${payoutId} for user ${wd.userId}`);
}

async function _handlePaymentFailure(event) {
  const orderId = event.order_id;

  const txSnap = await db.collection("transactions")
    .where("idempotencyKey", "==", orderId)
    .limit(1)
    .get();

  if (txSnap.empty) return;

  await txSnap.docs[0].ref.update({
    status: "failed",
    failureReason: event.message || event.error || "Payment failed",
    processedAt: Timestamp.now(),
  });
}

// ═══════════════════════════════════════════════════════════════
//  2. WITHDRAWAL PROCESSOR (Triggered on new withdrawal doc)
// ═══════════════════════════════════════════════════════════════

exports.processWithdrawal = onDocCreatedV2(
  {document: "withdrawals/{withdrawalId}"},
  async (event) => {
    const wd = event.data.data();
    const withdrawalId = event.params.withdrawalId;

    try {
      // Validate balance
      const wallet = await getOrCreateWallet(wd.userId);
      if (wallet.availableBalance < wd.amount) {
        await event.data.ref.update({
          status: "failed",
          failureReason: "Insufficient balance",
        });
        return;
      }

      const settings = await getSystemSettings();
      if (wd.amount < settings.MIN_WITHDRAWAL) {
        await event.data.ref.update({
          status: "failed",
          failureReason: `Minimum withdrawal is ${settings.MIN_WITHDRAWAL}`,
        });
        return;
      }

      // Lock the amount
      await updateWalletBalance(wd.userId, (w) => ({
        ...w,
        availableBalance: (w.availableBalance || 0) - wd.amount,
        lockedBalance: (w.lockedBalance || 0) + wd.amount,
      }));

      // Update status
      await event.data.ref.update({status: "processing"});

      // Call Selcom payout API
      const payoutId = `PAYOUT_${withdrawalId}`;
      const apiKey = process.env.SELCOM_API_KEY;
      const apiSecret = process.env.SELCOM_API_SECRET;
      const vendorId = process.env.SELCOM_VENDOR_ID;

      const body = JSON.stringify({
        vendor: vendorId,
        payout_id: payoutId,
        amount: wd.amount,
        currency: "TZS",
        recipient: {
          phone: wd.phone,
          wallet_provider: _mapProvider(wd.provider),
        },
        narration: `Dalali withdrawal for ${wd.userId}`,
      });

      // In production, call actual Selcom API
      // const response = await fetch("https://api.selcommobile.com/v1/payout/create", {
      //   method: "POST",
      //   headers: {
      //     "Content-Type": "application/json",
      //     "Authorization": `Bearer ${apiKey}`,
      //     "X-Signature": hmacSign(body, apiSecret),
      //   },
      //   body,
      // });

      // For now, store the payout ID and wait for webhook
      await event.data.ref.update({
        selcomPayoutId: payoutId,
        status: "processing",
      });

      console.log(`Withdrawal processing: ${withdrawalId}, payout=${payoutId}`);
    } catch (err) {
      console.error(`Withdrawal processing failed: ${withdrawalId}`, err);
      await event.data.ref.update({
        status: "failed",
        failureReason: err.message || "Processing error",
      });

      // Release locked funds
      await updateWalletBalance(wd.userId, (w) => ({
        ...w,
        availableBalance: (w.availableBalance || 0) + wd.amount,
        lockedBalance: Math.max(0, (w.lockedBalance || 0) - wd.amount),
      }));
    }
  }
);

function _mapProvider(provider) {
  const map = {
    mpesa: "MPESA",
    airtelMoney: "AIRTEL",
    tigoPesa: "TIGO",
    haloPesa: "HALOPESA",
    bankTransfer: "BANK",
  };
  return map[provider] || "MPESA";
}

// ═══════════════════════════════════════════════════════════════
//  3. SETTLEMENT SCHEDULER (runs periodically via Cloud Scheduler)
// ═══════════════════════════════════════════════════════════════

exports.scheduledSettlement = onRequest(
  {secrets: []},
  async (req, res) => {
    // This endpoint is triggered by Cloud Scheduler every hour
    // to settle any transactions past their settlement delay

    try {
      const settings = await getSystemSettings();
      const cutoff = Timestamp.fromDate(
        new Date(Date.now() - settings.SETTLEMENT_DELAY_HOURS * 60 * 60 * 1000)
      );

      const txSnap = await db.collection("transactions")
        .where("status", "==", "processing")
        .where("processedAt", "<=", cutoff)
        .limit(100)
        .get();

      const promises = [];
      for (const doc of txSnap.docs) {
        const tx = doc.data();
        const agentShare = tx.split?.agentId || 0;
        const platformShare = tx.split?.platform || 0;
        promises.push(_settleTransaction(doc.id, tx.payeeId, agentShare, platformShare));
      }

      await Promise.all(promises);
      res.status(200).json({settled: txSnap.size});
    } catch (err) {
      console.error("Scheduled settlement error:", err);
      res.status(500).send("Error");
    }
  }
);

// ═══════════════════════════════════════════════════════════════
//  4. MANUAL SETTLEMENT (admin endpoint)
// ═══════════════════════════════════════════════════════════════

exports.manualSettle = onRequest(
  {secrets: []},
  async (req, res) => {
    const {transactionId, adminKey} = req.body || {};
    const expectedAdminKey = process.env.ADMIN_API_KEY;

    if (adminKey !== expectedAdminKey) {
      res.status(403).send("Forbidden");
      return;
    }

    try {
      const txDoc = await db.collection("transactions").doc(transactionId).get();
      if (!txDoc.exists) {
        res.status(404).send("Transaction not found");
        return;
      }

      const tx = txDoc.data();
      const agentShare = tx.split?.agentId || 0;
      const platformShare = tx.split?.platform || 0;

      await _settleTransaction(transactionId, tx.payeeId, agentShare, platformShare);
      res.status(200).json({success: true, message: "Settled"});
    } catch (err) {
      res.status(500).json({error: err.message});
    }
  }
);

// ═══════════════════════════════════════════════════════════════
//  5. FRAUD PREVENTION: Duplicate payment check
// ═══════════════════════════════════════════════════════════════

exports.checkDuplicatePayment = onRequest(
  {secrets: []},
  async (req, res) => {
    const {propertyId, payerId} = req.body || {};

    const snap = await db.collection("transactions")
      .where("propertyId", "==", propertyId)
      .where("payerId", "==", payerId)
      .where("status", "in", ["pending", "processing", "locked", "available"])
      .limit(1)
      .get();

    res.status(200).json({
      hasExistingPayment: !snap.empty,
      existingTransactionId: snap.empty ? null : snap.docs[0].id,
    });
  }
);

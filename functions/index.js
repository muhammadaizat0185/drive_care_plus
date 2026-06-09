const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

// ToyyibPay Callback Webhook Receiver
exports.toyyibpayWebhook = functions.https.onRequest(async (req, res) => {
  // ToyyibPay sends transaction status updates via POST
  if (req.method !== 'POST') {
    return res.status(405).send('Method Not Allowed');
  }

  const { status_id, billcode, amount, refno, userId } = req.body;

  if (!userId || !billcode || !amount) {
    return res.status(400).send('Missing required fields');
  }

  try {
    // 1. Double check the transaction status
    // status_id: 1 = Success, 2 = Pending, 3 = Failed
    const isSuccess = status_id === '1';
    const transactionStatus = isSuccess 
      ? 'completed' 
      : (status_id === '2' ? 'pending' : 'failed');

    const topUpAmount = parseFloat(amount);
    if (isNaN(topUpAmount) || topUpAmount <= 0) {
      return res.status(400).send('Invalid amount format');
    }

    const userRef = db.collection('users').doc(userId);
    const transactionData = {
      amount: isSuccess ? topUpAmount : 0.0, // Only completed additions change ledger balance
      type: 'top_up',
      description: `Wallet Top-up via ToyyibPay (Bill: ${billcode}, Ref: ${refno || 'N/A'})`,
      status: transactionStatus,
      date: new Date().toISOString()
    };

    // Run a Firestore transaction to ensure atomic updates
    await db.runTransaction(async (t) => {
      const userDoc = await t.get(userRef);
      if (!userDoc.exists) {
        throw new Error('User document does not exist');
      }

      const currentBalance = userDoc.data().wallet_balance || 0.0;
      
      // Update balance if transaction is completed
      if (isSuccess) {
        t.update(userRef, {
          wallet_balance: currentBalance + topUpAmount
        });
      }

      // Append transaction record to sub-collection
      const newTxnRef = userRef.collection('wallet_transactions').doc();
      t.set(newTxnRef, transactionData);
    });

    console.log(`Successfully processed ToyyibPay webhook for User ${userId}. Status: ${transactionStatus}, Amount: ${amount}`);
    return res.status(200).send('OK');
  } catch (error) {
    console.error('Error processing ToyyibPay webhook: ', error);
    return res.status(500).send('Internal Server Error');
  }
});

import {firestore} from "firebase-functions/v1";
import * as admin from "firebase-admin";
import Stripe from "stripe";

const stripeSecretKey =
  process.env.STRIPE_SECRET_KEY ||
  "sk_test_51RLTAWQTDRu4l9W2x0TXBgayKVUCgPbX8lNawNYmDv0v7d8mOX4J38oZqnVKj" +
  "AvmGf0JCe7mYsLgO7y0aPYjC3L700xun9NSD8";

const stripeConfig: Stripe.StripeConfig = {
  apiVersion: "2025-04-30.basil" as const,
  typescript: true,
};

const stripe = new Stripe(stripeSecretKey, stripeConfig);

export const processTeacherPayout = firestore
  .document("payouts/{payoutId}")
  .onCreate(async (snapshot) => {
    const payoutData = snapshot.data();

    const isValidPayoutData =
      payoutData.teacherId &&
      payoutData.amount &&
      payoutData.currency &&
      payoutData.iban;

    if (!isValidPayoutData) {
      console.error("Invalid payout data");
      return null;
    }

    try {
      let stripeAccountId = payoutData.stripeAccountId;

      if (!stripeAccountId) {
        const account = await stripe.accounts.create({
          type: "express",
          country: "US",
          email: payoutData.teacherEmail,
          capabilities: {
            transfers: {requested: true},
          },
        });

        stripeAccountId = account.id;

        await admin
          .firestore()
          .collection("teachers")
          .doc(payoutData.teacherId)
          .update({stripeAccountId});
      }

      const transfer = await stripe.transfers.create({
        amount: payoutData.amount,
        currency: payoutData.currency,
        destination: stripeAccountId,
        description: `Payout for ${payoutData.period}`,
      });

      const amountStr = `$${payoutData.amount / 100}`;
      const notificationBody =
        `Your payout of ${amountStr} ${payoutData.currency} is processed`;

      await admin.messaging().sendToDevice(
        payoutData.fcmToken,
        {
          notification: {
            title: "Payout Processed",
            body: notificationBody,
          },
        }
      );

      await snapshot.ref.update({
        status: "processed",
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        transferId: transfer.id,
      });

      return null;
    } catch (error) {
      console.error("Payout error:", error);
      await snapshot.ref.update({
        status: "failed",
        error: error instanceof Error ? error.message : "Unknown error",
      });
      return null;
    }
  });

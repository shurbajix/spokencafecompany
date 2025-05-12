import * as functions from "firebase-functions";
import Stripe from "stripe";

const stripeSecretKey = process.env.STRIPE_SECRET_KEY ||
  "sk_test_51RLTAWQTDRu4l9W2x0TXBgayKVUCgPbX8lNawNYmDv0v7d8mOX4J38oZqnVKj" +
  "AvmGf0JCe7mYsLgO7y0aPYjC3L700xun9NSD8";

const stripeConfig: Stripe.StripeConfig = {
  apiVersion: "2025-04-30.basil" as const,
  typescript: true,
};

const stripe = new Stripe(stripeSecretKey, stripeConfig);

interface PaymentRequestData {
  amount: number;
  currency: string;
  customerId?: string;
}

export const createStudentPaymentIntent = functions.https.onCall(
  async (request: functions.https.CallableRequest<PaymentRequestData>) => {
    const {data, auth} = request;

    if (!auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Only authenticated users can make payments"
      );
    }

    if (typeof data.amount !== "number" || data.amount <= 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "A valid positive amount is required"
      );
    }

    const isValidCurrency = typeof data.currency === "string" &&
      /^[a-z]{3}$/i.test(data.currency);

    if (!isValidCurrency) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "A valid 3-letter currency code is required"
      );
    }

    try {
      const paymentIntent = await stripe.paymentIntents.create({
        amount: data.amount,
        currency: data.currency.toLowerCase(),
        customer: data.customerId,
        metadata: {
          userId: auth.uid,
          purpose: "lesson_payment",
        },
        automatic_payment_methods: {
          enabled: true,
        },
      });

      return {
        clientSecret: paymentIntent.client_secret,
        paymentId: paymentIntent.id,
      };
    } catch (error) {
      console.error("Stripe error:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Payment processing failed"
      );
    }
  }
);

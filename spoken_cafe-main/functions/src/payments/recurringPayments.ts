// ✅ recurringPayments.ts – repeat payments using saved token (cleaned)
import axios from "axios";
import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import {parseStringPromise} from "xml2js";

type RepeatPaymentData = {
  amount: number;
  currency: string;
  orderId: string;
};

export const payWithRecurringId = functions.https.onCall(
  async (
    request: functions.https.CallableRequest<RepeatPaymentData>
  ): Promise<{ status: string; message: string }> => {
    const {auth, data} = request;

    if (!auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Login required"
      );
    }

    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(auth.uid)
      .get();

    const recurringId = userDoc.data()?.recurringId;

    if (!recurringId) {
      throw new functions.https.HttpsError(
        "not-found",
        "No saved card found"
      );
    }

    const xml = `
      <CC5Request>
        <Name>${functions.config().nestpay.username}</Name>
        <Password>${functions.config().nestpay.password}</Password>
        <ClientId>${functions.config().nestpay.clientid}</ClientId>
        <Type>Auth</Type>
        <OrderId>${data.orderId}</OrderId>
        <Total>${data.amount.toFixed(2)}</Total>
        <Currency>${data.currency}</Currency>
        <Extra>
          <RECURRINGID>${recurringId}</RECURRINGID>
        </Extra>
      </CC5Request>
    `;

    try {
      const response = await axios.post(
        functions.config().nestpay.api_url,
        xml,
        {
          headers: {
            "Content-Type": "text/xml",
          },
        }
      );

      const parsed = await parseStringPromise(response.data, {
        explicitArray: false,
      });

      const res = parsed.CC5Response;

      if (res.Response === "Approved") {
        return {
          status: "success",
          message: "Recurring payment success",
        };
      } else {
        throw new Error(
          res.ErrMsg || "Recurring payment failed"
        );
      }
    } catch (err: unknown) {
      const error = err as Error;
      throw new functions.https.HttpsError(
        "internal",
        error.message
      );
    }
  }
);

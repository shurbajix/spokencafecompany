// ✅ teacherPayouts.ts – payout to teachers by IBAN (linted)
import * as admin from "firebase-admin";
import {firestore} from "firebase-functions/v1";

export const processTeacherPayout = firestore
  .document("payouts/{payoutId}")
  .onCreate(async (snapshot) => {
    const data = snapshot.data();

    if (
      !data.teacherId ||
      !data.amount ||
      !data.iban ||
      !data.teacherName
    ) {
      return null;
    }

    try {
      // 🧪 Simulate EFT/FAST payout until live API is available
      const payoutStatus = "success";

      if (payoutStatus === "success") {
        await snapshot.ref.update({
          status: "processed",
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else {
        await snapshot.ref.update({
          status: "failed",
          error: "Bank payout failed",
        });
      }
    } catch (err: unknown) {
      const error = err as Error;
      await snapshot.ref.update({
        status: "failed",
        error: error.message,
      });
    }

    return null;
  });

import {firestore} from "firebase-functions/v1";
import * as admin from "firebase-admin";

export const onLessonCreated = firestore
  .document("lessons/{lessonId}")
  .onCreate(async (snapshot) => {
    const lessonData = snapshot.data();
    const teacherName = lessonData?.teacherName || "A teacher";

    try {
      const studentsSnapshot = await admin
        .firestore()
        .collection("users")
        .where("role", "==", "student")
        .get();

      const tokens: string[] = studentsSnapshot.docs
        .map((doc) => doc.data().fcmToken)
        .filter(
          (token): token is string =>
            typeof token === "string" && token.length > 0
        );

      if (tokens.length === 0) {
        console.log("No student tokens found");
        return null;
      }

      const message: admin.messaging.MulticastMessage = {
        notification: {
          title: "New Lesson Started",
          body: `Teacher ${teacherName} has started a lesson.`,
        },
        tokens,
      };

      const response = await admin.messaging().sendMulticast(message);

      console.log(
        "✅ Sent",
        response.successCount,
        "notifications,",
        response.failureCount,
        "failures"
      );

      return null;
    } catch (error) {
      console.error("❌ Error sending notification:", error);
      return null;
    }
  });

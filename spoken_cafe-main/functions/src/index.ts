import * as admin from "firebase-admin";

// Initialize Firebase Admin only once
if (!admin.apps.length) {
  admin.initializeApp();
}

// Import functions
import {onLessonCreated} from "./notifications/lessonNotifications";
import {createStudentPaymentIntent} from "./payments/studentPayments";
import {processTeacherPayout} from "./payments/teacherPayouts";

// Export functions to Firebase
export {
  onLessonCreated,
  createStudentPaymentIntent,
  processTeacherPayout,
};

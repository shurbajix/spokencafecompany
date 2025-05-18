// import * as admin from "firebase-admin";
// import {
//   onLessonCreated,
// } from "./notifications/lessonNotifications";
// import {
//   createStudentNestpayPaymentHttp,
// } from "./payments/createStudentNestpayPaymentHttp";
// import {
//   payWithRecurringId,
// } from "./payments/recurringPayments";
// import {
//   processTeacherPayout,
// } from "./payments/teacherPayouts";

// if (!admin.apps.length) {
//   admin.initializeApp();
// }

// export {
//   createStudentNestpayPaymentHttp, onLessonCreated, payWithRecurringId,
//   processTeacherPayout,
// };
import * as admin from "firebase-admin";
import {onLessonCreated} from "./notifications/lessonNotifications";
import {processNestpayPayment} from "./payments/createNestpayPaymentLink";
import {payWithRecurringId} from "./payments/recurringPayments";
import {processTeacherPayout} from "./payments/teacherPayouts";

if (!admin.apps.length) {
  admin.initializeApp();
}

export {
  processNestpayPayment,
  onLessonCreated,
  payWithRecurringId,
  processTeacherPayout,
};

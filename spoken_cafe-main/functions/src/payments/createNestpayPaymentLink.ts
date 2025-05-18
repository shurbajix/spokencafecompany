import {onRequest} from "firebase-functions/v2/https";
import * as crypto from "crypto";
import axios, {isAxiosError} from "axios";

interface NestpayPaymentRequest {
  cardNumber: string;
  expMonth: string;
  expYear: string;
  cvv: string;
  amount: string | number;
  currency: string;
  orderId: string;
  email: string;
  name: string;
}

interface NestpayResponseExtra {
  settleId?: string;
  trxDate?: string;
  errorCode?: string;
  hostMsg?: string;
  numCode?: string;
}

interface NestpayRawResponse {
  orderId?: string;
  groupId?: string;
  response?: string;
  authCode?: string;
  hostRefNum?: string;
  procReturnCode: string;
  transId?: string;
  errMsg?: string;
  extra?: NestpayResponseExtra;
}

interface NestpayPaymentResult {
  success: boolean;
  errorMessage?: string;
  nestpayResponse: NestpayRawResponse;
}

export const processNestpayPayment = onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({success: false, errorMessage: "Method Not Allowed"});
    return;
  }

  const body = req.body as NestpayPaymentRequest;
  const requiredFields: (keyof NestpayPaymentRequest)[] = [
    "cardNumber",
    "expMonth",
    "expYear",
    "cvv",
    "amount",
    "currency",
    "orderId",
    "email",
    "name",
  ];
  for (const field of requiredFields) {
    if (!body[field] || body[field] === "") {
      res
        .status(400)
        .json({success: false, errorMessage: `Missing field: ${field}`});
      return;
    }
  }

  // Load and validate env vars
  const clientId = process.env.NESTPAY_CLIENTID;
  const apiUser = process.env.NESTPAY_USERNAME;
  const apiPassword = process.env.NESTPAY_PASSWORD;
  const mode = process.env.NESTPAY_MODE;
  const storeKey = process.env.NESTPAY_STORE_KEY;
  const apiUrl = process.env.NESTPAY_API_URL;
  if (!clientId || !apiUser || !apiPassword || !mode || !storeKey || !apiUrl) {
    res
      .status(500)
      .json({success: false, errorMessage: "Server configuration error"});
    return;
  }

  const orderId = body.orderId;
  const amountStr = Number(body.amount).toFixed(2);
  const currency = body.currency;
  const cardNumber = body.cardNumber;
  const expYearFull =
    body.expYear.length === 2 ? "20" + body.expYear : body.expYear;
  const expDate = `${body.expMonth}/${expYearFull}`;
  const cvv = body.cvv;
  const customerName = body.name;
  const customerEmail = body.email;
  const ipAddress =
    req.headers["x-forwarded-for"]?.toString().split(",")[0] ||
    req.socket.remoteAddress ||
    "";

  // Build Hash v3
  const paramsForHash: Record<string, string> = {
    BillToName: customerName,
    ClientId: clientId,
    Cvv2Val: cvv,
    Currency: currency,
    Email: customerEmail,
    Expires: expDate,
    IPAddress: ipAddress,
    Mode: mode,
    Number: cardNumber,
    OrderId: orderId,
    Total: amountStr,
    TranType: "Auth",
    hashAlgorithm: "ver3",
  };
  const sortedKeys = Object.keys(paramsForHash).sort((a, b) =>
    a.localeCompare(b, undefined, {sensitivity: "base"})
  );
  const hashString =
    sortedKeys.map((k) => paramsForHash[k]).join("|") + "|" + storeKey;
  const hashValue = crypto
    .createHash("sha512")
    .update(hashString, "utf8")
    .digest("base64");

  // XML-escape helper
  const escapeXml = (s: string) =>
    s
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/'/g, "&apos;")
      .replace(/"/g, "&quot;");

  // Build XML
  const xmlRequest = `<?xml version="1.0" encoding="UTF-8"?>
<CC5Request>
  <Name>${escapeXml(apiUser)}</Name>
  <Password>${escapeXml(apiPassword)}</Password>
  <ClientId>${escapeXml(clientId)}</ClientId>
  <IPAddress>${escapeXml(ipAddress)}</IPAddress>
  <Mode>${escapeXml(mode)}</Mode>
  <OrderId>${escapeXml(orderId)}</OrderId>
  <Type>Auth</Type>
  <Number>${escapeXml(cardNumber)}</Number>
  <Expires>${escapeXml(expDate)}</Expires>
  <Cvv2Val>${escapeXml(cvv)}</Cvv2Val>
  <Total>${escapeXml(amountStr)}</Total>
  <Currency>${escapeXml(currency)}</Currency>
  <BillTo>
    <Name>${escapeXml(customerName)}</Name>
    <Email>${escapeXml(customerEmail)}</Email>
  </BillTo>
  <Extra>
    <HASHAlgorithm>ver3</HASHAlgorithm>
    <HASH>${escapeXml(hashValue)}</HASH>
  </Extra>
</CC5Request>`;

  try {
    const resp = await axios.post<string>(apiUrl, xmlRequest, {
      headers: {"Content-Type": "text/xml"},
      timeout: 10000,
    });
    const text = resp.data;

    const parseTag = (tag: string): string | undefined => {
      const m = text.match(new RegExp(`<${tag}>([^<]*)</${tag}>`));
      return m ? m[1] : undefined;
    };

    const result: NestpayRawResponse = {
      orderId: parseTag("OrderId"),
      groupId: parseTag("GroupId"),
      response: parseTag("Response"),
      authCode: parseTag("AuthCode"),
      hostRefNum: parseTag("HostRefNum"),
      procReturnCode: parseTag("ProcReturnCode") || "",
      transId: parseTag("TransId"),
      errMsg: parseTag("ErrMsg"),
      extra: {
        settleId: parseTag("SETTLEID"),
        trxDate: parseTag("TRXDATE"),
        errorCode: parseTag("ERRORCODE"),
        hostMsg: parseTag("HOSTMSG"),
        numCode: parseTag("NUMCODE"),
      },
    };

    const success =
      result.procReturnCode === "00" && result.response === "Approved";
    const errorMessage = success ?
      undefined :
      result.errMsg || result.extra?.hostMsg || "Payment failed";

    const out: NestpayPaymentResult = {
      success,
      errorMessage,
      nestpayResponse: result,
    };

    res.status(200).json(out);
  } catch (error: unknown) {
    let errorMsg: string;
    if (isAxiosError(error) && error.response) {
      errorMsg = `NestpayError: ${error.response.data}`;
    } else if (error instanceof Error) {
      errorMsg = error.message;
    } else {
      errorMsg = String(error);
    }
    console.error("Nestpay API error:", error);
    res.status(500).json({success: false, errorMessage: errorMsg});
  }
});

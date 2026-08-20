# عقد الـBackend الفعلي

تم تنفيذ Backend مستقل داخل `backend/nestjs` باستخدام NestJS + Prisma + PostgreSQL.

## المصادقة

- `POST /auth/customer/phone/start`
  - body: `{ "phone": "09xxxxxxxx" }`
  - يرجع `challengeId` ومدة الصلاحية، ويرجع `devCode` فقط عند تفعيل `OTP_DEV_MODE`.
- `POST /auth/customer/phone/verify`
  - body: `challengeId, phone, code, name, governorate`
  - ينشئ/يحدث ملف الزبون ويرجع access/refresh tokens.
- `POST /auth/customer/oauth`
  - body: `provider = GOOGLE | FACEBOOK, firebaseIdToken, name, governorate`
  - يتحقق من Firebase ID token قبل إنشاء الجلسة.
- `POST /auth/merchant/login`
- `POST /auth/admin/login`
- `POST /auth/refresh`
- `POST /auth/logout`

## الزبون

- `GET /stores?city=&category=`: قائمة المحلات النشطة.
- `GET /customer/profile`
- `PATCH /customer/profile`
- `GET /customer/points`: الرصيد، النقاط المحجوزة، الرصيد المتاح.
- `POST /customer/qr-token`: QR موقع وقصير الصلاحية.
- `GET /customer/transactions?cursor=&limit=`
- `GET /customer/digital-products`
- `GET /customer/redemptions/cash`
- `POST /customer/redemptions/cash`
- `POST /customer/redemptions/products`

## المحل

- `GET /merchant/me`: الحساب، المحل، الملخص، آخر العمليات.
- `POST /merchant/devices`: تسجيل بصمة جهاز موقعة/مجزأة.
- `POST /merchant/qr/resolve`: التحقق من QR الزبون.
- `POST /merchant/invoices`
  - body: `{ "customerQrPayload": "...", "amountSyp": 100000, "idempotencyKey": "uuid" }`
  - الخادم يحسب العمولة والنقاط ويكتب القيد في Ledger.
- `GET /merchant/summary?from=&to=`
- `GET /merchant/transactions?cursor=&limit=`

## الإدارة

- `GET /admin/overview`
- `GET /admin/customers`
- `POST /admin/customers/:customerId/points/grant`
- `POST /admin/customers/:customerId/points/deduct`
- `DELETE /admin/customers/:customerId`
- `GET /admin/cash-requests?status=pending`
- `POST /admin/cash-requests/:requestId/resolve`
- `GET|POST|PATCH /admin/stores`
- `GET|POST|PATCH /admin/products`
- `GET|POST /admin/merchant-accounts`
- `GET|PATCH /admin/settings`
- `GET /admin/settlements`
- `POST /admin/settlements/settle`

## شكل الخطأ

```json
{
  "statusCode": 400,
  "code": "bad_request",
  "message": "رسالة واضحة",
  "details": {},
  "path": "/customer/points",
  "timestamp": "2026-08-18T00:00:00.000Z"
}
```

## قواعد الخادم

- حساب العمولة والنقاط يتم في الخادم فقط.
- تطبيق المحل لا يرسل النسبة أو عدد النقاط المحسوب.
- تطبيق الزبون لا يعدّل الرصيد مباشرة.
- كل تعديل إداري على الرصيد ينشئ قيداً في `PointsLedgerEntry`.
- كل QR له توقيع وتاريخ انتهاء ومعرّف استعمال.
- كل فاتورة تحمل `idempotencyKey` لمنع التكرار.
- قاعدة البيانات تمنع وجود محل نشط ثانٍ لنفس المدينة والفئة.
- قاعدة البيانات تمنع وجود أكثر من طلب كاش معلق للزبون نفسه.

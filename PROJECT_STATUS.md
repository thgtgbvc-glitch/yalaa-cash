# حالة المشروع — النسخة 0.3.0

## مكتمل

- فصل تطبيق الزبون عن تطبيق المحل.
- حزمة مشتركة للنماذج والثيم والحسابات.
- تدفق تسجيل الزبون التجريبي.
- الرئيسية، المحلات، QR، المحفظة والمتجر.
- تسجيل دخول المحل والإحصائيات.
- مسح QR وإدخال الفاتورة وشاشة النجاح.
- اختبارات وحدة لمنطق العمولة والحجز وQR.
- اختبارات واجهة أساسية لتطبيقَي الموبايل ولوحة التحكم.
- مخطط PostgreSQL/Supabase مع RLS ودوال حساسة تعمل على الخادم.
- لوحة تحكم Flutter Web متجاوبة بجميع أقسام الإدارة الأساسية.
- اعتماد شعار Yalla Cash الرسمي وخط Almarai ExtraBold في التطبيقات الثلاثة.
- Backend مستقل داخل `backend/nestjs` باستخدام NestJS + Prisma + PostgreSQL.
- مصادقة JWT/Refresh وbcrypt للمحل والإدارة.
- OTP للزبون مع تخزين challenge مجزأ، وFirebase Admin كمسار OAuth.
- REST API كامل للزبون والمحل والإدارة.
- QR موقع وقصير الصلاحية يصدر من الخادم.
- Prisma migration مع قيود وفهارس للرصيد والحصرية وطلبات الكاش.
- طبقة Flutter Clean Architecture مشتركة: Repository contracts، Remote/InMemory repositories، API client، Cubits.
- توثيق معماري وتشغيلي محدث.
- تحقق Backend: `pnpm build` و`pnpm test`.

## المرحلة التالية

- تشغيل PostgreSQL محلياً أو staging وتشغيل `pnpm prisma:migrate && pnpm prisma:seed`.
- ربط تطبيقات Flutter فعلياً بـ `YallaCashRuntime` على جهاز يحتوي Flutter SDK.
- تشغيل `flutter pub get` و`flutter test` بعد تثبيت Flutter.
- ضبط Firebase Admin وموفر SMS حقيقي للإنتاج.
- إضافة إشعارات FCM وتنبيهات طلبات الكاش.
- توليد ملفات Android/iOS وتشغيل الاختبارات على أجهزة فعلية.
- توليد ملفات Web وتشغيل اختبار واجهة لوحة التحكم على Chrome.

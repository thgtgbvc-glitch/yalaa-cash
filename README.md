# يلا كاش — Flutter MVP

نسخة أولى منظمة من مشروع «يلا كاش» مبنية كتطبيقين منفصلين ولوحة تحكم تشترك جميعها في حزمة منطق وبيانات واحدة:

- `apps/yalla_cash_customer`: تطبيق الزبون.
- `apps/yalla_cash_merchant`: تطبيق المحل.
- `apps/yalla_cash_admin`: لوحة تحكم Flutter Web.
- `packages/yalla_cash_core`: النماذج، منطق العمولات، بيانات العرض والثيم المشترك.
- `backend/nestjs`: Backend إنتاجي مستقل مبني بـ NestJS + Prisma + PostgreSQL.
- `backend/supabase`: مخطط PostgreSQL مبدئي للمرحلة المتصلة.

## الهوية البصرية

- تم اعتماد شعار Yalla Cash الرسمي في التطبيقات الثلاثة.
- يستخدم الشعار الكامل في شاشات الدخول، والرمز المختصر داخل المساحات الصغيرة.
- تم اعتماد خط `Almarai ExtraBold` كثيم موحد للنصوص العربية.
- أصول الهوية موجودة داخل `packages/yalla_cash_core/assets` لتبقى مشتركة بين جميع التطبيقات.

## ما يعمل في النسخة الحالية

### تطبيق الزبون

- تسجيل دخول تجريبي برقم الهاتف أو Google أو Facebook.
- الرصيد والمتاح بعد حجز طلبات الاستبدال.
- قائمة المحلات الحصرية وتفاصيلها.
- QR شخصي.
- سجل العمليات.
- استبدال النقاط بكاش أو منتج رقمي.
- الوضع الداكن وتسجيل الخروج.

### تطبيق المحل

- تسجيل دخول بحساب يصدر من الإدارة.
- إحصائيات المبيعات والعمولة.
- مسح QR بالكاميرا أو استخدام كود تجريبي للمحاكي.
- إدخال قيمة الفاتورة وحساب العمولة والنقاط.
- شاشة نجاح وسجل آخر العمليات.

### لوحة التحكم

- تسجيل دخول إدارة تجريبي.
- مؤشرات المبيعات والمستخدمين ودخل المنصة.
- معالجة طلبات استبدال النقاط بكاش.
- منح وخصم النقاط وإدارة المستخدمين.
- إضافة وتعديل المحلات ونسب العمولات.
- إدارة المنتجات الرقمية وحسابات المحلات.
- التحاسب الشهري وإعداد قيمة النقطة.
- تصميم متجاوب للكمبيوتر والجوال ووضع داكن.

### Backend NestJS

- مصادقة زبون عبر OTP، ومصادقة Google/Facebook عبر Firebase Admin عند ضبط مفاتيح Firebase.
- تسجيل دخول محلات وإدارة عبر بريد/كلمة مرور مع bcrypt وJWT.
- Refresh tokens مخزنة كـ hash وقابلة للإلغاء.
- QR زبون موقع وقصير الصلاحية.
- API كامل للزبون والمحل والإدارة.
- Rate limiting عام مع حدود أشد على مسارات المصادقة.
- Prisma schema ومigration PostgreSQL مع قيود وفهارس إنتاجية.
- Ledger لكل حركة نقاط.
- حساب العمولة والنقاط داخل الخادم فقط مع `idempotencyKey` للفواتير.
- اختبارات وحدة لمنطق الولاء وتشفير كلمات المرور.

## التشغيل

تحتاج Flutter SDK حديثاً. لأن ملفات المنصات مولّدة آلياً ولا تحتوي منطق المشروع، أنشئها أول مرة فقط داخل كل تطبيق:

```bash
cd apps/yalla_cash_customer
flutter create --platforms=android,ios .
flutter pub get
flutter run
```

ثم كرر الخطوات لتطبيق المحل:

```bash
cd ../yalla_cash_merchant
flutter create --platforms=android,ios .
flutter pub get
flutter run
```

بعد إنشاء ملفات iOS لتطبيق المحل، أضف المفتاح التالي إلى `ios/Runner/Info.plist` حتى تعمل الكاميرا:

```xml
<key>NSCameraUsageDescription</key>
<string>نستخدم الكاميرا لمسح كود الزبون وتسجيل الفاتورة.</string>
```

بيانات دخول المحل التجريبية:

```text
wasim@yallacash.app
123456
```

لتشغيل لوحة التحكم على الويب:

```bash
cd apps/yalla_cash_admin
flutter create --platforms=web .
flutter pub get
flutter run -d chrome
```

بيانات دخول لوحة التحكم التجريبية:

```text
admin@yallacash.app
admin123
```

## تشغيل الـBackend

```bash
cd backend/nestjs
cp .env.example .env
docker compose up -d
pnpm install
pnpm prisma:generate
pnpm prisma:migrate
pnpm prisma:seed
pnpm start:dev
```

بيانات التطوير الافتراضية بعد seed:

```text
admin@yallacash.app / admin123
wasim@yallacash.app / 123456
```

عند استخدام `YallaCashRuntime.fromEnvironment()` وCubits الجديدة في واجهات Flutter، فعّل الاتصال بالـBackend عبر:

```bash
flutter run \
  --dart-define=YALLA_CASH_USE_REMOTE=true \
  --dart-define=YALLA_CASH_API_BASE_URL=http://localhost:3000
```

على محاكي Android غالباً استخدم:

```bash
--dart-define=YALLA_CASH_API_BASE_URL=http://10.0.2.2:3000
```

## ملاحظة مهمة عن النسخة الأولى

الواجهات الحالية ما زالت مرجعاً بصرياً محافظاً على تجربة النسخة الأولى، وتحتاج خطوة ربط نهائية لاستهلاك Cubits مباشرة داخل ملفات الشاشات. حزمة `yalla_cash_core` أصبحت تحتوي طبقة ربط حقيقية:

- `RemoteYallaCashRepository` للاتصال بـ NestJS.
- `InMemoryYallaCashRepository` للتجربة والاختبارات.
- Cubits منفصلة للزبون والمحل والإدارة.
- `YallaCashRuntime.fromEnvironment()` لاختيار Remote أو Demo عبر dart-define.

قبل إطلاق أموال حقيقية، يجب تشغيل تطبيقات Flutter على SDK فعلي وربط OTP/Firebase/الإشعارات ومراجعة التدفقات قانونياً ومالياً.

## قاعدة احتساب النقاط

حتى يبقى تقسيم العمولة نصفاً للمنصة ونصفاً للزبون صحيحاً مالياً، تحسب النقاط كالآتي:

```text
العمولة = قيمة الفاتورة × نسبة المحل
حصة الزبون بالليرة = نصف العمولة
النقاط المكتسبة = حصة الزبون بالليرة ÷ قيمة النقطة
```

قيمة النقطة قابلة للتعديل من الإعدادات الخلفية. يجب تثبيت هذه القاعدة مع صاحب المشروع قبل إطلاق النظام الفعلي.

## التحقق

بعد تثبيت Flutter:

```bash
(cd packages/yalla_cash_core && flutter test)
(cd apps/yalla_cash_customer && flutter test)
(cd apps/yalla_cash_merchant && flutter test)
(cd apps/yalla_cash_admin && flutter test)
(cd backend/nestjs && pnpm build && pnpm test)
```

تم التحقق في بيئة الإنشاء من Backend عبر `pnpm build` و`pnpm test`. لم يكن Flutter SDK متاحاً داخل بيئة الإنشاء، لذلك يجب تشغيل أوامر `flutter pub get` و`flutter test` على جهاز يحتوي Flutter قبل إصدار APK/AAB.

# استخدام صورة Dart الرسمية
FROM dart:stable AS build

# تعيين مجلد العمل
WORKDIR /app

# نسخ ملفات المشروع
COPY pubspec.* ./
RUN dart pub get

COPY . .

# بناء المشروع
RUN dart pub get --offline

# المرحلة النهائية
FROM dart:stable

WORKDIR /app

# نسخ الملفات المطلوبة من مرحلة البناء
COPY --from=build /app /app
# نسخ التبعيات المثبتة
COPY --from=build /root/.pub-cache /root/.pub-cache

# تعيين المتغير البيئي للمنفذ
ENV PORT=3000

# فتح المنفذ
EXPOSE 3000

# تشغيل السيرفر
CMD ["dart", "run", "bin/server.dart"]

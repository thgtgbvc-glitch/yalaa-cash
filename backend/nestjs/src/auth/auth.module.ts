import { Module } from "@nestjs/common";
import { ConfigModule, ConfigService } from "@nestjs/config";
import { JwtModule } from "@nestjs/jwt";
import { AuthController } from "./auth.controller";
import { AuthService } from "./auth.service";
import { FirebaseOAuthService } from "./firebase-oauth.service";
import { LinkSyriaOtpModule } from "./linksyria/linksyria-otp.module";
import { PasswordService } from "./password.service";

@Module({
  imports: [
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.getOrThrow<string>("JWT_ACCESS_SECRET"),
      }),
    }),
    LinkSyriaOtpModule,
  ],
  controllers: [AuthController],
  providers: [AuthService, PasswordService, FirebaseOAuthService],
  exports: [AuthService, JwtModule, PasswordService],
})
export class AuthModule {}

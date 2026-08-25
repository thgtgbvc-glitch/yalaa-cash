import { Module } from "@nestjs/common";
import { LinkSyriaOtpService } from "./linksyria-otp.service";

@Module({
  providers: [LinkSyriaOtpService],
  exports: [LinkSyriaOtpService],
})
export class LinkSyriaOtpModule {}

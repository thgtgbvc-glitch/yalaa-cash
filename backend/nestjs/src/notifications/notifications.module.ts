import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { FcmService } from "./fcm.service";

@Module({
  imports: [AuthModule],
  providers: [FcmService],
  exports: [FcmService],
})
export class NotificationsModule {}

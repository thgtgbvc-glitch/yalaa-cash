import { Body, Controller, HttpCode, HttpStatus, Post } from "@nestjs/common";
import { Throttle } from "@nestjs/throttler";
import { CurrentUser } from "./decorators/current-user.decorator";
import type { AuthenticatedUser } from "./decorators/current-user.decorator";
import { Public } from "./decorators/public.decorator";
import {
  CustomerOAuthDto,
  LogoutDto,
  PasswordLoginDto,
  RefreshTokenDto,
  RequestPhoneOtpDto,
  VerifyPhoneOtpDto,
} from "./dto/auth.dto";
import { AuthService } from "./auth.service";

@Controller("auth")
@Throttle({ default: { limit: 12, ttl: 60000 } })
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Public()
  @Post("customer/phone/start")
  @HttpCode(HttpStatus.OK)
  startCustomerPhoneOtp(@Body() dto: RequestPhoneOtpDto) {
    return this.auth.requestPhoneOtp(dto);
  }

  @Public()
  @Post("customer/phone/verify")
  @HttpCode(HttpStatus.OK)
  verifyCustomerPhoneOtp(@Body() dto: VerifyPhoneOtpDto) {
    return this.auth.verifyPhoneOtp(dto);
  }

  @Public()
  @Post("customer/oauth")
  @HttpCode(HttpStatus.OK)
  verifyCustomerOAuth(@Body() dto: CustomerOAuthDto) {
    return this.auth.verifyCustomerOAuth(dto);
  }

  @Public()
  @Post("merchant/login")
  @HttpCode(HttpStatus.OK)
  loginMerchant(@Body() dto: PasswordLoginDto) {
    return this.auth.loginMerchant(dto);
  }

  @Public()
  @Post("admin/login")
  @HttpCode(HttpStatus.OK)
  loginAdmin(@Body() dto: PasswordLoginDto) {
    return this.auth.loginAdmin(dto);
  }

  @Public()
  @Post("refresh")
  @HttpCode(HttpStatus.OK)
  refresh(@Body() dto: RefreshTokenDto) {
    return this.auth.refresh(dto.refreshToken);
  }

  @Post("logout")
  @HttpCode(HttpStatus.OK)
  logout(@CurrentUser() _user: AuthenticatedUser, @Body() dto: LogoutDto) {
    return this.auth.logout(dto.refreshToken);
  }
}

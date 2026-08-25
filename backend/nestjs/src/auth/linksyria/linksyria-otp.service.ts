import {
  BadRequestException,
  Injectable,
  Logger,
  OnModuleInit,
  ServiceUnavailableException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { randomUUID } from "crypto";

/**
 * Sends OTP SMS messages through the LinkSyria gateway.
 *
 * This service has exactly one responsibility: deliver an already-generated
 * OTP code to a phone number. It never generates, stores, or verifies OTP
 * codes — that logic lives entirely in AuthService and is untouched here.
 */
@Injectable()
export class LinkSyriaOtpService implements OnModuleInit {
  private readonly logger = new Logger(LinkSyriaOtpService.name);
  private static readonly SEND_PATH = "/api/v1/otp/send/";

  constructor(private readonly config: ConfigService) {}

  /**
   * Logs, once at boot, whether this process actually sees a LinkSyria API
   * key — never the value itself. This is the fastest way to tell "the code
   * can't find the key" apart from "the env var isn't reaching this process
   * (stale deploy, wrong service, name mismatch)" from the deploy logs.
   */
  onModuleInit(): void {
    const url = this.config.get<string>(
      "LINKSYRIA_API_URL",
      "https://linksyria.online",
    );
    this.logger.log(
      `LinkSyria OTP delivery: apiKeyConfigured=${this.isConfigured()} apiUrl=${url}`,
    );
  }

  /** True when a LinkSyria API key is present, i.e. sending is possible. */
  isConfigured(): boolean {
    return Boolean(this.config.get<string>("LINKSYRIA_API_KEY"));
  }

  async sendOtp(phone: string, code: string): Promise<void> {
    const apiKey = this.config.get<string>("LINKSYRIA_API_KEY");
    if (!apiKey) {
      throw new ServiceUnavailableException("SMS provider is not configured.");
    }

    const baseUrl = this.config
      .get<string>("LINKSYRIA_API_URL", "https://linksyria.online")
      .replace(/\/+$/, "");
    const timeoutMs = this.config.get<number>("LINKSYRIA_TIMEOUT_MS", 10000);
    const phoneNumber = this.toSyrianPhoneNumber(phone);
    const idempotencyKey = randomUUID();

    const payload = JSON.stringify({
      phone_number: phoneNumber,
      template_id: null,
      language: "ar",
      custom_code: code,
    });

    const headers = {
      "X-API-Key": apiKey,
      "Content-Type": "application/json",
      "Idempotency-Key": idempotencyKey,
    };

    // A single retry, reusing the same Idempotency-Key, so a retried
    // request cannot cause LinkSyria to send a duplicate SMS.
    const attempts = 2;
    let lastError: unknown;
    for (let attempt = 1; attempt <= attempts; attempt += 1) {
      try {
        await this.postOnce(`${baseUrl}${LinkSyriaOtpService.SEND_PATH}`, headers, payload, timeoutMs);
        return;
      } catch (error) {
        lastError = error;
        this.logger.warn(
          `LinkSyria OTP send attempt ${attempt}/${attempts} failed for ${this.maskPhone(phoneNumber)}: ${this.describeError(error)}`,
        );
      }
    }

    throw new ServiceUnavailableException(
      "Failed to send OTP SMS.",
      lastError instanceof Error ? { cause: lastError } : undefined,
    );
  }

  private async postOnce(
    url: string,
    headers: Record<string, string>,
    body: string,
    timeoutMs: number,
  ): Promise<void> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), timeoutMs);

    try {
      const response = await fetch(url, {
        method: "POST",
        headers,
        body,
        signal: controller.signal,
      });

      if (!response.ok) {
        throw new Error(`LinkSyria responded with HTTP ${response.status}`);
      }
    } finally {
      clearTimeout(timeout);
    }
  }

  private describeError(error: unknown): string {
    if (error instanceof Error) {
      return error.name === "AbortError" ? "request timed out" : error.message;
    }
    return "unknown error";
  }

  /** Never logs the OTP code or the API key — only safe metadata. */
  private maskPhone(phone: string): string {
    return phone.length > 4 ? `${phone.slice(0, -4).replace(/\d/g, "*")}${phone.slice(-4)}` : phone;
  }

  /**
   * Converts an already-normalized phone number (as stored/hashed by
   * AuthService) into the +963XXXXXXXXX format LinkSyria expects, without
   * altering how the number is stored or hashed elsewhere.
   */
  private toSyrianPhoneNumber(phone: string): string {
    const digits = phone.replace(/[^\d+]/g, "");

    if (/^\+963\d{9}$/.test(digits)) return digits;
    if (/^963\d{9}$/.test(digits)) return `+${digits}`;
    if (/^0\d{9}$/.test(digits)) return `+963${digits.slice(1)}`;
    if (/^9\d{8}$/.test(digits)) return `+963${digits}`;

    throw new BadRequestException("Phone number is not a valid Syrian number.");
  }
}

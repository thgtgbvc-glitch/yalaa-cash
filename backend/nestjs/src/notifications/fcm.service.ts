import { Injectable, Logger } from "@nestjs/common";
import { getMessaging } from "firebase-admin/messaging";
import { FirebaseOAuthService } from "../auth/firebase-oauth.service";
import { PrismaService } from "../prisma/prisma.service";

interface PushMessage {
  title: string;
  body: string;
  data?: Record<string, string>;
}

/**
 * Sends push notifications through Firebase Cloud Messaging, reusing the
 * same Firebase Admin app FirebaseOAuthService initializes for Google
 * Sign-In verification. Every send is best-effort: a customer-facing
 * request (redemption submit/resolve) must never fail because a push
 * notification could not be delivered, so callers fire-and-forget these
 * methods and failures are only logged.
 */
@Injectable()
export class FcmService {
  private readonly logger = new Logger(FcmService.name);
  private static readonly BATCH_SIZE = 500;

  constructor(
    private readonly firebaseOAuth: FirebaseOAuthService,
    private readonly prisma: PrismaService,
  ) {}

  /**
   * Fully guarded: every caller treats this as fire-and-forget (`void
   * this.fcm.sendToUser(...)`), so nothing in this method may ever reject —
   * an uncaught rejection here would be an unhandled promise rejection,
   * which crashes the whole Node process. A DB hiccup while looking up
   * someone's device tokens must never take down an unrelated request.
   */
  async sendToUser(userId: string, message: PushMessage): Promise<void> {
    try {
      const tokens = await this.prisma.deviceToken.findMany({
        where: { userId },
        select: { token: true },
      });
      if (tokens.length === 0) return;
      await this.sendToTokens(
        tokens.map((t) => t.token),
        message,
      );
    } catch (error) {
      this.logger.warn(
        `sendToUser failed, notification skipped: ${this.describeError(error)}`,
      );
    }
  }

  /** Same guarantee as sendToUser: never throws, never rejects. */
  async sendToAllCustomers(message: PushMessage): Promise<{ sent: number }> {
    try {
      const tokens = await this.prisma.deviceToken.findMany({
        where: { user: { role: "CUSTOMER" } },
        select: { token: true },
      });
      await this.sendToTokens(
        tokens.map((t) => t.token),
        message,
      );
      return { sent: tokens.length };
    } catch (error) {
      this.logger.warn(
        `sendToAllCustomers failed, broadcast skipped: ${this.describeError(error)}`,
      );
      return { sent: 0 };
    }
  }

  private async sendToTokens(
    tokens: string[],
    message: PushMessage,
  ): Promise<void> {
    if (tokens.length === 0) return;

    let app;
    try {
      app = this.firebaseOAuth.getApp();
    } catch {
      this.logger.warn("Skipped push send: Firebase Admin is not configured.");
      return;
    }

    let messaging;
    try {
      messaging = getMessaging(app);
    } catch (error) {
      this.logger.warn(
        `Skipped push send: could not obtain messaging client: ${this.describeError(error)}`,
      );
      return;
    }

    const staleTokens: string[] = [];

    for (let i = 0; i < tokens.length; i += FcmService.BATCH_SIZE) {
      const batch = tokens.slice(i, i + FcmService.BATCH_SIZE);
      try {
        const response = await messaging.sendEachForMulticast({
          tokens: batch,
          notification: { title: message.title, body: message.body },
          ...(message.data ? { data: message.data } : {}),
        });
        response.responses.forEach((res, index) => {
          const code = (res.error as { code?: string } | undefined)?.code;
          if (
            !res.success &&
            (code === "messaging/registration-token-not-registered" ||
              code === "messaging/invalid-registration-token")
          ) {
            staleTokens.push(batch[index]);
          }
        });
      } catch (error) {
        this.logger.warn(`FCM batch send failed: ${this.describeError(error)}`);
      }
    }

    if (staleTokens.length > 0) {
      try {
        await this.prisma.deviceToken.deleteMany({
          where: { token: { in: staleTokens } },
        });
      } catch (error) {
        this.logger.warn(
          `Failed to clean up ${staleTokens.length} stale token(s): ${this.describeError(error)}`,
        );
      }
    }
  }

  /** Never includes token values or credentials — message/error text only. */
  private describeError(error: unknown): string {
    return error instanceof Error ? error.message : "unknown error";
  }
}

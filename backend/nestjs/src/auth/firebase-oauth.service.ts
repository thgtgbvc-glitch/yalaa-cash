import {
  Injectable,
  Logger,
  OnModuleInit,
  ServiceUnavailableException,
  UnauthorizedException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { AuthMethod } from "@prisma/client";
import { App, cert, getApps, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

interface VerifiedOAuthIdentity {
  subject: string;
  email?: string;
  phone?: string;
}

@Injectable()
export class FirebaseOAuthService implements OnModuleInit {
  private readonly logger = new Logger(FirebaseOAuthService.name);
  private app?: App;

  constructor(private readonly config: ConfigService) {}

  /**
   * Logs, once at boot, whether Firebase Admin actually initializes with
   * this process's env — never the credential values. Initializing eagerly
   * here (instead of waiting for the first real OAuth request) also makes a
   * malformed FIREBASE_PRIVATE_KEY fail fast in the deploy logs rather than
   * on a user's first Google sign-in attempt.
   */
  onModuleInit(): void {
    const projectId = this.config.get<string>("FIREBASE_PROJECT_ID");
    try {
      this.getApp();
      this.logger.log(
        `Firebase Admin: configured=true projectId=${projectId}`,
      );
    } catch {
      this.logger.log(
        `Firebase Admin: configured=false (FIREBASE_PROJECT_ID/CLIENT_EMAIL/PRIVATE_KEY missing or invalid)`,
      );
    }
  }

  async verifyCustomerToken(
    provider: Extract<AuthMethod, "GOOGLE" | "FACEBOOK">,
    idToken: string,
  ): Promise<VerifiedOAuthIdentity> {
    const app = this.getApp();
    const token = await getAuth(app).verifyIdToken(idToken, true);
    const signInProvider = token.firebase?.sign_in_provider;
    const expected =
      provider === AuthMethod.GOOGLE ? "google.com" : "facebook.com";

    if (signInProvider !== expected) {
      throw new UnauthorizedException("OAuth provider does not match token.");
    }

    return {
      subject: token.uid,
      email: token.email,
      phone: token.phone_number,
    };
  }

  private getApp(): App {
    if (this.app) return this.app;
    if (getApps().length > 0) {
      this.app = getApps()[0];
      return this.app;
    }

    const projectId = this.config.get<string>("FIREBASE_PROJECT_ID");
    const clientEmail = this.config.get<string>("FIREBASE_CLIENT_EMAIL");
    const privateKey = this.config
      .get<string>("FIREBASE_PRIVATE_KEY")
      ?.replace(/\\n/g, "\n");

    if (!projectId || !clientEmail || !privateKey) {
      throw new ServiceUnavailableException(
        "Firebase OAuth verification is not configured.",
      );
    }

    this.app = initializeApp({
      credential: cert({ projectId, clientEmail, privateKey }),
    });
    return this.app;
  }
}

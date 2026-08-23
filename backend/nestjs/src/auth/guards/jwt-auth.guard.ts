import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";
import { Reflector } from "@nestjs/core";
import { JwtService } from "@nestjs/jwt";
import { UserRole } from "@prisma/client";
import type { Request } from "express";
import { PrismaService } from "../../prisma/prisma.service";
import { IS_PUBLIC_KEY } from "../auth.constants";

interface JwtPayload {
  sub: string;
  role: UserRole;
}

interface RequestWithUser extends Request {
  user?: { id: string; role: UserRole };
}

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) return true;

    const request = context.switchToHttp().getRequest<RequestWithUser>();
    const token = this.extractBearerToken(request);
    if (!token) throw new UnauthorizedException("Missing bearer token.");

    try {
      const payload = await this.jwt.verifyAsync<JwtPayload>(token);
      const user = await this.prisma.user.findUnique({
        where: { id: payload.sub },
        select: { id: true, role: true, isActive: true },
      });
      if (!user?.isActive)
        throw new UnauthorizedException("User account is disabled.");
      request.user = { id: user.id, role: user.role };
      return true;
    } catch {
      throw new UnauthorizedException("Invalid or expired bearer token.");
    }
  }

  private extractBearerToken(request: Request): string | null {
    const value = request.headers.authorization;
    if (!value) return null;
    const [type, token] = value.split(" ");
    return type?.toLowerCase() === "bearer" && token ? token : null;
  }
}

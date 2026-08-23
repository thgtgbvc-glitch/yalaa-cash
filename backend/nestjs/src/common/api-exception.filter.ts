import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from "@nestjs/common";
import { Prisma } from "@prisma/client";
import type { Request, Response } from "express";

interface ApiErrorBody {
  statusCode: number;
  code: string;
  message: string;
  details?: unknown;
  path: string;
  timestamp: string;
}

@Catch()
export class ApiExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(ApiExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();
    const body = this.toErrorBody(exception, request);

    if (body.statusCode >= 500) {
      this.logger.error(
        body.message,
        exception instanceof Error ? exception.stack : undefined,
      );
    }

    response.status(body.statusCode).json(body);
  }

  private toErrorBody(exception: unknown, request: Request): ApiErrorBody {
    if (exception instanceof HttpException) {
      const statusCode = exception.getStatus();
      const raw = exception.getResponse();
      const message =
        typeof raw === "object" && raw !== null && "message" in raw
          ? Array.isArray((raw as { message: unknown }).message)
            ? (raw as { message: string[] }).message.join(", ")
            : String((raw as { message: unknown }).message)
          : exception.message;

      return {
        statusCode,
        code: this.codeFromStatus(statusCode),
        message,
        details: typeof raw === "object" ? raw : undefined,
        path: request.url,
        timestamp: new Date().toISOString(),
      };
    }

    if (exception instanceof Prisma.PrismaClientKnownRequestError) {
      const statusCode =
        exception.code === "P2002"
          ? HttpStatus.CONFLICT
          : exception.code === "P2025"
            ? HttpStatus.NOT_FOUND
            : HttpStatus.BAD_REQUEST;
      return {
        statusCode,
        code: exception.code,
        message: "Database request failed.",
        details: exception.meta,
        path: request.url,
        timestamp: new Date().toISOString(),
      };
    }

    return {
      statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
      code: "internal_server_error",
      message: "Unexpected server error.",
      path: request.url,
      timestamp: new Date().toISOString(),
    };
  }

  private codeFromStatus(status: number): string {
    switch (status) {
      case HttpStatus.BAD_REQUEST:
        return "bad_request";
      case HttpStatus.UNAUTHORIZED:
        return "unauthorized";
      case HttpStatus.FORBIDDEN:
        return "forbidden";
      case HttpStatus.NOT_FOUND:
        return "not_found";
      case HttpStatus.CONFLICT:
        return "conflict";
      default:
        return status >= 500 ? "server_error" : "request_error";
    }
  }
}

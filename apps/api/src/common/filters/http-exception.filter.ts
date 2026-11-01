import { ArgumentsHost, Catch, ExceptionFilter, HttpException, HttpStatus, Logger } from '@nestjs/common';
import type { Response } from 'express';

/** Consistent error envelope; never leaks stack traces. */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger('Exceptions');

  catch(exception: unknown, host: ArgumentsHost) {
    const res = host.switchToHttp().getResponse<Response>();
    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let code = 'INTERNAL_ERROR';
    let message = 'Something went wrong';

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const body = exception.getResponse();
      if (typeof body === 'string') {
        message = body;
        code = HttpStatus[status] ?? 'ERROR';
      } else {
        const b = body as { code?: string; message?: string | string[] };
        message = Array.isArray(b.message) ? b.message.join('; ') : (b.message ?? exception.message);
        code = b.code ?? HttpStatus[status] ?? 'ERROR';
      }
    } else {
      this.logger.error(exception instanceof Error ? exception.stack : String(exception));
    }

    res.status(status).json({ success: false, error: { code, message } });
  }
}

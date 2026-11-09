import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';
import { SkipThrottle } from '@nestjs/throttler';
import { PrismaService } from '../prisma/prisma.service';

/** For load balancers and orchestrators. Unauthenticated and never rate limited, so probes cannot be locked out. */
@Controller('health')
@SkipThrottle()
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

  /** Liveness: the process is up. Must not depend on anything else, or a database blip restarts healthy servers. */
  @Get()
  live() {
    return { status: 'ok' };
  }

  /** Readiness: safe to send traffic. Fails (503) if the database cannot answer. */
  @Get('ready')
  async ready() {
    try {
      await Promise.race([
        this.prisma.$queryRaw`SELECT 1`,
        new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 3000)),
      ]);
      return { status: 'ready' };
    } catch {
      throw new ServiceUnavailableException({ code: 'NOT_READY', message: 'Database unavailable' });
    }
  }
}

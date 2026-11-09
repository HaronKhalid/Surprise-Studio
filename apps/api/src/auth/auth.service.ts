import { ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Prisma } from '@prisma/client';
import * as argon2 from 'argon2';
import { createHash, randomBytes } from 'crypto';
import { AssetCleanupService } from '../assets/asset-cleanup.service';
import { PrismaService } from '../prisma/prisma.service';
import { LoginDto, RegisterDto } from './dto/auth.dto';

const ACCESS_TTL_SECONDS = 15 * 60;
const REFRESH_TTL_MS = 30 * 24 * 60 * 60 * 1000;

const sha256 = (v: string) => createHash('sha256').update(v).digest('hex');

/** A real argon2 hash of a random value, computed once, used to equalise login timing. */
let dummy: Promise<string> | undefined;
const dummyHash = () => (dummy ??= argon2.hash(randomBytes(16).toString('hex')));

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly cleanup: AssetCleanupService,
  ) {}

  async register(dto: RegisterDto) {
    const email = dto.email.toLowerCase();
    if (await this.prisma.user.findUnique({ where: { email } })) {
      throw new ConflictException({ code: 'EMAIL_TAKEN', message: 'Email is already registered' });
    }
    let user;
    try {
      user = await this.prisma.user.create({
        data: { email, passwordHash: await argon2.hash(dto.password), displayName: dto.displayName },
      });
    } catch (err) {
      // Two simultaneous sign-ups for one address: the unique index decides, not the check above.
      if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
        throw new ConflictException({ code: 'EMAIL_TAKEN', message: 'Email is already registered' });
      }
      throw err;
    }
    return { user: this.publicUser(user), ...(await this.issueTokens(user.id)) };
  }

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({ where: { email: dto.email.toLowerCase() } });
    // Always do one argon2 verification, so an unknown email takes as long as a wrong password
    // and response time cannot be used to find out which emails have accounts.
    const ok = await argon2.verify(user?.passwordHash ?? (await dummyHash()), dto.password).catch(() => false);
    if (!user || !ok) {
      throw new UnauthorizedException({ code: 'INVALID_CREDENTIALS', message: 'Incorrect email or password' });
    }
    return { user: this.publicUser(user), ...(await this.issueTokens(user.id)) };
  }

  /** Rotation: each refresh token is single-use. Reuse of a spent token revokes all sessions. */
  async refresh(refreshToken: string) {
    const record = await this.prisma.refreshToken.findUnique({ where: { tokenHash: sha256(refreshToken) } });
    if (!record) throw new UnauthorizedException({ code: 'INVALID_REFRESH_TOKEN', message: 'Invalid refresh token' });
    if (record.revokedAt) {
      await this.prisma.refreshToken.updateMany({
        where: { userId: record.userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      throw new UnauthorizedException({ code: 'REFRESH_TOKEN_REUSED', message: 'Session revoked, please log in again' });
    }
    if (record.expiresAt < new Date()) {
      throw new UnauthorizedException({ code: 'INVALID_REFRESH_TOKEN', message: 'Refresh token expired' });
    }
    await this.prisma.refreshToken.update({ where: { id: record.id }, data: { revokedAt: new Date() } });
    return this.issueTokens(record.userId);
  }

  async logout(refreshToken: string) {
    await this.prisma.refreshToken.updateMany({
      where: { tokenHash: sha256(refreshToken), revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  async me(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    // A valid access token can outlive its account (deleted within the last 15 minutes).
    if (!user) throw new UnauthorizedException({ code: 'INVALID_TOKEN', message: 'Account no longer exists' });
    return this.publicUser(user);
  }

  /**
   * Permanently deletes the account and everything it owns. Requires the password so a stolen
   * access token alone cannot do this. Photos are erased first; if that fails nothing else is
   * deleted, so the user can simply try again rather than leaving files behind.
   */
  async deleteAccount(userId: string, password: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new UnauthorizedException({ code: 'INVALID_TOKEN', message: 'Account no longer exists' });
    if (!(await argon2.verify(user.passwordHash, password).catch(() => false))) {
      throw new UnauthorizedException({ code: 'INVALID_CREDENTIALS', message: 'Incorrect password' });
    }
    await this.cleanup.deleteForUser(userId);
    // Cascades to surprises, assets and refresh tokens; analytics events are kept but detached.
    await this.prisma.user.delete({ where: { id: userId } });
  }

  private async issueTokens(userId: string) {
    const accessToken = await this.jwt.signAsync(
      { sub: userId },
      { secret: this.config.getOrThrow('JWT_SECRET'), expiresIn: ACCESS_TTL_SECONDS },
    );
    const refreshToken = randomBytes(48).toString('base64url');
    await this.prisma.refreshToken.create({
      data: { userId, tokenHash: sha256(refreshToken), expiresAt: new Date(Date.now() + REFRESH_TTL_MS) },
    });
    return { accessToken, refreshToken, expiresIn: ACCESS_TTL_SECONDS };
  }

  private publicUser(u: { id: string; email: string; displayName: string | null; avatarUrl: string | null }) {
    return { id: u.id, email: u.email, displayName: u.displayName, avatarUrl: u.avatarUrl };
  }
}

import { Body, Controller, Get, HttpCode, Post, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { AuthUser, CurrentUser } from '../common/decorators/current-user.decorator';
import { AuthService } from './auth.service';
import { LoginDto, RefreshDto, RegisterDto } from './dto/auth.dto';
import { JwtAuthGuard } from './jwt-auth.guard';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('register')
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  async register(@Body() dto: RegisterDto) {
    return { success: true, data: await this.auth.register(dto) };
  }

  @Post('login')
  @HttpCode(200)
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  async login(@Body() dto: LoginDto) {
    return { success: true, data: await this.auth.login(dto) };
  }

  @Post('refresh')
  @HttpCode(200)
  async refresh(@Body() dto: RefreshDto) {
    return { success: true, data: await this.auth.refresh(dto.refreshToken) };
  }

  @Post('logout')
  @HttpCode(200)
  async logout(@Body() dto: RefreshDto) {
    await this.auth.logout(dto.refreshToken);
    return { success: true, data: null };
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  async me(@CurrentUser() user: AuthUser) {
    return { success: true, data: await this.auth.me(user.id) };
  }
}

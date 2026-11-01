import { IsEmail, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class RegisterDto {
  @IsEmail() @MaxLength(254) email!: string;
  @IsString() @MinLength(8) @MaxLength(128) password!: string;
  @IsOptional() @IsString() @MaxLength(80) displayName?: string;
}

export class LoginDto {
  @IsEmail() email!: string;
  @IsString() @MaxLength(128) password!: string;
}

export class RefreshDto {
  @IsString() @MinLength(20) @MaxLength(256) refreshToken!: string;
}

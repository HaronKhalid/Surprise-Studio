import { PartialType } from '@nestjs/mapped-types';
import { Visibility } from '@prisma/client';
import { IsEnum, IsObject, IsOptional, IsString, IsUUID, MaxLength, MinLength } from 'class-validator';

export class CreateSurpriseDto {
  @IsOptional() @IsString() @MaxLength(40) occasion?: string;
  @IsString() @MinLength(1) @MaxLength(80) recipientName!: string;
  @IsOptional() @IsString() @MaxLength(80) recipientNickname?: string;
  @IsOptional() @IsString() @MaxLength(60) relationship?: string;
  @IsOptional() @IsString() @MaxLength(5000) message?: string;
  @IsOptional() @IsUUID() templateId?: string;
  @IsOptional() @IsObject() content?: Record<string, unknown>;
  @IsOptional() @IsObject() theme?: Record<string, unknown>;
  @IsOptional() @IsEnum(Visibility) visibility?: Visibility;
}

export class UpdateSurpriseDto extends PartialType(CreateSurpriseDto) {}

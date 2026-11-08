import { PartialType } from '@nestjs/mapped-types';
import { Visibility } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  MaxLength,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { HEX_COLOR } from '../../templates/template-config';

const hex = { message: 'must be a #rrggbb colour' };

/** Shape only. Which colours/fonts are allowed depends on the template and is checked in the service. */
export class ThemeColorsDto {
  @IsOptional() @Matches(HEX_COLOR, hex) background?: string;
  @IsOptional() @Matches(HEX_COLOR, hex) surface?: string;
  @IsOptional() @Matches(HEX_COLOR, hex) text?: string;
  @IsOptional() @Matches(HEX_COLOR, hex) accent?: string;
}

export class ThemeDto {
  @IsOptional() @ValidateNested() @Type(() => ThemeColorsDto) colors?: ThemeColorsDto;
  @IsOptional() @Matches(/^[a-z0-9-]{1,30}$/, { message: 'font must be a font key' }) font?: string;
}

export class MemoryDto {
  @IsOptional() @IsString() @MaxLength(80) title?: string;
  @IsString() @MinLength(1) @MaxLength(500) text!: string;
}

export class ContentDto {
  @IsOptional() @IsString() @MaxLength(300) intro?: string;
  @IsOptional() @IsString() @MaxLength(600) ending?: string;
  @IsOptional() @IsArray() @ArrayMaxSize(10) @ValidateNested({ each: true }) @Type(() => MemoryDto) memories?: MemoryDto[];
}

export class CreateSurpriseDto {
  @IsOptional() @IsString() @MaxLength(40) occasion?: string;
  @IsString() @MinLength(1) @MaxLength(80) recipientName!: string;
  @IsOptional() @IsString() @MaxLength(80) recipientNickname?: string;
  @IsOptional() @IsString() @MaxLength(60) relationship?: string;
  @IsOptional() @IsString() @MaxLength(5000) message?: string;
  @IsOptional() @IsUUID() templateId?: string;
  @IsOptional() @ValidateNested() @Type(() => ContentDto) content?: ContentDto;
  @IsOptional() @ValidateNested() @Type(() => ThemeDto) theme?: ThemeDto;
  @IsOptional() @IsEnum(Visibility) visibility?: Visibility;
}

export class UpdateSurpriseDto extends PartialType(CreateSurpriseDto) {}

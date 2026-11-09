import { Type } from 'class-transformer';
import { IsIn, IsOptional, IsString, Matches, ValidateNested } from 'class-validator';
import { EVENT_TYPES, EventType } from './event-types';

const TOKEN = /^[a-z0-9_-]{1,30}$/;

/** Three short tokens, nothing free-form: analytics must never become a place to stash personal data. */
export class EventMetadataDto {
  @IsOptional() @Matches(TOKEN) source?: string;
  @IsOptional() @Matches(TOKEN) template?: string;
  @IsOptional() @Matches(TOKEN) step?: string;
}

export class TrackEventDto {
  @IsIn(EVENT_TYPES) eventType!: EventType;
  /** Public slug of the surprise the event is about (web events). Unknown slugs are ignored. */
  @IsOptional() @IsString() @Matches(/^[A-Za-z0-9_-]{6,32}$/) slug?: string;
  @IsOptional() @ValidateNested() @Type(() => EventMetadataDto) metadata?: EventMetadataDto;
}
